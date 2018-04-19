//
//  MistApi.m
//  Mist
//
//  Created by Jan on 09/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MistApi.h"
#import "MistApiResponseHandler.h"

#include "wish_app.h"
#include "mist_app.h"
#include "mist_api.h"
#include "bson_visit.h"

static wish_app_t *wish_app;
static mist_app_t *mist_app;
static mist_api_t *mist_api;

static int next_rpc_id = 1;

NSMutableDictionary *cbDictionary;

static void generic_callback(rpc_client_req* req, void *ctx, const uint8_t *payload, size_t payload_len) {
    //NSLog(@"Callback!");
    int req_id = 0;
    bool is_ack = false, is_sig = false, is_err = false;
    
    bson_iterator it;
    bson_find_from_buffer(&it, (const char*)payload, "ack");
    if (bson_iterator_type(&it) == BSON_INT) {
        req_id = bson_iterator_int(&it);
        is_ack = true;
    }
    
    bson_find_from_buffer(&it, (const char*)payload, "sig");
    if (bson_iterator_type(&it) == BSON_INT) {
        req_id = bson_iterator_int(&it);
        is_sig = true;
    }
    
    bson_find_from_buffer(&it, (const char*)payload, "err");
    if (bson_iterator_type(&it) == BSON_INT) {
        req_id = bson_iterator_int(&it);
        is_err = true;
    }
    
    bson_find_from_buffer(&it, (const char*)payload, "fin");
    if (bson_iterator_type(&it) == BSON_INT) {
        req_id = bson_iterator_int(&it);
        NSLog(@"(fin for rpc id %i)", req_id);
        return;
    }
    
    if (!is_ack && !is_err && !is_sig) {
        bson_visit("No ack, sig, or err, Here is the payload:", payload);
        return;
    }
    
    NSValue *key = [NSValue valueWithBytes:&req_id objCType:@encode(int)];
    id<MistApiResponseHandler> cb = [cbDictionary objectForKey:key];
    
    if (cb == nil) {
        NSLog(@"Error: No callback object for RPC id %i", req_id);
        return;
    }
    
    if (is_ack || is_sig) {
        bson bs;
        bson_init(&bs);
        
        bson_find_from_buffer(&it, (const char*) payload, "data");
        
        if ( BSON_EOO != bson_iterator_type(&it)) {
            bson_append_element(&bs, "data", &it);
        }
        else {
            NSLog(@"Error appending element");
        }
        
        bson_finish(&bs);
        
        NSData *data = [[NSData alloc] initWithBytes:bson_data(&bs) length:bson_size(&bs)];
        [cb handleResponse:data];
        bson_destroy(&bs);
    }
    else if (is_err) {
        bson_visit("RPC error: ", payload);
        
        bson bs;
        bson_init_with_data(&bs, payload);
        bson_iterator sit;
        bson_iterator_init(&sit, &bs);
        bson_find_fieldpath_value("data.code", &sit);
        
        int err_code = 0;
        char *err_msg = NULL;
        if ( BSON_INT != bson_iterator_type(&sit)) {
            NSLog(@"error data is not an object!");
            [cb handleError:-1 message:@"no message here, see your console"];
        }
        else {
            err_code = bson_iterator_int(&sit);
            bson_iterator_init(&sit, &bs);
            bson_find_fieldpath_value("data.msg", &sit);
            if ( BSON_STRING != bson_iterator_type(&sit)) {
                NSLog(@"error data is not an object!");
                [cb handleError:-2 message:@"no message here, see your console"];
            }
            else {
                err_msg = (char*) bson_iterator_string(&sit);
                [cb handleError:err_code message:[[NSString alloc] initWithFormat:@"%s", err_msg]];
            }
        }
    }
    
    if (is_ack || is_err) {
        [cbDictionary removeObjectForKey:key];
    }
}



@implementation MistApi
+ (void)startMistApi:(NSString *)appName {
    wish_app = wish_app_create([appName UTF8String]);
    
    if (wish_app == NULL) {
        NSLog(@"Cannot create Wish app!");
    }
    
    mist_app = start_mist_app();
    
    if (mist_app == NULL) {
        NSLog(@"Cannot create mist_app!");
    }
    
    wish_app_add_protocol(wish_app, &mist_app->protocol);
    mist_app->app = wish_app;
    
    mist_api = mist_api_init(mist_app);
    
    cbDictionary = [[NSMutableDictionary alloc] init];
    wish_app_connected(wish_app, true);;
}

+ (int)mistApiRequestWithBson:(bson *)reqBson callback:(id <MistApiResponseHandler>)cb {
    bson_iterator it;
    if ( BSON_INT != bson_find(&it, reqBson, "id")) {
        NSLog(@"no id in BSON request");
        return 0;
    }
    bson_inplace_set_long(&it, ++next_rpc_id);
    
    char *op;
    if (BSON_STRING != bson_find(&it, reqBson, "op")) {
        NSLog(@"no op in BSON request");
        return 0;
    }
    op = (char*) bson_iterator_string(&it);
    cb.opString = [[NSString alloc] initWithUTF8String:op];
    
    cb.rpcId = next_rpc_id;
    [cbDictionary setObject:cb forKey:[NSValue valueWithBytes:&next_rpc_id objCType:@encode(int)]];
    mist_api_request(mist_api, reqBson, generic_callback);
    
    return next_rpc_id;
}

+ (void)mistApiCancel:(int)rpcId {
    mist_api_request_cancel(mist_api, rpcId);
}

+ (int)wishApiRequestWithBson:(bson *)reqBson callback:(id <MistApiResponseHandler>)cb {
    bson_iterator it;
    if ( BSON_INT != bson_find(&it, reqBson, "id")) {
        NSLog(@"no id in BSON request");
        return 0;
    }
    bson_inplace_set_long(&it, ++next_rpc_id);
    
    cb.rpcId = next_rpc_id;
    [cbDictionary setObject:cb forKey:[NSValue valueWithBytes:&next_rpc_id objCType:@encode(int)]];
    wish_api_request(mist_api, reqBson, generic_callback);
    
    return next_rpc_id;
}

+ (void)wishApiCancel:(int)rpcId {
    wish_api_request_cancel(mist_api, rpcId);
}

+(void)initMistApp:(id) param {
    
    [MistApi startMistApi:@"iOS MistApi"];
    
}

+(void)sendToMistApp:(NSArray *) params {
    
    uint8_t *wsid = NULL;
    uint8_t *data = NULL;
    size_t len = 0;
    
    [params[0] getValue:&wsid];
    [params[1] getValue:&data];
    [params[2] getValue:&len];
    
    if (wsid != NULL && data!= NULL && len > 0) {
        wish_app_t *app = wish_app_find_by_wsid(wsid);
        wish_app_determine_handler(app, data, len);
    }
    
    free(wsid);
    free(data);
}

@end
