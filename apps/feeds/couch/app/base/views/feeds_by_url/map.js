function(doc) {
  var docuri = require('views/lib/docuri');
  var routes = require('views/lib/uris').uris(docuri);

  var r;

  if (r = routes.feed_uri(doc._id)) {
    emit(doc.url, 1)
  }
}
