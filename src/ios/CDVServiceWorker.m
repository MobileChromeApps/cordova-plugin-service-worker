/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import <Cordova/CDV.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CommonCrypto/CommonDigest.h>
#import "CDVServiceWorker.h"
#import "FetchConnectionDelegate.h"
#import "FetchInterceptorProtocol.h"
#import "ServiceWorkerCacheApi.h"
#import "ServiceWorkerRequest.h"

static bool isServiceWorkerActive = NO;

NSString * const SERVICE_WORKER = @"serviceworker";
NSString * const SERVICE_WORKER_SCOPE = @"serviceworkerscope";
NSString * const SERVICE_WORKER_CACHE_CORDOVA_ASSETS = @"cachecordovaassets";
NSString * const SERVICE_WORKER_ACTIVATED = @"ServiceWorkerActivated";
NSString * const SERVICE_WORKER_INSTALLED = @"ServiceWorkerInstalled";
NSString * const SERVICE_WORKER_SCRIPT_CHECKSUM = @"ServiceWorkerScriptChecksum";

NSString * const REGISTER_OPTIONS_KEY_SCOPE = @"scope";

NSString * const REGISTRATION_KEY_ACTIVE = @"active";
NSString * const REGISTRATION_KEY_INSTALLING = @"installing";
NSString * const REGISTRATION_KEY_REGISTERING_SCRIPT_URL = @"registeringScriptURL";
NSString * const REGISTRATION_KEY_SCOPE = @"scope";
NSString * const REGISTRATION_KEY_WAITING = @"waiting";

NSString * const SERVICE_WORKER_KEY_SCRIPT_URL = @"scriptURL";

@implementation CDVServiceWorker

@synthesize context = _context;
@synthesize workerWebView = _workerWebView;
@synthesize registration = _registration;
@synthesize requestDelegates = _requestDelegates;
@synthesize requestQueue = _requestQueue;
@synthesize serviceWorkerScriptFilename = _serviceWorkerScriptFilename;
@synthesize cacheApi = _cacheApi;

- (NSString *)hashForString:(NSString *)string
{
    const char *cstring = [string UTF8String];
    size_t length = strlen(cstring);

    // We're assuming below that CC_LONG is an unsigned int; fail here if that's not true.
    assert(sizeof(CC_LONG) == sizeof(unsigned int));

    unsigned char hash[33];

    CC_MD5_CTX hashContext;

    // We'll almost certainly never see >4GB files, but loop with UINT32_MAX sized-chunks just to be correct
    CC_MD5_Init(&hashContext);
    CC_LONG dataToHash;
    while (length != 0) {
        if (length > UINT32_MAX) {
            dataToHash = UINT32_MAX;
            length -= UINT32_MAX;
        } else {
            dataToHash = (CC_LONG)length;
            length = 0;
        }
        CC_MD5_Update(&hashContext, cstring, dataToHash);
        cstring += dataToHash;
    }
    CC_MD5_Final(hash, &hashContext);

    // Construct a simple base-16 representation of the hash for comparison
    for (int i=15; i >= 0; --i) {
        hash[i*2+1] = 'a' + (hash[i] & 0x0f);
        hash[i*2] = 'a' + ((hash[i] >> 4) & 0x0f);
    }
    // Null-terminate
    hash[32] = 0;

    return [NSString stringWithCString:(char *)hash
                                          encoding:NSUTF8StringEncoding];
}

CDVServiceWorker *singletonInstance = nil; // TODO: Something better
+ (CDVServiceWorker *)instanceForRequest:(NSURLRequest *)request
{
    return singletonInstance;
}

