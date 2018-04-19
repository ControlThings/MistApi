//
//  Signals.h
//  Mist
//
//  Created by Jan on 06/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import "MistRequest.h"
#import "MistApiResponseHandler.h"

typedef void (^SignalsCb)(NSString *data);

@interface Signals : MistRequest
@property (copy) SignalsCb callbackBlock;
+(Signals*)requestWithCallback:(SignalsCb)cb errorCallback:(MistErrorCb) errCb;
@end
