# Service Worker Plugin for iOS

This plugin adds [ServiceWorker](https://github.com/slightlyoff/ServiceWorker) support to Cordova apps.  To use it:

1. Install this plugin.
2. Add the following preference to your config.xml file:

   ```
   <preference name="ServiceWorker" value="sw.js" />
   ```

That's it!  Your calls to the ServiceWorker API should now work.

## Caveats

* Having multiple ServiceWorkers in your app is unsupported.
* ServiceWorker uninstallation is unsupported.
