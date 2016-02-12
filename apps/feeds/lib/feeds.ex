defmodule Feeds do
  use Application

  @evmgr_name Feeds.EventManager
  @sup_name Feeds.Supervisor

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # start a hacknex pool
    :ok = :hackney_pool.start_pool(:fetcher_pool, [timeout: 10000, max_connections: 200])

    import Supervisor.Spec, warn: false

    children = [
      worker(GenEvent, [[name: @evmgr_name]]),
      supervisor(@sup_name, [[name: @sup_name]]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Feeds.AppSupervisor]
    Supervisor.start_link(children, opts)
  end
end
