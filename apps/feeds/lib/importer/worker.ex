defmodule Feeds.Importer.Worker do
  use GenServer

  def start_link([]) do
    :gen_server.start_link(__MODULE__, [], [])
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(url, from, state) do
    #:timer.sleep(2000)
    {res, feed_id} = Feeds.FeedManager.try_feed(url)
    case res do
      :ok -> nil #IO.inspect feed_id
      _ -> nil # IO.inspect {url, res, feed_id}
    end

    IO.puts "Worker Reports: #{url} result is #{res}"
    {:reply, {res, feed_id}, state}
  end

  def import(pid, url) do
    :gen_server.call(pid, url)
  end

end