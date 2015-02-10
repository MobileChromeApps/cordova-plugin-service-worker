Cache = function(cacheName) {
    this.name = cacheName;
    return this;
};

Cache.prototype.put = function(request, response) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    put(cacheName, request, response, resolve, reject);
  });
};

CacheStorage = function() {
    return this;
};

// This function returns a promise for a response.
CacheStorage.prototype.match = function(request, options) {
  return new Promise(function(resolve, reject) {
    match(request, options, resolve, reject);
  });
};

CacheStorage.prototype.get = function(cacheName) {
  return new Cache(cacheName);
};

var caches = new CacheStorage();

