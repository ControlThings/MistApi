/**
 * Copyright (C) 2020, ControlThings Oy Ab
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * @license Apache-2.0
 */
//
//  PassthroughRequest.m
//  MistApi
//
//  Created by Jan on 02/07/2018.
//  Copyright © 2018 ControlThings. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PassthroughRequest.h"
#import "MistApi.h"
#include "bson.h"
#include "bson_visit.h"

@implementation PassthroughRequest

/* This dictionary holds mapping between mist-api level RPC ids that we manage inside MistApi.m, and RPC ids from the rpc client on the upper level,
 key: mist_api_rpc_id, value: rpc_client_id
 */
static NSMutableDictionary<NSNumber *, NSNumber *> *mistApiRewriteDict;

static NSMutableDictionary<NSNumber *, NSNumber *> *wishApiRewriteDict;

enum cb_type { CB_WISHAPI, CB_MISTAPI };

@synthesize callback;

static PassthroughCb wishApiCallback;
static PassthroughCb mistApiCallback;

+ (void) setWishApiCallback:(PassthroughCb) cb {
    wishApiRewriteDict = [[NSMutableDictionary<NSNumber *, NSNumber *> alloc] init];
    wishApiCallback = cb;
}

+ (void) setMistApiCallback:(PassthroughCb) cb {
    mistApiRewriteDict = [[NSMutableDictionary<NSNumber *, NSNumber *> alloc] init];
    mistApiCallback = cb;
}

static void generic_callback(rpc_client_req* req, void *ctx, const uint8_t *payload, size_t payload_len, enum cb_type cb_type) {
    id idRewriteDict = nil;
    
    if (cb_type == CB_MISTAPI) {
        idRewriteDict = mistApiRewriteDict;
    }
    else if (cb_type == CB_WISHAPI) {
        idRewriteDict = wishApiRewriteDict;
    }
    else {
        NSLog(@"Bad cb type");
        return;
    }
    
    bson_visit("generic_callback", payload);
    bson_iterator it;
    BOOL mappingFound = NO;
    if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "ack")) {
        /* A reply to a normal request, rewrite the id and remove mapping */
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        if (idRewriteDict[key] != nil) {
            int passthrough_id = [idRewriteDict[key] intValue];
            bson_inplace_set_long(&it, passthrough_id);
            [idRewriteDict removeObjectForKey:key];
            mappingFound = YES;
            //NSLog(@"Ack for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
        else {
            NSLog(@"ack, but no mapping");
        }
    }
    else if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "err")) {
        /* An error reply to a normal request, rewrite the id and remove mapping */
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        if (idRewriteDict[key] != nil) {
            int passthrough_id = [idRewriteDict[key] intValue];
            bson_inplace_set_long(&it, passthrough_id);
            [idRewriteDict removeObjectForKey:key];
            mappingFound = YES;
            //NSLog(@"Err for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
        else {
            NSLog(@"err, but no mapping");
        }
    }
    else if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "sig")) {
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        
        NSNumber *value = idRewriteDict[key];
        if (value != nil) {
            int passthrough_id = [value intValue];
            bson_inplace_set_long(&it, passthrough_id);
            mappingFound = YES;
            //NSLog(@"Sig for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
        else {
            NSLog(@"sig, but no mapping");
        }
    }
    else if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "fin")) {
        /* Remove mapping */
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        if (idRewriteDict[key] != nil) {
            [idRewriteDict removeObjectForKey:key];
            mappingFound = YES;
            //NSLog(@"Fin for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
        else {
            NSLog(@"fin, but no mapping");
        }
    }
    else {
        NSLog(@"generic_callback: no ack, err, sig or fin!");
        return;
    }
    
    if (mappingFound) {
        if (cb_type == CB_MISTAPI) {
            mistApiCallback([[NSData alloc] initWithBytes:payload length:payload_len]);
        }
        else if (cb_type == CB_WISHAPI) {
            wishApiCallback([[NSData alloc] initWithBytes:payload length:payload_len]);
        }
        else {
            NSLog(@"Bad cb type");
            return;
        }
    }
    else {
        NSLog(@"Unexpected data to mistApi");
        bson_visit("Unexpected data", payload);
    }
}

static void mist_api_callback(rpc_client_req* req, void *ctx, const uint8_t *payload, size_t payload_len) {
    generic_callback(req, ctx, payload, payload_len, CB_MISTAPI);
}

