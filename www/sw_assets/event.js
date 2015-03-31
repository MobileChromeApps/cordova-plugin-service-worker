EventQueue = {};
var self=this;

Event = function(type) {
  this.type = type;
  this.cancelable = true;

  this.stopPropagation_ = false;
  this.stopImmediatePropagation_ = false;
  this.canceled_ = false;
  this.initialized_ = false;
  this.dispatch_ = false;
};

Event.prototype.preventDefault = function() {
  if (this.cancelable) {
    this.canceled_ = true;
  }
};

ExtendableEvent = function(type) {
  Event.call(this, type);
  this._promises = null;
};

ExtendableEvent.prototype = Object.create(Event.prototype);
ExtendableEvent.constructor = ExtendableEvent;

ExtendableEvent.prototype.waitUntil = function(promise) {
  if (this._promises === null) {
    this._promises = [];
  }
  this._promises.push(promise);
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
      handler.call(self, event);
    }
  });
  if (!event.canceled_) {
    if (typeof event.default === 'function') {
      event.default.call(self, event);
    }
  }
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
    // See https://html.spec.whatwg.org/multipage/webappapis.html#the-event-handler-processing-algorithm
    var wrappedHandler = function(ev) {
      if (handler === null) return;
      // TODO: this is different for error events
      var handlerReturn = handler.call(self, ev);
      if (!handlerReturn) ev.preventDefault();
    };
    if (eventType in propertyEventHandlers) {
      EventQueue[eventType][propertyEventHandlers[eventType]] = wrappedHandler;
    } else {
      addEventListener(eventType, wrappedHandler);
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

Object.defineProperty(this, 'onfetch', {
  configurable: false,
  enumerable: true,
  get: eventGetter('fetch'),
  set: eventSetter('fetch')
});


InstallEvent = function() {
  ExtendableEvent.call(this, 'install');
  this.activeWorker = null;
};
InstallEvent.prototype = Object.create(ExtendableEvent.prototype);
InstallEvent.constructor = InstallEvent;

ActivateEvent = function() {
  ExtendableEvent.call(this, 'activate');
};
ActivateEvent.prototype = Object.create(ExtendableEvent.prototype);
ActivateEvent.constructor = ActivateEvent;

FireInstallEvent = function() {
  var ev = new InstallEvent();
  var InstallFailed;
  dispatchEvent(ev);
  if (Array.isArray(ev._promises)) {
    return Promise.all(ev._promises).then(null, function(err) { InstallFailed = true; });
  } else {
    return Promise.resolve();
  }
};

FireActivateEvent = function() {
  var ev = new ActivateEvent();
  dispatchEvent(ev);
  if (Array.isArray(ev._promises)) {
    return Promise.all(ev._promises);
  } else {
    return Promise.resolve();
  }
};

