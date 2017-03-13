context("heartbeat")

test_that("basic", {
  skip_if_no_redis()
  key <- "heartbeat_key:basic"
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

test_that("Garbage collection", {
  skip_if_no_redis()
  key <- "heartbeat_key:gc"
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
  skip_if_no_redis()
  skip_on_os("windows")
  key <- "heartbeat_key:signals"
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

test_that("auth", {
  skip_if_not_isolated_redis()
  con <- redux::hiredis()

  key <- "heartbeat_key:auth"
  password <- "password"

  con$CONFIG_SET("requirepass", password)
  con$AUTH(password)
  on.exit(con$CONFIG_SET("requirepass", ""))

  expect_error(redux::hiredis()$PING(), "NOAUTH")

  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire = expire, password = password)
  expect_is(obj, "heartbeat")
  expect_is(obj, "R6")
  expect_true(obj$is_running())
  expect_equal(con$EXISTS(key), 1)
  expect_true(obj$stop())
  expect_false(obj$is_running())
  expect_equal(con$EXISTS(key), 0)
})

test_that("db", {
  skip_if_no_redis()
  con <- redux::hiredis()

  key <- "heartbeat_key:db"
  db <- 3L

  con$SELECT(db)

  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire = expire, db = db)

  expect_is(obj, "heartbeat")
  expect_is(obj, "R6")
  expect_true(obj$is_running())
  expect_equal(con$EXISTS(key), 1)
  expect_true(obj$stop())
  expect_false(obj$is_running())
  expect_equal(con$EXISTS(key), 0)
})
