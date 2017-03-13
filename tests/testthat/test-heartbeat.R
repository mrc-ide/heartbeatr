context("heartbeat")

test_that("heartbeat", {
  key <- "heartbeat_key"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire = expire, start = FALSE)
  expect_is(obj, "heartbeat")
  expect_is(obj, "R6")

  con <- redux::hiredis()
  expect_equal(con$EXISTS(key), 0)
  on.exit(con$DEL(key))
  expect_false(obj$is_running())

  obj$start()
  expect_equal(con$EXISTS(key), 1)
  expect_equal(con$GET(key), as.character(expire))
  ttl <- con$TTL(key)

  expect_gt(ttl, period - expire)
  expect_lte(ttl, expire)
  expect_true(obj$is_running())

  expect_true(obj$stop())
  expect_false(obj$is_running())
  expect_equal(con$EXISTS(key), 0)
})

test_that("simple interface", {
  key <- "mykey2"
  period <- 1
  expire <- 2
  con <- redux::hiredis()

  obj <- heartbeat(key, period, expire = expire)
  expect_equal(con$EXISTS(key), 1)
  expect_true(obj$is_running())

  rm(obj)
  gc()
  Sys.sleep(0.5)
  expect_equal(con$EXISTS(key), 0)
})

test_that("Send signals", {
  skip_on_os("windows")
  key <- "heartbeat_key"
  period <- 10
  expire <- 20
  con <- redux::hiredis()
  on.exit(con$DEL(key))

  obj <- heartbeat(key, period, expire = expire, start = TRUE)
  expect_equal(con$EXISTS(key), 1)
  expect_true(obj$is_running())

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
  expect_true(ans)
  expect_gte(idx, 1)
  expect_lt(idx, 10)
  expect_true(obj$is_running())
  obj$stop()
})
