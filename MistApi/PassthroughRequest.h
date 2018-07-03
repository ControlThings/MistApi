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
