defmodule Feeds.PodcastRegistryTest do
  use ExUnit.Case, async: true

  alias Feeds.Podcast
  alias Feeds.Podcast.Registry
  alias Feeds.Podcast.Meta

  defmodule Forwarder do
    use GenEvent
    def handle_event(event, parent) do
      send parent, event
      {:ok, parent}
    end
  end

  setup do
    {:ok, sup} = Feeds.Podcast.Supervisor.start_link()
    {:ok, evmgr} = GenEvent.start_link()

    :random.seed(:os.timestamp)
    r = :random.uniform()
    name = String.to_atom "test_podcast_registry_name_#{r}"

    {:ok, registry} = Registry.start_link(sup, evmgr, [name: name])

    GenEvent.add_mon_handler(evmgr, Forwarder, self())
    {:ok, registry: registry}
  end

  @tag skip: "old stuff"
  test "start_podcast", %{registry: registry} do
    podcast_info = %Meta{_id: "test"}
    assert match? {:ok, "test"}, Registry.start_podcast(registry, podcast_info)
    assert match? {:ok, "test"}, Registry.start_podcast(registry, podcast_info)

    podcast_info = %Meta{}
    assert match? {:error, :invalid_podcast_info}, Registry.start_podcast(registry, podcast_info)
  end

  @tag skip: "old stuff"
  test "sends events on create", %{registry: registry} do
    podcast_info = %Meta{_id: "test"}
    {_ok, id} = Registry.start_podcast(registry, podcast_info)
    {:ok, podcast} = Registry.get_podcast(registry, id)
    assert_receive {:podcast_registry_podcast_start, ^id, ^podcast}
  end

  @tag skip: "old stuff"
  test "sends events on exit", %{registry: registry} do
    podcast_info = %Meta{_id: "test"}
    {:ok, id} = Registry.start_podcast(registry, podcast_info)
    {:ok, pid} = Registry.get_podcast(registry, id)
    {:ok, :stopped} = Registry.stop_podcast(registry, id)   
    assert_receive {:podcast_registry_podcast_exit, ^id, ^pid}
  end

  @tag skip: "old stuff"
  test "get_podcast", %{registry: registry} do
    podcast_info = %Meta{_id: "test"}
    {:ok, id} = Registry.start_podcast(registry, podcast_info)

    {:ok, pid} = Registry.get_podcast(registry, id)
    assert is_pid(pid)
    {:ok, pid2} = Registry.get_podcast(registry, id)
    assert pid == pid2

    assert match? :error, Registry.get_podcast(registry, "non existing id")

    podcast_info = %Meta{_id: "test2"}
    {:ok, id2} = Registry.start_podcast(registry, podcast_info)
    {:ok, pid2} = Registry.get_podcast(registry, id2)
    assert id != id2
    assert pid != pid2
  end

  @tag skip: "old stuff"
  test "stop_podcast", %{registry: registry} do
    podcast_info = %Meta{_id: "test"}
    {:ok, id} = Registry.start_podcast(registry, podcast_info)
    {:ok, pid} = Registry.get_podcast(registry, id)
    assert is_pid(pid)

    assert match? {:ok, :stopped}, Registry.stop_podcast(registry, id)
    assert match? :error, Registry.get_podcast(registry, id)
  end

  @tag skip: "old stuff"
  test "stop_all", %{registry: registry} do
    podcast_info = %Meta{_id: "test"}
    {:ok, id} = Registry.start_podcast(registry, podcast_info)
    podcast_info = %Meta{_id: "test2"}
    {:ok, id2} = Registry.start_podcast(registry, podcast_info)

    assert match? {:ok, :all_stopped}, Registry.stop_all(registry)
    assert_receive :podcast_registry_all_stopped
    assert match? :error, Registry.get_podcast(registry, id)
    assert match? :error, Registry.get_podcast(registry, id2)
  end

  @tag skip: "old stuff"
  test "removes podcast on exit", %{registry: registry} do
    {:ok, id} = Registry.start_podcast(registry, %Meta{_id: "test"})
    {:ok, pid} = Registry.get_podcast(registry, id)
    Podcast.stop(pid)
    assert_receive {:podcast_registry_podcast_exit, ^id, ^pid}
    assert match? :error, Registry.get_podcast(registry, id)
  end

  @tag skip: "old stuff"
  test "removes podcast on crash", %{registry: registry} do
    {:ok, id} = Registry.start_podcast(registry, %Meta{_id: "test"})
    {:ok, podcast} = Registry.get_podcast(registry, id)

    Process.exit(podcast, :shutdown)
    assert_receive {:podcast_registry_podcast_exit, ^id, ^podcast}
    assert match? :error, Registry.get_podcast(registry, id)
  end

end