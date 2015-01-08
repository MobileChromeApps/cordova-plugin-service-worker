var exec = require('cordova/exec');

var ServiceWorker = function() {
    return this;
};

ServiceWorker.prototype.postMessage = function() {
    console.log("PostMessage to service worker");
};

module.exports = ServiceWorker;
