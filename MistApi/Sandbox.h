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
- (id) initWithCallback:(SandboxCb) cb;
- (void) requestWithData:(NSData *)reqData;
@end