- (void)pluginInitialize
{
    // TODO: Make this better; probably a registry
    singletonInstance = self;

    self.requestDelegates = [[NSMutableDictionary alloc] initWithCapacity:10];
    self.requestQueue = [NSMutableArray new];

    [NSURLProtocol registerClass:[FetchInterceptorProtocol class]];

    // Get the app settings.
    BOOL cacheCordovaAssets = YES;
    NSString *serviceWorkerScope;
    if ([[self viewController] isKindOfClass:[CDVViewController class]]) {
        CDVViewController *vc = (CDVViewController *)[self viewController];
        NSMutableDictionary *settings = [vc settings];
        self.serviceWorkerScriptFilename = [settings objectForKey:SERVICE_WORKER];
        NSObject *cacheCordovaAssetsObject = [settings objectForKey:SERVICE_WORKER_CACHE_CORDOVA_ASSETS];
        serviceWorkerScope = [settings objectForKey:SERVICE_WORKER_SCOPE];
        cacheCordovaAssets = (cacheCordovaAssetsObject == nil) ? YES : [(NSString *)cacheCordovaAssetsObject boolValue];
    }

    // Initialize CoreData for the Cache API.
    self.cacheApi = [[ServiceWorkerCacheApi alloc] initWithScope:serviceWorkerScope cacheCordovaAssets:cacheCordovaAssets];
    [self.cacheApi initializeStorage];

    self.workerWebView = [[UIWebView alloc] init]; // Headless
    [self.viewController.view addSubview:self.workerWebView];
    [self.workerWebView setDelegate:self];
    [self.workerWebView loadHTMLString:@"<html><title>Service Worker Page</title></html>" baseURL:[NSURL fileURLWithPath:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"GeneratedWorker.html"]]];
}

# pragma mark ServiceWorker Functions

- (void)register:(CDVInvokedUrlCommand*)command
{
    NSString *scriptUrl = [command argumentAtIndex:0];
    NSDictionary *options = [command argumentAtIndex:1];

    // The script url must be at the root.
    // TODO: Look into supporting non-root ServiceWorker scripts.
    if ([scriptUrl containsString:@"/"]) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"The script URL must be at the root."];
        [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
    }

    // The provided scope is ignored; we always set it to the root.
    // TODO: Support provided scopes.
    NSString *scopeUrl = @"/";

    // If we have a registration on record, make sure it matches the attempted registration.
    // If it matches, return it.  If it doesn't, we have a problem!
    // If we don't have a registration on record, create one, store it, and return it.
    if (self.registration != nil) {
        if (![[self.registration valueForKey:REGISTRATION_KEY_REGISTERING_SCRIPT_URL] isEqualToString:scriptUrl]) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:@"The script URL doesn't match the existing registration."];
            [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
        } else if (![[self.registration valueForKey:REGISTRATION_KEY_SCOPE] isEqualToString:scopeUrl]) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:@"The scope URL doesn't match the existing registration."];
            [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
        }
    } else {
        [self createServiceWorkerRegistrationWithScriptUrl:scriptUrl scopeUrl:scopeUrl];
    }

    // Return the registration.
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
    [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
}

- (void)createServiceWorkerRegistrationWithScriptUrl:(NSString*)scriptUrl scopeUrl:(NSString*)scopeUrl
{
    NSDictionary *serviceWorker = [NSDictionary dictionaryWithObject:scriptUrl forKey:SERVICE_WORKER_KEY_SCRIPT_URL];
    // TODO: Add a state to the ServiceWorker object.

    NSArray *registrationKeys = @[REGISTRATION_KEY_INSTALLING,
                                  REGISTRATION_KEY_WAITING,
                                  REGISTRATION_KEY_ACTIVE,
                                  REGISTRATION_KEY_REGISTERING_SCRIPT_URL,
                                  REGISTRATION_KEY_SCOPE];
    NSArray *registrationObjects = @[[NSNull null], [NSNull null], serviceWorker, scriptUrl, scopeUrl];
    self.registration = [NSDictionary dictionaryWithObjects:registrationObjects forKeys:registrationKeys];
}

