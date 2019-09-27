# heartbeatr

[![Project Status: WIP - Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](http://www.repostatus.org/badges/latest/wip.svg)](http://www.repostatus.org/#wip)
[![Build Status](https://travis-ci.org/mrc-ide/heartbeatr.svg?branch=master)](https://travis-ci.org/mrc-ide/heartbeatr)
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/richfitz/heartbeatr?branch=master&svg=true)](https://ci.appveyor.com/project/richfitz/heartbeatr)
[![codecov.io](https://codecov.io/github/mrc-ide/heartbeatr/coverage.svg?branch=master)](https://codecov.io/github/mrc-ide/heartbeatr?branch=master)

If you run a long running calculation on a remote machine your calculation can fail if the machine falls over, the network goes down, or your code crashes R.  This package provides a "heartbeat" service that uses Redis to periodically prevent a key from expiring, forming a [dead man's switch](https://en.wikipedia.org/wiki/Dead_man%27s_switch).  You can then monitor the key to detect failure in your process and re-queue/rerun/investigate as appropriate.

## Usage

```r
f <- function() {
  h <- heartbeatr::heartbeat("mykey", 4)
  # ... long running job here
  # h$stop() # optional - will stop automatically once h is garbage collected
}
```

## Installation

``` r
drat:::add("mrc-ide")
install.packges("heartbeatr")
```

It is also possible to install directly from GitHub using `remotes` as

``` r
remotes::install_gituhb("mrc-ide/heartbeatr", ugprade = FALSE)
```

## License

MIT + file LICENSE © Imperial College of Science, Technology and Medicine

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms.
