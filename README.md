# Service Worker Plugin for iOS

This plugin adds [Service Worker](https://github.com/slightlyoff/ServiceWorker) support to Cordova apps on iOS.  To use it:

1. Install this plugin.
2. Create `sw.js` in your `www/` directory.
3. Add the following preference to your config.xml file:

   ```
   <preference name="ServiceWorker" value="sw.js" />
   ```

That's it!  Your calls to the ServiceWorker API should now work.

## Cordova Asset Cache

This plugin automatically creates a cache (called `Cordova Assets`) containing all of the assets in your app's `www/` directory.

To prevent this automatic caching, add the following preference to your config.xml file:

```
<preference name="CacheCordovaAssets" value="false" />
```

## Examples

One use case is to check your caches for any fetch request, only attempting to retrieve it from the network if it's not there.

```
self.addEventListener('fetch', function(event) {
    event.respondWith(
        // Check the caches.
        caches.match(event.request).then(function(response) {
            // If the response exists, return it; otherwise, fetch it from the network.
            return response || fetch(event.request);
        })
    );
});
```

Another option is to go to the network first, only checking the cache if that fails (e.g. if the device is offline).

```
self.addEventListener('fetch', function(event) {
    // If the caches provide a response, return it.  Otherwise, return the original network response.
    event.respondWith(
        // Fetch from the network.
        fetch(event.request).then(function(networkResponse) {
            // If the response exists and has a 200 status, return it.
            if (networkResponse && networkResponse.status === 200) {
                return networkResponse;
            }

            // The network didn't yield a useful response, so check the caches.
            return caches.match(event.request).then(function(cacheResponse) {
                // If the cache yielded a response, return it; otherwise, return the original network response.
                return cacheResponse || networkResponse;
            });
        })
    );
});
```

## Caveats

* Having multiple Service Workers in your app is unsupported.
* Service Worker uninstallation is unsupported.
* IndexedDB is unsupported.

## Release Notes

### 1.0.1

* Significantly enhanced version numbering.

### 1.0.0

* Initial release.
