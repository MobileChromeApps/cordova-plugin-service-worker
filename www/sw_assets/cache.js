CacheStorage = function() {
    return this;
};

// This function returns a promise for a response.
CacheStorage.prototype.match = function(request, options) {
  return new Promise(function(resolve, reject) {
    match(request, options, resolve, reject);
  });
};

var caches = new CacheStorage();

