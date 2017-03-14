#ifndef HEARTBEAT_THREAD_H
#define HEARTBEAT_THREAD_H

#include "heartbeat.h"

#ifdef __cplusplus
extern "C" {
#endif

payload * controller_create(heartbeat_data *data);
bool controller_stop(payload *x, bool wait, double timeout);

#ifdef __cplusplus
}
#endif

#endif
