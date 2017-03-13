#include "heartbeat.h"

#ifndef __WIN32
#include <signal.h>
#include <unistd.h>
#endif

#include "util.h"

heartbeat_data * heartbeat_data_alloc(const char *host, int port,
                                      const char *pass, int db,
                                      const char *key, const char *value,
                                      const char *key_signal,
                                      int expire, int interval) {
  heartbeat_data * ret = (heartbeat_data*) calloc(1, sizeof(heartbeat_data));
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
    free((void*) data->host);
    free((void*) data->pass);
    free((void*) data->key);
    free((void*) data->value);
    free((void*) data->key_signal);
    free(data);
  }
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
