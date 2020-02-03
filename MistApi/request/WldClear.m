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
//  WldClear.m
//  Mist
//
//  Created by Jan on 16/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WldClear.h"
#import "MistApi.h"

#include "bson.h"

@implementation WldClear
+ (WldClear *)requestWithCallback:(WldClearCb)cb errorCallback:(MistErrorCb)errCb {
    bson bs;
    bson_init(&bs);
    bson_append_string(&bs, "op", "wld.clear");
    bson_append_start_array(&bs, "args");
    bson_append_finish_array(&bs);
    bson_append_int(&bs, "id", 0);
    bson_finish(&bs);
    
    WldClear * req = [[WldClear alloc] init];
    req.callbackBlock = cb;
    req.errorCbBlock = errCb;
    [MistApi wishApiRequestWithBson: &bs callback:req];
    bson_destroy(&bs);
    
    return req;
}

- (void)handleResponse:(NSData *)data {
    bson bs;
    bson_init_with_data(&bs, data.bytes);
    bson_iterator it;
    bson_find(&it, &bs, "data");
    if (BSON_BOOL != bson_iterator_type(&it)) {
        self.errorCbBlock(-1, @"data is not bool!");
        return;
    }
    BOOL ret = bson_iterator_bool(&it);
    
    self.callbackBlock(ret);
    
}
@end
