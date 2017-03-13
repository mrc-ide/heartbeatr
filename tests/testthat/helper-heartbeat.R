skip_if_no_redis <- function() {
  testthat::skip_if_not_installed("redux")
  if (redux::redis_available()) {
    return()
  }
  testthat::skip("Redis is not available")
}

skip_if_not_isolated_redis <- function() {
  skip_if_no_redis()
  ## TODO: set this so that some tests can be skipped unless I flag
  ## that we're allowed to do destructive things.
  return()
}
