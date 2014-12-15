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

@implementation CDVServiceWorker

@synthesize context=_context;

- (void)pluginInitialize
{
    NSString *serviceworker = nil;
    if([self.viewController isKindOfClass:[CDVViewController class]]) {
        CDVViewController *vc = (CDVViewController *)self.viewController;
        NSMutableDictionary *settings = vc.settings;
        serviceworker = [settings objectForKey:@"service_worker"];
    }
    if (serviceworker != nil) {
        NSLog(@"%@", serviceworker);
        NSString *serviceWorkerScript = [self readServiceWorkerScriptFromFile:serviceworker];
        if (serviceWorkerScript != nil) {
            [self createServiceWorkerWithScript:serviceWorkerScript];
        }
    }
    else NSLog(@"No service worker script defined");
}

- (NSString *)readServiceWorkerScriptFromFile:(NSString*)filename
{
    // Read the ServiceWorker script.
    NSString *scriptPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:[NSString stringWithFormat:@"/www/%@", filename]];
    NSError* error;
    NSString* serviceWorkerScript = [NSString stringWithContentsOfFile:scriptPath encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"Could not read ServiceWorker script: %@", [error description]);
        return nil;
    }

    return serviceWorkerScript;
}

- (void)createServiceWorkerWithScript:(NSString *)serviceWorkerScript inContext:(JSContext *)context
{
    // Evaluate the ServiceWorker script.
    [context evaluateScript:serviceWorkerScript];
}

- (void)createServiceWorkerWithScript:(NSString *)serviceWorkerScript
{
    // Create a JS context.
    JSContext *context = [JSContext new];

    [self createServiceWorkerWithScript:serviceWorkerScript inContext:context];

    // Save the JS context.
    [self setContext:context];
}

- (void)registerServiceWorker:(CDVInvokedUrlCommand*)command
{
    // Extract the arguments.
    NSString* scriptUrl = [command argumentAtIndex:0];
    NSDictionary* options = [command argumentAtIndex:1];

    // Read the ServiceWorker script.
    NSString* serviceWorkerScript = [self readServiceWorkerScriptFromFile:scriptUrl];

    if (serviceWorkerScript == nil) {
        // TODO(maxw): Send the appropriate PluginResult.
        return;
    }

    [self createServiceWorkerWithScript:serviceWorkerScript];

    // TODO(maxw): Send the appropriate PluginResult.
}

@end

