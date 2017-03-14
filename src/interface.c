#include "interface.h"
#include "heartbeat.h"
#include "thread.h"
#include "util.h"
#include <R_ext/Rdynload.h>

static void r_heartbeat_finalize(SEXP ext_ptr);
payload * controller_get(SEXP ext_ptr, bool closed_error);

// TODO: We need to stick all this within a C++ try/catch block to
// prevent C++ exceptions bombing and dropping us out of R.  All entry
// points are in this file and it should be sufficient to consider
// this only.
SEXP r_heartbeat_create(SEXP r_host, SEXP r_port, SEXP r_password, SEXP r_db,
                        SEXP r_key, SEXP r_value, SEXP r_key_signal,
                        SEXP r_expire, SEXP r_interval, SEXP r_timeout) {
  const char
    *host = scalar_string(r_host),
    *password = scalar_string(r_password),
    *key = scalar_string(r_key),
    *value = scalar_string(r_value),
    *key_signal = scalar_string(r_key_signal);
  int
    port = scalar_integer(r_port),
    db = scalar_integer(r_db),
    expire = scalar_integer(r_expire),
    interval = scalar_integer(r_interval);
  double timeout = scalar_numeric(r_timeout);

  heartbeat_data *data = heartbeat_data_alloc(host, port, password, db,
                                              key, value, key_signal,
                                              expire, interval);
  if (data == NULL) {
    Rf_error("Failure allocating memory"); // # nocov
  }
  void * ptr = controller_create(data, timeout);

  if (ptr == NULL) {
    Rf_error("Error creating heartbeat thread (probably connection failure)");
  }

  SEXP ext_ptr = PROTECT(R_MakeExternalPtr(ptr, R_NilValue, R_NilValue));
  R_RegisterCFinalizer(ext_ptr, r_heartbeat_finalize);
  UNPROTECT(1);
  return ext_ptr;
}

SEXP r_heartbeat_stop(SEXP ext_ptr, SEXP r_closed_error, SEXP r_wait,
                      SEXP r_timeout) {
  bool
    closed_error = scalar_logical(r_closed_error),
    wait = scalar_logical(r_wait);
  double timeout = scalar_numeric(r_timeout);
  payload *ptr = controller_get(ext_ptr, closed_error);
  bool exists = ptr != NULL;
  if (exists) {
    controller_stop(ptr, wait, timeout);
    R_ClearExternalPtr(ext_ptr);
  }
  return ScalarLogical(exists);
}

SEXP r_heartbeat_running(SEXP ext_ptr) {
  payload *ptr = controller_get(ext_ptr, false);
  return ScalarLogical(ptr != NULL);
}

void r_heartbeat_finalize(SEXP ext_ptr) {
  payload * ptr = controller_get(ext_ptr, false);
  if (ptr) {
    controller_stop(ptr, false, 0);
    R_ClearExternalPtr(ext_ptr);
  }
}

payload * controller_get(SEXP ext_ptr, bool closed_error) {
  payload *ptr = NULL;
  if (TYPEOF(ext_ptr) != EXTPTRSXP) {
    Rf_error("Expected an external pointer");
  }
  ptr = (payload*)R_ExternalPtrAddr(ext_ptr);
  if (closed_error && ptr == NULL) {
    Rf_error("heartbeat pointer already freed");
  }
  return ptr;
}

static R_CallMethodDef call_methods[]  = {
  {"heartbeat_create",  (DL_FUNC) &r_heartbeat_create,  10},
  {"heartbeat_stop",    (DL_FUNC) &r_heartbeat_stop,     4},
  {"heartbeat_running", (DL_FUNC) &r_heartbeat_running,  1},
  {NULL, NULL, 0}
};

void R_init_heartbeatr(DllInfo *info) {
  R_registerRoutines(info, NULL, call_methods, NULL, NULL);
}
