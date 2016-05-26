context("heartbeat")

test_that("heartbeat", {
  key <- "heartbeat_key"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire=expire, start=FALSE)

  con <- redux::hiredis()
  expect_equal(con$EXISTS(key), 0)
  on.exit(con$DEL(key))
  expect_false(obj$is_running())

  obj$start()
  Sys.sleep(0.5)
  expect_equal(con$EXISTS(key), 1)
  expect_equal(con$GET(key), as.character(expire))
  ttl <- con$TTL(key)
  expect_gt(ttl, period - expire)
  expect_lt(ttl, expire + 1)
  expect_true(obj$is_running())

  obj$stop()
  expect_false(obj$is_running())
  expect_equal(con$EXISTS(key), 1)
  ttl <- con$TTL(key)
  Sys.sleep(ttl + 1)
  expect_equal(con$EXISTS(key), 0)

  obj$start()
  Sys.sleep(0.5)
  expect_error(obj$start(), "Already running on key")
  obj$stop()
})

test_that("simple interface", {
  key <- "mykey2"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire=expire)
  con <- redux::hiredis()
  on.exit(con$DEL(key))
  Sys.sleep(0.5)
  expect_equal(con$EXISTS(key), 1)
  expect_true(obj$is_running())
  rm(obj)
  gc()
  Sys.sleep(1)
  expect_equal(con$EXISTS(key), 0)
})

test_that("period zero does not enable heartbeat", {
  key <- "mykey3"
  period <- 0
  expire <- 0
  obj <- heartbeat(key, period, expire=expire)
  con <- redux::hiredis()
  on.exit(con$DEL(key))
  expect_equal(con$EXISTS(key), 1)
  expect_false(obj$is_running())
  expect_equal(con$TTL(key), -1) # infinite ttl
  rm(obj)
  gc()
  expect_equal(con$EXISTS(key), 0)
})

test_that("Send signals", {
  key <- "heartbeat_key"
  period <- 10
  expire <- 20
  con <- redux::hiredis()
  on.exit(con$DEL(key))

  obj <- heartbeat(key, period, expire=expire, start=TRUE)
  Sys.sleep(0.5)
  expect_equal(con$EXISTS(key), 1)
  expect_true(obj$is_running())

  idx <- 0
  f <- function() {
    for (i in 1:20) {
      idx <<- i
      if (i > 1) {
        heartbeat_send_signal(con, obj$key, tools::SIGINT)
      }
      Sys.sleep(.1)
    }
    i
  }

  ans <- tryCatch(f(), interrupt=function(e) TRUE)
  expect_true(ans)
  expect_gte(idx, 1)
  expect_lt(idx, 10)
  obj$stop()
})
