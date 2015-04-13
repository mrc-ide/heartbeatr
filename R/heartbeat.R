##' @importFrom R6 R6Class
##' @useDynLib RedisHeartbeat
##' @importFrom Rcpp evalCpp
.R6_heartbeat <- R6::R6Class(
  "heartbeat",

  public=list(
    host=NULL,
    port=NULL,
    initialize=function(host, port) {
      self$host <- host
      self$port <- port
      reg.finalizer(self, function(e) self$stop())
    },

    is_running=function() {
      heartbeat_status()
    },

    start=function(key, timeout, expire=timeout * 3) {
      if (self$is_running()) {
        stop("Already running on key ", heartbeat_key())
      }
      heartbeat_start(self$host, self$port, key, timeout, expire)
    },

    stop=function() {
      heartbeat_stop()
    }))

##' Create a heartbeat instance.  This can be used by running
##' \code{obj$start(key, timeout)} which will reset the TTL on
##' \code{key} every \code{timeout} seconds (don't set this too high).
##' If the R process dies, then the key will expire after \code{3 *
##' timeout} seconds (or set \code{expire}) and another application can
##' tell that this R instance has died.
##'
##' Heavily inspired by the \code{doRedis} package.
##' @title Create a heartbeat instance
##' @param host Hostname
##' @param port Port number
##' @export
heartbeat <- function(host="127.0.0.1", port=6379) {
  .R6_heartbeat$new(host, port)
}
