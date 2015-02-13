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

#import <JavaScriptCore/JavaScriptCore.h>
#import "FetchConnectionDelegate.h"
#import "ServiceWorkerCache.h"
#import "ServiceWorkerResponse.h"

@implementation ServiceWorkerCache

@synthesize cache=cache_;

-(id) init {
    if ((self = [super init]) != nil) {
        cache_ = [[NSMutableDictionary alloc] initWithCapacity:10];
    }
    return self;
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request
{
    return [self matchForRequest:request withOptions:@{}];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options
{
    // TODO: Implement correct matching algorithm
    return [self.cache objectForKey:request];
}

-(void)putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *)response
{
    [self.cache setObject:response forKey:request];
}

-(bool)deleteRequest:(NSURLRequest *)request
{
    bool requestExistsInCache = ([self.cache objectForKey:request] != nil);
    if (requestExistsInCache) {
        [self.cache removeObjectForKey:request];
    }
    return requestExistsInCache;
}

-(NSArray *)requests
{
    return [self.cache allKeys];
}

@end

@implementation ServiceWorkerCacheStorage

@synthesize caches=caches_;

-(id) init {
    if ((self = [super init]) != nil) {
        caches_ = [[NSMutableDictionary alloc] initWithCapacity:2];
    }
    return self;
}

-(NSArray *)getCacheNames
{
    return [self.caches allKeys];
}

-(ServiceWorkerCache *)cacheWithName:(NSString *)cacheName
{
    ServiceWorkerCache *cache = [self.caches objectForKey:cacheName];
    if (cache == nil) {
        cache = [[ServiceWorkerCache alloc] init];
        [self.caches setObject:cache forKey:cacheName];
    }
    return cache;
}

-(void)deleteCacheWithName:(NSString *)cacheName
{
    [self.caches removeObjectForKey:cacheName];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request
{
    return [self matchForRequest:request withOptions:@{}];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options
{
    ServiceWorkerResponse *response = nil;
    for (ServiceWorkerCache* cache in self.caches) {
        response = [cache matchForRequest:request withOptions:options];
        if (response != nil) {
            break;
        }
    }
    return response;
}

@end

@implementation ServiceWorkerCacheApi

static NSMutableDictionary *cacheStorageMap;

+(ServiceWorkerCacheStorage *)cacheStorageForScope:(NSURL *)scope
{
    if (cacheStorageMap == nil) {
        cacheStorageMap = [[NSMutableDictionary alloc] initWithCapacity:1];
    }
    ServiceWorkerCacheStorage *cachesForScope = (ServiceWorkerCacheStorage *)[cacheStorageMap objectForKey:scope];
    if (cachesForScope == nil) {
        // TODO: Init this properly, using `initWithEntity:insertIntoManagedObjectContext:`.
        cachesForScope = [[ServiceWorkerCacheStorage alloc] init];
        [cacheStorageMap setObject:cachesForScope forKey:scope];
    }
    return cachesForScope;
}

+(void)defineFunctionsInContext:(JSContext *)context
{
    // Cache functions.

    // Resolve with a response.
    context[@"cacheMatch"] = ^(JSValue *cacheName, JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Convert the given request into an NSURLRequest.
        NSURLRequest *urlRequest = [ServiceWorkerCacheApi nativeRequestFromJsRequest:request];

        // Check for a match in the cache.
        // TODO: Deal with multiple matches.
        ServiceWorkerResponse *cachedResponse;
        if (cacheName == nil) {
            cachedResponse = [cacheStorage matchForRequest:urlRequest];
        } else {
            cachedResponse = [[cacheStorage cacheWithName:[cacheName toString]] matchForRequest:urlRequest];
        }

        if (cachedResponse != nil) {
            // Convert the response to a dictionary and send it to the promise resolver.
            NSDictionary *responseDictionary = [cachedResponse toDictionary];
            [resolve callWithArguments:@[responseDictionary]];
        } else {
            [resolve callWithArguments:@[[NSNull null]]];
        }
    };

    // Resolve with a list of responses.
    context[@"cacheMatchAll"] = ^(JSValue *cacheName, JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {

    };

    // Resolve with nothing.
    context[@"cacheAdd"] = ^(JSValue *cacheName, JSValue *request, JSValue *resolve, JSValue *reject) {
        // Convert the given request into an NSURLRequest.
        NSMutableURLRequest *urlRequest;
        if ([request isString]) {
            urlRequest = [ServiceWorkerCacheApi nativeRequestFromDictionary:@{@"url" : [request toString]}];
        } else {
            urlRequest = [ServiceWorkerCacheApi nativeRequestFromJsRequest:request];
        }
        [NSURLProtocol setProperty:@YES forKey:@"PureFetch" inRequest:urlRequest];

        // Create a connection and send the request.
        FetchConnectionDelegate *delegate = [FetchConnectionDelegate new];
        delegate.resolve = resolve;
        delegate.reject = reject;
        [NSURLConnection connectionWithRequest:urlRequest delegate:delegate];
    };

    // Resolve with nothing.
    context[@"cachePut"] = ^(JSValue *cacheName, JSValue *request, JSValue *response, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Get or create the specified cache.
        ServiceWorkerCache *cache = [cacheStorage cacheWithName:[cacheName toString]];

        // Convert the given request into an NSURLRequest.
        NSMutableURLRequest *urlRequest;
        if ([request isString]) {
            urlRequest = [ServiceWorkerCacheApi nativeRequestFromDictionary:@{@"url" : [request toString]}];
        } else {
            urlRequest = [ServiceWorkerCacheApi nativeRequestFromJsRequest:request];
        }

        // Convert the response into a ServiceWorkerResponse.
        // TODO: Factor this out.
        ServiceWorkerResponse *serviceWorkerResponse = [ServiceWorkerResponse responseFromJSValue:response];
        [cache putRequest:urlRequest andResponse:serviceWorkerResponse];

        // Resolve!
        [resolve callWithArguments:@[[NSNull null]]];
    };

    // Resolve with a boolean.
    context[@"cacheDelete"] = ^(JSValue *cacheName, JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Get or create the specified cache.
        ServiceWorkerCache *cache =[cacheStorage cacheWithName:[cacheName toString]];

        // Convert the given request into an NSURLRequest.
        NSURLRequest *urlRequest = [ServiceWorkerCacheApi nativeRequestFromJsRequest:request];

        // Delete the request key from the cache.
        [cache deleteRequest:urlRequest];

        // Resolve!
        [resolve callWithArguments:@[[NSNull null]]];
    };

    // Resolve with a list of requests.
    context[@"cacheKeys"] = ^(JSValue *cacheName, JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Get or create the specified cache.
        ServiceWorkerCache *cache =[cacheStorage cacheWithName:[cacheName toString]];

        // Return the requests from the cache.
        [resolve callWithArguments:@[[cache requests]]];
    };


    // CacheStorage functions.

    // Resolve with nothing.
    context[@"openCache"] = ^(JSValue *cacheName, JSValue *resolve) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Get or create the specified cache.
        [cacheStorage cacheWithName:[cacheName toString]];

        // Resolve!
        [resolve callWithArguments:@[[NSNull null]]];
    };

    // Resolve with nothing.
    context[@"deleteCache"] = ^(JSValue *cacheName, JSValue *resolve) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Delete the specified cache.
        [cacheStorage deleteCacheWithName:[cacheName toString]];

        // Resolve!
        [resolve callWithArguments:@[[NSNull null]]];
    };
}

+ (NSMutableURLRequest *)nativeRequestFromJsRequest:(JSValue *)jsRequest
{
    NSDictionary *requestDictionary = [jsRequest toDictionary];
    return [ServiceWorkerCacheApi nativeRequestFromDictionary:requestDictionary];
}

+ (NSMutableURLRequest *)nativeRequestFromDictionary:(NSDictionary *)requestDictionary
{
    NSString *urlString = requestDictionary[@"url"];
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

@end

