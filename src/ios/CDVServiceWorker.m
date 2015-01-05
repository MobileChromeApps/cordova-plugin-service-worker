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

NSString * const SERVICE_WORKER = @"service_worker";
NSString * const SERVICE_WORKER_ACTIVATED = @"ServiceWorkerActivated";
NSString * const SERVICE_WORKER_INSTALLED = @"ServiceWorkerInstalled";
NSString * const SERVICE_WORKER_SCRIPT_CHECKSUM = @"ServiceWorkerScriptChecksum";

@implementation CDVServiceWorker

@synthesize context=_context;

- (NSString *)hashForString:(NSString *)string
{
    return @"9";
}

- (void)pluginInitialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    Boolean serviceWorkerInstalled = [defaults boolForKey:SERVICE_WORKER_INSTALLED];
    Boolean serviceWorkerActivated = [defaults boolForKey:SERVICE_WORKER_ACTIVATED];
    NSString *serviceWorkerScriptChecksum = [defaults stringForKey:SERVICE_WORKER_SCRIPT_CHECKSUM];

    NSString *serviceWorker = nil;
    if ([[self viewController] isKindOfClass:[CDVViewController class]]) {
        CDVViewController *vc = (CDVViewController *)[self viewController];
        NSMutableDictionary *settings = [vc settings];
        serviceWorker = [settings objectForKey:SERVICE_WORKER];
    }
    if (serviceWorker != nil) {
        NSLog(@"%@", serviceWorker);
        NSString *serviceWorkerScript = [self readServiceWorkerScriptFromFile:serviceWorker];
        if (serviceWorkerScript != nil) {
            if (![[self hashForString:serviceWorkerScript] isEqualToString:serviceWorkerScriptChecksum]) {
                serviceWorkerInstalled = NO;
                serviceWorkerActivated = NO;
                [defaults setBool:NO forKey:SERVICE_WORKER_INSTALLED];
                [defaults setBool:NO forKey:SERVICE_WORKER_ACTIVATED];
                [defaults setObject:[self hashForString:serviceWorkerScript] forKey:SERVICE_WORKER_SCRIPT_CHECKSUM];
            }
            [self createServiceWorkerWithScript:serviceWorkerScript];
            if (!serviceWorkerInstalled) {
                [self installServiceWorker];
                // TODO: Don't do this on exception. Wait for extended events to complete
                serviceWorkerInstalled = YES;
                [defaults setBool:YES forKey:SERVICE_WORKER_INSTALLED];
            }
            // TODO: Don't do this immediately. Wait for installation to complete
            if (!serviceWorkerActivated) {
                [self activateServiceWorker];
                // TODO: Don't do this on exception. Wait for extended events to complete
                serviceWorkerActivated = YES;
                [defaults setBool:YES forKey:SERVICE_WORKER_ACTIVATED];
            }
        }
    } else {
        NSLog(@"No service worker script defined");
    }
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

- (void)installServiceWorker
{
    [[self context] evaluateScript:@"this.oninstall && (typeof oninstall === 'function') && oninstall()"];
}

- (void)activateServiceWorker
{
    [[self context] evaluateScript:@"this.onactivate && (typeof onactivate === 'function') && onactivate()"];
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

