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
  // Prevent the default handler from running, so that it doesn't override this response.
  this.preventDefault();

  // Store the id locally, for use in the `convertAndHandle` function.
  var requestId = this.__requestId;

  // Convert the response body to an array buffer and send the response to native.
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

Headers = function(headerDict) {
  // TODO: Allow multiple values with the same key.
  this.headerDict = headerDict || {};
};

Headers.prototype.append = function(name, value) {
  this.headerDict[name] = value;
};

Headers.prototype.delete = function(name) {
  delete this.headerDict[name];
};

Headers.prototype.get = function(name) {
  return this.headerDict[name];
};

Headers.prototype.getAll = function(name) {
  return this.headerDict[name];
};

Headers.prototype.has = function(name, value) {
  return this.headerDict[name] !== undefined;
};

Headers.prototype.set = function(name, value) {
  this.headerDict[name] = value;
};

Request = function(method, url, headers) {
  this.method = method;
  this.url = url;
  this.headers = headers || new Headers({});
};

Request.prototype.clone = function() {
  return new Request(this.method, this.url, this.headers);
}

Response = function(url, body, status, headers) {
  this.url = url;
  this.body = body;
  this.status = status || 200;
  this.headers = headers || new Headers({});
};

Response.prototype.clone = function() {
  return new Response(this.url, this.body, this.status, this.headers);
}

// This function returns a promise with a response for fetching the given resource.
function fetch(input) {
  // Assume the passed in input is a resource URL string.
  // TODO: What should the default headers be?
  var method = 'GET';
  var url = input;
  var headers = {};

  // If it's actually an object, get the data from it.
  if (typeof input === 'object') {
    method = input.method;
    url = input.url;
    headers = input.headers;
  }

  return new Promise(function(innerResolve, reject) {
    // Wrap the resolve callback so we can decode the response body.
    var resolve = function(response) {
        console.log("RESPONSE HEADERS FOR " + response.url + ": " + JSON.stringify(response.headers));
        var jsResponse = new Response(response.url, window.atob(response.body), response.status, response.headers);
        innerResolve(jsResponse);
    }

    // Call a native function to fetch the resource.
    handleTrueFetch(method, url, headers, resolve, reject);
  });
}

