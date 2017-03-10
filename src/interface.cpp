#include "interface.h"
#include "redisheartbeat.h"
#include "util.h"
#include <R_ext/Rdynload.h>

static void r_heartbeat_finalize(SEXP ext_ptr);
payload * controller_get(SEXP ext_ptr, bool closed_error);

// TODO: We need to stick all this within a C++ try/catch block to
// prevent C++ exceptions bombing and dropping us out of R.  All entry
// points are in this file and it should be sufficient to consider
// this only.
SEXP r_heartbeat_create(SEXP r_host, SEXP r_port, SEXP r_key,
                        SEXP r_value, SEXP r_key_signal,
                        SEXP r_expire, SEXP r_interval) {
  const char
    *host = scalar_string(r_host, "host"),
    *key = scalar_string(r_key, "key"),
    *value = scalar_string(r_value, "value"),
    *key_signal = scalar_string(r_key_signal, "key_signal");
  int
    port = scalar_integer(r_port, "port"),
    expire = scalar_integer(r_expire, "expire"),
    interval = scalar_integer(r_interval, "interval");

  void * data = controller_create(host, port, key, value, key_signal,
                                  expire, interval);
  SEXP ext_ptr = PROTECT(R_MakeExternalPtr(data, R_NilValue, R_NilValue));
  R_RegisterCFinalizer(ext_ptr, r_heartbeat_finalize);
  UNPROTECT(1);
  return ext_ptr;
}

SEXP r_heartbeat_stop(SEXP ext_ptr, SEXP r_closed_error, SEXP r_stop) {
  bool
    closed_error = scalar_logical(r_closed_error, "closed_error"),
    stop = scalar_logical(r_stop, "stop");
  payload *data = controller_get(ext_ptr, closed_error);
  bool exists = data != NULL;
  if (exists) {
    controller_stop(data, stop);
    R_ClearExternalPtr(ext_ptr);
  }
  // Here, we should open up a connection to the redis server and push
  // 0 onto the stack that is being popped off.  Then the heartbeat
  // process will stop very quickly!
  return ScalarLogical(exists);
}

SEXP r_heartbeat_running(SEXP ext_ptr) {
  payload *data = controller_get(ext_ptr, false);
  return ScalarLogical(data != NULL);
}

void r_heartbeat_finalize(SEXP ext_ptr) {
  Rprintf("Cleaning up pointer\n");
  payload * data = controller_get(ext_ptr, false);
  if (data) {
    controller_stop(data, false);
    R_ClearExternalPtr(ext_ptr);
  }
}

payload * controller_get(SEXP ext_ptr, bool closed_error) {
  payload *data = NULL;
  if (TYPEOF(ext_ptr) != EXTPTRSXP) {
    Rf_error("Expected an external pointer");
  }
  data = static_cast<payload*>(R_ExternalPtrAddr(ext_ptr));
  if (closed_error && data == NULL) {
    Rf_error("controller already freed");
  }
  return data;
}

static R_CallMethodDef call_methods[]  = {
  {"heartbeat_create",  (DL_FUNC) &r_heartbeat_create,  7},
  {"heartbeat_stop",    (DL_FUNC) &r_heartbeat_stop,    3},
  {"heartbeat_running", (DL_FUNC) &r_heartbeat_running, 1},
  {NULL, NULL, 0}
};

extern "C" void R_init_RedisHeartbeat(DllInfo *info) {
  R_registerRoutines(info, NULL, call_methods, NULL, NULL);
}
