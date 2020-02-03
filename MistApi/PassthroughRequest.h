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
//  PassthroughRequest.h
//  MistApi
//
//  Created by Jan on 02/07/2018.
//  Copyright © 2018 ControlThings. All rights reserved.
//

typedef void (^PassthroughCb)(NSData *responseData);

@interface PassthroughRequest : NSObject
@property id callback;

+ (void) setWishApiCallback:(PassthroughCb) cb;
+ (void) setMistApiCallback:(PassthroughCb) cb;
+ (void) mistApiRequestWithData:(NSData *)reqData;
+ (void) wishApiRequestWithData:(NSData *)reqData;
@end