- (void)serviceWorkerReady:(CDVInvokedUrlCommand*)command
{
    // The provided scope is ignored; we always set it to the root.
    // TODO: Support provided scopes.
    NSString *scopeUrl = @"/";
    NSString *scriptUrl = self.serviceWorkerScriptFilename;

    if (isServiceWorkerActive) {
        if (self.registration == nil) {
            [self createServiceWorkerRegistrationWithScriptUrl:scriptUrl scopeUrl:scopeUrl];
        }
        // Return the registration.
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
        [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"No Service Worker is currently active."];
        [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
    }
}

- (void)postMessage:(CDVInvokedUrlCommand*)command
{
    NSString *message = [command argumentAtIndex:0];

    // Fire a message event in the JSContext.
    NSString *dispatchCode = [NSString stringWithFormat:@"dispatchEvent(new MessageEvent({data:Kamino.parse('%@')}));", message];
    [self evaluateScript:dispatchCode];
}

- (void)installServiceWorker
{
    [self evaluateScript:@"FireInstallEvent().then(installServiceWorkerCallback);"];
}

- (void)activateServiceWorker
{
    [self evaluateScript:@"FireActivateEvent().then(activateServiceWorkerCallback);"];
}

- (void)initiateServiceWorker
{
    isServiceWorkerActive = YES;
    NSLog(@"SW active!  Processing request queue.");
    [self processRequestQueue];
}

# pragma mark Helper Functions

- (void)evaluateScript:(NSString *)script
{
    if ([NSThread isMainThread]) {
        [self.workerWebView stringByEvaluatingJavaScriptFromString:script];
    } else {
        [self.workerWebView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:script waitUntilDone:NO];
    }
}

- (void)createServiceWorkerFromScript:(NSString *)script
{
    // Get the JSContext from the webview
    self.context = [self.workerWebView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];

    [self.context setExceptionHandler:^(JSContext *context, JSValue *value) {
        NSLog(@"%@", value);
    }];

    // Pipe JS logging in this context to NSLog.
    // NOTE: Not the nicest of hacks, but useful!
    [self evaluateScript:@"var console = {}"];
    self.context[@"console"][@"log"] = ^(NSString *message) {
        NSLog(@"JS log: %@", message);
    };

    CDVServiceWorker * __weak weakSelf = self;

    self.context[@"installServiceWorkerCallback"] = ^() {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SERVICE_WORKER_INSTALLED];
        [weakSelf activateServiceWorker];
    };

    self.context[@"activateServiceWorkerCallback"] = ^() {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SERVICE_WORKER_ACTIVATED];
        [weakSelf initiateServiceWorker];
    };

    self.context[@"handleFetchResponse"] = ^(JSValue *jsRequestId, JSValue *response) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *requestId = [formatter numberFromString:[jsRequestId toString]];
        FetchInterceptorProtocol *interceptor = (FetchInterceptorProtocol *)[weakSelf.requestDelegates objectForKey:requestId];
        [weakSelf.requestDelegates removeObjectForKey:requestId];

        // Convert the response body to base64.
        NSData *data = [NSData dataFromBase64String:[response[@"body"] toString]];
        JSValue *headers = response[@"headers"];
        NSString *mimeType = [headers[@"mimeType"] toString];
        NSString *encoding = @"utf-8";
        NSString *url = [response[@"url"] toString]; // TODO: Can this ever be different than the request url? if not, don't allow it to be overridden

        NSURLResponse *urlResponse = [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:url]
                                                            MIMEType:mimeType
                                               expectedContentLength:data.length
                                                    textEncodingName:encoding];

        [interceptor handleAResponse:urlResponse withSomeData:data];
    };

    self.context[@"handleFetchDefault"] = ^(JSValue *jsRequestId, JSValue *response) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *requestId = [formatter numberFromString:[jsRequestId toString]];
        FetchInterceptorProtocol *interceptor = (FetchInterceptorProtocol *)[weakSelf.requestDelegates objectForKey:requestId];
        [weakSelf.requestDelegates removeObjectForKey:requestId];
        [interceptor passThrough];
    };

    self.context[@"handleTrueFetch"] = ^(JSValue *method, JSValue *resourceUrl, JSValue *headers, JSValue *resolve, JSValue *reject) {
        NSString *resourceUrlString = [resourceUrl toString];
        if (![[resourceUrl toString] containsString:@"://"]) {
            resourceUrlString = [NSString stringWithFormat:@"file://%@/www/%@", [[NSBundle mainBundle] resourcePath], resourceUrlString];
        }

        // Create the request.
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:resourceUrlString]];
        [request setHTTPMethod:[method toString]];
        NSDictionary *headerDictionary = [headers toDictionary];
        [headerDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
            [request addValue:value forHTTPHeaderField:key];
        }];
        [NSURLProtocol setProperty:@YES forKey:@"PureFetch" inRequest:request];

        // Create a connection and send the request.
        FetchConnectionDelegate *delegate = [FetchConnectionDelegate new];
        delegate.resolve = ^(ServiceWorkerResponse *response) {
            [resolve callWithArguments:@[[response toDictionary]]];
        };
        delegate.reject = ^(NSString *error) {
            [reject callWithArguments:@[error]];
        };
        [NSURLConnection connectionWithRequest:request delegate:delegate];
    };

    // This function is called by `postMessage`, defined in message.js.
    // `postMessage` serializes the message using kamino.js and passes it here.
    self.context[@"postMessageInternal"] = ^(JSValue *serializedMessage) {
        NSString *postMessageCode = [NSString stringWithFormat:@"window.postMessage(Kamino.parse('%@'), '*')", [serializedMessage toString]];
        [weakSelf.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:postMessageCode waitUntilDone:NO];
    };

    // Install cache API JS methods
    [self.cacheApi defineFunctionsInContext:self.context];

    // Load the required assets.
    [self loadServiceWorkerAssetsIntoContext];

    // Load the ServiceWorker script.
    [self loadScript:script];
}

