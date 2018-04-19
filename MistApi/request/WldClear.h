//
//  WldClear.h
//  Mist
//
//  Created by Jan on 16/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import "MistRequest.h"

typedef void (^WldClearCb)(BOOL result);

@interface WldClear : MistRequest
@property (copy) WldClearCb callbackBlock;
+(WldClear*)requestWithCallback:(WldClearCb)cb errorCallback:(MistErrorCb) errCb;
@end
