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
#pragma once

#include "wish_connection.h"

#define PORT_DNS_MAX_HOSTLEN 255

struct dns_resolver {
    bool finished;
    wish_core_t *core;
    wish_connection_t *conn;
    wish_relay_client_t *relay;
    int resolver_id;
    wish_ip_addr_t *result_ip;
    char qname[PORT_DNS_MAX_HOSTLEN];
    struct dns_resolver *next;
};

int port_dns_start_resolving(wish_core_t *core, wish_connection_t *conn, wish_relay_client_t *relay, char *qname);

int port_dns_poll_resolvers(void);
