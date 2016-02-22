defmodule Feeds do
  use Application

  @evmgr_name Feeds.EventManager
  @sup_name Feeds.Supervisor
  @repository_name Feeds.Repository

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # start a hackney pool
    :ok = :hackney_pool.start_pool(:fetcher_pool, [timeout: 10000, max_connections: 200])

    import Supervisor.Spec, warn: false

    children = [
      worker(GenEvent, [[name: @evmgr_name]]),
      worker(@repository_name, [[name: @repository_name]]),
      supervisor(@sup_name, [[name: @sup_name]]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Feeds.AppSupervisor]
    {:ok, pid} = Supervisor.start_link(children, opts) 
    Task.async(fn -> loadRepo() end)
    {:ok, pid}
  end

  # API
  # load all podcasts from the reposiotory and starts all fetching processes
  def loadRepo() do
    {:ok, docs} = Repository.all_podcasts @repository_name
    docs |> Enum.each(fn(pc) -> 
      Feeds.Podcast.Registry.start_podcast(pc)
    end)
    {:ok, :repo_loaded}
  end

  def addFeed(feed_url) do
    {:error, :not_implemented}
  end

  def search(serch_term) do
    []
  end

  def state do
    %{}
  end

end
