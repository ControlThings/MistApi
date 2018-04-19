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
