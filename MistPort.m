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

#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#include "MistPort.h"
#include "MistApi.h"

#include "fs_port.h"
#include "mist_port.h"
#include "wish_ip_addr.h"
#include "port_dns.h"
#include "relay_client.h"
#include "utlist.h"
#include "wish_connection_mgr.h"



int ios_port_main(void);
void ios_port_set_name(char *name);
void ios_port_setup_platform(void);

static NSThread *wishThread;
static NSLock *appToCoreLock;
static BOOL launchedOnce = NO;
static BOOL mistLaunchedOnce = NO;

id mistPort;

static NSLock *dnsResolverLock;
static struct dns_resolver *resolvers = NULL;
static int next_resolver_id;

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
    mistPort = self;
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
    dnsResolverLock = [[NSLock alloc] init];
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

+(void)startResolving:(id) parameter {
    
    NSArray *resolverThreadArgs = parameter;
    NSString *hostnameNSString = resolverThreadArgs[0];
    NSNumber *resolverIdNSNumber = resolverThreadArgs[1];
    
    
    int port = 37001;
    char host[PORT_DNS_MAX_HOSTLEN+1];
    memset(host, 0, PORT_DNS_MAX_HOSTLEN+1);
    int resolver_id = 0;
   
    
    [hostnameNSString getCString:host maxLength:PORT_DNS_MAX_HOSTLEN encoding:NSUTF8StringEncoding];
    resolver_id = [resolverIdNSNumber intValue];
    NSLog(@"Resolver thread executing, %s, id %i", host, resolver_id);
    
    /* This is a filter. Specify that we are interested only in IPv4 addresses. */
    struct addrinfo addrinfo_filter = { .ai_family = AF_INET, .ai_socktype = SOCK_STREAM };
    struct addrinfo *addrinfo_res = NULL;
    NSLog(@"Resolver thread executing still -2, id %i", resolver_id);
    size_t port_str_max_len = 5 + 1;
    char port_str[port_str_max_len];
    NSLog(@"Resolver thread executing still -1, id %i", resolver_id);
    snprintf(port_str, port_str_max_len, "%i", port);
    NSLog(@"Resolver thread executing still 0, id %i", resolver_id);
    int addr_err = getaddrinfo(host, port_str, &addrinfo_filter, &addrinfo_res);
    NSLog(@"Resolver thread executing still 2, id %i", resolver_id);
    if (addr_err == 0) {
        /* Resolving was a success. Note: we should be getting only IPv4 addresses because of the filter. */
        char* ip_str = inet_ntoa(((struct sockaddr_in*)addrinfo_res->ai_addr)->sin_addr);
        wish_ip_addr_t *ip = malloc(sizeof(wish_ip_addr_t));
        NSLog(@"Resolve result. %s id %i", ip_str, resolver_id);

        wish_parse_transport_ip(ip_str, 0, ip);
        
        /* Acquire lock */
        [dnsResolverLock lock];
        /* Lookup from the list of resolvings the structure with id result_id, and set result ip */
        struct dns_resolver *elem = NULL;
        LL_FOREACH(resolvers, elem) {
            if (elem->resolver_id == resolver_id) {
                NSLog(@"Found resolver entry for id %i", resolver_id);
                elem->finished = true;
                elem->result_ip = ip;
                break;
            }
        }
         
        /* Release lock */
        [dnsResolverLock unlock];
        freeaddrinfo(addrinfo_res);
    }
    else {
        printf("DNS resolve fail\n");
        /* Note: Don't call wish_close_connection() here, as it will do (platform-dependent) things set up by wish_open_connection(), which has not been called in this case. */
        struct dns_resolver *elem = NULL;
        
        /* Acquire lock */
        [dnsResolverLock lock];

        LL_FOREACH(resolvers, elem) {
            if (elem->resolver_id == resolver_id) {
                elem->finished = true;
                elem->result_ip = NULL;
                break;
            }
        }
        
        /* Release lock */
        [dnsResolverLock unlock];
    }
    NSLog(@"Resolver thread exitb, id %i", resolver_id);
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

#if TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

/* Building for real device, provide implementations for the Wifi functions */

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

#else //TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

/* Building for iPhone Simulator, provide dummy implementations for the Wifi functions */

void mist_port_wifi_join(mist_api_t* mist_api, const char* ssid, const char* password) {
    NSLog(@"Warning, wifi functionality is not available in the iPhone simulator!");
    NSLog(@"Pretending to hava joined wifi network SSID %s, password %s", ssid, password);
    mist_port_wifi_join_cb(get_mist_api(), WIFI_JOIN_OK);
}

#endif //TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

#if 0
void DNSResolverHostClientCallback ( CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void *info) {
    
    int resolver_id = *((int*) info);
    free(info);
    
    Boolean addrsAvailable = NO;
    CFArrayRef results = CFHostGetAddressing(theHost, &addrsAvailable);
    if (results && addrsAvailable) {
        NSLog(@"Resolver id %i finished with addresses, error %i", resolver_id, error->error );
        CFIndex i, c = CFArrayGetCount(results);
        
        for (i = 0; i < c; i++) {
            struct sockaddr *address = (struct sockaddr *)CFDataGetBytePtr(CFArrayGetValueAtIndex(results, i));
            
            if (address->sa_family == AF_INET) {
                struct sockaddr_in *addr4 = (struct sockaddr_in *) address;
                NSLog(@"Lookup resulted in %s", inet_ntoa(addr4->sin_addr));
                
                union ip {
                    uint32_t as_long;
                    uint8_t as_bytes[4];
                } ip;
                /* XXX Don't convert to host byte order here. Wish ip addresses
                 * have network byte order */
                ip.as_long = addr4->sin_addr.s_addr;
                wish_ip_addr_t ip_addr;
                memcpy(&ip_addr.addr, ip.as_bytes, 4);
                
                /* The IP now as wish_ip_addr */
                
            }
            else if (address->sa_family == AF_INET6) {
                //Not supported by Wish currently
                NSLog(@"Returned sockaddr is inet6");
            }
        }
        
    }
    else {
        NSLog(@"Resolver id %i failed to get any addresses", resolver_id);
    }
}

void startResolving(char* hostname, int resolve_id) {
    CFHostRef host = CFHostCreateWithName(NULL, CFStringCreateWithCString(NULL, hostname, kCFStringEncodingUTF8));
    
    int *info = malloc(sizeof(int));
    *info = resolve_id;
    CFHostClientContext ctx = {.info = info};
    CFHostSetClient(host, DNSResolverHostClientCallback, &ctx);
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFHostScheduleWithRunLoop(host, runloop, CFSTR("DNSResolverRunLoopMode"));
    
    CFStreamError error;
    Boolean didStart = CFHostStartInfoResolution(host, kCFHostAddresses, &error);
    if (!didStart) {
        //error should now have some data
        NSLog(@"Resolving failed to start, code: %i", error.error);
    }
    else {
        
        NSLog(@"Resolving %s started", hostname);
    }
    
    
}
#endif

int port_dns_start_resolving(wish_core_t *core, wish_connection_t *conn, wish_relay_client_t *relay, char *qname) {
    NSLog(@"port_dns_start_resolving");
    struct dns_resolver *new_resolver = malloc(sizeof (struct dns_resolver));
    if (new_resolver == NULL) {
        NSLog(@"Insufficient resources when resolving %s %p %p", qname, conn, relay);
        return -1;
    }
    
    memset(new_server, 0, sizeof (struct dns_resolver));
    int resolver_id = next_resolver_id++;
    new_resolver->finished = false;
    new_resolver->result_ip = NULL;
    new_resolver->core = core;
    new_resolver->conn = conn;
    new_resolver->relay = relay;
    new_resolver->resolver_id = resolver_id;
    
    /* Acquire lock */
    [dnsResolverLock lock];
    LL_APPEND(resolvers, new_resolver);
    /* Release lock */
    [dnsResolverLock unlock];
    
    if (new_resolver->conn && new_resolver->relay) {
        //It is as error to invoke this function when with both conn != NULL and relay != NULL
        NSLog(@"Resolve failure when resolving %s, conn != NULL && relay != NULL, ", qname);
        return -1;
    }
    
    NSString *hostnameNSString = [[NSString alloc] initWithUTF8String:qname];
    NSNumber *resolverIdNSNumber = [NSNumber numberWithInteger:resolver_id];
    
    NSArray *resolverThreadArgs = @[hostnameNSString, resolverIdNSNumber];
    
    NSThread *resolverThread = [[NSThread alloc] initWithTarget:mistPort
                                                selector:@selector(startResolving:)
                                                object:resolverThreadArgs];
    [resolverThread start];
    NSLog(@"port_dns_start_resolving out");
    return 0;
}

int port_dns_poll_resolvers(void) {
    NSLog(@"poll resolvers in");
    bool found = false;
    struct dns_resolver *elem = NULL;
    struct dns_resolver *tmp = NULL;
    
    /* Acquire lock */
    [dnsResolverLock lock];
    
    LL_FOREACH_SAFE(resolvers, elem, tmp) {
        if (elem->finished) {
            LL_DELETE(resolvers, elem);
            found = true;
            break;
        }
    }
    
    /* Release lock */
    [dnsResolverLock unlock];
    
    if (found) {
        NSLog(@"Found finished resolver entry, id %i %p %p", elem->resolver_id, elem->conn, elem->relay);
        if (elem->conn) {
            if (elem->result_ip != NULL) {
                wish_open_connection(elem->core, elem->conn, elem->result_ip,
                                     elem->conn->remote_port, elem->conn->via_relay);
                free(elem->result_ip);
            }
            else {
                // Name resolution failure
                NSLog(@"Name resolution failure, resolver %i, conn %p, relay %p",
                      elem->resolver_id, elem->conn, elem->relay);
                wish_core_signal_tcp_event(elem->core, elem->conn, TCP_DISCONNECTED);
            }
        }
        else if (elem->relay) {
            if (elem->result_ip != NULL) {
                port_relay_client_open(elem->relay, elem->result_ip);
                free(elem->result_ip);
            }
            else {
                // Name resolution failure
                NSLog(@"Name resolution failure, resolver %i, conn %p, relay %p",
                      elem->resolver_id, elem->conn, elem->relay);
                relay_ctrl_disconnect_cb(elem->core, elem->relay);
            }
        }
        free(elem);
    }
    
    
    NSLog(@"poll resolvers out");
    return 0;
}
