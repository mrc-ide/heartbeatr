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

test_that("dying process", {
  skip_if_no_redis()
  skip_if_not_installed("processx")
  Sys.setenv(R_TESTS = "")

  con <- redux::hiredis()
  expire <- 2

  key <- "heartbeat_key:die"
  Rscript <- file.path(R.home(), "bin", "Rscript")
  px <- processx::process$new(Rscript,
                              c("run-heartbeat.R", key, 1, expire, 600))
  Sys.sleep(0.5)
  expect_equal(con$EXISTS(key), 1)
  px$kill(0)
  Sys.sleep(0.5)
  expect_equal(con$EXISTS(key), 1)
  expect_false(px$is_alive())
  Sys.sleep(expire)
  expect_equal(con$EXISTS(key), 0)
})

test_that("pointer handling", {
  skip_if_no_redis()
  key <- "heartbeat_key:basic"
  period <- 1
  expire <- 2
  obj <- heartbeat(key, period, expire = expire, start = TRUE)

  private <- environment(obj$initialize)$private
  ptr <- private$ptr
  null_ptr <- unserialize(serialize(ptr, NULL))

  obj$stop()

  expect_error(.Call(heartbeat_stop, NULL, TRUE, FALSE, 1),
               "Expected an external pointer")
  expect_error(.Call(heartbeat_stop, null_ptr, TRUE, FALSE, 1),
               "already freed")
})

test_that("connnection failure", {
  skip_if_no_redis()
  key <- "heartbeat_key:confail"
  period <- 1
  expire <- 2

  expect_error(
    heartbeat(key, period, expire = expire, port = 9999, start = TRUE),
    "Error creating heartbeat thread")
  expect_error(
    heartbeat(key, period, expire = expire, password = "yo", start = TRUE),
    "Error creating heartbeat thread")
  expect_error(
    heartbeat(key, period, expire = expire, db = 99, start = TRUE),
    "Error creating heartbeat thread")

  skip_if_not_isolated_redis()
  password <- "yolo"
  con <- redux::hiredis()
  con$CONFIG_SET("requirepass", password)
  con$AUTH(password)
  on.exit(con$CONFIG_SET("requirepass", ""))
  expect_error(
    heartbeat(key, period, expire = expire, start = TRUE),
    "Error creating heartbeat thread")
})

test_that("invalid times", {
  key <- "heartbeat_key:confail"
  period <- 10
  expect_error(heartbeat(key, period, expire = period),
               "expire must be longer than period")
  expect_error(heartbeat(key, period, expire = period - 1),
               "expire must be longer than period")
})

test_that("positive timeout", {
  skip_if_no_redis()
  key <- "heartbeat_key:basic"
  period <- 1
  obj <- heartbeat(key, period, start = FALSE)
  expect_error(obj$stop(wait = TRUE, timeout = -1), "timeout must be positive")
})

test_that("print", {
  skip_if_no_redis()
  key <- "heartbeat_key:print"
  period <- 1
  obj <- heartbeat(key, period, start = FALSE)
  str <- capture.output(tmp <- print(obj))
  expect_identical(tmp, obj)
  expect_match(str, "<heartbeat>", fixed = TRUE, all = FALSE)
  expect_match(str, "running: false", fixed = TRUE, all = FALSE)
})

test_that("ungraceful exit", {
  skip_if_no_redis()
  key <- "heartbeat_key:ungraceful"
  period <- 1
  expect_error(heartbeat(key, period, timeout = 0),
               "Error creating heartbeat thread")
  Sys.sleep(0.25)
  expect_equal(redux::hiredis()$EXISTS(key), 0)
})
