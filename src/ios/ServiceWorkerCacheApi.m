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

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "FetchConnectionDelegate.h"
#import "ServiceWorkerCacheApi.h"
#import "ServiceWorkerResponse.h"

static NSManagedObjectContext *moc;
static NSString *rootPath_;

@implementation ServiceWorkerCacheStorage

@synthesize caches=caches_;

-(id) initWithContext:(NSManagedObjectContext *)moc
{
    if ((self = [super init]) != nil) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

        NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"Cache" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];

        NSError *error;
        NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];
    
        // TODO: check error on entries == nil
        if (!entries) {
            entries = @[];
        }
    
        caches_ = [[NSMutableDictionary alloc] initWithCapacity:entries.count+2];
        for (ServiceWorkerCache *cache in entries) {
            caches_[cache.name] = cache;
        }
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
        cache = (ServiceWorkerCache *)[NSEntityDescription insertNewObjectForEntityForName:@"Cache"
        inManagedObjectContext:moc];
        [self.caches setObject:cache forKey:cacheName];
        cache.name = cacheName;
        NSError *err;
        [moc save:&err];
        [self.caches setObject:cache forKey:cacheName];
    }
    return cache;
}

-(void)deleteCacheWithName:(NSString *)cacheName
{
//TODO: Delete from persistent storage
    [self.caches removeObjectForKey:cacheName];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request
{
    return [self matchForRequest:request withOptions:@{}];
}

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options
{
    ServiceWorkerResponse *response = nil;
    for (NSString* cacheName in self.caches) {
        ServiceWorkerCache* cache = self.caches[cacheName];
        response = [cache matchForRequest:request withOptions:options inContext:moc];
        if (response != nil) {
            break;
        }
    }
    return response;
}

@end

@implementation ServiceWorkerCacheApi

static NSMutableDictionary *cacheStorageMap;

-(id) init
{
    if (self = [super init]) {
        
    }
    return self;
}

+(BOOL)initializeStorage
{
    if (moc == nil) {
        NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        
        NSError *err;
        //TODO: switch to NSSQLiteStoreType!
        NSURL *storeURL;
        NSFileManager *fm = [NSFileManager defaultManager];
        storeURL = [fm URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&err];
        [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL URLWithString:@"swcache.db" relativeToURL:storeURL] options:nil error:&err];
        if (err) {
            // CHECK ERRORS!
            return NO;
        } else {
            moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            moc.persistentStoreCoordinator = psc;
        }
    }
    return YES;
}

+(ServiceWorkerCacheStorage *)cacheStorageForScope:(NSURL *)scope
{
    if (cacheStorageMap == nil) {
        cacheStorageMap = [[NSMutableDictionary alloc] initWithCapacity:1];
    }
    [ServiceWorkerCacheApi initializeStorage];
    ServiceWorkerCacheStorage *cachesForScope = (ServiceWorkerCacheStorage *)[cacheStorageMap objectForKey:scope];
    if (cachesForScope == nil) {
        // TODO: Init this properly, using `initWithEntity:insertIntoManagedObjectContext:`.
        cachesForScope = [[ServiceWorkerCacheStorage alloc] initWithContext:moc];
        [cacheStorageMap setObject:cachesForScope forKey:scope];
    }
    return cachesForScope;
}

+(void)defineFunctionsInContext:(JSContext *)context
{
    //TODO: Move this somewhere much better
    NSBundle* mainBundle = [NSBundle mainBundle];
    rootPath_ = [[NSURL fileURLWithPath:[mainBundle pathForResource:@"www" ofType:@"" inDirectory:@""]] absoluteString];

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
        if (cacheName == nil || !cacheName.isString || cacheName.toString.length == 0) {
            cachedResponse = [cacheStorage matchForRequest:urlRequest];
        } else {
            cachedResponse = [[cacheStorage cacheWithName:[cacheName toString]] matchForRequest:urlRequest inContext:moc];
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
        [cache putRequest:urlRequest andResponse:serviceWorkerResponse inContext:moc];

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
        [cache deleteRequest:urlRequest fromContext:moc];

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
        [resolve callWithArguments:@[[cache requestsFromContext:moc]]];
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
    if ([urlString hasPrefix:rootPath_]) {
        urlString = [urlString substringFromIndex:[rootPath_ length]-1];
    }
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

@end

