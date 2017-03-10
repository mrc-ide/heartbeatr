context("heartbeat")

test_that("heartbeat", {
  key <- "heartbeat_key"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire = expire, start = FALSE)
  expect_is(obj, "heartbeat")
  expect_is(obj, "R6")

  con <- redux::hiredis()
  expect_that(con$EXISTS(key), equals(0))
  on.exit(con$DEL(key))
  expect_that(obj$is_running(), is_false())

  obj$start()
  expect_that(con$EXISTS(key), equals(1))
  expect_that(con$GET(key), equals(as.character(expire)))
  ttl <- con$TTL(key)
  expect_that(ttl, is_more_than(period - expire))
  expect_that(ttl, is_less_than(expire + 1))
  expect_that(obj$is_running(), is_true())

  expect_true(obj$stop())
  expect_that(obj$is_running(), is_false())
  expect_that(con$EXISTS(key), equals(0))
})

test_that("simple interface", {
  key <- "mykey2"
  period <- 1
  expire <- 2
  con <- redux::hiredis()

  obj <- heartbeat(key, period, expire = expire)
  expect_that(con$EXISTS(key), equals(1))
  expect_that(obj$is_running(), is_true())

  ## OK, this does not work and that's very good to know!  Looks again
  ## like a double free
  rm(obj)
  gc()
  Sys.sleep(expire + 0.5)
  expect_that(con$EXISTS(key), equals(0))
})

test_that("Send signals", {
  skip_on_os("windows")
  key <- "heartbeat_key"
  period <- 10
  expire <- 20
  con <- redux::hiredis()
  on.exit(con$DEL(key))

  obj <- heartbeat(key, period, expire = expire, start = TRUE)
  expect_that(con$EXISTS(key), equals(1))
  expect_that(obj$is_running(), is_true())

  idx <- 0
  dt <- 0.1
  f <- function() {
    for (i in 1:(expire * dt)) {
      idx <<- i
      if (i > 1) {
        heartbeat_send_signal(con, key, tools::SIGINT)
      }
      Sys.sleep(dt)
    }
    i
  }

  ans <- tryCatch(f(), interrupt = function(e) TRUE)
  expect_that(ans, is_true())
  expect_that(idx, not(is_less_than(1)))
  expect_that(idx, is_less_than(10))
  ## expect_false(obj$is_running())
  obj$stop()
})
