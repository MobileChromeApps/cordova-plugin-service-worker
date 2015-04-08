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

NSString * const CORDOVA_ASSETS_CACHE_NAME = @"CordovaAssets";
NSString * const CORDOVA_ASSETS_VERSION_KEY = @"CordovaAssetsVersion";

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

-(ServiceWorkerCache *)cacheWithName:(NSString *)cacheName create:(BOOL)create
{
    ServiceWorkerCache *cache = [self.caches objectForKey:cacheName];
    if (cache == nil) {
        // First try to get it from storage:
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

        NSEntityDescription *entity = [NSEntityDescription
                                       entityForName:@"Cache" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];

        NSPredicate *predicate;

        predicate = [NSPredicate predicateWithFormat:@"(name == %@)", cacheName];
        [fetchRequest setPredicate:predicate];

        NSError *error;
        NSArray *entries = [moc executeFetchRequest:fetchRequest error:&error];
        if (entries.count > 0) {
        // TODO: HAVE NOT SEEN THIS BRANCH EXECUTE YET.
            cache = entries[0];
        } else if (create) {
            // Not there; add it
            cache = (ServiceWorkerCache *)[NSEntityDescription insertNewObjectForEntityForName:@"Cache"
                                                                        inManagedObjectContext:moc];
            [self.caches setObject:cache forKey:cacheName];
            cache.name = cacheName;
            NSError *err;
            [moc save:&err];
        }
    }
    if (cache) {
        // Cache the cache
        [self.caches setObject:cache forKey:cacheName];
    }
    return cache;
}

-(ServiceWorkerCache *)cacheWithName:(NSString *)cacheName
{
    return [self cacheWithName:cacheName create:YES];
}

-(BOOL)deleteCacheWithName:(NSString *)cacheName
{
    ServiceWorkerCache *cache = [self cacheWithName:cacheName create:NO];
    if (cache != nil) {
        [moc deleteObject:cache];
        NSError *err;
        [moc save:&err];
        [self.caches removeObjectForKey:cacheName];
        return YES;
    }
    return NO;
}

