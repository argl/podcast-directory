function(doc) {
  var docuri = require('views/lib/docuri');
  var routes = require('views/lib/uris').uris(docuri);

  var r;

  if (r = routes.podcast_uri(doc._id)) {
    emit([r.podcast_id], 0)
  }

  if (r = routes.episode_uri(doc._id)) {
    emit([r.podcast_id, r.episode_id], 1 )
  }

  if (r = routes.media_uri(doc._id)) {
    emit([r.podcast_id, r.episode_id, r.media_id], 0)
  }

}
