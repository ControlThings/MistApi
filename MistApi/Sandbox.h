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
//  Sandbox.h
//  MistApi
//
//  Created by Jan on 23/04/2018.
//  Copyright © 2018 ControlThings. All rights reserved.
//


typedef void (^SandboxCb)(NSData *responseData);

@interface Sandbox : NSObject
@property SandboxCb callback;
- (id) initWithSandboxId:(NSData *)sandboxId callback:(SandboxCb) cb;
- (void) requestWithData:(NSData *)reqData;
- (void) login;
@property NSData* sandboxId;
@end
