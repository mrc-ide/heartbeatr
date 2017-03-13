#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
if (length(args) != 4L) {
  stop("Expected 4 arguments")
}
key <- args[[1]]
period <- as.integer(args[[2]])
expire <- as.integer(args[[3]])
sleep <- as.integer(args[[4]])
key <- heartbeatr::heartbeat(key, period, expire)
Sys.sleep(sleep)