-(BOOL)hasCacheWithName:(NSString *)cacheName
{
    return ([self cacheWithName:cacheName create:NO] != nil);
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

@synthesize cacheStorageMap = _cacheStorageMap;
@synthesize cacheCordovaAssets = _cacheCordovaAssets;
@synthesize absoluteScope = _absoluteScope;

-(id)initWithScope:(NSString *)scope cacheCordovaAssets:(BOOL)cacheCordovaAssets
{
    if (self = [super init]) {
        if (scope == nil) {
            self.absoluteScope = @"/";
        } else {
            self.absoluteScope = scope;
        }
        self.cacheCordovaAssets = cacheCordovaAssets;
    }
    return self;
}

+(NSManagedObjectModel *)createManagedObjectModel
{
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    NSMutableArray *entities = [NSMutableArray array];

    // ServiceWorkerCache
    NSEntityDescription *cacheEntity = [[NSEntityDescription alloc] init];
    cacheEntity.name = @"Cache";
    cacheEntity.managedObjectClassName = @"ServiceWorkerCache";

    //ServiceWorkerCacheEntry
    NSEntityDescription *cacheEntryEntity = [[NSEntityDescription alloc] init];
    cacheEntryEntity.name = @"CacheEntry";
    cacheEntryEntity.managedObjectClassName = @"ServiceWorkerCacheEntry";

    NSMutableArray *cacheProperties = [NSMutableArray array];
    NSMutableArray *cacheEntryProperties = [NSMutableArray array];

    // ServiceWorkerCache::name
    NSAttributeDescription *nameAttribute = [[NSAttributeDescription alloc] init];
    nameAttribute.name = @"name";
    nameAttribute.attributeType = NSStringAttributeType;
    nameAttribute.optional = NO;
    nameAttribute.indexed = YES;
    [cacheProperties addObject:nameAttribute];

    // ServiceWorkerCache::scope
    NSAttributeDescription *scopeAttribute = [[NSAttributeDescription alloc] init];
    scopeAttribute.name = @"scope";
    scopeAttribute.attributeType = NSStringAttributeType;
    scopeAttribute.optional = YES;
    scopeAttribute.indexed = NO;
    [cacheProperties addObject:scopeAttribute];

    // ServiceWorkerCacheEntry::url
    NSAttributeDescription *urlAttribute = [[NSAttributeDescription alloc] init];
    urlAttribute.name = @"url";
    urlAttribute.attributeType = NSStringAttributeType;
    urlAttribute.optional = YES;
    urlAttribute.indexed = YES;
    [cacheEntryProperties addObject:urlAttribute];

    // ServiceWorkerCacheEntry::query
    NSAttributeDescription *queryAttribute = [[NSAttributeDescription alloc] init];
    queryAttribute.name = @"query";
    queryAttribute.attributeType = NSStringAttributeType;
    queryAttribute.optional = YES;
    queryAttribute.indexed = YES;
    [cacheEntryProperties addObject:queryAttribute];

    // ServiceWorkerCacheEntry::request
    NSAttributeDescription *requestAttribute = [[NSAttributeDescription alloc] init];
    requestAttribute.name = @"request";
    requestAttribute.attributeType = NSBinaryDataAttributeType;
    requestAttribute.optional = NO;
    requestAttribute.indexed = NO;
    [cacheEntryProperties addObject:requestAttribute];

    // ServiceWorkerCacheEntry::response
    NSAttributeDescription *responseAttribute = [[NSAttributeDescription alloc] init];
    responseAttribute.name = @"response";
    responseAttribute.attributeType = NSBinaryDataAttributeType;
    responseAttribute.optional = NO;
    responseAttribute.indexed = NO;
    [cacheEntryProperties addObject:responseAttribute];


    // ServiceWorkerCache::entries
    NSRelationshipDescription *entriesRelationship = [[NSRelationshipDescription alloc] init];
    entriesRelationship.name = @"entries";
    entriesRelationship.destinationEntity = cacheEntryEntity;
    entriesRelationship.minCount = 0;
    entriesRelationship.maxCount = 0;
    entriesRelationship.deleteRule = NSCascadeDeleteRule;

    // ServiceWorkerCacheEntry::cache
    NSRelationshipDescription *cacheRelationship = [[NSRelationshipDescription alloc] init];
    cacheRelationship.name = @"cache";
    cacheRelationship.destinationEntity = cacheEntity;
    cacheRelationship.minCount = 0;
    cacheRelationship.maxCount = 1;
    cacheRelationship.deleteRule = NSNullifyDeleteRule;
    cacheRelationship.inverseRelationship = entriesRelationship;
    [cacheEntryProperties addObject:cacheRelationship];


    entriesRelationship.inverseRelationship = cacheRelationship;
    [cacheProperties addObject:entriesRelationship];

    cacheEntity.properties = cacheProperties;
    cacheEntryEntity.properties = cacheEntryProperties;

    [entities addObject:cacheEntity];
    [entities addObject:cacheEntryEntity];

    model.entities = entities;
    return model;
}

-(BOOL)initializeStorage
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    rootPath_ = [[NSURL fileURLWithPath:[mainBundle pathForResource:@"www" ofType:@"" inDirectory:@""]] absoluteString];

    if (moc == nil) {
        NSManagedObjectModel *model = [ServiceWorkerCacheApi createManagedObjectModel];
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];

        NSError *err;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *documentsDirectoryURL = [fm URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&err];
        NSURL *cacheDirectoryURL = [documentsDirectoryURL URLByAppendingPathComponent:@"CacheData"];
        [fm createDirectoryAtURL:cacheDirectoryURL withIntermediateDirectories:YES attributes:nil error:&err];
        NSURL *storeURL = [cacheDirectoryURL URLByAppendingPathComponent:@"swcache.db"];

        if (![fm fileExistsAtPath:[storeURL path]]) {
            NSLog(@"Service Worker Cache doesn't exist.");
            NSString *initialDataPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"CacheData"];
            BOOL cacheDataIsDirectory;
            if ([fm fileExistsAtPath:initialDataPath isDirectory:&cacheDataIsDirectory]) {
                if (cacheDataIsDirectory) {
                    NSURL *initialDataURL = [NSURL fileURLWithPath:initialDataPath isDirectory:YES];
                    NSLog(@"Copying Initial Cache.");
                    NSArray *fileURLs = [fm contentsOfDirectoryAtURL:initialDataURL includingPropertiesForKeys:nil options:0 error:&err];
                    for (NSURL *fileURL in fileURLs) {
                        [fm copyItemAtURL:fileURL toURL:cacheDirectoryURL error:&err];
                    }
                }
            }
        }

        NSLog(@"Using file %@ for service worker cache", [cacheDirectoryURL path]);
        err = nil;
        [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL URLWithString:@"swcache.db" relativeToURL:storeURL] options:nil error:&err];
        if (err) {
            // Try to delete the old store and try again
            [fm removeItemAtURL:[NSURL URLWithString:@"swcache.db" relativeToURL:storeURL] error:&err];
            [fm removeItemAtURL:[NSURL URLWithString:@"swcache.db-shm" relativeToURL:storeURL] error:&err];
            [fm removeItemAtURL:[NSURL URLWithString:@"swcache.db-wal" relativeToURL:storeURL] error:&err];
            err = nil;
            [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL URLWithString:@"swcache.db" relativeToURL:storeURL] options:nil error:&err];
            if (err) {
                return NO;
            }
        }
        moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        moc.persistentStoreCoordinator = psc;

        // If this is the first run ever, or the app has been updated, populate the Cordova assets cache with assets from www/.
        if (self.cacheCordovaAssets) {
            NSString *cordovaAssetsVersion = [[NSUserDefaults standardUserDefaults] stringForKey:CORDOVA_ASSETS_VERSION_KEY];
            NSString *currentAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
            if (cordovaAssetsVersion == nil || ![cordovaAssetsVersion isEqualToString:currentAppVersion]) {
                // Delete the existing cache (if it exists).
                NSURL *scope = [NSURL URLWithString:self.absoluteScope];
                ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
                [cacheStorage deleteCacheWithName:CORDOVA_ASSETS_CACHE_NAME];

                // Populate the cache.
                [self populateCordovaAssetsCache];

                // Store the app version.
                [[NSUserDefaults standardUserDefaults] setObject:currentAppVersion forKey:CORDOVA_ASSETS_VERSION_KEY];
            }
        }
    }

    return YES;
}

