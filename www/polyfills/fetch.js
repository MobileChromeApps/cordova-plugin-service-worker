FetchEvent = function(eventInitDict) {
  Event.call(this, 'fetch');
  if (eventInitDict) {
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

FetchEvent.prototype.sendResponse = function(url, body) {
    handleFetchResponse({
        url:url,
        status:200,
        status_message:'OK',
        header_list: {
            mime_type:'text/html'
        },
        type:'default',
        body:body
    });
}

FetchEvent.prototype.respondWith = function(response) {};

FetchEvent.prototype.forwardTo = function(url) {};

FetchEvent.prototype.default = function(ev) {
  console.log("In fetch.default");
  handleFetchDefault({url:ev.request.url});
};
