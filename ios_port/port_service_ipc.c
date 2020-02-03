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
/*
 * A dummy, or "faux" Service IPC layer implementation, 
 * which exists only to tie services togheter with the core in the
 * situation where they are running in the same process */

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

#include "wish_core.h"
#include "core_service_ipc.h"
#include "bson_visit.h"
#include "wish_debug.h"
#include "wish_dispatcher.h"
#include "wish_port_config.h"
#include "wish_app.h"
#include "port_service_ipc.h"
#include "utlist.h"

static wish_core_t *core;

enum ipc_event_type { EVENT_UNKNOWN, EVENT_APP_TO_CORE, /* EVENT_CORE_TO_APP */ };

struct ipc_event {
    enum ipc_event_type type;
    uint8_t wsid[WISH_WSID_LEN];
    uint8_t *data;
    size_t len;
    struct ipc_event *next;
};

struct ipc_event *ipc_event_queue = NULL;

void core_service_ipc_init(wish_core_t* wish_core) {
    core = wish_core;
    
    /* Call the port_service_ipc_init(), which calls the "connected" method on the Main (Mist?) thread */
}

void port_service_ipc_init(wish_core_t* wish_core) {
    port_service_ipc_connected(true);
}

void port_service_ipc_periodic(wish_core_t* wish_core) {
    /*
     -Get lock
     -Remove first element from queue
     -Release lock
     -call receive_app_to_core(core, wsid_from_queue, data_from_queue...)
     */
    port_service_lock_acquire();
    
    struct ipc_event *event = ipc_event_queue;
    
    if (event == NULL) {
        port_service_lock_release();
        return;
    }
    LL_DELETE(ipc_event_queue, event);
    port_service_lock_release();
    
    if (event->type == EVENT_APP_TO_CORE) {
        receive_app_to_core(core, event->wsid, event->data, event->len);
    }
    else {
        printf("Error: Bad IPC event");
    }
    
    free(event->data);
    free(event);
}

/** Append 'data' to on the Core's input queue.
 -Get lock
 -Append to queue
 -Release lock
 */
void send_app_to_core(uint8_t *wsid, uint8_t *data, size_t len) {
    
    
    struct ipc_event *event = malloc(sizeof(struct ipc_event));
    if (event == NULL) {
        printf("Could allocate memory for IPC event\n");
        return;
    }
    else {
        event->data = malloc(len);
        if (event->data == NULL) {
            printf("Could not allocate memory for IPC data\n");
            return;
        }
        memcpy(event->data, data, len);
        event->len = len;
        memcpy(event->wsid, wsid, WISH_WSID_LEN);
        event->type = EVENT_APP_TO_CORE;
        port_service_lock_acquire();
        LL_APPEND(ipc_event_queue, event);
        port_service_lock_release();
    }
    
    /* Feed the message to core */
    //receive_app_to_core(core, wsid, data, len);
}


void receive_app_to_core(wish_core_t* core, const uint8_t wsid[WISH_ID_LEN], const uint8_t* data, size_t len) {
    wish_core_handle_app_to_core(core, wsid, data, len);
}


void send_core_to_app(wish_core_t* core, const uint8_t wsid[WISH_ID_LEN], const uint8_t *data, size_t len) {
    /*wish_app_t *app = wish_app_find_by_wsid(wsid);
    wish_app_determine_handler(app, data, len);
     */
    port_send_to_app(wsid, data, len);
}

