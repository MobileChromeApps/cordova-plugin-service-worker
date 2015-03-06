Cache = function(cacheName) {
    this.name = cacheName;
    return this;
};

Cache.prototype.match = function(request, options) {
  var cacheName = this.name;
  return new Promise(function(resolve, reject) {
    // Call the native match function.
    cacheMatch(cacheName, request, options, resolve, reject);
  });
};

Cache.prototype.matchAll = function(request, options) {
  var cacheName = this.name;
  return new Promise(function(resolve, reject) {
    // Call the native matchAll function.
    cacheMatchAll(cacheName, request, options, resolve, reject);
  });
};

Cache.prototype.add = function(request) {
  var cache = this;
  return new Promise(function(resolve, reject) {
    // This resolve function takes a response and calls `put` with it (and the request).
    // Then it calls the given resolve function.
    var innerResolve = function(response) {
      cache.put(request, response).then(resolve, reject);
    }

    // Call the native add function.
    cacheAdd(cache.name, request, innerResolve, reject);
  });
};

Cache.prototype.addAll = function(requests) {
  // Create a list of `add` promises, one for each request.
  var promiseList = [];
  for (var i=0; i<requests.length; i++) {
    promiseList.push(this.add(requests[i]));
  }

  // Return a promise for all of the `add` promises.
  return Promise.all(promiseList);
};

Cache.prototype.put = function(request, response) {
  var cacheName = this.name;
  return new Promise(function(resolve, reject) {
    // Call the native put function.
    cachePut(cacheName, request, response, resolve, reject);
  });
};

Cache.prototype.delete = function(request, options) {
  var cacheName = this.name;
  return new Promise(function(resolve, reject) {
    // Call the native delete function.
    cacheDelete(cacheName, request, options, resolve, reject);
  });
};

Cache.prototype.keys = function(request, options) {
  var cacheName = this.name;
  return new Promise(function(resolve, reject) {
    // Call the native keys function.
    cacheKeys(cacheName, request, options, resolve, reject);
  });
};


CacheStorage = function() {
    // TODO: Consider JS cache name caching solutions, such as a list of cache names and a flag for whether we have fetched from CoreData yet.
    // Right now, all calls except `open` go to native.
    return this;
};

// This function returns a promise for a response.
CacheStorage.prototype.match = function(request, options) {
  return new Promise(function(resolve, reject) {
    // Call the native match function.
    cacheMatch(options && options.cacheName, request, options, resolve, reject);
  });
};

CacheStorage.prototype.has = function(cacheName) {
  return new Promise(function(resolve, reject) {
    // Check if the cache exists in native.
    cachesHas(cacheName, resolve, reject);
  });
};

CacheStorage.prototype.open = function(cacheName) {
  return new Promise(function(resolve, reject) {
    // Resolve the promise with a JS cache.
    resolve(new Cache(cacheName));
  });
};

// This function returns a promise for a response.
CacheStorage.prototype.delete = function(cacheName) {
  return new Promise(function(resolve, reject) {
    // Delete the cache in native.
    cachesDelete(cacheName, resolve, reject);
  });
};

// This function returns a promise for a response.
CacheStorage.prototype.keys = function() {
  return new Promise(function(resolve, reject) {
    // Resolve the promise with the cache name list.
    cachesKeys(resolve, reject);
  });
};

var caches = new CacheStorage();

