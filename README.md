# heartbeatr

[![Build Status](https://travis-ci.org/richfitz/heartbeatr.png?branch=master)](https://travis-ci.org/richfitz/heartbeatr)

This only exists as a separate package so that `rrqueue` remains easy to install; eventually this will fold into one of the Redis packages or into `rrqueue`.

## Installation

Installation requires installing [hiredis](https://github.com/redis/hiredis) (download, run `make && make install`).  On OS X, you may need to run (or set in `~/.profile`)

```
export DYLD_LIBRARY_PATH=/usr/local/lib
```

If hiredis is stored in a more exotic location you'll need to tweak `src/Makevars`.  Compilation requires a C++11 compatible compiler.

Redis must be running.  Bad Things will happen if Redis stops while this is running.

## Usage

```r
f <- function() {
  h <- heartbeat("mykey", 4)
  # ... long running job here
  # h$stop() # optional - will stop automatically once h is garbage collected
}
```
