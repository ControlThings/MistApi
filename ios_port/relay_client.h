//
//  relay_client.h
//  MistApi
//
//  Created by Jan on 04/02/2019.
//  Copyright © 2019 ControlThings. All rights reserved.
//

#ifndef relay_client_h
#define relay_client_h

#include "wish_ip_addr.h"
#include "wish_relay_client.h"

void port_relay_client_open(wish_relay_client_t* relay, wish_ip_addr_t *relay_ip);

#endif /* relay_client_h */
