defmodule Feeds.FeedManager do

  alias Feeds.FeedFetcher

  @podcast_registry_name Feeds.Podcast.Registry
  @feed_fetcher_registry_name Feeds.FeedFetcher.Registry
  @evmgr_name Feeds.EventManager

  defmodule CompletionHandler do
    use GenEvent
    def handle_event(event, proc) do
      case event do
        {:feed_fetcher_update_end, fetcher} -> send proc, {:ok, fetcher}
        _ -> nil
      end
      {:ok, proc}
    end
  end

  def try_feed(url) do
    try_feed(url, 0)
  end

  def try_feed(url, retries) when retries > 5 do
    {:error, {:too_many_feed_url_redirects_on_self_or_first_page, url}}
  end
  def try_feed(url, retries) do
    feed_info = %Feeds.FeedFetcher.FeedInfo{ url: url, interval: 3600 }
    # create our checker event manager, install our event handler and start
    # the fetcher (unsupervised, just for checking)
    {:ok, evmgr} = GenEvent.start_link([])
    GenEvent.add_mon_handler(evmgr, CompletionHandler, self())
    
    {:ok, fetcher} = FeedFetcher.start_link(feed_info, evmgr)

    result = receive do
      {:ok, fetcher} -> {:ok, fetcher}
        # check if there was any error (awkward, but on running feeds errors could be transitional and should be ignored)
        case FeedFetcher.error(fetcher) do
          nil -> 
            # add feed to registry here
            # save data first
            feed_info = FeedFetcher.feed_info(fetcher)
            # stop our fetcher
            :ok = FeedFetcher.stop(fetcher)
            # re-start fetcher via feed registry and our data
            # this makes it supervised and using the global event managers
            {:ok, feed_id} = Feeds.FeedFetcher.Registry.start_feed(feed_info)
            {:ok, feed_id}
          err -> 
            FeedFetcher.stop(fetcher)
            {:error, err}
        end
    after
      120_000 -> 
        FeedFetcher.stop(fetcher)
        {:error, :timeout_on_fetcher}
    end
    # dont forget to stop our event menager
    GenEvent.stop(evmgr)
    # retry if possiblr, but keep a count of retries
    case result do
      {:error, {:self_ref_differs, real_url}} -> 
        # IO.puts "retrying because self ref differs: #{url} vs #{real_url} / #{retries}"
        try_feed(real_url, retries + 1)
      {:error, {:first_page_differs, real_url}} -> 
        # IO.puts "retrying because first page differs: #{url} vs #{real_url} / #{retries}"
        try_feed(real_url, retries + 1)
      # {:error, {:http_temporary_redirect, real_url}} -> 
      #   IO.puts "retrying because of temp redirect: #{url} vs #{real_url} / #{retries}"
      #   try_feed(real_url, retries + 1)
      res ->
        res
    end
  end

end


