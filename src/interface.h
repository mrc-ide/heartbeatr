#include <R.h>
#include <Rinternals.h>

extern "C" {
  SEXP r_heartbeat_create(SEXP r_host, SEXP r_port, SEXP r_key,
                          SEXP r_value, SEXP r_key_signal,
                          SEXP r_expire, SEXP r_interval);
  SEXP r_heartbeat_stop(SEXP ext_ptr, SEXP r_closed_error);
  SEXP r_heartbeat_running(SEXP ext_ptr);
}
