defmodule Feeds.FeedManagerTest do
  use ExUnit.Case, async: false

  alias Feeds.FeedManager

  setup_all do
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
    Feeds.Podcast.Registry.stop_all
    Feeds.FeedFetcher.Registry.stop_all
    :ok
  end

  # test "try a working feed" do
  #   {res, feed_id} = FeedManager.try_feed "http://localhost:8081/example.xml"
  #   assert res == :ok
  #   assert "feed/localhost-8081-example.xml" == feed_id
  # end

  test "ensure a working feed" do
    {res, feed} = FeedManager.ensure_feed "http://localhost:8081/example.xml"
    assert res == :ok
    assert is_pid(feed)
  end

  test "ensure a non-existent feed" do
    {res, feed} = FeedManager.ensure_feed "http://localhost:8081/no-feed-here.xml"
    assert res == :error
    assert feed == "non-200: 404"
  end

  test "ensure an already started feed" do
    {_, existing_feed} = FeedManager.ensure_feed "http://localhost:8081/example.xml"

    {:ok, feed} = FeedManager.ensure_feed "http://localhost:8081/example.xml"
    assert existing_feed == feed
  end

  test "ensure the feed is registered and will poll again in the future" do
    url = "http://localhost:8081/example.xml"
    {:ok, feed} = FeedManager.ensure_feed url
    x = Feeds.FeedFetcher.feed_info(feed)
    feed_id = x._id
    {res, fetcher} = Feeds.FeedFetcher.Registry.get_feed(feed_id)
    assert res == :ok
    assert is_pid(fetcher)
    assert fetcher == feed

    timer = Feeds.FeedFetcher.timer(fetcher)
    millis_until_fire = Process.read_timer(timer)
    feed_info = Feeds.FeedFetcher.feed_info(fetcher)

    assert millis_until_fire <= feed_info.interval * 1000
  end

end
