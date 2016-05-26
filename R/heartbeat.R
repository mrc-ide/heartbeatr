##' @importFrom R6 R6Class
##' @useDynLib RedisHeartbeat
##' @importFrom Rcpp evalCpp
.R6_heartbeat <- R6::R6Class(
  "heartbeat",

  public=list(
    config=NULL,
    key=NULL,
    period=NULL,
    expire=NULL,
    value=NULL,

    initialize=function(config, key, value, period, expire) {
      #
      if (expire <= period && period > 0) {
        stop("expire must be longer than period")
      }
      self$config <- config
      self$key    <- as.character(key)
      self$period <- as.integer(period)
      self$expire <- as.integer(expire)
      self$value  <- as.character(value)
      reg.finalizer(self, function(e) self$stop())
    },

    is_running=function() {
      heartbeat_status()
    },

    ## TODO: If period is 0, then don't start the heartbeat and don't
    ## expire the key.
    start=function() {
      if (self$is_running()) {
        stop("Already running on key ", heartbeat_key())
      }
      heartbeat_start(self$config$host, self$config$port,
                      self$key,    self$value,
                      self$period, self$expire)
    },

    stop=function() {
      if (self$period > 0) {
        heartbeat_stop()
      } else {
        heartbeat_cleanup(self$config$host, self$config$port, self$key)
      }
    }))

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
##' \item \code{is_running()} which returns \code{TRUE} or \code{FALSE}
##' if the heartbeat is/is not running.
##'
##' \item \code{start()} which starts a heartbeat
##'
##' \item \code{stop()} which stops the heartbeat
##'
##' }
##'
##' Heavily inspired by the \code{doRedis} package.
##' @title Create a heartbeat instance
##' @param key Key to use
##' @param period Timeout period (in seconds)
##' @param expire Key expiry time (in seconds)
##' @param value Value to store in the key.  By default it stores the
##' expiry time, so the time since last heartbeat can be computed.
##' @param config A \code{redux::redis_config} object.
##' @param start Should the heartbeat be started immediately?
##' @export
heartbeat <- function(key, period, expire=3 * period, value=expire,
                      config=redux::redis_config(), start=TRUE) {
  ret <- .R6_heartbeat$new(config, key, value, period, expire)
  if (start) {
    ret$start()
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
##' @importFrom redux hiredis
heartbeat_send_signal <- function(con, key, signal) {
  con$RPUSH(heartbeat_signal_key(key), signal)
}
