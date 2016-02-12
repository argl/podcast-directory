defmodule Feeds.Podcast.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def start_podcast(supervisor, podcast, events) do
    Supervisor.start_child(supervisor, [podcast, events])
  end

  def init(:ok) do
    children = [
      worker(Feeds.Podcast, [], restart: :permanent)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end