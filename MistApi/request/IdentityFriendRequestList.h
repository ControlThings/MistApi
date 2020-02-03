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
//  FriendRequestList.h
//  Mist
//
//  Created by Jan on 10/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//


#import "WishRequest.h"

@interface IdentityFriendRequestListEntry : NSObject
@property NSData *luid;
@property NSData *ruid;
@property NSString *alias;
@property NSData *pubkey;
@property NSData *metaBson;
@end

typedef void (^IdentityFriendRequestListCb)(NSArray<IdentityFriendRequestListEntry *> *entries);


@interface IdentityFriendRequestList : WishRequest
@property (copy) IdentityFriendRequestListCb callbackBlock;
+(IdentityFriendRequestList*)requestWithCallback:(IdentityFriendRequestListCb)cb errorCallback:(MistErrorCb) errCb;
@end

