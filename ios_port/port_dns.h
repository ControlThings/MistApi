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
