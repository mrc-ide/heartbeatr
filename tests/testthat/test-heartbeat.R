context("heartbeat")

test_that("heartbeat", {
  obj <- heartbeat()
  key <- "mykey"
  timeout <- 1
  expire <- 2

  con <- rrlite::hiredis()
  expect_that(con$EXISTS(key), equals(0))
  on.exit(con$DEL(key))
  expect_that(obj$is_running(), is_false())

  obj$start(key, timeout, expire)
  expect_that(con$EXISTS(key), equals(1))
  ttl <- con$TTL(key)
  expect_that(ttl, is_more_than(timeout - expire))
  expect_that(ttl, is_less_than(expire + 1))
  expect_that(obj$is_running(), is_true())

  obj$stop()
  expect_that(obj$is_running(), is_false())
  expect_that(con$EXISTS(key), equals(1))
  ttl <- con$TTL(key)
  Sys.sleep(ttl + 1)
  expect_that(con$EXISTS(key), equals(0))

  obj$start(key, timeout, expire)
  Sys.sleep(0.5)
  expect_that(obj$start(key, timeout, expire),
              throws_error("Already running on key"))
  obj$stop()
})
