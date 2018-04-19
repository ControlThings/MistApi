//
//  FriendRequestList.m
//  Mist
//
//  Created by Jan on 10/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IdentityFriendRequestList.h"
#import "MistApi.h"

#include "bson.h"
#include "bson_visit.h"

@implementation IdentityFriendRequestListEntry

@end

@implementation IdentityFriendRequestList
+(IdentityFriendRequestList *)requestWithCallback:(IdentityFriendRequestListCb)cb errorCallback:(MistErrorCb)errCb {
    bson bs;
    bson_init(&bs);
    bson_append_string(&bs, "op", "identity.friendRequestList");
    bson_append_start_array(&bs, "args");
    bson_append_finish_array(&bs);
    bson_append_int(&bs, "id", 0);
    bson_finish(&bs);
    
    IdentityFriendRequestList * req = [[IdentityFriendRequestList alloc] init];
    req.callbackBlock = cb;
    req.errorCbBlock = errCb;
    [MistApi wishApiRequestWithBson: &bs callback:req];
    bson_destroy(&bs);
    
    return req;
}

- (void)handleResponse:(NSData *)data {
    bson_visit("friendRequestList result:", data.bytes);
    
    
    bson bs;
    bson_init_with_data(&bs, data.bytes);
    bson_iterator it;
    bson_iterator_init(&it, &bs);
    
    NSMutableArray *listArray = [[NSMutableArray<IdentityFriendRequestListEntry *> alloc] init];
    
    int i = 0;
    
    do {
        char index_str[10];
        snprintf(index_str, 10, "data.%i", i);
        bson_find_fieldpath_value(index_str, &it);
        
        if (BSON_OBJECT == bson_iterator_type(&it)) {
            bson_iterator sit;
            
            bson_iterator_subiterator(&it, &sit);
            IdentityFriendRequestListEntry *entry = [[IdentityFriendRequestListEntry alloc] init];
            while (BSON_EOO != bson_iterator_next(&sit)) {
                printf("key: %s", bson_iterator_key(&sit));
                
                if (strcmp(bson_iterator_key(&sit), "luid") == 0) {
                    entry.luid = [NSData dataWithBytes:bson_iterator_bin_data(&sit)
                                                length:bson_iterator_bin_len(&sit)];
                }
                if (strcmp(bson_iterator_key(&sit), "ruid") == 0) {
                    entry.ruid = [NSData dataWithBytes:bson_iterator_bin_data(&sit)
                                                length:bson_iterator_bin_len(&sit)];
                }
                if (strcmp(bson_iterator_key(&sit), "alias") == 0) {
                    entry.alias = [NSString stringWithUTF8String:bson_iterator_string(&sit)];
                }
                if (strcmp(bson_iterator_key(&sit), "pubkey") == 0) {
                    entry.pubkey = [NSData dataWithBytes:bson_iterator_bin_data(&sit)
                                                length:bson_iterator_bin_len(&sit)];
                    
                }
                
            }
            listArray[i] = entry;
            
        }
        i++;
    } while (BSON_EOO != bson_iterator_type(&it));
    
    self.callbackBlock(listArray);
}
@end