-(void)populateCordovaAssetsCache
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *wwwDirectoryPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/www"];
    NSURL *wwwDirectoryUrl = [NSURL fileURLWithPath:wwwDirectoryPath isDirectory:YES];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];

    NSDirectoryEnumerator *enumerator = [fileManager
        enumeratorAtURL:wwwDirectoryUrl
        includingPropertiesForKeys:keys
        options:0
        errorHandler:^(NSURL *url, NSError *error) {
            // Handle the error.
            // Return YES if the enumeration should continue after the error.
            return YES;
        }
    ];

    // TODO: Prevent caching of sw_assets?
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // Handle error.
        } else if (![isDirectory boolValue]) {
            [self addToCordovaAssetsCache:url];
        }
    }
}

-(void)addToCordovaAssetsCache:(NSURL *)url
{
    // Create an NSURLRequest.
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];

    // Ensure we're fetching purely.
    [NSURLProtocol setProperty:@YES forKey:@"PureFetch" inRequest:urlRequest];

    // Create a connection and send the request.
    FetchConnectionDelegate *delegate = [FetchConnectionDelegate new];
    delegate.resolve = ^(ServiceWorkerResponse *response) {
        // Get or create the specified cache.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];
        ServiceWorkerCache *cache = [cacheStorage cacheWithName:CORDOVA_ASSETS_CACHE_NAME];

        // Create a URL request using a relative path.
        NSMutableURLRequest *shortUrlRequest = [self nativeRequestFromDictionary:@{@"url": [url absoluteString]}];
NSLog(@"Using short url: %@", shortUrlRequest.URL);

        // Put the request and response in the cache.
        [cache putRequest:shortUrlRequest andResponse:response inContext:moc];
    };
    [NSURLConnection connectionWithRequest:urlRequest delegate:delegate];
}

-(ServiceWorkerCacheStorage *)cacheStorageForScope:(NSURL *)scope
{
    if (self.cacheStorageMap == nil) {
        self.cacheStorageMap = [[NSMutableDictionary alloc] initWithCapacity:1];
    }
    [self initializeStorage];
    ServiceWorkerCacheStorage *cachesForScope = (ServiceWorkerCacheStorage *)[self.cacheStorageMap objectForKey:scope];
    if (cachesForScope == nil) {
        // TODO: Init this properly, using `initWithEntity:insertIntoManagedObjectContext:`.
        cachesForScope = [[ServiceWorkerCacheStorage alloc] initWithContext:moc];
        [self.cacheStorageMap setObject:cachesForScope forKey:scope];
    }
    return cachesForScope;
}

