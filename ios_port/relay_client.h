/**
 * Copyright (C) 2020, ControlThings Oy Ab
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * @license Apache-2.0
 */
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