- (void)createServiceWorkerClientWithUrl:(NSString *)url
{
    // Create a ServiceWorker client.
    NSString *createClientCode = [NSString stringWithFormat:@"var client = new Client('%@');", url];
    [self evaluateScript:createClientCode];
}

- (NSString *)readScriptAtRelativePath:(NSString *)relativePath
{
    // NOTE: Relative path means relative to the app bundle.

    // Compose the absolute path.
    NSString *absolutePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:[NSString stringWithFormat:@"/%@", relativePath]];

    // Read the script from the file.
    NSError *error;
    NSString *script = [NSString stringWithContentsOfFile:absolutePath encoding:NSUTF8StringEncoding error:&error];

    // If there was an error, log it and return.
    if (error) {
        NSLog(@"Could not read script: %@", [error description]);
        return nil;
    }

    // Return our script!
    return script;
}

- (void)loadServiceWorkerAssetsIntoContext
{
    // Specify the assets directory.
    // TODO: Move assets up one directory, so they're not in www.
    NSString *assetDirectoryPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/www/sw_assets"];

    // Get the list of assets.
    NSArray *assetFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:assetDirectoryPath error:NULL];

    // Read and load each asset.
    for (NSString *assetFilename in assetFilenames) {
        NSString *relativePath = [NSString stringWithFormat:@"www/sw_assets/%@", assetFilename];
        [self readAndLoadScriptAtRelativePath:relativePath];
    }
}

- (void)loadScript:(NSString *)script
{
    // Evaluate the script.
    [self evaluateScript:script];
}

