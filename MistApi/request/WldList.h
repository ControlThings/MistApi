//
//  WldList.h
//  Mist
//
//  Created by Jan on 16/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import "MistRequest.h"
#import "MistApiResponseHandler.h"

@interface WldListEntry : NSObject
@property NSString *type;
@property NSString *alias;
@property NSData *ruid;
@property NSData *rhid;
@property NSData *pubkey;
@property NSString *mistClass;
@end

typedef void (^WldListCb)(NSArray<WldListEntry *> *list);

@interface WldList : MistRequest
@property (copy) WldListCb callbackBlock;
+(WldList*)requestWithCallback:(WldListCb)cb errorCallback:(MistErrorCb) errCb;
@end

