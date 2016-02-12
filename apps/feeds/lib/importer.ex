defmodule Feeds.Importer do
  use Supervisor

  @pool_name :podcast_importer_pool
  @name Feeds.Importer

  def start(_) do
    poolboy_config = [
      {:name, {:local, @pool_name}},
      {:worker_module, Feeds.Importer.Worker},
      {:size, 250},
      {:max_overflow, 10}
    ]

    children = [
      :poolboy.child_spec(@pool_name, poolboy_config, [])
    ]

    options = [
      strategy: :one_for_one,
      name: @name
    ]

    Supervisor.start_link(children, options)
  end

  def init(_) do
    {:ok, %{}}
  end

  def import_urls(urls) do
    Enum.each(urls, fn(url) -> 
      spawn(fn() ->
        pool_import(url)
      end)
    end)
  end

  defp pool_import(url) do
    :poolboy.transaction(
      @pool_name,
      fn(pid) -> 
        Feeds.Importer.Worker.import(pid, url) end,
      :infinity
    )
  end

end