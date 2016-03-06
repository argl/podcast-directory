defmodule Feeds.FeedManager do

  alias Feeds.FeedFetcher
  use Timex

  alias Feeds.Repository

  @podcast_registry_name Feeds.Podcast.Registry
  @feed_fetcher_registry_name Feeds.FeedFetcher.Registry
  @evmgr_name Feeds.EventManager

  # either {:ok, feed_fetcher_pid} or {:error, reason}
  defp ensure_feed(url) do
    ensure_feed(url, 0)
  end
  defp ensure_feed(url, retries) when retries > 5 do
    {:error, :too_many_redirects_from_canonical_url}
  end
  defp ensure_feed(url, retries) do
    # check if we have the feed in the database
    case Repository.feed_by_url(url) do
      {:ok, feed} -> 
        podcast_id = feed.podcast_id
        Podcast.Registry.get_podcast(podcast_id)
      {:error, :not_found} ->
        # if not, try to get the data
        case get_feed_data(url) do
          {:error, reason} -> 
            {:error, reason}
          {:ok, feed_data} -> 
            # parse the feed and pin the real url
            case PodcastFeeds.parse feed_data do
              {:error, reason} -> {:error, reason}
              {:ok, feed} ->
                real_url = canonical_url(url, feed)
                if real_url == url do
                  # the url is canonical, it seems new.

                  # check if we got an existing podcast fitting to our feed
                  podcast_id = "podcast/" <> Feeds.Utils.Id.make(feed.meta.link)
                  podcast = case Repository.podcast_by_id do
                    {:error, :not_found} ->
                      pc = podcast_from_feed(feed)
                      {:ok, podcast} = Respository.insert(pc)
                    {:ok, podcast} ->
                      podcast
                  end

                  feed_info = %Feeds.FeedFetcher.FeedInfo{ 
                    url: url, 
                    interval: 3600, 
                    _id: "feed/" <> Feeds.Utils.Id.make(url),
                    last_check: Date.universal
                  }
                  {:ok, feed_info} = Repository.insert(feed_info)

                  Podcast.Registry.start_podcast(podcast)

                  # {:ok, feed_id} = Feeds.FeedFetcher.Registry.start_feed(feed_info)
                  # {:ok, fetcher} = Feeds.FeedFetcher.Registry.get_feed(feed_id)
                  # {:ok, fetcher}
                else
                  # the canonical url differs, so try with the real url
                  ensure_feed(real_url, retries + 1)
                end
            end
        end
    end
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

  defp podcast_from_feed(feed) do
    podcast_id = "podcast/" <> Feeds.Utils.Id.make(feed.meta.link)
    episodes = feed.entries |> Enum.reverse |> entry(feed, podcast_id)

    %Feeds.Podcast.Meta{
      _id: podcast_id,
      title: feed.meta.title,
      subtitle: feed.meta.itunes.subtitle,
      summary: feed.meta.itunes.summary,
      link: feed.meta.link,
      # generator: feed.meta.generator,
      # last_build_date: Feeds.Utils.Time.iso_date(feed.meta.last_build_date),
      # publication_date: Feeds.Utils.Time.iso_date(feed.meta.publication_date),
      description: feed.meta.description,
      author: feed.meta.author || feed.meta.itunes.author,
      language: feed.meta.language,
      copyright: feed.meta.copyright,
      categories: if(feed.meta.categories != [], do: feed.meta.categories, else: feed.meta.itunes.categories),
      managing_editor: feed.meta.managing_editor,
      web_master: feed.meta.web_master,
      image: feed.meta.image,
      explicit: feed.meta.itunes.explicit || false,
      #atom_links_remove_me: state.feed.meta.atom_links,
      episodes: episodes
    }
  end

end


