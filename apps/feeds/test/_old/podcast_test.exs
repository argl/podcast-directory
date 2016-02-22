defmodule Feeds.PodcastTest do
  use ExUnit.Case, async: true

  alias Feeds.Podcast
  alias Feeds.Podcast.Meta
  use Timex

  defmodule Forwarder do
    use GenEvent
    def handle_event(event, parent) do
      send parent, event
      {:ok, parent}
    end
  end

  setup do
    {:ok, evmgr} = GenEvent.start_link
    GenEvent.add_mon_handler(evmgr, Forwarder, self())
    {:ok, evmgr: evmgr}
  end

  @tag skip: "old stuff"
  test "startup with events", %{evmgr: evmgr} do
    podcast_info = %Meta{}
    result = Podcast.start_link(podcast_info, evmgr)
    assert {:ok, podcast} = result
    assert is_pid(podcast)

    assert_receive {:podcast_start, ^podcast}    
  end

  @tag skip: "old stuff"
  test "stop with events", %{evmgr: evmgr} do
    podcast_info = %Meta{}
    {:ok, podcast} = Podcast.start_link(podcast_info, evmgr)

    assert match? :ok,  Podcast.stop(podcast)
    assert_receive {:podcast_stop, ^podcast}
  end

end