#ifndef _REDISHEARTBEAT_H_
#define _REDISHEARTBEAT_H_

// This is written in a bit of a mix between C and C++ at the moment;
// partly this is because working with hiredis means we have a C API
// to play with and there's not much that can be done about that.
//
// Because I want to have control over the memory management using R's
// external pointer objects I need to use the C API there too.
//
// Basically, I'd be happy to rewrite this entirely in C but would
// like a platfor independent threading library; C++11 gives us that
// and for this package it seems enough.
//
// Eventually I might move this over into a more idiomatic C++
// interface but this is meant to be a relatively small and simple
// program.  Alternatively, I might pull the thread-requiring bits
// into their own file and do the rest as pure C; that is only
// controller_create and controller_stop

#include <hiredis/hiredis.h>
#include <R.h>
#include <Rinternals.h>

// This is the bits required to communicate with Redis; the
// connection, keys and timing information.
class heartbeat_data {
public:
  redisContext *con;
  const char * host;
  int port;
  const char * key;
  const char * key_signal;
  const char * value;
  int expire;
  int interval;
};

// This will hold both the allocated heartbeat data object and a
// shared flag that will be used to communicate between the processes.
class payload {
public:
  heartbeat_data *data;
  bool started;
  bool keep_going;
  bool stopped;
  bool orphaned;
};

heartbeat_data * heartbeat_data_alloc(const char *host, int port,
                                      const char *key, const char *value,
                                      const char *key_signal,
                                      int expire, int interval);
void heartbeat_data_free(heartbeat_data * obj);

void worker_create(payload *x);
bool worker_init(heartbeat_data *data);
void worker_cleanup(heartbeat_data *data);
void worker_loop(payload *x);
void worker_run_alive(heartbeat_data *data);
int worker_run_poll(heartbeat_data *data);

payload * controller_create(const char *host, int port,
                            const char *key, const char *value,
                            const char *key_signal, int expire, int interval);
bool controller_stop(payload *x, bool wait);

#endif
