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
#import <CoreData/CoreData.h>
#import <JavaScriptCore/JSContext.h>
#import "ServiceWorkerResponse.h"
#import "ServiceWorkerCache.h"

extern NSString * const SERVICE_WORKER;

@interface ServiceWorkerCacheStorage : NSObject { }

-(ServiceWorkerCache*)cacheWithName:(NSString *)cacheName;
-(BOOL)deleteCacheWithName:(NSString *)cacheName;
-(BOOL)hasCacheWithName:(NSString *)cacheName;

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request;
-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options;

@property (nonatomic, retain) NSMutableDictionary *caches;
@end

@interface ServiceWorkerCacheApi : NSObject { }

-(id)initWithScope:(NSString *)scope cacheCordovaAssets:(BOOL)cacheCordovaAssets;
-(void)defineFunctionsInContext:(JSContext *)context;
-(ServiceWorkerCacheStorage *)cacheStorageForScope:(NSURL *)scope;
-(BOOL)initializeStorage;

@property (nonatomic, retain) NSMutableDictionary *cacheStorageMap;
@property (nonatomic) BOOL cacheCordovaAssets;
@property (nonatomic, retain) NSString *absoluteScope;
@end

