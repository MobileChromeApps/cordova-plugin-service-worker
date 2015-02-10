Cache = function(cacheName) {
    this.name = cacheName;
    return this;
};

Cache.prototype.match = function(request, options) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    // Call the native match function.
    cacheMatch(cacheName, request, options, resolve, reject);
  });
};

Cache.prototype.matchAll = function(request, options) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    // Call the native matchAll function.
    cacheMatchAll(cacheName, request, options, resolve, reject);
  });
};

Cache.prototype.add = function(request) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    // Call the native add function.
    cacheAdd(cacheName, request, resolve, reject);
  });
};

Cache.prototype.addAll = function(requests) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    // Call the native addAll function.
    cacheAddAll(cacheName, requests, resolve, reject);
  });
};

Cache.prototype.put = function(request, response) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    // Call the native put function.
    cachePut(cacheName, request, response, resolve, reject);
  });
};

Cache.prototype.delete = function(request, options) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    // Call the native delete function.
    cacheDelete(cacheName, request, options, resolve, reject);
  });
};

Cache.prototype.keys = function(request, options) {
  var cacheName = this.cacheName;
  return new Promise(function(resolve, reject) {
    // Call the native keys function.
    cacheKeys(cacheName, request, options, resolve, reject);
  });
};


CacheStorage = function() {
    this.cacheNameList = [];
    return this;
};

// This function returns a promise for a response.
CacheStorage.prototype.match = function(request, options) {
  return new Promise(function(resolve, reject) {
    // Call the native match function.
    cacheMatch(options.cacheName, request, options, resolve, reject);
  });
};

CacheStorage.prototype.has = function(cacheName) {
  var cacheNameList = this.cacheNameList;
  return new Promise(function(resolve, reject) {
    // Check if the cache name is in the list.
    resolve(cacheNameList.indexOf(cacheName) >= 0);
  });
};

CacheStorage.prototype.open = function(cacheName) {
  var cacheNameList = this.cacheNameList;
  return new Promise(function(resolve, reject) {
    // Add to the list of cache names.
    cacheNameList.push(cacheName);

    // Create the cache in native and resolve the promise with a JS cache when done.
    openCache(cacheName, function() {
      resolve(new Cache(cacheName));
    });
  });
};

// This function returns a promise for a response.
CacheStorage.prototype.delete = function(cacheName) {
  var cacheNameList = this.cacheNameList;
  return new Promise(function(resolve, reject) {
    // Remove from the list of cache names.
    // Also, delete the cache in native and resolve the promise accordingly.
    var index = cacheNameList.indexOf(cacheName);
    if (index >= 0) {
      cacheNameList.splice(index, 1);
      deleteCache(cacheName, function() {
        resolve(true);
      });
    } else {
      resolve(false);
    }
  });
};

// This function returns a promise for a response.
CacheStorage.prototype.keys = function() {
  var cacheNameList = this.cacheNameList;
  return new Promise(function(resolve, reject) {
    // Resolve the promise with the cache name list.
    resolve(cacheNameList);
  });
};

var caches = new CacheStorage();

