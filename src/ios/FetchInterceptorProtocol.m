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

#import "FetchInterceptorProtocol.h"
#import "CDVServiceWorker.h"

#include <libkern/OSAtomic.h>

@implementation FetchInterceptorProtocol
@synthesize connection=_connection;

static int64_t requestCount = 0;

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // We don't want to intercept any requests for the worker page.
    if ([[[request URL] absoluteString] hasSuffix:@"GeneratedWorker.html"]) {
        return NO;
    }

    // Check - is there a service worker for this request?
    // For now, assume YES -- all requests go through service worker. This may be incorrect if there are iframes present.
    if ([NSURLProtocol propertyForKey:@"PassThrough" inRequest:request]) {
        // Already seen; not handling
        return NO;
    } else if ([NSURLProtocol propertyForKey:@"PureFetch" inRequest:request]) {
        // Fetching directly; bypass ServiceWorker.
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

    [instanceForRequest addRequestToQueue:workerRequest withId:requestId delegateTo:self];
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

