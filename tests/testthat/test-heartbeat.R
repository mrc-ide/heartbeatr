context("heartbeat")

test_that("heartbeat", {
  key <- "heartbeat_key"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire=expire, start=FALSE)

  con <- redux::hiredis()
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
  con <- redux::hiredis()
  on.exit(con$DEL(key))
  Sys.sleep(0.5)
  expect_that(con$EXISTS(key), equals(1))
  expect_that(obj$is_running(), is_true())
  rm(obj)
  gc()
  Sys.sleep(1)
  expect_that(con$EXISTS(key), equals(0))
})

test_that("period zero does not enable heartbeat", {
  key <- "mykey3"
  period <- 0
  expire <- 0
  obj <- heartbeat(key, period, expire=expire)
  con <- redux::hiredis()
  on.exit(con$DEL(key))
  expect_that(con$EXISTS(key), equals(1))
  expect_that(obj$is_running(), is_false())
  expect_that(con$TTL(key), equals(-1)) # infinite ttl
  rm(obj)
  gc()
  expect_that(con$EXISTS(key), equals(0))
})

test_that("Send signals", {
  key <- "heartbeat_key"
  period <- 10
  expire <- 20
  con <- redux::hiredis()
  on.exit(con$DEL(key))

  obj <- heartbeat(key, period, expire=expire, start=TRUE)
  Sys.sleep(0.5)
  expect_that(con$EXISTS(key), equals(1))
  expect_that(obj$is_running(), is_true())

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
  expect_that(ans, is_true())
  expect_that(idx, not(is_less_than(1)))
  expect_that(idx, is_less_than(10))
  obj$stop()
})
