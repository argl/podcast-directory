defmodule Feeds.FeedRegistryTest do
  use ExUnit.Case, async: true

  alias Feeds.FeedFetcher
  alias Feeds.FeedFetcher.Registry
  alias Feeds.FeedFetcher.FeedInfo


  # set up the event manager stuff, we 
  # test for event reception down below.
  defmodule Forwarder do
    use GenEvent
    def handle_event(event, parent) do
      send parent, event
      {:ok, parent}
    end
  end

  setup do
    {:ok, sup} = Feeds.FeedFetcher.Supervisor.start_link
    {:ok, evmgr} = GenEvent.start_link()

    :random.seed(:os.timestamp)
    r = :random.uniform()
    name = String.to_atom "test_fetcher_registry_name_#{r}"

    {:ok, registry} = Registry.start_link(sup, evmgr, [name: name])

    GenEvent.add_mon_handler(evmgr, Forwarder, self())
    {:ok, registry: registry}
  end


  test "start_feed", %{registry: registry} do
    feed_info = %FeedInfo{_id: "test", url: "http://test.at"}
    assert match? {:ok, "test"}, Registry.start_feed(registry, feed_info)
    assert match? {:ok, "test"}, Registry.start_feed(registry, feed_info)

    feed_info = %FeedInfo{}
    assert match? {:error, :invalid_feed_info}, Registry.start_feed(registry, feed_info)
  end

  test "sends events on create", %{registry: registry} do
    feed_info = %FeedInfo{_id: "test", url: "http://test.at"}
    {_ok, id} = Registry.start_feed(registry, feed_info)
    {:ok, feed_fetcher} = Registry.get_feed(registry, id)
    assert_receive {:feed_registry_feed_start, ^id, ^feed_fetcher}
  end

  test "sends events on exit", %{registry: registry} do
    feed_info = %FeedInfo{_id: "test", url: "http://test.at"}
    {:ok, id} = Registry.start_feed(registry, feed_info)
    {:ok, pid} = Registry.get_feed(registry, id)
    {:ok, :stopped} = Registry.stop_feed(registry, id)   
    assert_receive {:feed_registry_feed_exit, ^id, ^pid}
  end

  test "get_feed", %{registry: registry} do
    feed_info = %FeedInfo{_id: "test", url: "http://test.at"}
    {:ok, id} = Registry.start_feed(registry, feed_info)

    {:ok, pid} = Registry.get_feed(registry, id)
    assert is_pid(pid)
    {:ok, pid2} = Registry.get_feed(registry, id)
    assert pid == pid2

    assert match? :error, Registry.get_feed(registry, "non existing id")

    feed_info = %FeedInfo{_id: "test2", url: "http://test.at"}
    {:ok, id2} = Registry.start_feed(registry, feed_info)
    {:ok, pid2} = Registry.get_feed(registry, id2)
    assert id != id2
    assert pid != pid2
  end

  test "stop_feed", %{registry: registry} do
    feed_info = %FeedInfo{_id: "test", url: "http://test.at"}
    {:ok, id} = Registry.start_feed(registry, feed_info)
    {:ok, pid} = Registry.get_feed(registry, id)
    assert is_pid(pid)

    assert match? {:ok, :stopped}, Registry.stop_feed(registry, id)
    assert match? :error, Registry.get_feed(registry, id)
  end

  test "stop_all", %{registry: registry} do
    feed_info = %FeedInfo{_id: "test", url: "http://test.at"}
    {:ok, id} = Registry.start_feed(registry, feed_info)
    feed_info = %FeedInfo{_id: "test2", url: "http://test.at"}
    {:ok, id2} = Registry.start_feed(registry, feed_info)

    assert match? {:ok, :all_stopped}, Registry.stop_all(registry)
    assert_receive :feed_registry_all_stopped
    assert match? :error, Registry.get_feed(registry, id)
    assert match? :error, Registry.get_feed(registry, id2)
  end

  test "removes feed fetchers on exit", %{registry: registry} do
    {:ok, id} = Registry.start_feed(registry, %FeedInfo{_id: "test", url: "http://test.at"})
    {:ok, pid} = Registry.get_feed(registry, id)
    FeedFetcher.stop(pid)
    assert_receive {:feed_registry_feed_exit, ^id, ^pid}
    assert match? :error, Registry.get_feed(registry, id)
  end

  test "removes feed fetcher on crash", %{registry: registry} do
    {:ok, id} = Registry.start_feed(registry, %FeedInfo{_id: "test", url: "http://test.at"})
    {:ok, feed_fetcher} = Registry.get_feed(registry, id)

    Process.exit(feed_fetcher, :shutdown)
    assert_receive {:feed_registry_feed_exit, ^id, ^feed_fetcher}
    assert match? :error, Registry.get_feed(registry, id)
  end

end