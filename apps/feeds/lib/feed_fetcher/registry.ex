defmodule Feeds.FeedFetcher.Registry do
  use GenServer

  @name __MODULE__

  alias Feeds.FeedFetcher.FeedInfo
  alias Feeds.FeedFetcher

  ## CLient API
  def start_link(sup, evmgr, opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)
    GenServer.start_link(__MODULE__, %{sup: sup, evmgr: evmgr}, opts)
  end

  def stop(name \\ @name) do
    GenServer.call(name, :stop)
  end


  def start_feed(name \\ @name, %FeedInfo{}=feed_info) do
    GenServer.call(name, {:start_feed, feed_info})
  end

  def stop_feed(name \\ @name, id) do
    GenServer.call(name, {:stop_feed, id})
  end 

  def stop_all(name \\ @name) do
    GenServer.call(name, :stop_all)
  end

  def get_feed(name \\ @name, id) do
    GenServer.call(name, {:get_feed, id})
  end



  ## Server Callbacks
  def init(%{sup: sup, evmgr: evmgr}) do
    ids = Map.new
    refs = Map.new
    {:ok, %{ids: ids, refs: refs, sup: sup, evmgr: evmgr}} #, events: events, feed_fetchers: feed_fetchers}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:start_feed, %FeedInfo{_id: id}=_feed_info}, _from, state) when is_nil(id) do
    {:reply, {:error, :invalid_feed_info}, state}
  end
  def handle_call({:start_feed, %FeedInfo{_id: id}=feed_info}, _from, state) do
    if Map.has_key?(state.ids, id) do
      {:reply, {:ok, id}, state}
    else
      {:ok, pid} = Feeds.FeedFetcher.Supervisor.start_feed_fetcher(state.sup, feed_info, state.evmgr)
      ref = Process.monitor(pid)
      refs = Map.put(state.refs, ref, id)
      ids = Map.put(state.ids, id, pid)
      GenEvent.sync_notify(state.evmgr, {:feed_registry_feed_start, id, pid})
      {:reply, {:ok, id}, %{state | ids: ids, refs: refs}}
    end
  end

  def handle_call({:stop_feed, id}, _from, state) do
    case Map.fetch(state.ids, id) do
      {:ok, feed_fetcher} -> 
        FeedFetcher.stop(feed_fetcher)
        state = %{state | ids: Map.delete(state.ids, id)}
        {:reply, {:ok, :stopped}, state}
      {:error, _} ->
        {:reply, {:ok, :wasnt_running}, state}
    end
  end

  def handle_call(:stop_all, _from, state) do
    state = Enum.reduce state.ids, state, fn({id, _}, acc) ->
      {:ok, feed_fetcher} = Map.fetch(state.ids, id)
      FeedFetcher.stop(feed_fetcher)
      %{acc | ids: Map.delete(acc.ids, id)}
    end
    {:reply, {:ok, :all_stopped}, state}
  end

  def handle_call({:get_feed, id}, _from, state) do
    {:reply, Map.fetch(state.ids, id), state}
  end


  # this handlles our map bookkeeping since all fetchers
  # inform us about their ending.
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    {id, refs} = Map.pop(state.refs, ref)
    ids = Map.delete(state.ids, id)
    GenEvent.sync_notify(state.evmgr, {:feed_registry_feed_exit, id, pid})
    if Map.size(ids) == 0 do
      GenEvent.sync_notify(state.evmgr, :feed_registry_all_stopped)
    end

    {:noreply, %{state | ids: ids, refs: refs}}
  end

  # handle the catch-all case otherwise our supervisor will
  # crash when we receive random messages from anywhere
  def handle_info(_msg, state) do
    {:noreply, state}
  end

end