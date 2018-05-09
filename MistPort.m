//
//  WishPort.m
//  MistApi
//
//  Created by Jan on 19/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <UIKit/UIKit.h>
@import SystemConfiguration.CaptiveNetwork;
@import NetworkExtension;


#include "MistPort.h"
#include "MistApi.h"

#include "fs_port.h"
#include "mist_port.h"

int ios_port_main(void);
void ios_port_set_name(char *name);
void ios_port_setup_platform(void);

static NSThread *wishThread;
static NSLock *appToCoreLock;
static BOOL launchedOnce = NO;
static BOOL mistLaunchedOnce = NO;


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
        return;
        /*
        [NSException raise:NSInternalInconsistencyException
                    format:@"Wish cannot be launched several times."];
         */
    }
    
    [MistPort saveAppDocumentsPath];
    ios_port_setup_platform();
    
    appToCoreLock = [[NSLock alloc] init];
    wishThread = [[NSThread alloc] initWithTarget:self
                                         selector:@selector(wishTask:)
                                           object:nil];
    [wishThread setName:@"Wish core"];
    [wishThread start];
}

+(void)launchMistApi {
    if (!mistLaunchedOnce) {
        mistLaunchedOnce = YES;
    }
    else {
        return;
    }
    
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
    
    [MistApi performSelectorOnMainThread:@selector(sendToMistApp:) withObject:params waitUntilDone:true];
}

void port_service_lock_acquire(void) {
    [appToCoreLock lock];
}

void port_service_lock_release(void) {
    [appToCoreLock unlock];
}

static void show_curr_wifi(void) {
    NSLog(@"in show_curr_wifi");
    NSArray *interFaceNames = (__bridge_transfer id)CNCopySupportedInterfaces();
    
    for (NSString *name in interFaceNames) {
        NSDictionary *info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)name);
        
        NSLog(@"wifi info: bssid: %@, ssid:%@, ssidData: %@", info[@"BSSID"], info[@"SSID"], info[@"SSIDDATA"]);
        
    }
}

#define SSID_LEN (32 + 1) //SSID can be max 32 charaters, plus null term.

static void get_curr_wifi(char *ssid) {
    NSLog(@"in get_curr_wifi");
    NSArray *interFaceNames = (__bridge_transfer id)CNCopySupportedInterfaces();
    
    for (NSString *name in interFaceNames) {
        NSDictionary *info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)name);
        if (info != nil) {
            NSLog(@"wifi info: bssid: %@, ssid:%@, ssidData: %@", info[@"BSSID"], info[@"SSID"], info[@"SSIDDATA"]);
            strncpy(ssid, [info[@"SSID"] UTF8String], SSID_LEN);
            break;
        }
    }
}

void mist_port_wifi_join(mist_api_t* mist_api, const char* ssid, const char* password) {
    show_curr_wifi();
    //NEHotspotConfigurationManager *hotspotManager = [NEHotspotConfigurationManager sharedManager];
    NSLog(@"Now joining to wifi: %s, password %s", ssid, password);
    if (ssid != NULL) {
        NSString *ssidString = [NSString stringWithUTF8String:ssid];
        NEHotspotConfiguration *configuration;
        if (password == NULL) {
            NSLog(@"No password defined.");
            configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssidString];
        }
        else {
            NSString *passphraseString = [NSString stringWithUTF8String:password];
            configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssidString passphrase: passphraseString isWEP:NO];
        }
        configuration.joinOnce = YES;
        
        [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
            if (error) {
                if (error.code != NEHotspotConfigurationErrorAlreadyAssociated) {
                    NSLog(@"mist_port_wifi_join NSError code: %u", error.code);
                    mist_port_wifi_join_cb(get_mist_api(), WIFI_JOIN_FAILED);
                    return;
                }
                else {
                    NSLog(@"mist_port_wifi_join: Already associated with requested network.");
                }
            }
            show_curr_wifi();
            mist_port_wifi_join_cb(get_mist_api(), WIFI_JOIN_OK);
        }];
    }
    else {
        // ssid is null, in this case just try to remove the current network from list of known networks
        char curr_ssid[SSID_LEN];
        get_curr_wifi(curr_ssid);
        NSString *currSSIDString = [NSString stringWithUTF8String:curr_ssid];
        [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:currSSIDString];
        mist_port_wifi_join_cb(get_mist_api(), WIFI_JOIN_OK); //TODO
    }
}


