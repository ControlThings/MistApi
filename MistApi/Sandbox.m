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
static NSMutableDictionary *idDict;

char sandbox_id[SANDBOX_ID_LEN];

@implementation Sandbox
- (id)initWithCallback:(SandboxCb)cb {
    self = [super init];
    self.callback = cb;
    
    
    return self;
}

static void sandbox_callback(rpc_client_req* req, void *ctx, const uint8_t *payload, size_t payload_len) {
    
    bson_visit("sandbox_callback", payload);
    
    sandboxInstance.callback([[NSData alloc] initWithBytes:payload length:payload_len]);
}

- (void)requestWithData:(NSData *)reqData {
    sandboxInstance = self;
    
    /* We must also have a RPC request id re-writing scheme in place, because we must ensure that all the requests sent to mist-api, both "normal" and "sandboxed" requests, have distinct ids.
     
     */
    
    bson bs;
    bson_init_with_data(&bs, reqData.bytes);
    sandboxed_api_request_context(get_mist_api(), sandbox_id, &bs, sandbox_callback, NULL);
}



@end




