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

payload * controller_create(heartbeat_data *data) {
  payload * x = (payload*) std::calloc(1, sizeof(payload));
  x->data = data;
  x->con = NULL;
  x->started = false;
  x->stopped = false;
  x->orphaned = false;
  x->keep_going = true;

  std::thread t(worker_create, x);
  t.detach();
  // Wait for things to come up
  size_t every = 10;
  size_t n = x->data->expire * 1000 / every + 1;
  for (size_t i = 0; i < n; ++i) {
    if (x->started) {
      return x;
    } else if (!x->keep_going) {
      std::free(x);
      break;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(every));
  }
  // Didn't start but also didn't actively fail; try to recover as
  // best we can?  Not sure what can be done here, so I'm going to
  // prefer leaking to crashing and think about this later.
  if (x) {
    x->orphaned = false;
    x->keep_going = false;
  }
  return NULL;
}

bool controller_stop(payload *x, bool wait) {
  if (x) {
    redisContext * con = redisConnect(x->data->host, x->data->port);
    const char *key_signal = string_duplicate(x->data->key_signal);
    int expire = x->data->expire;
    bool ok = con && !con->err;

    if (!wait) {
      x->orphaned = true;
    }
    x->keep_going = false;
    if (ok) {
      redisReply *r = (redisReply*) redisCommand(con, "RPUSH %s 0", key_signal);
      if (r) {
        freeReplyObject(r);
      }
      redisFree(con);
    }
    if (wait) {
      size_t every = 10;
      size_t n = expire * 1000 / every + 1;
      for (size_t i = 0; i < n; ++i) {
        if (x->stopped) {
          std::free(x);
          return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(every));
      }
    }
  }
  return false;
}
