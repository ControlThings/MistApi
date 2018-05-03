//
//  Sandbox.m
//  MistApi
//
//  Created by Jan on 23/04/2018.
//  Copyright © 2018 ControlThings. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MistApi.h"
#import "Sandbox.h"
#include "bson.h"
#include "bson_visit.h"
#include "mist_api.h"

static Sandbox *sandboxInstance;

/* This dictionary holds mapping between mist-api level RPC ids that we manage inside MistApi.m, and RPC ids from sandbox,
 key: mist_api_rpc_id, value: sandbox_rpc_id
 */
static NSMutableDictionary<NSNumber *, NSNumber *> *idRewriteDict;

@implementation Sandbox
- (id)initWithSandboxId:(NSData *)sandboxId callback:(SandboxCb) cb; {
    self = [super init];
    self.callback = cb;
    
    self.sandboxId = sandboxId;
    
    idRewriteDict = [[NSMutableDictionary<NSNumber *, NSNumber *> alloc] init];
    sandboxInstance = self;
    
    return self;
}

static void sandbox_callback(rpc_client_req* req, void *ctx, const uint8_t *payload, size_t payload_len) {
    //bson_visit("sandbox_callback", payload);
    bson_iterator it;
    BOOL mappingFound = NO;
    if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "ack")) {
        /* A reply to a normal request, rewrite the id and remove mapping */
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        if (idRewriteDict[key] != nil) {
            int sandbox_rpc_id = [idRewriteDict[key] intValue];
            bson_inplace_set_long(&it, sandbox_rpc_id);
            [idRewriteDict removeObjectForKey:key];
            mappingFound = YES;
            //NSLog(@"Ack for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
    }
    else if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "err")) {
        /* An error reply to a normal request, rewrite the id and remove mapping */
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        if (idRewriteDict[key] != nil) {
            int sandbox_rpc_id = [idRewriteDict[key] intValue];
            bson_inplace_set_long(&it, sandbox_rpc_id);
            [idRewriteDict removeObjectForKey:key];
            mappingFound = YES;
            //NSLog(@"Err for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
    }
    else if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "sig")) {
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        
        NSNumber *value = idRewriteDict[key];
        if (value != nil) {
            int sandbox_rpc_id = [value intValue];
            bson_inplace_set_long(&it, sandbox_rpc_id);
            mappingFound = YES;
            //NSLog(@"Sig for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
        else {
            mappingFound = NO;
            //NSLog(@"Sig for rewritten rpc-id %i not found", rpc_id);
        }
    }
    else if (BSON_INT == bson_find_from_buffer(&it, (const char *) payload, "fin")) {
        /* Remove mapping */
        int rpc_id = bson_iterator_int(&it);
        NSNumber *key = [NSNumber numberWithInt:rpc_id];
        if (idRewriteDict[key] != nil) {
            int sandbox_rpc_id = [idRewriteDict[key] intValue];
            [idRewriteDict removeObjectForKey:key];
            mappingFound = YES;
            //NSLog(@"Fin for sandbox-rpc-id %i, which was rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        }
    }
    
    if (mappingFound) {
        sandboxInstance.callback([[NSData alloc] initWithBytes:payload length:payload_len]);
    }
    else {
        NSLog(@"Unexpected data to sandbox");
        bson_visit("Unexpected data", payload);
    }
}

static void sandbox_login_cb(rpc_client_req* req, void *ctx, const uint8_t *payload, size_t payload_len) {
    NSLog(@"in sandbox cb");
    //bson_visit("Sandbox login cb", payload);
}

/**
 Convenience function for login to sandbox.
 This is provided as an alternative for perfoming a "login" RPC from inside the sandbox.
 */
- (void)login {
    bson bs;
    bson_init(&bs);
    bson_append_string(&bs, "op", "sandboxed.login");
    bson_append_start_array(&bs, "args");
    bson_append_finish_array(&bs);
    bson_append_int(&bs, "id", get_next_rpc_id());
    bson_finish(&bs);
    
    sandboxed_api_request_context(get_mist_api(), self.sandboxId.bytes, &bs, sandbox_login_cb, NULL);
    bson_destroy(&bs);
}

- (void)requestWithData:(NSData *)reqData {
    /* We must also have a RPC request id re-writing scheme in place, because we must ensure that all the requests sent to mist-api, both "normal" and "sandboxed" requests, have distinct ids.
     So that sandboxed RPCs don't clash with RPCs performed using mist-api directly
     */
    
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
    
    bson rewritten_bs;
    bson_init(&rewritten_bs);
    
    if (normalRequest) {
        const char *op = bson_iterator_string(&rit);
        
        size_t rewritten_op_max_len = strlen(op) + 100;
        char new_op[rewritten_op_max_len];
        snprintf(new_op, rewritten_op_max_len, "sandboxed.%s", op);
        
        bson_append_string(&rewritten_bs, "op", new_op);
        
        if (BSON_ARRAY != bson_find_from_buffer(&rit, reqData.bytes, "args")) {
            NSLog(@"Error: no args.");
            return;
        }
        bson_append_element(&rewritten_bs, "args", &rit);
        
        if (BSON_INT != bson_find_from_buffer(&rit, reqData.bytes, "id")) {
            
            NSLog(@"Error: no id.");
            return;
        }
        bson_append_element(&rewritten_bs, "id", &rit);
        bson_finish(&rewritten_bs);
    }
    else if (cancelRequest) {
        if (BSON_INT != bson_find_from_buffer(&rit, reqData.bytes, "end")) {
            
            NSLog(@"Error: no end.");
            return;
        }
        bson_append_element(&rewritten_bs, "end", &rit);
        bson_finish(&rewritten_bs);
    }
    else {
        NSLog(@"Error: inconsistency.");
        return;
    }
    //bson_visit("Rewritten sandbox request. (id not rewritten yet)", bson_data(&rewritten_bs));
    
    int rpc_id = 0;
    int sandbox_rpc_id = 0;
    
    bson_iterator it;
    
    if (BSON_INT == bson_find_from_buffer(&it, bson_data(&rewritten_bs), "id")) {
        /* A normal RPC request from Sandbox, assign new RPC id and save mapping */
        rpc_id = get_next_rpc_id();
        sandbox_rpc_id = bson_iterator_int(&it);
        bson_inplace_set_long(&it, rpc_id);
        //NSLog(@"Saving sandbox-rpc-id %i, which is rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
        [idRewriteDict setObject:[NSNumber numberWithInt:sandbox_rpc_id] forKey:[NSNumber numberWithInt:rpc_id]];
        //NSLog(@"sandbox-rpc-id count %lu", [idRewriteDict count]);
        bson bs;
        bson_init_with_data(&bs, bson_data(&rewritten_bs));
        
        sandboxed_api_request_context(get_mist_api(), self.sandboxId.bytes, &bs, sandbox_callback, NULL);
    }
    else if (BSON_INT == bson_find_from_buffer(&it, bson_data(&rewritten_bs), "end")) {
        /* Request to end a RPC request ('sig') */
        sandbox_rpc_id = bson_iterator_int(&it);
        bool found = false;
        //NSLog(@"sandbox-rpc-id count %lu", [idRewriteDict count]);
        for (NSNumber *key in idRewriteDict) {
            //NSLog(@"sandbox-rp-id %i", [key intValue]);
            if ([idRewriteDict[key] intValue] == sandbox_rpc_id) {
                rpc_id = [key intValue];
                found = true;
                break;
            }
        }
        
        /* Call sandbox_api_cancel here */
        if (found == true) {
            //NSLog(@"Cancelling sandbox-rpc-id %i, which is rewritten as rpc-id %i", sandbox_rpc_id, rpc_id);
            //sandboxed_api_request_cancel(get_mist_api(), self.sandboxId.bytes, rpc_id);
        }
        else {
            NSLog(@"Cancelling sandbox-rpc-id %i, but rpc-id not found!", sandbox_rpc_id);
        }
        return;
    }
    else {
        NSLog(@"No RPC id in request from sandbox.");
        return;
    }
    bson_destroy(&rewritten_bs);
    
}



@end




