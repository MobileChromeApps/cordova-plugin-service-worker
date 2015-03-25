Cache = function(cacheName) {
    this.name = cacheName;
    return this;
};

Cache.prototype.match = function(request, options) {
  var cacheName = this.name;
  return new Promise(function(resolve, reject) {
    var encodeResponse = function(response) {
      if (response) {
        response = new Response(window.atob(response.body), response.url, response.status, response.headers);
      }
      return resolve(response);
    };
    // Call the native match function.
    cacheMatch(cacheName, request, options, encodeResponse, reject);
  });
};

Cache.prototype.matchAll = function(request, options) {
  var cacheName = this.name;
  return new Promise(function(resolve, reject) {
    var encodeResponses = function(responses) {
      if (responses instanceof Array) {
        var encodedResponses = [];
        for (var i=0; i < responses.length; ++i) {
          var response = responses[i];
          encodedReponses.push(new Response(window.atob(response.body), response.url, response.status, response.headers));
        }
        return resolve(encodedResponses);
      }
      return resolve(responses);
    };
    // Call the native matchAll function.
    cacheMatchAll(cacheName, request, options, encodeResponses, reject);
  });
};

Cache.prototype.add = function(request) {
  // Fetch a response for the given request, then put the pair into the cache.
  var cache = this;
  return fetch(request).then(function(response) {
    cache.put(request, response);
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
    cachePut(cacheName, request, response.toDict(), resolve, reject);
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
    // Convert the given request dictionaries to actual requests.
    var innerResolve = function(dicts) {
        var requests = [];
        for (var i=0; i<dicts.length; i++) {
            var requestDict = dicts[i];
            requests.push(new Request(requestDict.method, requestDict.url, requestDict.headers));
        }
        resolve(requests);
    };

    // Call the native keys function.
    cacheKeys(cacheName, request, options, innerResolve, reject);
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
    var encodeResponse = function(response) {
      if (response) {
        response = new Response(window.atob(response.body), response.url, response.status, response.headers);
      }
      return resolve(response);
    };
    // Call the native match function.
    cacheMatch(options && options.cacheName, request, options, encodeResponse, reject);
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

