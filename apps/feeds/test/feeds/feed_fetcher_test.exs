defmodule Feeds.FeedFetcherTest do
  use ExUnit.Case, async: false

  alias Feeds.FeedFetcher
  alias Feeds.FeedFetcher.FeedInfo
  use Timex

  defmodule Forwarder do
    use GenEvent
    def handle_event(event, parent) do
      send parent, event
      {:ok, parent}
    end
  end


  setup_all do
    # start a cowboy web server instance for us, serving some static content 
    dispatch = :cowboy_router.compile([
      {:_, [ 
        {'/[...]', :cowboy_static, {:dir, "test/fixtures", [{:mimetypes, {"application", "rss+xml", []} }]}}
      ]}
    ])
    :application.ensure_all_started(:cowboy)
    :cowboy.start_http(:http, 100, [port: 8081], [env: [dispatch: dispatch]])
    :ok
  end


  setup do
    # start up the podcast registry chain as well, for integration-y tests down below
    {:ok, sup} = Feeds.Podcast.Supervisor.start_link()
    {:ok, evmgr} = GenEvent.start_link()

    :random.seed(:os.timestamp)
    r = :random.uniform()
    name = String.to_atom "test_registry_name_#{r}"
    
    {:ok, podcast_registry} = Feeds.Podcast.Registry.start_link(sup, evmgr, [name: name])
    
    GenEvent.add_mon_handler(evmgr, Forwarder, self())
    
    {:ok, evmgr: evmgr, podcast_registry: podcast_registry}
  end


  test "startup with events", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{}

    result = FeedFetcher.start_link(feed_info, evmgr, podcast_registry)
    assert {:ok, feed_fetcher} = result
    assert is_pid(feed_fetcher)

    assert_receive {:feed_fetcher_start, ^feed_fetcher}    
  end

  test "stop with events", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{}
    {:ok, feed_fetcher} = FeedFetcher.start_link(feed_info, evmgr, podcast_registry)

    assert match? :ok,  FeedFetcher.stop(feed_fetcher)
    assert_receive {:feed_fetcher_stop, ^feed_fetcher}
  end

  test "data accessors", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{}
    {:ok, feed_fetcher} = FeedFetcher.start_link(feed_info, evmgr, podcast_registry)
    timer = FeedFetcher.timer(feed_fetcher)
    assert is_reference(timer)

    events = FeedFetcher.events(feed_fetcher)
    assert is_pid(events)
    assert events == evmgr

    feed_info = FeedFetcher.feed_info(feed_fetcher)
    assert match? %FeedInfo{}, feed_info

  end

  test "schedule fetching immediately if last_checked = nil and interval = nil", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{}
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    # at this point, teh fetcher should have been scheduled <interval> into the future
    timer = FeedFetcher.timer(feed_fetcher)
    time = :erlang.read_timer(timer)
    assert time <= 60 * 15 * 1000
    assert time >= 60 * 15 - 1000

    # also, the last_check should be pretty much now
    now = Date.universal
    last_check = FeedFetcher.feed_info(feed_fetcher).last_check
    assert Date.diff(last_check, now, :secs) < 2
  end

  test "schedule fetching immediately if last_checked plus interval is in the past", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    last_check = Date.from({2010,1,1})
    interval = 600
    feed_info = %FeedInfo{last_check: last_check, interval: interval}
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    # at this point, teh fetcher should have been scheduled <interval> into the future
    timer = FeedFetcher.timer(feed_fetcher)
    time = :erlang.read_timer(timer)
    assert time <= interval * 1000
    assert time >= (interval * 1000) - 1000
    
    # also, the last_check should be pretty much now
    now = Date.universal
    last_check = FeedFetcher.feed_info(feed_fetcher).last_check
    assert Date.diff(last_check, now, :secs) < 2
  end

  test "schedule fetching in the future if last_checked plus interval is in the future", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    last_check = Date.universal
    interval = 600
    feed_info = %FeedInfo{last_check: last_check, interval: interval}
    {:ok, feed_fetcher} = FeedFetcher.start_link(feed_info, evmgr, podcast_registry)

    refute_receive {:feed_fetcher_update_begin, ^feed_fetcher}
    refute_receive {:feed_fetcher_update_end, ^feed_fetcher}
    timer = FeedFetcher.timer(feed_fetcher)
    time = :erlang.read_timer(timer)
    assert time <= interval * 1000
    # assume that less than 1 sec passed since we started the fetcher
    assert time >= (interval * 1000) - 1000
  end

  test "sets error correctly if no url in feed info", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{}
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    assert :no_url == FeedFetcher.error(feed_fetcher)
  end

  test "parses a feed successfully", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{ url: "http://localhost:8081/example.xml" }
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    assert :nil == FeedFetcher.error(feed_fetcher)
    assert "feed/localhost-8081-example.xml" == FeedFetcher.feed_info(feed_fetcher)._id
  end

  test "reports on network errors", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{ url: "http://localhost:63210/example.xml" }
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    assert :econnrefused = FeedFetcher.error(feed_fetcher)
  end

  test "reports on non-200 status", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{ url: "http://localhost:8081/404.xml" }
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    assert "non-200: 404" = FeedFetcher.error(feed_fetcher)
  end

  test "reports self ref errors", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{ url: "http://localhost:8081/example_self_ref_differs.xml" }
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    assert match? {:self_ref_differs, "http://localhost:8081/example.xml"}, FeedFetcher.error(feed_fetcher)
  end

  test "reports self paged errors", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{ url: "http://localhost:8081/example_not_first_page.xml" }
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    assert match? {:first_page_differs, "http://localhost:8081/example.xml"}, FeedFetcher.error(feed_fetcher)
  end


  # check the podcast agent stuff
  @tag skip: "podcast is not set any ore, rewoked architecture"
  test "parses a feed successfully and sets the podcast", %{evmgr: evmgr, podcast_registry: podcast_registry} do
    feed_info = %FeedInfo{ url: "http://localhost:8081/example.xml" }
    feed_fetcher = assert_feed_and_trigger feed_info, evmgr, podcast_registry

    podcast_id = FeedFetcher.feed_info(feed_fetcher).podcast_id

    assert {:ok, podcast} = Feeds.Podcast.Registry.get_podcast(podcast_registry, podcast_id)
    assert is_pid(podcast)

    podcast_info = Feeds.Podcast.podcast(podcast)
    assert podcast_info.title == "Podcast Title"
    assert podcast_info.subtitle == "Itunes Subtitle"
    assert podcast_info.summary == "Itunes Summary"
    assert podcast_info.link == "http://localhost:8081/"
    assert podcast_info.generator == "Generator"
    assert podcast_info.last_build_date == "2015-11-12T22:47:30+00:00"
    assert podcast_info.publication_date == nil
    assert podcast_info.description == "Podcast Description"
    assert podcast_info.author == "Itunes Author"
    assert podcast_info.language == "de-DE"
    assert podcast_info.copyright == nil
    assert podcast_info.category == "Itunes Category"
    assert podcast_info.rating == nil
    assert podcast_info.managing_editor == nil
    assert podcast_info.web_master == nil
    assert podcast_info.image == %PodcastFeeds.Image{
      description: nil, height: nil, link: "http://podcast.example.com/",
      title: "Podcast Image Title", url: "http://localhost:8081/podcast-image.jpg", 
      width: nil
    }
    assert podcast_info.explicit == false

    assert length(podcast_info.episodes) == 2

  end



  # little helper

  defp assert_feed_and_trigger(feed_info, evmgr, podcast_registry) do
    {:ok, feed_fetcher} = FeedFetcher.start_link(feed_info, evmgr, podcast_registry)
    assert_receive {:feed_fetcher_update_begin, ^feed_fetcher}
    assert_receive {:feed_fetcher_update_end, ^feed_fetcher}, 1_000
    feed_fetcher
  end

  # test "get" do
  #   assert_response HTTPoison.get("localhost:8080/deny")
  #   assert_response HTTPoison.get("localhost:8080/deny"), fn(response) ->
  #     IO.inspect response.status_code
  #     assert :erlang.size(response.body) == 197
  #   end
  # end

  # @feed_url "http://cre.fm/feed/m4a/"

  # setup do
  #   HTTPoison.start
  #   {:ok, feed} = Feeds.FeedFetcher.start_link(@feed_url)
  #   {:ok, feed: feed}
  # end

  # test "set a url and fetch it", %{feed: feed} do
  #   assert {:ok, title} = Feeds.FeedFetcher.update(feed)
  #   assert title == "CRE: Technik, Kultur, Gesellschaft"
  #   assert Feeds.FeedFetcher.url(feed) == @feed_url
  #   assert Feeds.FeedFetcher.error(feed) == nil
  #   assert Feeds.FeedFetcher.feed(feed).meta.title == "CRE: Technik, Kultur, Gesellschaft"
  #   assert length(Feeds.FeedFetcher.feed(feed).entries) > 0
  # end

  # test "persist it", %{feed: feed} do
  #   assert {:ok, title} = Feeds.FeedFetcher.update(feed)
  #   assert {:ok, "podcast/cre-technik-kultur-gesellschaft/feed/http-cre-fm-feed-m4a"} = Feeds.FeedFetcher.persist(feed)
  # end


  # test "multiple instances" do
  # end

  # defp assert_response({:ok, response}, function \\ nil) do
  #   assert is_list(response.headers)
  #   assert response.status_code == 200
  #   assert is_binary(response.body)
  #   unless function == nil, do: function.(response)
  # end

end