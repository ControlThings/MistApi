//
//  FriendRequestAccept.h
//  Mist
//
//  Created by Jan on 12/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import "WishRequest.h"

typedef void (^IdentityFriendRequestAcceptCb)(BOOL result);

@interface IdentityFriendRequestAccept : WishRequest
@property (copy) IdentityFriendRequestAcceptCb callbackBlock;
+(IdentityFriendRequestAccept*)requestWithLuid:(NSData*)luid
                                  ruid:(NSData*) ruid
                              callback:(IdentityFriendRequestAcceptCb)cb
                         errorCallback:(MistErrorCb) errCb;
@end
