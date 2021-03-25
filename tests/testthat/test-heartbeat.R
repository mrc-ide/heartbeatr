context("heartbeat")

test_that("basic", {
  skip_if_no_redis()
  config <- redux::redis_config()
  key <- sprintf("heartbeat_key:basic:%s", rand_str())
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
  wait_timeout("Key not available in time", 5, function() con$EXISTS(key) == 0)

  expect_equal(con$EXISTS(key), 1)
  expect_equal(con$GET(key), as.character(expire))
  ttl <- con$TTL(key)

  expect_gt(ttl, period - expire)
  expect_lte(ttl, expire)
  expect_true(obj$is_running())

  expect_error(obj$start(), "Already running on key")
  expect_true(obj$is_running())

  expect_true(obj$stop())
  expect_false(obj$is_running())
  expect_equal(con$EXISTS(key), 0)
})


test_that("Garbage collection", {
  skip_if_no_redis()
  key <- sprintf("heartbeat_key:gc%s", rand_str())
  period <- 1
  expire <- 2
  con <- redux::hiredis()

  path <- "tmp.log"

  obj <- heartbeat(key, period, expire = expire, logfile = path)
  expect_equal(con$EXISTS(key), 1)
  expect_true(obj$is_running())

  rm(obj)
  gc()

  ## We might have to wait up to 'expire' seconds for this key to
  ## disappear. We could add an attempt to clean up into the finaliser
  ## but that will cause stalls on garbage collection, which is rude.
  wait_timeout("Key not expired in time", expire, function()
    con$EXISTS(key) == 1)
  expect_equal(con$EXISTS(key), 0)
})


test_that("Send signals", {
  skip("rewrite - may not be possible")
  skip_if_no_redis()
  skip_on_os("windows")
  key <- sprinf("heartbeat_key:signals:%s", rand_str())
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


test_that("dying process", {
  skip_if_no_redis()

  key <- sprintf("heartbeat_key:die:%s", rand_str())

  px <- callr::r_bg(function(key) {
    config <- redux::redis_config()
    obj <- heartbeatr::heartbeat(key, 1, 2, config = config)
    Sys.sleep(120)
  }, list(key = key))

  con <- redux::hiredis()
  wait_timeout("Process did not start up in time", 5, function()
    con$EXISTS(key) == 0 && px$is_alive(), poll = 0.2)

  ## This is not taking out our worker properly:
  expect_equal(con$EXISTS(key), 1)
  px$kill(0)
  wait_timeout("Process did not die in time", 5, px$is_alive)
  expect_equal(con$EXISTS(key), 1)
  Sys.sleep(2) # expire
  expect_equal(con$EXISTS(key), 0)
})


test_that("invalid times", {
  key <- sprintf("heartbeat_key:confail:%s", rand_str())
  period <- 10
  expect_error(heartbeat(key, period, expire = period),
               "expire must be longer than period")
  expect_error(heartbeat(key, period, expire = period - 1),
               "expire must be longer than period")
})


test_that("positive timeout", {
  skip_if_no_redis()
  key <- sprintf("heartbeat_key:basic:%s", rand_str())
  period <- 1
  obj <- heartbeat(key, period, start = FALSE)
  expect_error(obj$stop(wait = TRUE, timeout = -1),
               "'timeout' must be positive")
})


test_that("print", {
  skip_if_no_redis()
  key <- sprintf("heartbeat_key:print:%s", rand_str())
  period <- 1
  obj <- heartbeat(key, period, start = FALSE)
  str <- capture.output(tmp <- print(obj))
  expect_identical(tmp, obj)
  expect_match(str, "<heartbeat>", fixed = TRUE, all = FALSE)
  expect_match(str, "running: false", fixed = TRUE, all = FALSE)
})
