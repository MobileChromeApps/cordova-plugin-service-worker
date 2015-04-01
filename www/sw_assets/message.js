MessageEvent = function(eventInitDict) {
  Event.call(this, 'message');
  if (eventInitDict) {
    if (eventInitDict.data) {
      Object.defineProperty(this, 'data', {value: eventInitDict.data});
    }
    if (eventInitDict.origin) {
      Object.defineProperty(this, 'origin', {value: eventInitDict.origin});
    }
    if (eventInitDict.source) {
      Object.defineProperty(this, 'source', {value: eventInitDict.source});
    }
  }
};
MessageEvent.prototype = Object.create(Event.prototype);
MessageEvent.constructor = MessageEvent;

