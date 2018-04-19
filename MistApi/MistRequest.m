//
//  MistCallback.m
//  Mist
//
//  Created by Jan on 11/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MistApi.h"
#import "MistRequest.h"

@implementation MistRequest
@synthesize rpcId;
@synthesize errorCbBlock;
@synthesize opString;

-(void)handleResponse:(NSData*)data {
    /* Empty implementation, as a real request will always override this method */
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

-(void)handleError:(int)errorCode message:(NSString*)errorMsg {
    if (self.errorCbBlock == nil) {
        NSLog(@"RPC error op: %@ error code: %i, message: %@", self.opString, errorCode, errorMsg);
    }
    else {
        self.errorCbBlock(errorCode, errorMsg);
    }
}

-(void)cancel {
    NSLog(@"Cancelling request: %i", rpcId);
    [MistApi mistApiCancel:rpcId];
}

@end
