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
//  ResponseHandler.h
//  Mist
//
//  Created by Jan on 11/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

typedef void (^MistErrorCb)(int code, NSString *msg);

@protocol MistApiResponseHandler
@property int rpcId;
@property (copy) MistErrorCb errorCbBlock;
@property NSString *opString;
-(void)handleResponse:(NSData*)data;
-(void)handleError:(int)errorCode message:(NSString*)errorMsg;
-(void)cancel;
@end
