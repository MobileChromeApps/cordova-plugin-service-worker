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

#import <Cordova/CDVPlugin.h>
#import <JavaScriptCore/JSContext.h>
#import "ServiceWorkerCacheApi.h"

extern NSString * const SERVICE_WORKER;
extern NSString * const SERVICE_WORKER_CACHE_CORDOVA_ASSETS;
extern NSString * const SERVICE_WORKER_ACTIVATED;
extern NSString * const SERVICE_WORKER_INSTALLED;
extern NSString * const SERVICE_WORKER_SCRIPT_CHECKSUM;

extern NSString * const REGISTER_OPTIONS_KEY_SCOPE;

extern NSString * const REGISTRATION_KEY_ACTIVE;
extern NSString * const REGISTRATION_KEY_INSTALLING;
extern NSString * const REGISTRATION_KEY_REGISTERING_SCRIPT_URL;
extern NSString * const REGISTRATION_KEY_SCOPE;
extern NSString * const REGISTRATION_KEY_WAITING;

extern NSString * const SERVICE_WORKER_KEY_SCRIPT_URL;

@interface CDVServiceWorker : CDVPlugin <UIWebViewDelegate> {}

+ (CDVServiceWorker *)instanceForRequest:(NSURLRequest *)request;
- (void)addRequestToQueue:(NSURLRequest *)request withId:(NSNumber *)requestId delegateTo:(NSURLProtocol *)protocol;

@property (nonatomic, retain) JSContext *context;
@property (nonatomic, retain) UIWebView *workerWebView;
@property (nonatomic, retain) NSMutableDictionary *requestDelegates;
@property (nonatomic, retain) NSMutableArray *requestQueue;
@property (nonatomic, retain) NSDictionary *registration;
@property (nonatomic, retain) NSString *serviceWorkerScriptFilename;
@property (nonatomic, retain) ServiceWorkerCacheApi *cacheApi;

@end

