#include <Rcpp.h>
#include <tthread/tinythread.h>
// Unfortunately this makes compilation on OSX really nasty for some
// reason, but we do need a proper Redis client really.
#include <hiredis/hiredis.h>

std::string heartbeat_signal_key(std::string key);

// I don't like using these globals, but this is something that only
// exists once...
//
// TODO: I think I can move to C++11 lambdas nicely here; it would be
// useful to be able to easily associate heartbeats with different
// things, even though R is single threaded - they can advertise
// object lifetimes which is kind of cool.
//
// Another option is a global hash by key?
//   Create a heartbeat and set the hash
//   turn it off by setting the hash to false
bool global_heartbeat_status = false;
std::string global_heartbeat_key;

class heartbeat {
public:
  redisContext *con;
  std::string host;
  int port;
  std::string key;
  std::string key_signal;
  std::string value;
  int period;
  int expire;

  heartbeat(std::string host_, int port_,
            std::string key_, std::string value_,
            int period_, int expire_)
    : host(host_), port(port_),
      key(key_), key_signal(heartbeat_signal_key(key)), value(value_),
      period(period_), expire(expire_) {
  }
  ~heartbeat() {
    if (con != NULL) {
      disconnect();
    }
  }
  void connect() {
    con = redisConnect(host.c_str(), port);
    if (con->err) {
      Rcpp::stop(std::string("Redis connection error: ") +
                 std::string(con->errstr));
    }
  }
  void disconnect() {
    redisFree(con);
    con = NULL;
  }
  void set() {
    redisReply *reply = static_cast<redisReply*>
      (redisCommand(con, "SET %s %s", key.c_str(), value.c_str()));
    freeReplyObject(reply);
  }
  void alive() {
    redisReply *reply = static_cast<redisReply*>
      (redisCommand(con, "EXPIRE %s %d", key.c_str(), expire));
    freeReplyObject(reply);
  }
  void del() {
    redisReply *reply = static_cast<redisReply*>
      (redisCommand(con, "DEL %s", key.c_str()));
    freeReplyObject(reply);
  }
  int blpop() {
    redisReply *reply = static_cast<redisReply*>
      (redisCommand(con, "BLPOP %s %d", key_signal.c_str(), period));
    int ret = 0;
    if (reply && // avoid connection error
        reply->type == REDIS_REPLY_ARRAY &&
        reply->elements == 2) {
      ret = atoi(reply->element[1]->str);
    }
    freeReplyObject(reply);
    return ret;
  }
private:
  // add the copy constructor here to make this non copyable.
  heartbeat(const heartbeat&);                 // Prevent copy-construction
  heartbeat& operator=(const heartbeat&);      // Prevent assignment
};

// This is working on a thread so there's no access to R API things.
void redis_heartbeat_worker(void * data) {
  heartbeat *r = static_cast<heartbeat*>(data);
  const int period = r->period;

  // First, try and connect to the database
  r->connect();
  // Then try and set the key
  r->set();

  if (period > 0) {
    // Now we're good to go so set the globals
    global_heartbeat_status = true;
    global_heartbeat_key    = r->key;

    // Round and round we go
    do {
      r->alive();
      // tthread::this_thread::sleep_for(tthread::chrono::seconds(period));
      int signal = r->blpop();
      if (signal > 0) {
        char *name = strsignal(signal);
        REprintf("Heartbeat sending signal %s\n", name);
        kill(getpid(), signal);
      }
    } while (global_heartbeat_status);
    r->del();
  }

  r->disconnect();
  delete r;
}

// R interface:
// [[Rcpp::export]]
void heartbeat_start(std::string host, int port,
                     std::string key, std::string value,
                     int period, int expire) {
  heartbeat * data = new heartbeat(host, port, key, value, period, expire);
  tthread::thread t(redis_heartbeat_worker, data);
  t.detach();
}
// [[Rcpp::export]]
void heartbeat_stop() {
  global_heartbeat_status = false;
}
// [[Rcpp::export]]
bool heartbeat_status() {
  return global_heartbeat_status;
}
// [[Rcpp::export]]
std::string heartbeat_key() {
  return global_heartbeat_key;
}
// [[Rcpp::export]]
std::string heartbeat_signal_key(std::string key) {
  return key + ":signal";
}

// [[Rcpp::export]]
void heartbeat_cleanup(std::string host, int port, std::string key) {
  heartbeat data(host, port, key, "", 0, 0);
  data.connect();
  data.del();
  data.disconnect();
}
