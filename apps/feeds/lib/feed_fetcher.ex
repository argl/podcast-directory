defmodule Feeds.FeedFetcher do

  use GenServer
  use Timex



  defmodule FeedInfo do
    defstruct _id: nil,
      _rev: nil,
      pd_type: "feed",
      title: nil,
      url: nil,
      format: nil,
      new_feed_url: nil,
      error: nil,
      last_check: nil,
      interval: nil,
      podcast_id: nil
  end

  defmodule FetcherState do
    defstruct feed_info: nil,
      events: nil,
      podcast_registry: nil,
      repo: nil,
      feed: nil,
      error: nil,
      timer: nil
  end


  ## Client API

  @podcast_registry_name Feeds.Podcast.Registry
  @evmgr_name Feeds.EventManager
  @feed_fetcher_repository_name Feeds.FeedFetcher.Repository

  def start_link(%FeedInfo{}=feed_info, 
    events \\ @evmgr_name, 
    podcast_registry \\ @podcast_registry_name,
    repo \\ @feed_fetcher_repository_name,
    opts \\ []) do
    GenServer.start_link(__MODULE__, %{
      feed_info: feed_info, 
      events: events, 
      podcast_registry: podcast_registry,
      repo: repo
    }, opts)
  end

  def stop(feed_fetcher) do
    GenServer.call(feed_fetcher, :stop)
  end

  def update(feed_fetcher) do
    GenServer.call(feed_fetcher, :update)
  end


  def events(feed_fetcher) do
    GenServer.call(feed_fetcher, :events)
  end
  def timer(feed_fetcher) do
    GenServer.call(feed_fetcher, :timer)
  end
  def feed_info(feed_fetcher) do
    GenServer.call(feed_fetcher, :feed_info)
  end
  def error(feed_fetcher) do
    GenServer.call(feed_fetcher, :error)
  end
  #debug
  def state(feed_fetcher) do
    GenServer.call(feed_fetcher, :state)
  end


  # def persist(feed_fetcher) do
  #   GenServer.call(feed_fetcher, :persist)
  # end

  ## Server Callbacks

  def init(args) do
    feed_info = args.feed_info
    events = args.events
    podcast_registry = args.podcast_registry
    interval = feed_info.interval || (60 * 15) # 15 minutes default for now
    feed_info = %FeedInfo{feed_info | interval: interval}
    now = Date.universal
    timer = case feed_info.last_check do
      nil -> Process.send_after(self(), :trigger, 10)
      last_check ->
        case Date.compare(Date.shift(last_check, secs: interval), now, :secs) do
          1 -> 
            i = Date.diff(now, Date.shift(last_check, secs: interval), :secs)
            Process.send_after(self(), :trigger, i * 1000)
          _running_late ->
            Process.send_after(self(), :trigger, 10)
        end
    end
    GenEvent.notify(events, {:feed_fetcher_start, self()})
    state = %FetcherState{feed_info: feed_info, timer: timer, events: events, podcast_registry: podcast_registry}
    {:ok, state}
  end

  # def handle_call(:update, _from, state) do
  #   do_update(state)
  # end

  # def handle_call(:persist, _from, state) do
  #   do_persist(state)
  # end

  def handle_call(:events, _from, state) do
    {:reply, state.events, state}
  end
  def handle_call(:timer, _from, state) do
    {:reply, state.timer, state}
  end
  def handle_call(:feed_info, _from, state) do
    {:reply, state.feed_info, state}
  end
  def handle_call(:error, _from, state) do
    {:reply, state.error, state}
  end

  # debug 
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end


  def handle_call(:stop, _from, state) do
    GenEvent.notify(state.events, {:feed_fetcher_stop, self()})
    {:stop, :normal, :ok, state}
  end


  # actual fetch trigger
  def handle_info(:trigger, state) do
    GenEvent.notify(state.events, {:feed_fetcher_update_begin, self()})
    feed_info = state.feed_info

    # this contraption should be rewritten to form
    # an orderly pipeline.
    {error, feed} = case feed_info.url do
      nil -> {:no_url, state.feed}
      _url -> case fetch(feed_info) do
        {:ok, xml} ->
          case PodcastFeeds.parse(xml) do
            {:ok, feed} ->
              case check_refs_in_feed(state.feed_info, feed) do
                :ok -> 
                  {nil, feed} # feed should be alright here, all else is defensive digging
                {reason, url} -> 
                  {{reason, url}, state.feed}
                err ->
                  {err, state.feed}
              end          
            {:error, reason} ->
              {reason, state.feed}
          end
        {:error, reason} ->
          {reason, state.feed}
      end
    end

    feed_info = case error do
      nil ->
        # set the format to the format of the first entry
        format = case feed.entries do
          [] -> :unknown
          [first | _] -> 
            if first.enclosure && first.enclosure.type do
              first.enclosure.type
            else
              :unknown
            end
        end
        %FeedInfo{feed_info | last_check: Date.universal, title: feed.meta.title, format: format}
      _ -> 
        %FeedInfo{feed_info | last_check: Date.universal}
    end


    # either carry over the podcast we already have in the state,
    # or get an updated version from our fetch data
    # podcast_id = feed_info.podcast_id
    # check memory usage first before attempting this
    # if feed && state.podcast_registry do
    #   podcast_info = podacst_info_from_feed(feed)
    #   {:ok, podcast_id} = Feeds.Podcast.Registry.start_podcast(state.podcast_registry, podcast_info)
    #   feed_info = %FeedInfo{feed_info | podcast_id: podcast_id}
    # end
    podcast_id = case feed do
      nil -> feed_info.podcast_id
      feed ->
        podcast_info = podacst_info_from_feed(feed)
        podcast_info._id
    end

    # also, create a proper id for ourselve
    if feed_info._id == nil && podcast_id != nil do
      feed_id = podcast_id <> "/feed/" <> Feeds.Utils.Id.make(feed_info.url)
      feed_info = %FeedInfo{feed_info | _id: feed_id}
    end

    # here is the spot to manipulate the interval value based on whatever data we have
    # currently, we just reschedule according to the set interval
    timer = Process.send_after(self(), :trigger, state.feed_info.interval * 1000)

    # persist ourselves
    Feeds.FeedFetcher.Repository.insert_async(@feed_fetcher_repository_name, feed_info)

    state = %FetcherState{state | error: error, timer: timer, feed_info: feed_info, feed: feed}

    GenEvent.notify(state.events, {:feed_fetcher_update_end, self()})
    {:noreply, state}
  end

  ## Private 

  defp entry(entries, feed, podcast_id) do
    entries 
    |> Enum.with_index 
    |> Enum.map(fn({entry, idx}) ->
      case entry.enclosure do
        nil -> 
          nil
        _ ->
          guid = entry.guid || "#{entry.title}-#{Feeds.Utils.Time.iso_date(entry.publication_date)}"

          enclosure = entry.enclosure
          media_id = "#{podcast_id}/episode/#{Feeds.Utils.Id.make(guid)}/media/#{Feeds.Utils.Id.make(enclosure.type)}"
          media_doc = %Feeds.Podcast.Media{
            _id: media_id,
            url: enclosure.url,
            type: enclosure.type,
            length: enclosure.length
          }
          # sort_string = :io_lib.format("~8..0B", [idx])
          # if !entry.guid do
          #   check_problems = ["Item with title #{entry.title} has no guid element." | check_problems]
          # end
          entry_id = "#{podcast_id}/episode/#{Feeds.Utils.Id.make(guid)}"

          entry_doc = %Feeds.Podcast.Episode{
            _id: entry_id,
            sorter: idx,
            title: entry.title,
            subtitle: entry.itunes.subtitle,
            link: entry.link,
            publication_date: Feeds.Utils.Time.iso_date(entry.publication_date),
            description: entry.description,
            author: entry.author || entry.itunes.author,
            duration: entry.itunes.duration,
            summary: entry.itunes.summary,
            image: entry.itunes.image_href,
            categories: entry.itunes.categories,
            # enclosure: entry.enclosure,
            guid: entry.guid,
            publication_date: Feeds.Utils.Time.iso_date(entry.publication_date),
            source: entry.source,
            #itunes: entry.itunes,
            chapters: entry.chapters, #Enum.map(entry.psc, fn(e) -> struct Feedme.Psc, e end),
            atom_links: entry.atom_links, #|> Enum.map(fn(e) -> Feedme.AtomLink |> struct(e) end),
            explicit: feed.meta.itunes.explicit || false,
            media: [media_doc]
          }
          entry_doc
      end
    end)
    |> Enum.filter(fn(e) -> e end)
  end

  defp podacst_info_from_feed(feed) do
    podcast_id = "podcast/" <> Feeds.Utils.Id.make(feed.meta.link)
    episodes = feed.entries |> Enum.reverse |> entry(feed, podcast_id)

    _podcast_info = %Feeds.Podcast.PodcastInfo{
      _id: podcast_id,
      title: feed.meta.title,
      subtitle: feed.meta.itunes.subtitle,
      summary: feed.meta.itunes.summary,
      link: feed.meta.link,
      generator: feed.meta.generator,
      last_build_date: Feeds.Utils.Time.iso_date(feed.meta.last_build_date),
      publication_date: Feeds.Utils.Time.iso_date(feed.meta.publication_date),
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

  defp href_from_atom_by_rel(atom_links, rel, default) do
    atom_links
    |> Enum.find_value(default, fn(al) ->
      al.rel == rel && al.href && al.href != "" && al.href
    end)
  end

  defp check_refs_in_feed(feed_info, feed) do
    atom_links = feed.meta.atom_links

    # rel=first has precedence over the rel=self, if there is any doubt

    self_url = href_from_atom_by_rel(atom_links, "self", nil)
    first_url = href_from_atom_by_rel(atom_links, "first", nil)

    case {first_url, self_url, feed_info.url == first_url, feed_info.url == self_url} do
      {nil, nil, _, _} -> :ok
      {nil, _self_url, _, true} -> :ok
      {nil, self_url, _, false} -> {:self_ref_differs, self_url}
      {_first_url, _, true, _} -> :ok
      {first_url, _, false, _} -> {:first_page_differs, first_url}
    end

    # case {feed_info.url == self_url, feed_info.url == paged_url} do
    #   {true, true} -> :ok
    #   {_, true} -> 
    #     {:self_ref_differs, self_url}
    #   {_, false} ->
    #     {:first_page_differs, paged_url}
    # end

    # case {feed_info.url == self_url} do
    #   {true} -> :ok
    #   {false} -> {:self_ref_differs, self_url}
    # end
  end


  defp fetch(feed_info) do
    case :hackney.get(feed_info.url, ["User-Agent": "podcast-directory-fetcher-1.0--we-come-in-peace"], "", 
      [follow_redirect: true, max_redirect: 10, pool: :fetcher_pool, recv_timeout: 30000]) do
        {:ok, 200, _, ref} ->
          case :hackney.body(ref) do
            {:error, err} -> {:error, err} # <- this is where receive timeouts end up, i.e. the server sends the data too slow
            {:ok, body} -> {:ok, body}
          end
        # {:ok, 307, headers, ref} ->
        #   case List.keyfind(headers, "Location", 0) do
        #     nil -> {:error, :http_temporary_redirect_without_location_header}
        #     {"Location", url} -> {:error, {:http_temporary_redirect, url}}
        #   end
        # {:ok, 301, headers, ref} ->
        #   case List.keyfind(headers, "Location", 0) do
        #     nil -> {:error, :http_permanent_redirect_without_location_header}
        #     {"Location", url} -> {:error, {:http_permanent_redirect, url}}
        #   end
        {:ok, non_200_status, _headers, ref} ->
          # {:ok, body} = :hackney.body(ref)
          # TODO this is shit, use a proper tuple
          {:error, "non-200: #{non_200_status}"}
        {:error, err} ->
          {:error, err}
        error ->
          {:error, "unknown #{inspect error}"}
    end

  end

  # defp iso_date(date) do
  #   case date do
  #     nil -> nil
  #     d -> DateFormat.format(d, "{ISO}") |> (fn {:ok, v} -> v end).()
  #   end
  # end

  # defp encode_json_param(v) do
  #   {:ok, v} = Poison.encode(v)
  #   v
  # end


  # defp do_persist(state) do
  #   case {state.feed, state.error} do
  #     {nil, nil} ->
  #       {:reply, :feed_not_fetched, state}
  #     {feed, nil} ->
  #       url = Application.get_env(:couch, :url)
  #       server = Client.server_connection url
  #       db = %Client.DB{server: server, name: Application.get_env(:couch, :db)}
  #       check_problems = []
  #       podcast_id = "podcast/" <> Feeds.Utils.Id.make(feed.meta.link) 

  #       podcast_doc = %Podcast{
  #         _id: podcast_id,
  #         title: state.feed.meta.title,
  #         subtitle: state.feed.meta.itunes.subtitle,
  #         summary: state.feed.meta.itunes.summary,
  #         link: state.feed.meta.link,
  #         generator: state.feed.meta.generator,
  #         last_build_date: iso_date(state.feed.meta.last_build_date),
  #         publication_date: iso_date(state.feed.meta.publication_date),
  #         description: state.feed.meta.description,
  #         author: state.feed.meta.author || state.feed.meta.itunes.author,
  #         language: state.feed.meta.language,
  #         copyright: state.feed.meta.copyright,
  #         category: state.feed.meta.category || state.feed.meta.itunes.category,
  #         managing_editor: state.feed.meta.managing_editor,
  #         web_master: state.feed.meta.web_master,
  #         image: state.feed.meta.image,
  #         explicit: state.feed.meta.itunes.explicit || false,
  #         #atom_links_remove_me: state.feed.meta.atom_links
  #       }
        

  #       feed_title = case Enum.find(state.feed.meta.atom_links, fn(a) -> a.rel == "self" end) do
  #         nil -> state.feed.meta.title
  #         link -> link.title
  #       end

  #       feed_url = case Enum.find(state.feed.meta.atom_links, fn(a) -> a.rel == "self" end) do
  #         nil -> state.url
  #         link -> link.href
  #       end

  #       feed_id = podcast_id <> "/feed/" <> Feeds.Utils.Id.make(feed_url)

  #       now = Date.universal

  #       format = case state.feed.entries do
  #         [] -> nil
  #         [entry | _] -> case entry.enclosure do
  #           nil -> nil
  #           encl -> encl.type
  #         end
  #       end

  #       feed_doc = %FeedInfo{
  #         _id: feed_id,
  #         title: feed_title,
  #         url: feed_url,
  #         #new_feed_url: state.feed.meta.itunes.new_feed_url,
  #         format: format,
  #         new_feed_url: nil,
  #         error: nil,
  #         last_check: iso_date(now),
  #       }

  #       {:ok, now_string} = now |> DateFormat.format("%Y%m%d%H%M%S", :strftime)

  #       # reverse the entire episodes collection, map to tuples with index and use the index as a sorter
  #       episode_and_media_docs = Enum.reverse state.feed.entries |> Enum.with_index |> Enum.map(fn({entry, idx}) ->
  #         case entry.enclosure do
  #           nil -> 
  #             nil
  #           _ ->
  #             # sort_string = :io_lib.format("~8..0B", [idx])
  #             if !entry.guid do
  #               check_problems = ["Item with title #{entry.title} has no guid element." | check_problems]
  #             end
  #             guid = entry.guid || "#{entry.title}-#{iso_date(entry.publication_date)}"
  #             entry_id = "#{podcast_id}/episode/#{Feeds.Utils.Id.make(guid)}"

  #             entry_doc = %Episode{
  #               _id: entry_id,
  #               sorter: idx,
  #               title: entry.title,
  #               subtitle: entry.itunes.subtitle,
  #               link: entry.link,
  #               publication_date: iso_date(entry.publication_date),
  #               description: entry.description,
  #               author: entry.author || entry.itunes.author,
  #               duration: entry.itunes.duration,
  #               summary: entry.itunes.summary,
  #               image: entry.itunes.image,
  #               category: entry.itunes.category,
  #               # enclosure: entry.enclosure,
  #               guid: entry.guid,
  #               publication_date: iso_date(entry.publication_date),
  #               source: entry.source,
  #               #itunes: entry.itunes,
  #               psc: entry.psc, #Enum.map(entry.psc, fn(e) -> struct Feedme.Psc, e end),
  #               atom_links: entry.atom_links, #|> Enum.map(fn(e) -> Feedme.AtomLink |> struct(e) end),
  #               explicit: state.feed.meta.itunes.explicit || false
  #             }

  #             enclosure = entry.enclosure
  #             media_id = "#{podcast_id}/episode/#{Feeds.Utils.Id.make(guid)}/media/#{Feeds.Utils.Id.make(enclosure.type)}"
  #             media_doc = %Media{
  #               _id: media_id,
  #               url: enclosure.url,
  #               type: enclosure.type,
  #               length: enclosure.length
  #             }
  #             [entry_doc, media_doc]
  #         end
  #       end) 
  #       |> List.flatten 
  #       |> Enum.filter(fn(e) -> e end)

  #       # check_doc_id = feed_id <> "/check/" <> Feeds.Utils.Id.make(now_string)
  #       # check_doc = %CheckResult{
  #       #   _id: check_doc_id,
  #       #   timestamp: iso_date(now),
  #       #   status: "test",
  #       #   info: check_problems
  #       # }

  #       # load existing documents
  #       {:ok, res} = Client.fetch_view(db, "base", "podcasts-by-podcast-id", [
  #         reduce: false, 
  #         key: encode_json_param(podcast_id),
  #         include_docs: true
  #       ])
  #       existing_docs = Enum.reduce res.rows, %{}, fn(row, acc) -> Map.put(acc, row.doc._id, row.doc) end

  #       existing_feed_doc = case Client.open_doc(db, feed_doc._id) do
  #         {:ok, doc} -> doc
  #         {:error, _} -> nil
  #       end
        
  #       if existing_feed_doc do
  #         existing_docs = Map.put(existing_docs, existing_feed_doc._id, existing_feed_doc)
  #       end
        
  #       # create missing documents or merge existing, see if anything changed
  #       docs_to_save = [podcast_doc | [ feed_doc | episode_and_media_docs]]
  #       docs_to_save = Enum.map(docs_to_save, fn(doc) -> 
  #         case existing_docs[doc._id] do
  #           nil ->
  #             # new document, save it without _rev
  #             doc
  #           existing_doc ->
  #             # update _rev in new doc
  #             doc = %{ doc | _rev: existing_doc._rev }
  #             # look for changes
  #             case Feeds.Utils.MapDiffEx.diff doc, existing_doc do
  #               nil ->
  #                 # no change, no doc
  #                 nil
  #               diff ->
  #                 #IO.inspect diff
  #                 doc
  #             end
  #         end
  #       end) |> Enum.filter(fn(e) -> e end) # filter out nil elements

  #       # add the check document to the mix
  #       # docs_to_save = [check_doc | docs_to_save]

  #       # TODO: find deleted data and delete it from the db
  #       # a.k.a. weed gone-missing entries

  #       if docs_to_save != [] do
  #         #IO.inspect docs_to_save
  #         {:ok, resp} = Client.save_docs(db, docs_to_save)
  #         error_responses = resp |> Enum.filter fn(e) -> e[:error] == "conflict" end
  #         IO.inspect error_responses

  #       end
  #       {:reply, {:ok, :saved}, state}
  #     _ ->
  #       {:reply, {:ok, :fetch_had_error}, state}
  #   end
  # end



end


