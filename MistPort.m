//
//  WishPort.m
//  MistApi
//
//  Created by Jan on 19/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "MistPort.h"
#include "MistApi.h"

#include "fs_port.h"

int ios_port_main(void);
void ios_port_set_name(char *name);
void ios_port_setup_platform(void);

static NSThread *wishThread;
static NSLock *appToCoreLock;
static BOOL launchedOnce = NO;


@implementation MistPort


+(void)saveAppDocumentsPath {
    NSString *path;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    path = [paths objectAtIndex:0];
    set_doc_dir((char *) [path UTF8String]);
}

// Wish core thread
+(void)wishTask:(id) param {
    
    ios_port_set_name((char*) [[UIDevice currentDevice] name].UTF8String);
    
    ios_port_main();
    
    /* unreachable */
}

+(void)launchWish {
    
    if (!launchedOnce) {
        launchedOnce = YES;
    }
    else {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Wish cannot be launched several times."];
    }
    
    [MistPort saveAppDocumentsPath];
    ios_port_setup_platform();
    
    appToCoreLock = [[NSLock alloc] init];
    wishThread = [[NSThread alloc] initWithTarget:self
                                         selector:@selector(wishTask:)
                                              object:nil];
    [wishThread start];
}

+(void)launchMistApi {
    [MistApi startMistApi:@"MistApi"];
}


@end


/**
 This function is used to signal that the Core is ready for an app to log in.
 It will call a function on the app's main thread to signal that app can log in.
 
 This function is run in the context of the wish thread.
 */
void port_service_ipc_connected(bool connected) {
    [MistApi performSelectorOnMainThread:@selector(connected:) withObject:nil waitUntilDone:false];
}

/* Send data to app, invoking a method on the main thread to transport the the data.
 
 This function is run in the context of the wish thread.
 */
void port_send_to_app(const uint8_t wsid[32], const uint8_t *data, size_t len) {
    uint8_t *wsid_copy = malloc(32);
    uint8_t *data_copy = malloc(len);
    
    memcpy(wsid_copy, wsid, 32);
    memcpy(data_copy, data, len);
    
    NSValue *wsidValue = [NSValue valueWithBytes:&wsid_copy objCType:@encode(uint8_t **)];
    NSValue *dataValue = [NSValue valueWithBytes:&data_copy objCType:@encode(uint8_t **)];
    NSValue *lenValue = [NSValue valueWithBytes:&len objCType:@encode(size_t)];
    NSArray *params = @[wsidValue, dataValue, lenValue];
    
    [MistApi performSelectorOnMainThread:@selector(sendToMistApp:) withObject:params waitUntilDone:false];
}

void port_service_lock_acquire(void) {
    [appToCoreLock lock];
}

void port_service_lock_release(void) {
    [appToCoreLock unlock];
}

