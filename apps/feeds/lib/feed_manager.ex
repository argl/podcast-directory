defmodule Feeds.FeedManager do

  alias Feeds.FeedFetcher
  use Timex


  @podcast_registry_name Feeds.Podcast.Registry
  @feed_fetcher_registry_name Feeds.FeedFetcher.Registry
  @evmgr_name Feeds.EventManager

  # either {:ok, feed_fetcher_pid} or {:error, reason}
  def ensure_feed(url) do
    ensure_feed(url, 0)
  end
  def ensure_feed(url, retries) when retries > 5 do
    {:error, :too_many_redirects_from_canonical_url}
  end
  def ensure_feed(url, retries) do
    # check if we have the feed in the database
    case check_for_existing_feed(url) do
      {:ok, fetcher} -> {:ok, fetcher}
      :error ->
        # if not, try to get the data
        case get_feed_data(url) do
          {:error, reason} -> {:error, reason}
          {:ok, feed_data} -> 
            # parse the feed and pin the real url
            case PodcastFeeds.parse feed_data do
              {:error, reason} -> {:error, reason}
              {:ok, feed} ->
                real_url = canonical_url(url, feed)
                if real_url == url do
                  # the url is canonical, it seems new, so start it
                  feed_info = %Feeds.FeedFetcher.FeedInfo{ 
                    url: url, 
                    interval: 3600, 
                    _id: "feed/" <> Feeds.Utils.Id.make(url),
                    last_check: Date.universal
                  }

                  Feeds.FeedFetcher.Repository.insert_async(feed_info)
                  {:ok, feed_id} = Feeds.FeedFetcher.Registry.start_feed(feed_info)
                  {:ok, fetcher} = Feeds.FeedFetcher.Registry.get_feed(feed_id)
                  {:ok, fetcher}
                else
                  # the canonical url differs, so try with the real url
                  ensure_feed(real_url, retries + 1)
                end
            end
        end
    end
  end
  
  defp check_for_existing_feed(url) do
    id = "feed/" <> Feeds.Utils.Id.make(url)
    Feeds.FeedFetcher.Registry.get_feed(id)
  end

  defp get_feed_data(url) do
    case :hackney.get(url, ["User-Agent": "podcast-directory-fetcher-1.0--we-come-in-peace"], "", 
      [follow_redirect: true, max_redirect: 10, recv_timeout: 30000]) do
        {:ok, 200, _, ref} ->
          case :hackney.body(ref) do
            {:error, err} -> {:error, err} # <- this is where receive timeouts end up, i.e. the server sends the data too slow
            {:ok, body} -> {:ok, body}
          end
        {:ok, non_200_status, _headers, ref} ->
          {:error, "non-200: #{non_200_status}"}
        {:error, err} ->
          {:error, err}
        error ->
          {:error, "unknown #{inspect error}"}
    end
  end

  defp href_from_atom_by_rel(atom_links, rel, default) do
    atom_links
    |> Enum.find_value(default, fn(al) ->
      al.rel == rel && al.href && al.href != "" && al.href
    end)
  end

  defp canonical_url(url, feed) do
    atom_links = feed.meta.atom_links
    self_url = href_from_atom_by_rel(atom_links, "self", nil)
    first_url = href_from_atom_by_rel(atom_links, "first", nil)
    case {first_url, self_url, url == first_url, url == self_url} do
      {nil, nil, _, _} -> url
      {nil, _self_url, _, true} -> url
      {nil, self_url, _, false} -> self_url
      {_first_url, _, true, _} -> url
      {first_url, _, false, _} -> first_url
    end
  end

end


