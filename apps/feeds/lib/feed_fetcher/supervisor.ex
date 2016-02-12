defmodule Feeds.FeedFetcher.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def start_feed_fetcher(supervisor, feed_info, events) do
    Supervisor.start_child(supervisor, [feed_info, events])
  end

  def init(:ok) do
    children = [
      worker(Feeds.FeedFetcher, [], restart: :permanent)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end