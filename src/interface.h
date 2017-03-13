#ifndef HEARTBEAT_INTERFACE_H
#define HEARTBEAT_INTERFACE_H

#include <R.h>
#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

SEXP r_heartbeat_create(SEXP r_host, SEXP r_port, SEXP r_password, SEXP r_db,
                        SEXP r_key, SEXP r_value, SEXP r_key_signal,
                        SEXP r_expire, SEXP r_interval);
SEXP r_heartbeat_stop(SEXP ext_ptr, SEXP r_closed_error, SEXP r_stop);
SEXP r_heartbeat_running(SEXP ext_ptr);

#ifdef __cplusplus
}
#endif

#endif
