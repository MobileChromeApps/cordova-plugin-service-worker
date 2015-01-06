;EventQueue = {};

Event = function(type) {
  this.type = type;
  return this;
};

ExtendableEvent = function(type) {
  Event.call(this, type);
  this.promises = null;
};

ExtendableEvent.prototype = new Event();

ExtendableEvent.prototype.waitUntil = function(promise) {
  if (this.promises === null) {
    this.promises = [];
  }
  this.promises.push(promise);
};


//originalAddEventListener = addEventListener;
addEventListener = function(eventName, callback) {
//  if (eventName == 'message') {
//    originalEventListener.apply(self, arguments);
//  } else {
    if (!(eventName in EventQueue))
      EventQueue[eventName] = [];
    EventQueue[eventName].push(callback);
//  }
};

dispatchEvent = function(event) {
  (EventQueue[event.type] || []).forEach(function(handler) {
    if (typeof handler === 'function') {
      handler(event);
    }
  });
};


propertyEventHandlers = {};

eventGetter = function(eventType) {
  return function() {
    if (eventType in propertyEventHandlers) {
      return EventQueue[eventType][propertyEventHandlers[eventType]];
    } else {
      return null;
    }
  };
};

eventSetter = function(eventType) {
  return function(handler) {
    if (eventType in propertyEventHandlers) {
      EventQueue[eventType][propertyEventHandlers[eventType]] = handler;
    } else {
      addEventListener(eventType, handler);
      propertyEventHandlers[eventType] = EventQueue[eventType].length - 1;
    }
  };
};

Object.defineProperty(this, 'oninstall', {
  configurable: false,
  enumerable: true,
  get: eventGetter('install'),
  set: eventSetter('install')
});

Object.defineProperty(this, 'onactivate', {
  configurable: false,
  enumerable: true,
  get: eventGetter('activate'),
  set: eventSetter('activate')
});
