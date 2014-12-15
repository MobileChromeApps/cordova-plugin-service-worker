var ServiceWorkerContainer = {
    register: function(scriptURL, options) {
        console.log("Registering " + scriptURL);
        // TODO: Validate scope, options, url, etc. Ensure that it is not attempting to register a different SW.
        var scope = options && options.scope;
        return Promise.resolve(new ServiceWorkerRegistration(document, scriptURL, scope));
    }
};

module.exports = ServiceWorkerContainer;

