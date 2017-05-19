# heartbeatr

[![Project Status: WIP - Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](http://www.repostatus.org/badges/latest/wip.svg)](http://www.repostatus.org/#wip)
[![Build Status](https://travis-ci.org/richfitz/heartbeatr.svg?branch=master)](https://travis-ci.org/richfitz/heartbeatr)
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/richfitz/heartbeatr?branch=master&svg=true)](https://ci.appveyor.com/project/richfitz/heartbeatr)
[![codecov.io](https://codecov.io/github/richfitz/heartbeatr/coverage.svg?branch=master)](https://codecov.io/github/richfitz/heartbeatr?branch=master)

If you run a long running calculation on a remote machine your calculation can fail if the machine falls over, the network goes down, or your code crashes R.  This package provides a "heartbeat" service that uses Redis to periodically prevent a key from expiring, forming a [dead man's switch](https://en.wikipedia.org/wiki/Dead_man%27s_switch).  You can then monitor the key to detect failure in your process and requeue/rerun/investigate as appropriate.

## Usage

```r
f <- function() {
  h <- heartbeat("mykey", 4)
  # ... long running job here
  # h$stop() # optional - will stop automatically once h is garbage collected
}
```

## Installation

``` r
remotes::install_gituhb("richfitz/heartbeatr", ugprade = FALSE)
```
