var exec = require('cordova/exec');

var ServiceWorkerRegistration = function(installing, waiting, active, registeringScriptURL, scope) {
    this.installing = installing;
    this.waiting = waiting;
    this.active = active;
    this.scope = scope;
    this.registeringScriptURL = registeringScriptURL;
    this.uninstalling = false;
    
    // TODO: Update?
};

module.exports = ServiceWorkerRegistration;

