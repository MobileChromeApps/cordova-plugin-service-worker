var self = this;

// The event queue is a JavaScript array containing items which look like
// {id: number,
//  timeToRun: number,
//  ready: boolean,
//  callback: callable
// }
// id is used for bookkeeping, to be able to delete items with clearInterval and clearTimeout.
// timeToRun is the system time in milliseconds at which the event should run (may be 0 to run immediately).
// ready is a flag which can be set by native -- if false, the event will not be run, no matter how stale
// the event is.
// callback should take no arguments (it will be called with none) and its `this` will be set to the global
// object (self, in a worker context)
var eventQueue = [];

// This method will run all ready events, and remove them from the event queue.
spinEventLoop = function(currentTime, eventQueue) {
  var newEventQueue = [];
  if (typeof eventQueue === "Array") {
    eventQueue.forEach(function(item) {
      if (item.ready && !item.running && item.timeToRun <= currentTime) {
        item.running = true;
        item.callable.call(self);
        item.finished = true;
      } else {
        newEventQueue.push(item);
      }
    });
  }
  eventQueue = newEventQueue;
};

setTimeout = function(code, delay) {
  var runTime = +(new Date()) + delay;
  if (typeof code === "string") {
    code = function() { eval(code); };
  }
  return addToEventQueue({timeToRun: runTime, ready: true, callback: code});
};

setInterval = function(code, delay) {
  var initialRunTime = +(new Date()) + delay;
  if (typeof code === "string") {
    code = function() { eval(code); };
  }
  var wrappedCode = function() {
    var nextRunTime = +(new Date()) + delay;
    code.call(self);
    addToEventQueue({timeToRun: nextRunTime, ready: true, callback: wrappedCode});
  };
  return addToEventQueue({timeToRun: initialRunTime, ready: true, callback: code});
};

removeFromEventQueue = function(id) {
  eventQueue = eventQueue.filter(function(event) { return event.id !== id; });
};

addToEventQueue = function(event) {
  eventQueue.push(event);
};

clearInterval = clearTimeout = removeFromEventQueue;