static void wish_api_callback(rpc_client_req* req, void *ctx, const uint8_t *payload, size_t payload_len) {
    generic_callback(req, ctx, payload, payload_len, CB_WISHAPI);
}

+ (void) mistApiRequestWithData:(NSData *)reqData {
    bson_iterator rit;
    
    bson_iterator_from_buffer(&rit, reqData.bytes);
    
    BOOL normalRequest = false;
    BOOL cancelRequest = false;
    
    if (BSON_STRING != bson_find_from_buffer(&rit, reqData.bytes, "op")) {
        if (BSON_INT != bson_find_from_buffer(&rit, reqData.bytes, "end")) {
            NSLog(@"Sandbox.requestWithData: Error: no op or end.");
            return;
        }
        else {
            cancelRequest = true;
        }
    }
    else {
        normalRequest = true;
    }
    
    /* TODO: no need to do this in this complicated way, bson_inplace_set_long will be enough. */
    
    if (normalRequest) {
        const char *op = bson_iterator_string(&rit);
        bson rewritten_bs;
        bson_init(&rewritten_bs);
        int passthrough_id = 0;
        
        bson_append_string(&rewritten_bs, "op", op);
        
        if (BSON_ARRAY != bson_find_from_buffer(&rit, reqData.bytes, "args")) {
            NSLog(@"Error: no args.");
            return;
        }
        bson_append_element(&rewritten_bs, "args", &rit);
        
        if (BSON_INT != bson_find_from_buffer(&rit, reqData.bytes, "id")) {
            NSLog(@"Error: no id.");
            return;
        }
        passthrough_id = bson_iterator_int(&rit);
        
        int rpc_id = get_next_rpc_id();
        bson_append_int(&rewritten_bs, "id", rpc_id);
        bson_finish(&rewritten_bs);
        
        [mistApiRewriteDict setObject:[NSNumber numberWithInt:passthrough_id] forKey:[NSNumber numberWithInt:rpc_id]];
        
        mist_api_request(get_mist_api(), &rewritten_bs, mist_api_callback);
        bson_destroy(&rewritten_bs);
    }
    else if (cancelRequest) {
        if (BSON_INT != bson_find_from_buffer(&rit, reqData.bytes, "end")) {
            
            NSLog(@"Error: no end.");
            return;
        }
        int passthrough_id = bson_iterator_int(&rit);
        
        /* TODO: Lookup the real id from dictionary here, and call MistApi.reqeuestCancel! */
        int rpc_id = 0;
       
        
        for (NSNumber *key in mistApiRewriteDict) {
            //NSLog(@"mist-api level rpc-id %i", [key intValue]);
            if ([mistApiRewriteDict[key] intValue] == passthrough_id) {
                rpc_id = [key intValue];
                [MistApi mistApiCancel:rpc_id];
                break;
            }
        }
        
    }
    else {
        NSLog(@"Error: inconsistency.");
        return;
    }
}

+ (void) wishApiRequestWithData:(NSData *)reqData {
    
    bson_iterator it;
    char req_buffer[reqData.length];
    memcpy(req_buffer, reqData.bytes, reqData.length);
    
    if (BSON_INT == bson_find_from_buffer(&it, (const char *) req_buffer, "id")) {
        /* Normal request, save the mapping between passthrough id and actual rpc id */
        int passthrough_id = bson_iterator_int(&it);
        int rpc_id = get_next_rpc_id();
        
        [wishApiRewriteDict setObject:[NSNumber numberWithInt:passthrough_id] forKey:[NSNumber numberWithInt:rpc_id]];
        bson_inplace_set_long(&it, rpc_id);
        NSLog(@"wishApi mapping: %i -> %i", passthrough_id, rpc_id);
        bson bs;
        bson_init_with_data(&bs, req_buffer);
        wish_api_request(get_mist_api(), &bs, wish_api_callback);
        bson_visit("made wish api request:", bson_data(&bs));

    }
    else if (BSON_INT == bson_find_from_buffer(&it, (const char *) req_buffer, "end")) {
        int passthrough_id = bson_iterator_int(&it);
        for (NSNumber *key in wishApiRewriteDict) {
            //NSLog(@"mist-api level rpc-id %i", [key intValue]);
            if ([mistApiRewriteDict[key] intValue] == passthrough_id) {
                int rpc_id = [key intValue];
                [MistApi wishApiCancel:rpc_id];
                break;
            }
        }
    }
    else {
        NSLog(@"Error: no 'id' or 'end' in request");
        return;
    }
}

@end
