defmodule Feeds.FeedFetcher.Repository do
  use GenServer
  use Timex

  alias Couch.Client


  @name __MODULE__

  alias Feeds.FeedFetcher.FeedInfo

  ## CLient API
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)
    GenServer.start_link(__MODULE__, [], opts)
  end

  def stop(name \\ @name) do
    GenServer.call(name, :stop)
  end


  def insert(name \\ @name, %FeedInfo{}=feed_info) do
    GenServer.call(name, {:insert, feed_info})
  end

  def insert_async(name \\ @name, %FeedInfo{}=feed_info) do
    GenServer.cast(name, {:insert, feed_info})
  end

  def one(name \\ @name, id) do
    GenServer.call(name, {:one, id})
  end

  def all(name \\ @name, options \\ %{}) do
    GenServer.call(name, {:all, options})
  end


  ## Server Callbacks
  def init(_) do
    url = Application.get_env(:couch, :url)
    server = Client.server_connection url
    db = %Client.DB{server: server, name: Application.get_env(:couch, :db)}
    {:ok, %{db: db}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:insert, %FeedInfo{_id: nil} = feed_info}, _from, state) do
    {:reply, {:error, :no_id}, state}
  end
  def handle_call({:insert, feed_info}, _from, state) do
    # get rev from existing
    feed_info = case Client.open_doc(state.db, feed_info._id) do
      {:ok, doc} -> %FeedInfo{feed_info | _rev: doc._rev}
      {:error, _} -> feed_info
    end
    encoded = encode_feed_info(feed_info)
    # IO.inspect encoded
    {:ok, [resp]} = Client.save_docs(state.db, [encoded])
    feed_info = %FeedInfo{feed_info | _rev: resp.rev}
    {:reply, {:ok, feed_info}, state}
  end

  def handle_call({:one, _id}, _from, state) do
    {:reply, {:ok, %FeedInfo{}}, state}
  end

  def handle_call({:all, _options}, _from, state) do
    {:ok, res} = Client.fetch_view(state.db, "base", "feeds-by-id", [
      reduce: false, 
      include_docs: true
    ])
    docs = res.rows 
    |> Enum.map(fn(row) ->
      decode_feed_info(row.doc)
    end)

    {:reply, {:ok, docs}, state}
  end



  def handle_cast({:insert, %FeedInfo{_id: nil} = feed_info}, state) do
    {:noreply, state}
  end
  def handle_cast({:insert, feed_info}, state) do
    # get rev from existing
    feed_info = case Client.open_doc(state.db, feed_info._id) do
      {:ok, doc} -> %{feed_info | _rev: doc._rev}
      {:error, _} -> feed_info
    end
    encoded = encode_feed_info(feed_info)
    case Client.save_docs(state.db, [encoded]) do
      {:ok, [resp]} -> 
        {:noreply, state}
      {:error, reason} -> 
        Client.open_doc(state.db, feed_info._id)
        |> IO.inspect
        {:noreply, state}
    end
    {:noreply, state}
  end



  # handle the catch-all case otherwise our supervisor will
  # crash when we receive random messages from anywhere
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp decode_feed_info(doc) do
    %FeedInfo{
      _id: doc._id,
      _rev: doc._rev,
      title: doc.title,
      url: doc.url,
      format: doc.format,
      new_feed_url: doc.new_feed_url,
      error: doc.error,
      last_check: doc.last_check |> DateFormat.parse("{ISO}"),
      interval: doc.interval,
      podcast_id: doc.podcast_id
    }
  end

  defp encode_feed_info(feed_info) do
    feed_info |> encode_timestamp_fields([:last_check])
  end

  defp encode_timestamp_fields(feed_info, fields) do
    # IO.inspect iso_date(Map.get(feed_info, :last_check))
    Enum.reduce(fields, feed_info, fn(field, feed_info) -> 
      Map.put(feed_info, field, Feeds.Utils.Time.iso_date(Map.get(feed_info, field)))
    end)
  end


end