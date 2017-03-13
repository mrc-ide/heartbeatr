#include "redisheartbeat.h"

#include <thread>
#include <chrono>
#include <cstdlib>

#ifndef __WIN32
#include <csignal>
#endif

#include "util.h"

heartbeat_data * heartbeat_data_alloc(const char *host, int port,
                                      const char *pass, int db,
                                      const char *key, const char *value,
                                      const char *key_signal,
                                      int expire, int interval) {
  heartbeat_data * ret = new heartbeat_data;
  if (ret == NULL) {
    return NULL;
  }
  ret->host = string_duplicate(host);
  ret->port = port;
  ret->pass = string_duplicate(pass);
  ret->db = db;
  ret->key = string_duplicate(key);
  ret->value = string_duplicate(value);
  ret->key_signal = string_duplicate(key_signal);
  ret->expire = expire;
  ret->interval = interval;
  return ret;
}

void heartbeat_data_free(heartbeat_data * data) {
  if (data) {
    std::free((void*) data->host);
    std::free((void*) data->pass);
    std::free((void*) data->key);
    std::free((void*) data->value);
    std::free((void*) data->key_signal);
    std::free(data);
  }
}

payload * controller_create(heartbeat_data *data) {
  payload * x = new payload;
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
      delete x;
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
          delete x;
          return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(every));
      }
    }
  }
  return false;
}

void worker_create(payload *x) {
  x->con = worker_init(x->data);
  x->started = x->con != NULL;
  if (!x->started) {
    x->keep_going = false;
    heartbeat_data_free(x->data);
    x->data = NULL;
    return;
  }
  worker_loop(x);
  worker_cleanup(x->con, x->data);
  heartbeat_data_free(x->data);
  x->data = NULL;
  x->stopped = true;
  if (x->orphaned) {
    delete x;
  }
}

void worker_loop(payload *x) {
  while (x->keep_going) {
    worker_run_alive(x->con, x->data);
    int signal = worker_run_poll(x->con, x->data);
    if (signal > 0) {
#ifndef __WIN32
      kill(getpid(), signal);
#endif
    }
  }
}

redisContext * worker_init(const heartbeat_data *data) {
  redisContext *con = redisConnect(data->host, data->port);
  if (con->err) {
    redisFree(con);
    return NULL;
  }
  redisReply *reply = (redisReply*)
    redisCommand(con, "SET %s %s", data->key, data->value);
  if (!reply) {
    redisFree(con);
    return NULL;
  }
  freeReplyObject(reply);
  return con;
}

void worker_cleanup(redisContext *con, const heartbeat_data *data) {
  redisReply *reply = (redisReply*)
    redisCommand(con, "DEL %s", data->key);
  if (reply) {
    freeReplyObject(reply);
  }
}

void worker_run_alive(redisContext *con, const heartbeat_data * data) {
  redisReply *reply = (redisReply*)
    redisCommand(con, "EXPIRE %s %d", data->key, data->expire);
  if (reply) {
    freeReplyObject(reply);
  }
}

int worker_run_poll(redisContext *con, const heartbeat_data * data) {
  redisReply *reply = (redisReply*)
    redisCommand(con, "BLPOP %s %d", data->key_signal, data->interval);
  int ret = 0;
  if (reply &&
      reply->type == REDIS_REPLY_ARRAY &&
      reply->elements == 2) {
    ret = atoi(reply->element[1]->str);
  }
  if (reply) {
    freeReplyObject(reply);
  }
  return ret;
}
