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
//  Signals.m
//  Mist
//
//  Created by Jan on 06/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Signals.h"
#import "MistRequest.h"
#import "MistApi.h"

#include "mist_api.h"


@implementation Signals
+(Signals*)requestWithCallback:(SignalsCb)cb errorCallback:(MistErrorCb)errCb {
    bson bs;
    bson_init(&bs);
    
    bson_append_string(&bs, "op", "signals");
    bson_append_start_array(&bs, "args");
    bson_append_finish_array(&bs);
    bson_append_int(&bs, "id", 0); //will be modified in-place by MistApi.mistApiRequest
    bson_finish(&bs);

    Signals *req = [[Signals alloc] init];
    req.callbackBlock = cb;
    req.errorCbBlock = errCb;
    req.rpcId = [MistApi mistApiRequestWithBson:&bs callback:req];
    
    bson_destroy(&bs);
    return req;
}

- (void)handleResponse:(NSData *)data {
    bson bs;
    bson_init_with_data(&bs, data.bytes);
    bson_iterator it;
    
    bson_iterator_init(&it, &bs);
    bson_find_fieldpath_value("data.0", &it);
    if (bson_iterator_type(&it) == BSON_STRING) {
        self.callbackBlock([[NSString alloc] initWithUTF8String:bson_iterator_string(&it)]);
    }
}
@end
