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

-(void) putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *)response
{
    [self.cache setObject:response forKey:request];
}

-(bool) deleteRequest:(NSURLRequest *)request
{
    bool requestExistsInCache = ([self.cache objectForKey:request] != nil);
    if (requestExistsInCache) {
        [self.cache removeObjectForKey:request];
    }
    return requestExistsInCache;
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

-(NSArray *)getCaches
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
        cachesForScope = [[ServiceWorkerCacheStorage alloc] init];
        [cacheStorageMap setObject:cachesForScope forKey:scope];
    }
    return cachesForScope;
}

+(void)defineFunctionsInContext:(JSContext *)context {
    context[@"match"] = ^(JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Convert the given request into an NSURLRequest.
        // TODO: Refactor this; it's also used in `handleTrueFetch`.
        NSDictionary *requestDictionary = [request toDictionary];
        NSString *urlString = requestDictionary[@"url"];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];

        // Check for a match in the cache.
        // TODO: Deal with multiple matches.
        ServiceWorkerResponse *cachedResponse = [cacheStorage matchForRequest:urlRequest];
        if (cachedResponse != nil) {
            // Convert the response to a dictionary and send it to the promise resolver.
            NSDictionary *responseDictionary = [cachedResponse toDictionary];
            [resolve callWithArguments:@[responseDictionary]];
        } else {
            [resolve callWithArguments:@[[NSNull null]]];
        }
    };

    context[@"put"] = ^(JSValue *cacheName, JSValue *request, JSValue *response, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:@"/"];
        ServiceWorkerCacheStorage *cacheStorage = [ServiceWorkerCacheApi cacheStorageForScope:scope];

        // Get or create the specified cache
        ServiceWorkerCache *cache = [cacheStorage cacheWithName:[cacheName toString]];

        // Convert the given request into an NSURLRequest.
        // TODO: Refactor this; it's also used in `handleTrueFetch`.
        NSDictionary *requestDictionary = [request toDictionary];
        NSString *urlString = requestDictionary[@"url"];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];

        // Convert the response into a ServiceWorkerResponse.
        // TODO: Factor this out.
        ServiceWorkerResponse *serviceWorkerResponse = [ServiceWorkerResponse responseFromJSValue:response];

        [cache putRequest:urlRequest andResponse:serviceWorkerResponse];
        // Umm... return a something?
        [resolve callWithArguments:@[[NSNull null]]];
    };

}

@end

