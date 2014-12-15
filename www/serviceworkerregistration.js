var exec = require('cordova/exec');

var ServiceWorkerRegistration = function(doc, scriptURL, scope) {
    this.active = null;
    this.waiting = null;
    this.installing = null;
    this.scope = scope;
    this.registeringUrl = doc && doc.location && doc.location.href;
    this.uninstalling = false;
    console.log("Created");
    return Update.call(this, scriptURL);
};

var Update = function(scriptURL) {
  console.log("Starting Update algorithm");
  var registration = this;

  this.active = new ServiceWorker();
  return Promise.resolve(this);
};

module.exports = ServiceWorkerRegistration;
