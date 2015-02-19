var exec = require('cordova/exec');

var ServiceWorkerContainer = {
    //The ready promise is resolved when there is an active Service Worker with registration and the device is ready
    ready: new Promise(function(resolve, reject) {
	var innerResolve = function(result) {
	    var onDeviceReady = function() {
		resolve(new ServiceWorkerRegistration(result.installing, result.waiting, new ServiceWorker(), result.registeringScriptUrl, result.scope));
	    }
	    document.addEventListener('deviceready', onDeviceReady, false); 
	}
	exec(innerResolve, null, "ServiceWorker", "serviceWorkerReady", []);
    }),
    register: function(scriptURL, options) {
        console.log("Registering " + scriptURL);
        return new Promise(function(resolve, reject) {
            var innerResolve = function(result) {
		resolve(new ServiceWorkerRegistration(result.installing, result.waiting, new ServiceWorker(), result.registeringScriptUrl, result.scope));		
            }
            exec(innerResolve, reject, "ServiceWorker", "register", [scriptURL, options]);
        });
    }
};

module.exports = ServiceWorkerContainer;
