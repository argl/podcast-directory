defmodule Feeds.Repository do
  use GenServer
  use Timex

  alias Couch.Client

  @name __MODULE__

  alias Feeds.Podcast

  ## CLient API
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)
    GenServer.start_link(__MODULE__, [], opts)
  end

  def stop(name \\ @name) do
    GenServer.call(name, :stop)
  end

  def all_podcasts(name \\ @name) do
    GenServer.call(name, :all_podcasts)
  end
  def podcast_by_id(name \\ @name, id) do
    GenServer.call(name, {:podcast, id})
  end
  def feed_by_url(name \\ @name, url) do
    GenServer.call(name, {:feed_by_url, url})
  end
  def insert(name \\ @name, doc) do
    GenServer.call(name, {:insert, doc})
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


  def handle_call(:all_podcasts, _from, state) do
    {:ok, res} = Client.fetch_view(state.db, "base", "podcasts-by-podcast-id", [
      reduce: false, 
      include_docs: true
    ])
    docs = res.rows 
    |> Enum.map(fn(row) ->
      decode_document(Feeds.Podcast.Meta, row.doc)
    end)

    {:reply, {:ok, docs}, state}
  end

  def handle_call({:podcast_by_id, id}, _from, state) do
    {:ok, res} = Client.fetch_view(state.db, "base", "podcast_by_podcast_id", [
      reduce: false,
      key: id,
      include_docs: true,
      limit: 1
    ])
    case res.rows do
      [] -> 
        {:reply, {:error, :not_found}, state}
      [doc] ->
        {:reply, {:ok, decode_document(Feeds.Podcast.Meta, doc)}, state}
    end
  end


  def handle_call({:feed_by_url, url}, _from, state) do
    {:ok, res} = Client.fetch_view(state.db, "base", "feeds-by-url", [
      reduce: false,
      key: url,
      include_docs: true,
      limit: 1
    ])
    case res.rows do
      [] -> 
        {:reply, {:error, :not_found}, state}
      [doc] ->
        {:reply, {:ok, decode_document(Feeds.FeedFetcher.FeedInfo, doc)}, state}
    end
  end

  def handle_call({:insert, doc}, _from, state) do
    # get rev from existing
    doc = case Client.open_doc(state.db, doc._id) do
      {:ok, doc} -> %{doc | _rev: doc._rev}
      {:error, _} -> doc
    end
    encoded = encode_feed_info(doc)
    # IO.inspect encoded
    {:ok, [resp]} = Client.save_docs(state.db, [encoded])
    doc = %{doc | _rev: resp.rev}
    {:reply, {:ok, doc}, state}
  end




  defp decode_document(struct, document) do
    struct(struct, document)
  end


  defp encode_feed_info(feed_info) do
    feed_info |> encode_timestamp_fields([:last_check])
  end

  defp encode_timestamp_fields(feed_info, fields) do
    Enum.reduce(fields, feed_info, fn(field, feed_info) -> 
      Map.put(feed_info, field, Feeds.Utils.Time.iso_date(Map.get(feed_info, field)))
    end)
  end


end