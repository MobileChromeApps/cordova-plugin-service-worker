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

@interface ServiceWorkerCache : NSManagedObject { }

-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request;
-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options;
-(void) putRequest:(NSURLRequest *)request andResponse:(ServiceWorkerResponse *)response;
-(bool) deleteRequest:(NSURLRequest *)request;

@property (nonatomic, retain) NSMutableDictionary *cache;
@end

@interface ServiceWorkerCacheStorage : NSManagedObject { }

-(NSArray*)getCaches;
-(ServiceWorkerCache*)cacheWithName:(NSString *)cacheName;
-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request;
-(ServiceWorkerResponse *)matchForRequest:(NSURLRequest *)request withOptions:(/*ServiceWorkerCacheMatchOptions*/NSDictionary *)options;

@property (nonatomic, retain) NSMutableDictionary *caches;
@end

@interface ServiceWorkerCacheApi : NSObject { }

+(void)defineFunctionsInContext:(JSContext *)context;
+(ServiceWorkerCacheStorage *)cacheStorageForScope:(NSURL *)scope;

@end

