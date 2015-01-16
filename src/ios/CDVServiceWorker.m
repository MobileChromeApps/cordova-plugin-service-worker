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
#import "CDVServiceWorker.h"

#include <libkern/OSAtomic.h>

@interface FetchInterceptorProtocol : NSURLProtocol {}
+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
- (void)handleAResponse:(NSURLResponse *)response withSomeData:(NSData *)data;
@property (nonatomic, retain) NSURLConnection *connection;
@end

@implementation FetchInterceptorProtocol
@synthesize connection=_connection;

static int64_t requestCount = 0;

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // Temporary: Disable URL handling
    NSLog(@"%@",[request URL]);
    return NO;
    // Check - is there a service worker for this request?
    // For now, assume YES -- all requests go through service worker. This may be incorrect if there are iframes present.
    if ([NSURLProtocol propertyForKey:@"PassThrough" inRequest:request]) {
        // Already seen; not handling
        return NO;
    } else {
        if ([CDVServiceWorker instanceForRequest:request]) {
            // Handling
            return YES;
        } else {
            // No Service Worker installed; not handling
            return NO;
        }
    }
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    // Attach a reference to the Service Worker to a copy of the request
    NSMutableURLRequest *workerRequest = [self.request mutableCopy];
    CDVServiceWorker *instanceForRequest = [CDVServiceWorker instanceForRequest:workerRequest];
    [NSURLProtocol setProperty:instanceForRequest forKey:@"ServiceWorkerPlugin" inRequest:workerRequest];
    NSNumber *requestId = [NSNumber numberWithLongLong:OSAtomicIncrement64(&requestCount)];
    [NSURLProtocol setProperty:requestId forKey:@"RequestId" inRequest:workerRequest];

    [instanceForRequest fetchResponseForRequest:workerRequest withId:requestId delegateTo:self];
}

- (void)stopLoading {
    [self.connection cancel];
    self.connection = nil;
}

- (void)passThrough {
    // Flag this request as a pass-through so that the URLProtocol doesn't try to grab it again
    NSMutableURLRequest *taggedRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"PassThrough" inRequest:taggedRequest];

    // Initiate a new request to actually retrieve the resource
    self.connection = [NSURLConnection connectionWithRequest:taggedRequest delegate:self];
}

- (void)handleAResponse:(NSURLResponse *)response withSomeData:(NSData *)data {
    // TODO: Move cache storage policy into args
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}
@end

NSString * const SERVICE_WORKER = @"service_worker";
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
@synthesize registration = _registration;
@synthesize requestDelegates = _requestDelegates;

- (NSString *)hashForString:(NSString *)string
{
    return @"17";
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

    _requestDelegates = [[NSMutableDictionary alloc] initWithCapacity:10];

    [NSURLProtocol registerClass:[FetchInterceptorProtocol class]];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    Boolean serviceWorkerInstalled = [defaults boolForKey:SERVICE_WORKER_INSTALLED];
    Boolean serviceWorkerActivated = [defaults boolForKey:SERVICE_WORKER_ACTIVATED];
    NSString *serviceWorkerScriptChecksum = [defaults stringForKey:SERVICE_WORKER_SCRIPT_CHECKSUM];

    NSString *serviceWorkerScriptFilename = nil;
    if ([[self viewController] isKindOfClass:[CDVViewController class]]) {
        CDVViewController *vc = (CDVViewController *)[self viewController];
        NSMutableDictionary *settings = [vc settings];
        serviceWorkerScriptFilename = [settings objectForKey:SERVICE_WORKER];
    }
    if (serviceWorkerScriptFilename != nil) {
        NSString *serviceWorkerScriptRelativePath = [NSString stringWithFormat:@"www/%@", serviceWorkerScriptFilename];
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
            [self createServiceWorkerClientWithUrl:serviceWorkerScriptFilename];
            if (!serviceWorkerInstalled) {
                [self installServiceWorker];
                // TODO: Don't do this on exception. Wait for extended events to complete
                serviceWorkerInstalled = YES;
                [defaults setBool:YES forKey:SERVICE_WORKER_INSTALLED];
            }
            // TODO: Don't do this immediately. Wait for installation to complete
            if (!serviceWorkerActivated) {
                [self activateServiceWorker];
                // TODO: Don't do this on exception. Wait for extended events to complete
                serviceWorkerActivated = YES;
                [defaults setBool:YES forKey:SERVICE_WORKER_ACTIVATED];
            }
        }
    } else {
        NSLog(@"No service worker script defined");
    }
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

    // Return the registration.
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.registration];
    [[self commandDelegate] sendPluginResult:pluginResult callbackId:[command callbackId]];
}

