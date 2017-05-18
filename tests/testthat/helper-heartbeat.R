skip_if_no_redis <- function() {
  if (redux::redis_available()) {
    return()
  }
  testthat::skip("Redis is not available")
}

skip_if_not_isolated_redis <- function() {
  skip_if_no_redis()
  if (identical(Sys.getenv("ISOLATED_REDIS"), "true")) {
    return()
  }
  testthat::skip("Redis is not isolated (set envvar ISOLATED_REDIS to 'true')")
}
