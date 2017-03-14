#include "thread.h"

#include <thread>
#include <chrono>
#include <cstdlib> // for std::calloc, std::free
#include "util.h"

// This file exists in C++ (forcing the rest of things into using the
// C++ linker) because C++11 has nice platform-independent threading
// and sleeping.  I will probably look at replacing this with plain C
// at some point.  Because the rest of the package uses hiredis' C
// interface and R's C interface there's not much gained from a C++
// approach and so this uses a naked pointer C-style programming
// approach.

payload * controller_create(heartbeat_data *data, double timeout,
                            heartbeat_connection_status *status) {
  // I do not know what in here is throwable but in general I can't
  // have things throwing!  This might all need to go in a big
  // try/catch.
  payload * x = (payload*) std::calloc(1, sizeof(payload));
  x->data = data;
  x->con = NULL;
  x->started = false;
  x->stopped = false;
  x->orphaned = false;
  x->keep_going = true;
  x->status = UNSET;

  std::thread t(worker_create, x);
  t.detach();
  // Wait for things to come up
  size_t time_poll = 10; // must go into 1000 nicely
  size_t timeout_ms = ceil(timeout * 1000);
  size_t n = timeout_ms / time_poll;
  for (size_t i = 0; i < n; ++i) {
    if (x->started) {
      *status = OK;
      return x;
    } else if (!x->keep_going) {
      *status = x->status;
      std::free(x);
      x = NULL;
      break;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(time_poll));
  }
  // We did not come up in time!
  if (x) {
    *status = FAILURE_ORPHAN;
    x->orphaned = false;
    x->keep_going = false;
  }
  return NULL;
}

bool controller_stop(payload *x, bool wait, double timeout) {
  bool ret = false;
  if (x) {
    heartbeat_connection_status status;
    redisContext * con = heartbeat_connect(x->data, &status);
    const char *key_signal = string_duplicate(x->data->key_signal);

    if (!wait) {
      x->orphaned = true;
    }
    x->keep_going = false;
    if (con) {
      redisReply *r = (redisReply*) redisCommand(con, "RPUSH %s 0", key_signal);
      if (r) {
        freeReplyObject(r);
      }
      redisFree(con);
    }
    if (wait) {
      size_t time_poll = 10; // must go into 1000 nicely
      size_t timeout_ms = ceil(timeout * 1000);
      size_t n = timeout_ms / time_poll;
      for (size_t i = 0; i < n; ++i) {
        if (x->stopped) {
          std::free(x);
          ret = true;
          break;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(time_poll));
      }
    }
    std::free((void*) key_signal);
  }
  return ret;
}
