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
//  FriendRequestAccept.h
//  Mist
//
//  Created by Jan on 12/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import "WishRequest.h"

typedef void (^IdentityFriendRequestAcceptCb)(BOOL result);

@interface IdentityFriendRequestAccept : WishRequest
@property (copy) IdentityFriendRequestAcceptCb callbackBlock;
+(IdentityFriendRequestAccept*)requestWithLuid:(NSData*)luid
                                  ruid:(NSData*) ruid
                              callback:(IdentityFriendRequestAcceptCb)cb
                         errorCallback:(MistErrorCb) errCb;
@end
