function(doc) {
  var docuri = require('views/lib/docuri');
  var routes = require('views/lib/uris').uris(docuri);

  var r;

  if (r = routes.podcast_uri(doc._id)) {
    emit(doc.title.toLowerCase(), doc.title)
  }

}
