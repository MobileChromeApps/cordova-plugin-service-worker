#How To Create Plugins for Service Worker on iOS
imintz@ - March 2015

Below are some useful pieces of information that can help you create new cordova service worker plugins on iOS. Example code in this document originates from the background sync plugin and the geofencing plugin.

##Setting Up an Event in Service Worker Context:
Create a new folder in the www directory of your plugin named sw_assets. This folder will contain all of your plugin components that will be run in the service worker. In sw_assets/ create a javascript file for your event.
First, you need to define your event as a global property in the service worker context.
```javascript
Object.defineProperty(this, ‘onsync’, {
      configurable: false,
      enumerable: true,
      get: eventGetter(‘sync’),
      set: eventSetter(‘sync’)
 });
```
The above code defines an event property for when the system initiates a background sync. Note that the event property has the prefix “on”, while the getter and setter do not. 
Next, you need to define the event object class that will be passed to the service worker when your new event is fired.
```javascript
function SyncEvent() {
    ExtendableEvent.call(this, ‘sync’);
    this.registration = new Registration();
}
SyncEvent.prototype = Object.create(ExtendableEvent.prototype);
SyncEvent.constructor = SyncEvent;
```
If your event needs any data, attach it to this object. In this example, the SyncEvent has a registration object as a property. 
    The above sync event inherits from the ExtendableEvent class. This enables the service worker to invoke the waitUntil function  from within its event handler. waitUntil will take a promise and prevent the device from terminating the service worker until that promise has been settled. 
For extendable events, it is necessary to create a custom event firing function. This allows the plugin to handle what happens after the waitUntil promise has been settled.
```javascript
function FireSyncEvent (data) {
     var ev = new SyncEvent();
     ev.registration.id = data.id;
     dispatchEvent(ev);
     if (Array.isArray(ev._promises) {
         return Promise.all(ev._promises).then(function(){
                 sendSyncResponse(0, data.id);
             },function(){
                 sendSyncResponse(2, data.id);
             });
     } else {
         sendSyncResponse(1, data.id);
         return Promise.resolve();
     }
 }
 ```
The first thing that happens in this function is the creation of a new event object from the class we just defined. Then the event object is populated with any additional data that may be needed in the service worker script. The event object is dispatched in the service worker context using the dispatchEvent function. 
Since our event inherits from the ExtendableEvent class, when the service worker calls waitUntil on the event, an array of promises will be created and added to the event object. A new promise is returned that does not resolve until every promise in the array of promises resolves. This array will only be fully resolved once waitUntil has resolved. A then property is also added to this promise. In the case of background sync, once all of the promises have resolved (waitUntil has resolved), the function sendSyncResponse is called to tell iOS that the background fetch is over and it can put the app back into a suspended state.
The last thing that needs to be done for your new service worker event is to add it to the plugin.xml. 
```<asset src="www/sw_assets/sync.js" target="sw_assets/sync.js" />```
This will put your new service worker event in the correct place for when a project is created.

##Communicating between Objective C and Service Worker
In your plugin class, define a CDVServiceWorker property called serviceWorker. This will be your access variable for the active service worker instance. Inside your pluginInitialize function, include the following line of code:    
```self.serviceWorker = [self.commandDelegate getCommandInstance:@"ServiceWorker"];```
This line returns a reference to the current active service worker. 
Note: Unless you specify ```<param name=”onload” value=”true” />``` in your plugin.xml file, ```pluginInitialize``` will not be executed until the first cordova exec call. As an alternative to pluginInitialize, you can create an initialization function that you manually execute after service worker is ready (more about ready later).
There are two ways to run javascript code on the service worker context from Objective C. If the closure of the function that you are calling is not relevant, or you want to define some javascript code in an Objective C string, use the evaluateScript function.
```javascript
NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(%@);", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
[serviceWorker.context evaluateScript:dispatchCode];
```
In this block of code, a json object is created out of data that needs to be sent to the service worker. A string, dispatchCode, is created with the javascript that needs to be called. In this case, that javascript is the FireSyncEvent that was defined in the previous section.
The other method allows your to preserve the closure of your function, however you cannot define your script in objective C, you must use a function callback passed in from javascript as a JSValue.

Note: Trying to use evaluateScript in an asynchronous function can cause threading issues or throw an exception. To get around this problem, you can use the performSelectorOnMainThread function as shown here.
```javascript
[serviceWorker.context performSelectorOnMainThread:@selector(evaluateScript:) withObject:dispatchCode waitUntilDone:NO];
```
To have service worker context javascript call functions in the native code of your plugin you use JSCore’s javascript block definition capability.
```javascript
__weak CDVBackgroundSync* weakSelf = self;
serviceWorker.context[@"unregisterSync"] = ^(JSValue *registrationId) {
    [weakSelf unregisterSyncById:[registrationId toString]];
};
```
A weak reference to the calling class is created to prevent a retain cycle in the code block. Then a block is defined for the service worker context variable of unregisterSync. After these lines of code have been executed, whenever unregisterSync is called from the service worker context, this block will be executed. In this case, the block simply calls class method of the plugin. All of the parameters for this type of code block should be of type JSValue.
If one of your JSValue parameters is a function, you can use callWithArguments to invoke that function with its original closure. For example, if we wanted unregisterSync to have a callback we would add:
```javascript
serviceWorker.context[@"unregisterSync"] = ^(JSValue *registrationId, JSValue *callback) {
    [weakSelf unregisterSyncById:[registrationId toString]];
    NSArray *arguments = @[registrationId];
    [callback callWithArguments:arguments];
};
```
Calling callback like this will execute the function as though it was called directly from  where it was defined in javascript. 
##Attaching Property to Service Worker Registration
If you want to attach some object to a service worker registration, simply a class or object as you normally would in javascript. In the same file as your class definition listen for the serviceWorker.ready promise and then add a new object from your class as a property of the service worker registration that is returned by ready.
```javascript
navigator.serviceWorker.ready.then(function(serviceWorkerRegistration) {
serviceWorkerRegistration.syncManager = new SyncManager();
...
});
```
The sample code above illustrates the simplicity of adding a property to the service worker registration.
