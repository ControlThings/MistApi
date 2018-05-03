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
