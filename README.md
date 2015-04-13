# RedisHeartbeat

[![Build Status](https://travis-ci.org/richfitz/RedisHeartbeat.png?branch=master)](https://travis-ci.org/richfitz/RedisHeartbeat)

This only exists as a separate package so that `rrqueue` remains easy to install; eventually this will fold into one of the Redis packages or into `rrqueue`.

## Installation

Installation requires installing [hiredis](https://github.com/redis/hiredis) (download, run `make && make install`).  On OS X, you may need to run (or set in `~/.profile`)

```
export DYLD_LIBRARY_PATH=/usr/local/lib
```

If hiredis is stored in a more exotic location you'll need to tweak `src/Makevars`.  Compilation requires a C++11 compatible compiler.

Redis must be running.  Bad Things will happen if Redis stops while this is running.

This uses the [tiny thread](http://tinythreadpp.bitsnbites.eu/) library, following the lead of [RcppParallel](https://github.com/RcppCore/RcppParallel) - it's possible that we could achive this directly with RcppParallel.

## Usage

```r
f <- function() {
  h <- heartbeat()
  h$start("mykey", 4)
  # ... long running job here
  h$stop() # optional - will stop once h is garbage collected
}
```
