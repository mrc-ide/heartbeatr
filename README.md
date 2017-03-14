# heartbeatr

[![Build Status](https://travis-ci.org/richfitz/heartbeatr.png?branch=master)](https://travis-ci.org/richfitz/heartbeatr)

If you run a long running calculation on a remote machine your calculation can fail if the machine falls over, the network goes down, or your code crashes R.  This package provides a "heartbeat" service that uses Redis to periodically prevent a key from expiring, forming a [dead man's switch](https://en.wikipedia.org/wiki/Dead_man%27s_switch).  You can then monitor the key to detect failure in your process and requeue/rerun/investigate as appropriate.

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
