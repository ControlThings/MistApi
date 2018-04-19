//
//  FriendRequestAccept.m
//  Mist
//
//  Created by Jan on 12/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IdentityFriendRequestAccept.h"
#import "MistApi.h"

#include "bson.h"

@implementation IdentityFriendRequestAccept
+ (IdentityFriendRequestAccept *)requestWithLuid:(NSData *)luid
                                    ruid:(NSData *)ruid
                                callback:(IdentityFriendRequestAcceptCb)cb
                           errorCallback:(MistErrorCb)errCb {
    bson bs;
    bson_init(&bs);
    bson_append_string(&bs, "op", "identity.friendRequestAccept");
    bson_append_start_array(&bs, "args");
    bson_append_binary(&bs, "0", luid.bytes, (int) luid.length);
    bson_append_binary(&bs, "1", ruid.bytes, (int) luid.length);
    bson_append_finish_array(&bs);
    bson_append_int(&bs, "id", 0);
    bson_finish(&bs);
    
    IdentityFriendRequestAccept *req = [[IdentityFriendRequestAccept alloc] init];
    req.callbackBlock = cb;
    req.errorCbBlock = errCb;
    [MistApi wishApiRequestWithBson: &bs callback:req];
    bson_destroy(&bs);
    return req;
}

- (void)handleResponse:(NSData *)data {
    bson bs;
    bson_init_with_data(&bs, data.bytes);
    bson_iterator it;
    
    bson_iterator_init(&it, &bs);
    bson_find_fieldpath_value("data", &it);
    if (bson_iterator_type(&it) == BSON_BOOL) {
        self.callbackBlock(bson_iterator_bool(&it));
    }
    
    
}
@end
