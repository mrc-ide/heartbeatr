context("heartbeat")

test_that("heartbeat", {
  key <- "mykey"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire=expire, start=FALSE)

  con <- RedisAPI::hiredis()
  expect_that(con$EXISTS(key), equals(0))
  on.exit(con$DEL(key))
  expect_that(obj$is_running(), is_false())

  obj$start()
  Sys.sleep(0.5)
  expect_that(con$EXISTS(key), equals(1))
  expect_that(con$GET(key), equals(as.character(expire)))
  ttl <- con$TTL(key)
  expect_that(ttl, is_more_than(period - expire))
  expect_that(ttl, is_less_than(expire + 1))
  expect_that(obj$is_running(), is_true())

  obj$stop()
  expect_that(obj$is_running(), is_false())
  expect_that(con$EXISTS(key), equals(1))
  ttl <- con$TTL(key)
  Sys.sleep(ttl + 1)
  expect_that(con$EXISTS(key), equals(0))

  obj$start()
  Sys.sleep(0.5)
  expect_that(obj$start(),
              throws_error("Already running on key"))
  obj$stop()
})

test_that("simple interface", {
  key <- "mykey2"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire=expire)
  con <- RedisAPI::hiredis()
  on.exit(con$DEL(key))
  Sys.sleep(0.5)
  expect_that(con$EXISTS(key), equals(1))
  expect_that(obj$is_running(), is_true())
  rm(obj)
  gc()
  Sys.sleep(0.5)
  expect_that(con$EXISTS(key), equals(0))
})

test_that("period zero does not enable heartbeat", {
  key <- "mykey3"
  period <- 0
  expire <- 0
  obj <- heartbeat(key, period, expire=expire)
  con <- RedisAPI::hiredis()
  on.exit(con$DEL(key))
  expect_that(con$EXISTS(key), equals(1))
  expect_that(obj$is_running(), is_false())
  expect_that(con$TTL(key), equals(-1)) # infinite ttl
  rm(obj)
  gc()
  expect_that(con$EXISTS(key), equals(0))
})
