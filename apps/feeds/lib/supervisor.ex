defmodule Feeds.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  # @feed_fetcher_sup_name Feeds.FeedFetcher.Supervisor
  # @feed_fetcher_registry_name Feeds.FeedFetcher.Registry

  @podcast_sup_name Feeds.Podcast.Supervisor
  @podcast_registry_name Feeds.Podcast.Registry

  @evmgr_name Feeds.EventManager


  def init(:ok) do
    children = [

      supervisor(@podcast_sup_name, [[name: @podcast_sup_name]]),
      worker(@podcast_registry_name, [@podcast_sup_name, @evmgr_name]),

      # worker(@feed_fetcher_repository_name, [[name: @feed_fetcher_repository_name]]),
      
      # supervisor(@feed_fetcher_sup_name, [[name: @feed_fetcher_sup_name]]),
      # worker(@feed_fetcher_registry_name, [@feed_fetcher_sup_name, @evmgr_name, [name: @feed_fetcher_registry_name]])
    ]

    supervise(children, strategy: :one_for_all)
  end
end