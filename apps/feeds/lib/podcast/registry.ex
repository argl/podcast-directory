defmodule Feeds.Podcast.Registry do
  use GenServer

  @name __MODULE__

  ## CLient API
  def start_link(sup, evmgr, opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)
    GenServer.start_link(__MODULE__, %{sup: sup, evmgr: evmgr}, opts)
  end

  def stop(name \\ @name) do
    GenServer.call(name, :stop)
  end


  def start_podcast(name \\ @name, %Feeds.Podcast.PodcastInfo{}=podcast_info) do
    GenServer.call(name, {:start_podcast, podcast_info})
  end

  def stop_podcast(name \\ @name, id) do
    GenServer.call(name, {:stop_podcast, id})
  end 

  def stop_all(name \\ @name) do
    GenServer.call(name, :stop_all)
  end

  def get_podcast(name \\ @name, id) do
    GenServer.call(name, {:get_podcast, id})
  end

  # debug
  def state(name \\ @name) do
    GenServer.call(name, :state)
  end




  ## Server Callbacks
  def init(%{sup: sup, evmgr: evmgr}) do
    ids = Map.new
    refs = Map.new
    {:ok, %{ids: ids, refs: refs, sup: sup, evmgr: evmgr}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:start_podcast, %Feeds.Podcast.PodcastInfo{_id: id}=_podcast_info}, _from, state) when is_nil(id) do
    {:reply, {:error, :invalid_podcast_info}, state}
  end
  def handle_call({:start_podcast, %Feeds.Podcast.PodcastInfo{_id: id}=podcast_info}, _from, state) do
    if Map.has_key?(state.ids, id) do
      {:reply, {:ok, id}, state}
    else
      {:ok, pid} = Feeds.Podcast.Supervisor.start_podcast(state.sup, podcast_info, state.evmgr)
      ref = Process.monitor(pid)
      refs = Map.put(state.refs, ref, id)
      ids = Map.put(state.ids, id, pid)
      GenEvent.sync_notify(state.evmgr, {:podcast_registry_podcast_start, id, pid})
      {:reply, {:ok, id}, %{state | ids: ids, refs: refs}}
    end
  end

  def handle_call({:stop_podcast, id}, _from, state) do
    case Map.fetch(state.ids, id) do
      {:ok, podcast} -> 
        Feeds.Podcast.stop(podcast)
        state = %{state | ids: Map.delete(state.ids, id)}
        {:reply, {:ok, :stopped}, state}
      {:error, _} ->
        {:reply, {:ok, :wasnt_running}, state}
    end
  end

  def handle_call(:stop_all, _from, state) do
    state = Enum.reduce state.ids, state, fn({id, _}, acc) ->
      {:ok, podcast} = Map.fetch(state.ids, id)
      Feeds.Podcast.stop(podcast)
      %{acc | ids: Map.delete(acc.ids, id)}
    end
    {:reply, {:ok, :all_stopped}, state}
  end

  def handle_call({:get_podcast, id}, _from, state) do
    {:reply, Map.fetch(state.ids, id), state}
  end

  # debug
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end



  # this handlles our map bookkeeping since all processes
  # inform us about their ending.
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    {id, refs} = Map.pop(state.refs, ref)
    ids = Map.delete(state.ids, id)
    GenEvent.sync_notify(state.evmgr, {:podcast_registry_podcast_exit, id, pid})
    if Map.size(ids) == 0 do
      GenEvent.sync_notify(state.evmgr, :podcast_registry_all_stopped)
    end
    {:noreply, %{state | ids: ids, refs: refs}}
  end

  # handle the catch-all case otherwise our supervisor will
  # crash when we receive random messages from anywhere
  def handle_info(_msg, state) do
    {:noreply, state}
  end

end