- (void)readAndLoadScriptAtRelativePath:(NSString *)relativePath
{
    // Log!
    NSLog(@"Loading script: %@", relativePath);

    // Read the script.
    NSString *script = [self readScriptAtRelativePath:relativePath];

    if (script == nil) {
        return;
    }

    // Load the script into the context.
    [self loadScript:script];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bool serviceWorkerInstalled = [defaults boolForKey:SERVICE_WORKER_INSTALLED];
    bool serviceWorkerActivated = [defaults boolForKey:SERVICE_WORKER_ACTIVATED];
    NSString *serviceWorkerScriptChecksum = [defaults stringForKey:SERVICE_WORKER_SCRIPT_CHECKSUM];
    if (self.serviceWorkerScriptFilename != nil) {
        NSString *serviceWorkerScriptRelativePath = [NSString stringWithFormat:@"www/%@", self.serviceWorkerScriptFilename];
        NSLog(@"ServiceWorker relative path: %@", serviceWorkerScriptRelativePath);
        NSString *serviceWorkerScript = [self readScriptAtRelativePath:serviceWorkerScriptRelativePath];
        if (serviceWorkerScript != nil) {
            if (![[self hashForString:serviceWorkerScript] isEqualToString:serviceWorkerScriptChecksum]) {
                serviceWorkerInstalled = NO;
                serviceWorkerActivated = NO;
                [defaults setBool:NO forKey:SERVICE_WORKER_INSTALLED];
                [defaults setBool:NO forKey:SERVICE_WORKER_ACTIVATED];
                [defaults setObject:[self hashForString:serviceWorkerScript] forKey:SERVICE_WORKER_SCRIPT_CHECKSUM];
            }
            [self createServiceWorkerFromScript:serviceWorkerScript];
            [self createServiceWorkerClientWithUrl:self.serviceWorkerScriptFilename];
            if (!serviceWorkerInstalled) {
                [self installServiceWorker];
            } else if (!serviceWorkerActivated) {
                [self activateServiceWorker];
            } else {
                [self initiateServiceWorker];
            }
        }
    } else {
        NSLog(@"No service worker script defined");
    }
}

- (void)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request {}
- (void)webViewDidStartLoad:(UIWebView *)wv {}
- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {}


- (void)addRequestToQueue:(NSURLRequest *)request withId:(NSNumber *)requestId delegateTo:(NSURLProtocol *)protocol
{
    // Log!
    NSLog(@"Adding to queue: %@", [[request URL] absoluteString]);

    // Create a request object.
    ServiceWorkerRequest *swRequest = [ServiceWorkerRequest new];
    swRequest.request = request;
    swRequest.requestId = requestId;
    swRequest.protocol = protocol;

    // Add the request object to the queue.
    [self.requestQueue addObject:swRequest];

    // Process the request queue.
    [self processRequestQueue];
}

- (void)processRequestQueue {
    // If the ServiceWorker isn't active, there's nothing we can do yet.
    if (!isServiceWorkerActive) {
        return;
    }

    for (ServiceWorkerRequest *swRequest in self.requestQueue) {
        // Log!
        NSLog(@"Processing from queue: %@", [[swRequest.request URL] absoluteString]);

        // Register the request and delegate.
        [self.requestDelegates setObject:swRequest.protocol forKey:swRequest.requestId];

        // Fire a fetch event in the JSContext.
        NSURLRequest *request = swRequest.request;
        NSString *method = [request HTTPMethod];
        NSString *url = [[request URL] absoluteString];
        NSData *headerData = [NSJSONSerialization dataWithJSONObject:[request allHTTPHeaderFields]
                                                             options:NSJSONWritingPrettyPrinted
                                                               error:nil];
        NSString *headers = [[[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

        NSString *requestCode = [NSString stringWithFormat:@"new Request('%@', '%@', %@)", method, url, headers];
        NSString *dispatchCode = [NSString stringWithFormat:@"dispatchEvent(new FetchEvent({request:%@, id:'%lld'}));", requestCode, [swRequest.requestId longLongValue]];
        [self evaluateScript:dispatchCode];
    }

    // Clear the queue.
    // TODO: Deal with the possibility that requests could be added during the loop that we might not necessarily want to remove.
    [self.requestQueue removeAllObjects];
}

@end

