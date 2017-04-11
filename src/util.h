#ifndef HEARTBEAT_UTIL_H
#define HEARTBEAT_UTIL_H

#include <stdbool.h>
#include <R.h>
#include <Rinternals.h>

#ifdef __cplusplus
extern "C" {
#endif

char * string_duplicate(const char * x);
const char * scalar_string(SEXP x);
bool scalar_logical(SEXP x);
int scalar_integer(SEXP x);
double scalar_numeric(SEXP x);

#ifdef __cplusplus
}
#endif

#endif
