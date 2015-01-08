var exec = require('cordova/exec');

var ServiceWorkerContainer = {
    register: function(scriptURL, options) {
        console.log("Registering " + scriptURL);
        
        return new Promise(function(resolve, reject) {
            var innerResolve = function(result) {
                resolve(new ServiceWorkerRegistration(result.installing, result.waiting, result.active, result.registeringScriptUrl, result.scope));
            }
        
            exec(innerResolve, reject, "ServiceWorker", "register", [scriptURL, options]);
        });
    }
};

module.exports = ServiceWorkerContainer;

