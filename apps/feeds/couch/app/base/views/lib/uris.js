exports.uris = function(docuri) {
  routes = {
    podcast_uri  : docuri.route('podcast/:podcast_id'),
    feed_uri     : docuri.route('podcast/:podcast_id/feed/:feed_id'),
    check_uri    : docuri.route('podcast/:podcast_id/feed/:feed_id/check/:check_id'),
    episode_uri  : docuri.route('podcast/:podcast_id/episode/:episode_id'),
    media_uri    : docuri.route('podcast/:podcast_id/episode/:episode_id/media/:media_id')
  }
  return routes
}


