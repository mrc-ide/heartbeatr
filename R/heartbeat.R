##' @importFrom R6 R6Class
##' @useDynLib heartbeatr, .registration = TRUE
R6_heartbeat <- R6::R6Class(
  "heartbeat",

  cloneable = FALSE,

  public = list(
    initialize = function(config, key, value, period, expire) {
      assert_scalar_character(key)
      assert_scalar_character(value)
      assert_scalar_positive_integer(expire)
      assert_scalar_positive_integer(period)

      if (expire <= period) {
        stop("expire must be longer than period")
      }

      private$config <- redux::redis_config(config = config)
      if (private$config$scheme != "redis") {
        stop("Only tcp redis connections are supported")
      }

      private$key <- key
      private$key_signal <- heartbeat_key_signal(key)
      private$value <- value

      private$period <- as.integer(period)
      private$expire <- as.integer(expire)
    },

    ## There is an issue here with _exactly_ what happens where we
    ## have a situation where the heartbeat has been scheduled for
    ## closure but it has not closed.  At some point the other thread
    ## will clear out the pointer and we want to check that it has
    ## been set to NULL.  So when doing the check for keep_going we
    ## need to check that able to read safely.  There's a NULL check
    ## there in the code but it seems unsafe at this point.  I don't
    ## think this is super hard to get right and it only impacts the
    ## keep_going bit so we don't have to lock when dealing with the
    ## BLPOP (which could be fairly slow).
    is_running = function() {
      if (is.null(private$ptr)) {
        FALSE
      } else {
        ## I don't know that this is sensible or not; if this returns
        ## FALSE then it does not mean that the heartbeat is
        ## *absolutely* running because it could have died in the
        ## meantime and we don't check here for the key.  So this
        ## probably needs expanding but it requires a better knowledge
        ## of the real-life failure modes.
        .Call(heartbeat_running, private$ptr)
      }
    },

    start = function(timeout = 10) {
      if (self$is_running()) {
        stop("Already running on key ", private$key)
      }
      assert_scalar_numeric(timeout)
      private$ptr <- .Call(heartbeat_create,
                           private$config$host,
                           as.integer(private$config$port),
                           private$config$password %||% "",
                           as.integer(private$config$db %||% 0L),
                           private$key, private$value, private$key_signal,
                           private$expire, private$period, timeout)
      invisible(self)
    },

    stop = function(wait = TRUE, timeout = 10) {
      assert_scalar_logical(wait)
      assert_scalar_numeric(timeout)
      if (timeout < 0) {
        stop("timeout must be positive")
      }
      ret <- .Call(heartbeat_stop, private$ptr, FALSE, wait,
                   as.numeric(timeout))
      private$ptr <- NULL
      ret
    },

    print = function(...) {
      cat("<heartbeat>\n")
      cat(sprintf("  - running: %s\n", tolower(self$is_running())))
      cat(sprintf("  - key: %s\n", private$key))
      cat(sprintf("  - period: %d\n", private$period))
      cat(sprintf("  - expire: %d\n", private$expire))
      cat(sprintf("  - redis:\n%s\n",
                  paste0("      ", capture.output(print(private$config))[-1],
                         collapse = "\n")))
      invisible(self)
    }
  ),

  private = list(
    config = NULL,
    ptr = NULL,
    key = NULL,
    key_signal = NULL,
    period = NULL,
    expire = NULL,
    value = NULL
  ))

##' Create a heartbeat instance.  This can be used by running
##' \code{obj$start()} which will reset the TTL on \code{key} every
##' \code{period} seconds (don't set this too high).  If the R process
##' dies, then the key will expire after \code{3 * period} seconds (or
##' set \code{expire}) and another application can tell that this R
##' instance has died.
##'
##' The heartbeat object has three methods:
##' \itemize{
##'
##' \item \code{is_running()} which returns \code{TRUE} or
##' \code{FALSE} if the heartbeat is/is not running.
##'
##' \item \code{start()} which starts a heartbeat
##'
##' \item \code{stop()} which requess a stops for the heartbeat
##'
##' }
##'
##' Heavily inspired by the \code{doRedis} package.
##' @title Create a heartbeat instance
##' @param key Key to use
##' @param period Timeout period (in seconds)
##' @param expire Key expiry time (in seconds)
##' @param value Value to store in the key.  By default it stores the
##'   expiry time, so the time since last heartbeat can be computed.
##' @param config Configuration parameters passed through to
##'   \code{redux::redis_config}.  Provide as either a named list or a
##'   \code{redis_config} object.  This allows host, port, password,
##'   db, etc all to be set.  Socket connections (i.e., using
##'   \code{path} to access Redis over a socket) are not currently
##'   supported.
##' @param start Should the heartbeat be started immediately?
##' @param timeout Time, in seconds, to wait for the heartbeat to
##'   appear.  It should generally appear very quickly (within a
##'   second unless your connection is very slow) so this can be
##'   generally left alone.
##' @export
heartbeat <- function(key, period, expire = 3 * period, value = expire,
                      config = NULL, start = TRUE, timeout = 10) {
  ret <- R6_heartbeat$new(config, key, as.character(value), period, expire)
  if (start) {
    ret$start(timeout)
  }
  ret
}

##' Sends a signal to a hearbeat process that is using key \code{key}
##' @title Send a signal
##' @param key The heartbeat key
##' @param signal A signal to send (e.g. \code{tools::SIGINT} or
##'   \code{tools::SIGKILL})
##' @param con A hiredis object
##' @export
heartbeat_send_signal <- function(con, key, signal) {
  assert_scalar_character(key)
  con$RPUSH(heartbeat_key_signal(key), signal)
}

heartbeat_key_signal <- function(key) {
  paste0(key, ":signal")
}
