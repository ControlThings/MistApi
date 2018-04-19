//
//  FriendRequestList.h
//  Mist
//
//  Created by Jan on 10/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//


#import "WishRequest.h"

@interface IdentityFriendRequestListEntry : NSObject
@property NSData *luid;
@property NSData *ruid;
@property NSString *alias;
@property NSData *pubkey;
@property NSData *metaBson;
@end

typedef void (^IdentityFriendRequestListCb)(NSArray<IdentityFriendRequestListEntry *> *entries);


@interface IdentityFriendRequestList : WishRequest
@property (copy) IdentityFriendRequestListCb callbackBlock;
+(IdentityFriendRequestList*)requestWithCallback:(IdentityFriendRequestListCb)cb errorCallback:(MistErrorCb) errCb;
@end

