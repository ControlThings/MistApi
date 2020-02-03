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
//  WldList.h
//  Mist
//
//  Created by Jan on 16/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import "MistRequest.h"
#import "MistApiResponseHandler.h"

@interface WldListEntry : NSObject
@property NSString *type;
@property NSString *alias;
@property NSData *ruid;
@property NSData *rhid;
@property NSData *pubkey;
@property NSString *mistClass;
@end

typedef void (^WldListCb)(NSArray<WldListEntry *> *list);

@interface WldList : MistRequest
@property (copy) WldListCb callbackBlock;
+(WldList*)requestWithCallback:(WldListCb)cb errorCallback:(MistErrorCb) errCb;
@end

