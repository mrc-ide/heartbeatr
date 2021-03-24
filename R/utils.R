assert_logical <- function(x, name = deparse(substitute(x))) {
  if (!is.logical(x)) {
    stop(sprintf("'%s' must be a logical", name), call. = FALSE)
  }
}
assert_numeric <- function(x, name = deparse(substitute(x))) {
  if (!is.numeric(x)) {
    stop(sprintf("'%s' must be a numeric", name), call. = FALSE)
  }
}
assert_character <- function(x, name = deparse(substitute(x))) {
  if (!is.character(x)) {
    stop(sprintf("'%s' must be a character", name), call. = FALSE)
  }
}
assert_scalar <- function(x, name = deparse(substitute(x))) {
  if (length(x) != 1) {
    stop(sprintf("'%s' must be a scalar", name), call. = FALSE)
  }
}
assert_nonmissing <- function(x, name = deparse(substitute(x))) {
  if (any(is.na(x))) {
    stop(sprintf("'%s' must not be NA", name), call. = FALSE)
  }
}
assert_scalar_positive_integer <- function(x, zero_ok = FALSE,
                                           name = deparse(substitute(x))) {
  assert_scalar(x, name)
  assert_nonmissing(x, name)
  assert_integer_like(x, name)
  if (x < if (zero_ok) 0 else 1) {
    stop(sprintf("'%s' must be a positive integer", name), call. = FALSE)
  }
}

assert_integer_like <- function(x, name = deparse(substitute(x))) {
  if (!isTRUE(all.equal(as.integer(x), x))) {
    stop(sprintf("'%s' is not integer like", name))
  }
}

assert_scalar_logical <- function(x, name = deparse(substitute(x))) {
  assert_scalar(x, name)
  assert_logical(x, name)
  assert_nonmissing(x, name)
}

assert_scalar_numeric <- function(x, name = deparse(substitute(x))) {
  assert_scalar(x, name)
  assert_numeric(x, name)
  assert_nonmissing(x, name)
}

assert_scalar_character <- function(x, name = deparse(substitute(x))) {
  assert_scalar(x, name)
  assert_character(x, name)
  assert_nonmissing(x, name)
}

assert_valid_timeout <- function(x, name = deparse(substitute(x))) {
  assert_scalar_numeric(x, name)
  if (x < 0) {
    stop(sprintf("'%s' must be positive", name))
  }
}

`%||%` <- function(a, b) { # nolint
  if (is.null(a)) b else a
}


wait_timeout <- function(explanation, timeout, keep_going,
                         poll = timeout / 100) {
  t_end <- Sys.time() + timeout
  while (keep_going()) {
    if (Sys.time() > t_end) {
      stop("Timeout: ", explanation)
    }
    Sys.sleep(poll)
  }
}
