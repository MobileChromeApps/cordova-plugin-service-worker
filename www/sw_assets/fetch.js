FetchEvent = function(eventInitDict) {
  Event.call(this, 'fetch');
  if (eventInitDict) {
    if (eventInitDict.id) {
      Object.defineProperty(this, '__requestId', {value: eventInitDict.id});
    }
    if (eventInitDict.request) {
      Object.defineProperty(this, 'request', {value: eventInitDict.request});
    }
    if (eventInitDict.client) {
      Object.defineProperty(this, 'client', {value: eventInitDict.client});
    }
    if (eventInitDict.isReload) {
      Object.defineProperty(this, 'isReload', {value: !!(eventInitDict.isReload)});
    }
  }
};
FetchEvent.prototype = new Event();

FetchEvent.prototype.respondWith = function(response) {
  var requestId = this.__requestId;

  var convertAndHandle = function(response) {
    response.body = window.btoa(response.body);
    handleFetchResponse(requestId, response);
  }

  // TODO: Find a better way to determine whether `response` is a promise.
  if (response.then) {
    // `response` is a promise!
    response.then(convertAndHandle);
  } else {
    convertAndHandle(response);
  }
};

FetchEvent.prototype.forwardTo = function(url) {};

FetchEvent.prototype.default = function(ev) {
  handleFetchDefault(ev.__requestId, {url:ev.request.url});
};

// These objects are *incredibly* simplified right now.
Request = function(url) {
  this.url = url;
};

Response = function(url, body) {
  this.url = url;
  this.body = body;
  this.status = 200;
  this.headerList = { mimeType: "text/html" };
};

// This function returns a promise with a response for fetching the given resource.
function fetch(resourceUrl) {
  return new Promise(function(innerResolve, reject) {
    // Wrap the resolve callback so we can decode the response body.
    var resolve = function(response) {
        response.body = window.atob(response.body);
        innerResolve(response);
    }

    // Call a native function to fetch the resource.
    handleTrueFetch(resourceUrl, resolve, reject);
  });
}

