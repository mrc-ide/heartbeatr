#ifndef HEARTBEAT_UTIL_H
#define HEARTBEAT_UTIL_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <R.h>
#include <Rinternals.h>

char * string_duplicate(const char * x);
const char * scalar_string(SEXP x, const char * name);
int scalar_integer(SEXP x, const char * name);
bool scalar_logical(SEXP x, const char * name);

#ifdef __cplusplus
}
#endif

#endif
