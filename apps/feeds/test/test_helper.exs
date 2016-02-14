# ExUnit.start([capture_log: true, assert_receive_timeout: 200, trace: true])
ExUnit.start()

defmodule Feeds.TestHelpers do
  alias Couch.Client

  def delete_db(dbname) do
    url = Application.get_env(:couch, :url)
    server = Client.server_connection url
    Client.delete_db(server, dbname)
  end

  def feed_info do
    %Feeds.FeedFetcher.FeedInfo{_id: "podcast/localhost-8081/feed/localhost-8081-example.xml",
     _rev: nil, error: nil, format: "audio/mp4", interval: 900,
     last_check: %Timex.DateTime{calendar: :gregorian, day: 9, hour: 23, minute: 33,
      month: 1, ms: 984, second: 41,
      timezone: %Timex.TimezoneInfo{abbreviation: "UTC", from: :min,
       full_name: "UTC", offset_std: 0, offset_utc: 0, until: :max}, year: 2016},
     new_feed_url: nil, pd_type: "feed", podcast_id: "podcast/localhost-8081",
     title: "Podcast Title", url: "http://localhost:8081/example.xml"}
  end

end