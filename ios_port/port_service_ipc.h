//
//  service_ipc.h
//  Mist
//
//  Created by Jan on 05/04/2018.
//  Copyright © 2018 Jan. All rights reserved.
//

#ifndef port_service_ipc_h
#define port_service_ipc_h

void port_service_ipc_init(wish_core_t* wish_core);

void port_service_ipc_periodic(wish_core_t* wish_core);

void port_service_ipc_connected(bool);

/* Send data to app: Call a method on the main thread, which runs wish_app_find_by_wsid, and wish_app_determine_handler. */
void port_send_to_app(const uint8_t wsid[WISH_ID_LEN], const uint8_t *data, size_t len);

void port_service_lock_acquire(void);

void port_service_lock_release(void);

#endif /* port_service_ipc_h */