- (void)postMessage:(CDVInvokedUrlCommand*)command
{
    NSString *message = [command argumentAtIndex:0];
    NSDictionary *targetOrigin = [command argumentAtIndex:1];

    // Fire a message event in the JSContext.
    NSString *dispatchCode = [NSString stringWithFormat:@"dispatchEvent(new MessageEvent({data:Kamino.parse('%@')}));", message];
    [self.context evaluateScript:dispatchCode];
}

- (void)installServiceWorker
{
    [self.context evaluateScript:@"dispatchEvent(new ExtendableEvent('install'));"];
}

- (void)activateServiceWorker
{
    [self.context evaluateScript:@"dispatchEvent(new ExtendableEvent('activate'));"];
}

# pragma mark Helper Functions

- (void)createServiceWorkerFromScript:(NSString *)script
{
    // Create a JS context.
    JSContext *context = [JSContext new];

    [context setExceptionHandler:^(JSContext *context, JSValue *value) {
        NSLog(@"%@", value);
    }];

    context[@"handleFetchResponse"] = ^(JSValue *jsRequestId, JSValue *response) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *requestId = [formatter numberFromString:[jsRequestId toString]];
        FetchInterceptorProtocol *interceptor = (FetchInterceptorProtocol *)[self.requestDelegates objectForKey:requestId];
        [self.requestDelegates removeObjectForKey:requestId];

        NSData *data = [[response[@"body"] toString] dataUsingEncoding:NSUTF8StringEncoding];
        JSValue *headerList = response[@"header_list"];
        NSString *mimeType = [headerList[@"mime_type"] toString];
        NSString *encoding = @"utf-8";
        NSString *url = [response[@"url"] toString]; // TODO: Can this ever be different than the request url? if not, don't allow it to be overridden

        NSURLResponse *urlResponse = [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:url]
                                                            MIMEType:mimeType
                                               expectedContentLength:data.length
                                                    textEncodingName:encoding];

        [interceptor handleAResponse:urlResponse withSomeData:data];
    };

    context[@"handleFetchDefault"] = ^(JSValue *jsRequestId, JSValue *response) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *requestId = [formatter numberFromString:[jsRequestId toString]];
        FetchInterceptorProtocol *interceptor = (FetchInterceptorProtocol *)[self.requestDelegates objectForKey:requestId];
        [self.requestDelegates removeObjectForKey:requestId];
        [interceptor passThrough];
    };

    // This function is called by `postMessage`, defined in message.js.
    // `postMessage` serializes the message using kamino.js and passes it here.
    context[@"postMessageInternal"] = ^(JSValue *serializedMessage) {
        NSString *postMessageCode = [NSString stringWithFormat:@"window.postMessage(Kamino.parse('%@'), '*')", [serializedMessage toString]];
        [self.webView stringByEvaluatingJavaScriptFromString:postMessageCode];
    };

    // Load the required assets.
    [self loadServiceWorkerAssetsIntoContext:context];

    // Load the ServiceWorker script.
    [self loadScript:script intoContext:context];

    // Save the JS context.
    [self setContext:context];
}

- (void)createServiceWorkerClientWithUrl:(NSString *)url
{
    // Create a ServiceWorker client.
    NSString *createClientCode = [NSString stringWithFormat:@"var client = new Client('%@');", url];
    [self.context evaluateScript:createClientCode];
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

- (void)loadServiceWorkerAssetsIntoContext:(JSContext *)context
{
    // Specify the assets directory.
    // TODO: Move assets up one directory, so they're not in www.
    NSString *assetDirectoryPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/www/sw_assets"];

    // Get the list of assets.
    NSArray *assetFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:assetDirectoryPath error:NULL];

    // Read and load each asset.
    for (NSString *assetFilename in assetFilenames) {
        NSString *relativePath = [NSString stringWithFormat:@"www/sw_assets/%@", assetFilename];
        [self readAndLoadScriptAtRelativePath:relativePath intoContext:context];
    }
}

- (void)loadScript:(NSString *)script intoContext:(JSContext *)context
{
    // Evaluate the script.
    [context evaluateScript:script];
}

- (void)readAndLoadScriptAtRelativePath:(NSString *)relativePath intoContext:(JSContext *)context
{
    // Read the script.
    NSString *script = [self readScriptAtRelativePath:relativePath];

    if (script == nil) {
        return;
    }

    // Load the script into the context.
    [self loadScript:script intoContext:context];
}


// Test whether a resource should be fetched
- (void)fetchResponseForRequest:(NSURLRequest *)request withId:(NSNumber *)requestId delegateTo:(NSURLProtocol *)protocol
{
    // Register the request and delegate
    [self.requestDelegates setObject:protocol forKey:requestId];

    // Fire a fetch event in the JSContext
    NSString *dispatchCode = [NSString stringWithFormat:@"dispatchEvent(new FetchEvent({request:{url:'%@'}, id:'%lld'}));", [[request URL] absoluteString], [requestId longLongValue]];
    [self.context evaluateScript:dispatchCode];
}

@end

