function(doc) {
  var docuri = require('views/lib/docuri');
  var routes = require('views/lib/uris').uris(docuri);

  var r;

  if (r = routes.podcast_uri(doc._id)) {
    emit(doc._id, 0 )
  }

  if (r = routes.episode_uri(doc._id)) {
    emit(routes.podcast_uri({podcast_id: r.podcast_id}), 1 )
  }

  if (r = routes.media_uri(doc._id)) {
    emit(routes.podcast_uri({podcast_id: r.podcast_id}), 0 )
  }

  if (r = routes.feed_uri(doc._id)) {
    emit(routes.podcast_uri({podcast_id: r.podcast_id}), 0 )
  }

  // if (r = routes.check_uri(doc._id)) {
  //   emit(routes.podcast_uri({podcast_id: r.podcast_id}), 0 )
  // }

}
