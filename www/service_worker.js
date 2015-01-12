var exec = require('cordova/exec');

var ServiceWorker = function() {
    return this;
};

ServiceWorker.prototype.postMessage = function(message, targetOrigin) {
    // TODO: Validate the target origin.

    // Serialize the message.
    var serializedMessage = Kamino.stringify(message);

    // Send the message to native for delivery to the JSContext.
    exec(null, null, "ServiceWorker", "postMessage", [serializedMessage, targetOrigin]);
};

module.exports = ServiceWorker;

