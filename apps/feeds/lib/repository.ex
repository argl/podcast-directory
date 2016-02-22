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





  defp decode_document(struct, document) do
    struct(struct, document)
    # %FeedInfo{
    #   _id: doc._id,
    #   _rev: doc._rev,
    #   title: doc.title,
    #   url: doc.url,
    #   format: doc.format,
    #   new_feed_url: doc.new_feed_url,
    #   error: doc.error,
    #   last_check: doc.last_check |> DateFormat.parse("{ISO}"),
    #   interval: doc.interval,
    #   podcast_id: doc.podcast_id
    # }
  end

end