-(void)defineFunctionsInContext:(JSContext *)context
{
    // Cache functions.

    // Resolve with a response.
    context[@"cacheMatch"] = ^(JSValue *cacheName, JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

        // Convert the given request into an NSURLRequest.
        NSURLRequest *urlRequest = [self nativeRequestFromJsRequest:request];

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
    context[@"cachePut"] = ^(JSValue *cacheName, JSValue *request, JSValue *response, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

        // Get or create the specified cache.
        ServiceWorkerCache *cache = [cacheStorage cacheWithName:[cacheName toString]];

        // Convert the given request into an NSURLRequest.
        NSMutableURLRequest *urlRequest;
        if ([request isString]) {
            urlRequest = [self nativeRequestFromDictionary:@{@"url" : [request toString]}];
        } else {
            urlRequest = [self nativeRequestFromJsRequest:request];
        }

        // Convert the response into a ServiceWorkerResponse.
        ServiceWorkerResponse *serviceWorkerResponse = [ServiceWorkerResponse responseFromJSValue:response];
        [cache putRequest:urlRequest andResponse:serviceWorkerResponse inContext:moc];

        // Resolve!
        [resolve callWithArguments:@[[NSNull null]]];
    };

    // Resolve with a boolean.
    context[@"cacheDelete"] = ^(JSValue *cacheName, JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

        // Get or create the specified cache.
        ServiceWorkerCache *cache =[cacheStorage cacheWithName:[cacheName toString]];

        // Convert the given request into an NSURLRequest.
        NSURLRequest *urlRequest = [self nativeRequestFromJsRequest:request];

        // Delete the request key from the cache.
        [cache deleteRequest:urlRequest fromContext:moc];

        // Resolve!
        [resolve callWithArguments:@[[NSNull null]]];
    };

    // Resolve with a list of requests.
    context[@"cacheKeys"] = ^(JSValue *cacheName, JSValue *request, JSValue *options, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

        // Get or create the specified cache.
        ServiceWorkerCache *cache =[cacheStorage cacheWithName:[cacheName toString]];

        // Return the requests from the cache.
        // TODO: Use the given (optional) request.
        NSArray *cacheEntries = [cache requestsFromContext:moc];
        NSMutableArray *requests = [NSMutableArray new];
        for (ServiceWorkerCacheEntry *entry in cacheEntries) {
            NSURLRequest *urlRequest = (NSURLRequest *)[NSKeyedUnarchiver unarchiveObjectWithData:entry.request];
            NSString *method = [urlRequest HTTPMethod];
            NSString *url = [[urlRequest URL] absoluteString];
            NSDictionary *headers = [urlRequest allHTTPHeaderFields];
            if (headers == nil) {
                headers = [NSDictionary new];
            }
            NSDictionary *requestDictionary = @{ @"method": method, @"url": url, @"headers": headers };
            [requests addObject:requestDictionary];
        }
        [resolve callWithArguments:@[requests]];
    };


    // CacheStorage functions.

    // Resolve with a boolean.
    context[@"cachesHas"] = ^(JSValue *cacheName, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

        // Check whether the specified cache exists.
        BOOL hasCache = [cacheStorage hasCacheWithName:[cacheName toString]];

        // Resolve!
        [resolve callWithArguments:@[[NSNumber numberWithBool:hasCache]]];
    };

    // Resolve with a boolean.
    context[@"cachesDelete"] = ^(JSValue *cacheName, JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

        // Delete the specified cache.
        BOOL cacheDeleted = [cacheStorage deleteCacheWithName:[cacheName toString]];

        // Resolve!
        [resolve callWithArguments:@[[NSNumber numberWithBool:cacheDeleted]]];
    };

    // Resolve with a list of strings.
    context[@"cachesKeys"] = ^(JSValue *resolve, JSValue *reject) {
        // Retrieve the caches.
        NSURL *scope = [NSURL URLWithString:self.absoluteScope];
        ServiceWorkerCacheStorage *cacheStorage = [self cacheStorageForScope:scope];

        // Resolve!
        [resolve callWithArguments:@[[cacheStorage.caches allKeys]]];
    };
}

-(NSMutableURLRequest *)nativeRequestFromJsRequest:(JSValue *)jsRequest
{
    NSDictionary *requestDictionary = [jsRequest toDictionary];
    return [self nativeRequestFromDictionary:requestDictionary];
}

-(NSMutableURLRequest *)nativeRequestFromDictionary:(NSDictionary *)requestDictionary
{
    NSString *urlString = requestDictionary[@"url"];
    if ([urlString hasPrefix:rootPath_]) {
        urlString = [NSString stringWithFormat:@"%@%@", self.absoluteScope, [urlString substringFromIndex:[rootPath_ length]]];
    }
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

@end

