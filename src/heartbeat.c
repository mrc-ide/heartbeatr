#include "heartbeat.h"

#ifndef __WIN32
#include <signal.h>
#include <unistd.h>
#endif

#include "util.h"

heartbeat_data * heartbeat_data_alloc(const char *host, int port,
                                      const char *password, int db,
                                      const char *key, const char *value,
                                      const char *key_signal,
                                      int expire, int interval) {
  heartbeat_data * ret = (heartbeat_data*) calloc(1, sizeof(heartbeat_data));
  if (ret == NULL) {
    // This is only the case when there is a failure in the allocator
    // allocating a single element (so probably not very common)
    return NULL; // # nocov
  }
  ret->host = string_duplicate(host);
  ret->port = port;
  if (strlen(password) == 0) {
    ret->password = NULL;
  } else {
    ret->password = string_duplicate(password);
  }
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
    free((void*) data->host);
    if (data->password != NULL) {
      free((void*) data->password);
    }
    free((void*) data->key);
    free((void*) data->value);
    free((void*) data->key_signal);
    free(data);
  }
}

redisContext * heartbeat_connect(const heartbeat_data * data,
                                 heartbeat_connection_status * status) {
  redisContext *con = redisConnect(data->host, data->port);
  if (con->err) {
    *status = FAILURE_CONNECT;
    // If running into trouble, it may be useful to print the error like so:
    //
    //   REprintf("Redis connection failure: %s", con->errstr);
    //
    // However, this will not end up in the actual error message and
    // may be hard to capture, suppress or work with.
    redisFree(con);
    return NULL;
  }
  if (data->password != NULL) {
    redisReply *reply = (redisReply*)
      redisCommand(con, "AUTH %s", data->password);
    bool error = reply == NULL || reply->type == REDIS_REPLY_ERROR;
    if (reply) {
      freeReplyObject(reply);
    }
    if (error) {
      *status = FAILURE_AUTH;
      redisFree(con);
      return NULL;
    }
  }
  if (data->db != 0) {
    redisReply *reply = (redisReply*) redisCommand(con, "SELECT %d", data->db);
    bool error = reply == NULL || reply->type == REDIS_REPLY_ERROR;
    if (reply) {
      *status = FAILURE_SELECT;
      freeReplyObject(reply);
    }
    if (error) {
      redisFree(con);
      return NULL;
    }
  }
  return con;
}

void worker_create(payload *x) {
  x->con = worker_init(x->data, &(x->status));
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
    free(x);
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

redisContext * worker_init(const heartbeat_data *data,
                           heartbeat_connection_status * status) {
  redisContext *con = heartbeat_connect(data, status);
  if (!con) {
    return NULL;
  }
  redisReply *reply = (redisReply*)
    redisCommand(con, "SET %s %s EX %d", data->key, data->value, data->expire);
  bool error = reply == NULL || reply->type == REDIS_REPLY_ERROR;
  if (reply) {
    freeReplyObject(reply);
  }
  if (error) {
    *status = FAILURE_SET;
    redisFree(con);
    return NULL;
  }
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
