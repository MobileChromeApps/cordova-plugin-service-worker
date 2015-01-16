/* Here is the worker */
s4w = self;
s5w = 'Here is a thing';

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
    }
  } else {
  console.log(ev);
  postMessage(s5w);
  postMessage(self.importScripts ? "YES" : "NO");
}
};
