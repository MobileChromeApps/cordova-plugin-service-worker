/* Here is the worker */
s4w = self;

onmessage = function(ev) {
  if (ev.data instanceof Array) {
    if (ev.data[0] === 'Install') {
      console.log(ev.data);
      importScripts([ev.data[1]]);
    } else if (ev.data[0] === 'ls') {
      postMessage(Object.keys(self));
    } else if (ev.data[0] === 'Inspect') {
      postMessage(JSON.stringify(self[ev.data[1]]));
      postMessage(""+self[ev.data[1]]);
      try {
        postMessage(self[ev.data[1]]);
      } catch (ex) {
        postMessage("Error");
        postMessage(ex);
      }
    } else if (ev.data[0] === 'Echo') {
      postMessage(ev.data[1]);
    } else if (ev.data[0] === 'Event') {
      // On Event, the event type will be in data[1], and the initialization parameters in data[2] through data[n]
      var newEvent;
      if (ev.data[1] === 'Fetch') {
        newEvent = new FetchEvent(ev.data[2]);
      } else if (ev.data[1] === 'Install') {
        newEvent = new ExtendableEvent('install');
      }
      if (newEvent) {
        self.dispatchEvent(newEvent);
      }
    }
  }
};
