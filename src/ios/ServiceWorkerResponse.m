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
#import "ServiceWorkerResponse.h"

@implementation ServiceWorkerResponse

@synthesize url = _url;
@synthesize body = _body;
@synthesize status = _status;

- (id) initWithUrl:(NSString *)url body:(NSString *)body status:(NSNumber *)status {
    if (self = [super init]) {
        _url = url;
        _body = body;
        _status = status;
    }
    return self;
}

+ (ServiceWorkerResponse *)responseFromJSValue:(JSValue *)jvalue
{
    NSString *url = [jvalue[@"url"] toString];
    NSString *body = [jvalue[@"body"] toString];
    NSNumber *status = [jvalue[@"status"] toNumber];
    return [[ServiceWorkerResponse alloc] initWithUrl:url body:body status:status];
}

- (NSDictionary *)toDictionary {
    return [NSDictionary dictionaryWithObjects:@[self.url, self.body, self.status] forKeys:@[@"url", @"body", @"status"]];
}

@end

