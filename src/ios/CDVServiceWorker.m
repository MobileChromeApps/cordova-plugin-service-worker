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

NSString * const SERVICE_WORKER = @"service_worker";
NSString * const SERVICE_WORKER_ACTIVATED = @"ServiceWorkerActivated";
NSString * const SERVICE_WORKER_INSTALLED = @"ServiceWorkerInstalled";
NSString * const SERVICE_WORKER_SCRIPT_CHECKSUM = @"ServiceWorkerScriptChecksum";

@interface FetchInterceptorProtocol : NSURLProtocol {}
+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
- (void)handleAResponse:(NSURLResponse *)response withSomeData:(NSData *)data;
@property (nonatomic, retain) NSURLConnection *connection;
@end

@implementation FetchInterceptorProtocol
@synthesize connection=_connection;

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
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

    [instanceForRequest fetchResponseForRequest:workerRequest delegateTo:self];
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

@implementation CDVServiceWorker

@synthesize context=_context;
@synthesize requestDelegates=_requestDelegates;

- (NSString *)hashForString:(NSString *)string
{
    return @"15";
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

- (void)registerServiceWorker:(CDVInvokedUrlCommand*)command
{
    // Extract the arguments.
    NSString *scriptUrl = [command argumentAtIndex:0];
    NSDictionary *options = [command argumentAtIndex:1];

    // Create the ServiceWorker.
    [self createServiceWorkerFromFile:scriptUrl];
}

- (void)installServiceWorker
{
    [self.context evaluateScript:@"dispatchEvent(new ExtendableEvent('install'))"];
}

- (void)activateServiceWorker
{
    [self.context evaluateScript:@"dispatchEvent(new ExtendableEvent('activate'))"];
}

# pragma mark Helper Functions

- (void)createServiceWorkerFromFile:(NSString *)filename
{
    // Read the ServiceWorker script.
    NSString *serviceWorkerScript = [self readScriptAtRelativePath:[NSString stringWithFormat:@"www/%@", filename]];

    // Create the ServiceWorker using this script.
    [self createServiceWorkerFromScript:serviceWorkerScript];
}

- (void)createServiceWorkerFromScript:(NSString *)script
{
    // Create a JS context.
    JSContext *context = [JSContext new];

    // Pipe JS logging in this context to NSLog.
    // NOTE: Not the nicest of hacks, but useful!
    [context evaluateScript:@"var console = {}"];
    context[@"console"][@"log"] = ^(NSString *message) {
        NSLog(@"JS log: %@", message);
    };
    
    [context setExceptionHandler:^(JSContext *context, JSValue *value) {
        NSLog(@"%@", value);
    }];

    context[@"handleFetchResponse"] = ^(JSValue *response) {
        NSNumber *requestId=@6;
        FetchInterceptorProtocol *interceptor = (FetchInterceptorProtocol *)[self.requestDelegates objectForKey:requestId];
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
    
    context[@"handleFetchDefault"] = ^(JSValue *response) {
        NSNumber *requestId=@6;
        FetchInterceptorProtocol *interceptor = (FetchInterceptorProtocol *)[self.requestDelegates objectForKey:requestId];
        [interceptor passThrough];
    };
    
    // Load the required polyfills.
    [self loadPolyfillsIntoContext:context];

    // Load the service worker script.
    [self loadScript:script intoContext:context];

    // Save the JS context.
    [self setContext:context];
}

- (NSString *)readScriptAtRelativePath:(NSString*)relativePath
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

- (void)loadPolyfillsIntoContext:(JSContext *)context
{
    // Specify the polyfill directory.
    // TODO: Move polyfills up one directory, so they're not in www.
    NSString *polyfillDirectoryPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/www/polyfills"];

    // Get the list of polyfills.
    NSArray *polyfillFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:polyfillDirectoryPath error:NULL];

    // Read and load each polyfill.
    for (NSString *polyfillFilename in polyfillFilenames) {
        NSString *relativePath = [NSString stringWithFormat:@"www/polyfills/%@", polyfillFilename];
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
- (void)fetchResponseForRequest:(NSURLRequest *)request delegateTo:(NSURLProtocol *)protocol
{
    // Register the request and delegate
    [self.requestDelegates setObject:protocol forKey:@6];
    
    // Build JS Request object from self.request
    
    // Fire a fetch event in the JSContext
    [self.context evaluateScript:[NSString stringWithFormat:@"dispatchEvent(new FetchEvent({request:{url:'%@', id:6}}));", [[request URL] absoluteString]]];
}



@end

