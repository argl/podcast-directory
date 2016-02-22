defmodule Feeds.Podcast do

  use GenServer
  use Timex

  defmodule Meta do
    defstruct _id: nil,
      _rev: nil,
      #pd_type: "podcast",
      title: nil,
      subtitle: nil,
      summary: nil,
      link: nil,
      #generator: nil,
      #last_build_date: nil,
      #publication_date: nil,
      description: nil,
      author: nil,
      language: nil,
      copyright: nil,
      categories: [],
      rating: nil,
      managing_editor: nil,
      web_master: nil,
      image: nil,
      explicit: false,
      episodes: []
  end

  defmodule Episode do
    defstruct _id: nil,
      _rev: nil,
      #pd_type: "episode",
      sorter: nil,
      title: nil,
      subtitle: nil,
      link: nil,
      publication_date: nil,
      description: nil,
      author: nil,
      duration: nil,
      summary: nil,
      image: nil,
      categories: [],
      guid: nil,
      source: nil,
      chapters: [],
      atom_links: [],
      media: [],
      explicit: false
  end

  defmodule Media do
    defstruct _id: nil,
      _rev: nil,
      #pd_type: "media",
      url: nil,
      type: nil,
      length: nil
  end

  defmodule State do
    defstruct podcast: nil,
      events: nil
  end


  ## Client API

  def start_link(%Meta{}=podcast, events, opts \\ []) do
    GenServer.start_link(__MODULE__, %{podcast: podcast, events: events}, opts)
  end

  def stop(podcast) do
    GenServer.call(podcast, :stop)
  end

  def events(podcast) do
    GenServer.call(podcast, :events)
  end
  def podcast(podcast) do
    GenServer.call(podcast, :podcast)
  end

  ## Server Callbacks

  def init(args) do
    podcast = args.podcast
    events = args.events
    GenEvent.notify(events, {:podcast_start, self()})
    state = %State{podcast: podcast, events: events}
    {:ok, state}
  end

  def handle_call(:stop, _from, state) do
    GenEvent.notify(state.events, {:podcast_stop, self()})
    {:stop, :normal, :ok, state}
  end

  def handle_call(:events, _from, state) do
    {:reply, state.events, state}
  end

  def handle_call(:podcast, _from, state) do
    {:reply, state.podcast, state}
  end

end


