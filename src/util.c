#include "util.h"
#include <string.h>
#include <stdlib.h>

// This is basically C code that I'm compiling with the C++ compiler
// to keep things relatively straightforward.  That should be allowed
// and later I might roll it back to use C, but there's not a great
// need to do so.
char * string_duplicate(const char * x) {
  const size_t n = strlen(x);
  char * ret = (char*) calloc(n + 1, sizeof(char));
  strcpy(ret, x);
  return ret;
}

const char * scalar_string(SEXP x) {
  return CHAR(STRING_ELT(x, 0));
}

int scalar_integer(SEXP x) {
  return INTEGER(x)[0];
}

bool scalar_logical(SEXP x) {
  return INTEGER(x)[0] != 0;
}

double scalar_numeric(SEXP x) {
  return REAL(x)[0];
}
