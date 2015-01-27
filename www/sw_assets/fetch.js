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
  handleFetchResponse(this.__requestId, response);
};

FetchEvent.prototype.forwardTo = function(url) {};

FetchEvent.prototype.default = function(ev) {
  console.log("In fetch.default");
  handleFetchDefault(ev.__requestId, {url:ev.request.url});
};

// This is *incredibly* simplified right now.
Request = function(url) {
  this.url = url;
};

Response = function(url, body) {
  this.url = url;
  this.body = body;
  this.status = 200;
  this.headerList = { mimeType: "text/html" };
};

