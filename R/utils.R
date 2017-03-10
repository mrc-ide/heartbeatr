assert_logical <- function(x, name = deparse(substitute(x))) {
  if (!is.logical(x) && !is.na(x)) {
    stop(sprintf("%s must be logical", name), call. = FALSE)
  }
}
assert_character <- function(x, name = deparse(substitute(x))) {
  if (!is.character(x) && !is.na(x)) {
    stop(sprintf("%s must be character", name), call. = FALSE)
  }
}
assert_scalar <- function(x, name = deparse(substitute(x))) {
  if (length(x) != 1) {
    stop(sprintf("%s must be a scalar", name), call. = FALSE)
  }
}
assert_nonmissing <- function(x, name = deparse(substitute(x))) {
  if (any(is.na(x))) {
    stop(sprintf("%s must not be NA", name), call. = FALSE)
  }
}
assert_scalar_positive_integer <- function(x, name = deparse(substitute(x))) {
  assert_scalar(x, name)
  assert_nonmissing(x, name)
  assert_integer_like(x, name)
  if (x <= 0) {
    stop(sprintf("%s must be a positive integer", name), call. = FALSE)
  }
}

assert_integer_like <- function(x, name = deparse(substitute(x))) {
  if (!isTRUE(all.equal(as.integer(x), x))) {
    stop(sprintf("%s is not integer like", name))
  }
}

assert_scalar_logical <- function(x, name = deparse(substitute(x))) {
  assert_scalar(x, name)
  assert_logical(x, name)
  assert_nonmissing(x, name)
}

assert_scalar_character <- function(x, name = deparse(substitute(x))) {
  assert_scalar(x, name)
  assert_character(x, name)
  assert_nonmissing(x, name)
}
