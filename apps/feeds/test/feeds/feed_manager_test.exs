defmodule Feeds.FeedManagerTest do
  use ExUnit.Case, async: true

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

  test "try a working feed" do
    {res, feed_id} = FeedManager.try_feed "http://localhost:8081/example.xml"
    assert res == :ok
    assert "podcast/localhost-8081/feed/localhost-8081-example.xml" == feed_id
  end

  test "try a non-existent feed" do
    {res, feed_fetcher} = FeedManager.try_feed "http://localhost:8081/no-feed-here.xml"
    assert res == :error
    assert feed_fetcher == "non-200: 404"
  end

  test "try an already started feed" do
    {_, existing_feed_id} = FeedManager.try_feed "http://localhost:8081/example.xml"

    {:ok, feed_id} = FeedManager.try_feed "http://localhost:8081/example.xml"
    assert existing_feed_id == feed_id
  end

  test "make sure the feed is registered and will poll again in the future" do
    {:ok, feed_id} = FeedManager.try_feed "http://localhost:8081/example.xml"
    {res, fetcher} = Feeds.FeedFetcher.Registry.get_feed(feed_id)
    assert res == :ok
    assert is_pid(fetcher)

    timer = Feeds.FeedFetcher.timer(fetcher)
    millis_until_fire = Process.read_timer(timer)
    feed_info = Feeds.FeedFetcher.feed_info(fetcher)

    assert millis_until_fire <= feed_info.interval * 1000
  end

  @tag skip: "podcast is not set any ore, rewoked architecture"
  test "make sure the podcast is registered" do
    {:ok, feed_id} = FeedManager.try_feed "http://localhost:8081/example.xml"
    {:ok, fetcher} = Feeds.FeedFetcher.Registry.get_feed(feed_id)

    podcast_id = Feeds.FeedFetcher.feed_info(fetcher).podcast_id
    {res, podcast} = Feeds.Podcast.Registry.get_podcast(podcast_id)
    assert res == :ok

    assert is_pid(podcast)
    podcast_info = Feeds.Podcast.podcast(podcast)
    assert %Feeds.Podcast.PodcastInfo{_id: ^podcast_id} = podcast_info
  end


end
