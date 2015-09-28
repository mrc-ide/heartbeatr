#include <Rcpp.h>
#include <tthread/tinythread.h>
// Unfortunately this makes compilation on OSX really nasty for some
// reason, but we do need a proper Redis client really.
#include <hiredis/hiredis.h>

std::string heartbeat_signal_key(std::string key);
// This would be better done with C++11 std::to_string()
template<typename T>
std::string to_string(T x) {
  std::ostringstream o;
  if (!(o << x)) {
    Rcpp::stop("String conversion failure");
  }
  return o.str();
}

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
  int period;
  int expire;
  std::vector<std::string> cmd_set;
  std::vector<std::string> cmd_alive;
  std::vector<std::string> cmd_del;
  std::vector<std::string> cmd_blpop;

  heartbeat(std::string host_, int port_,
            std::string key_, std::string value_,
            int period_, int expire_)
    : host(host_), port(port_),
      key(key_), key_signal(heartbeat_signal_key(key)),
      period(period_), expire(expire_) {
    cmd_set.push_back("SET");
    cmd_set.push_back(key_);
    cmd_set.push_back(value_);
    cmd_alive.push_back("EXPIRE");
    cmd_alive.push_back(key);
    cmd_alive.push_back(to_string(expire));
    cmd_del.push_back("DEL");
    cmd_del.push_back(key_);
    cmd_blpop.push_back("BLPOP");
    cmd_blpop.push_back(key_signal);
    cmd_blpop.push_back(to_string(period));
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
  int run_redis(const std::vector<std::string>& cmd) {
    int ret = 0;
    // TODO: cache all this stuff at the beginning I think; it doesn't
    // change.
    std::vector<const char*> cmdv(cmd.size());
    std::vector<size_t> cmdlen(cmd.size());
    for (size_t i=0; i < cmd.size(); ++i) {
      cmdv[i]   = cmd[i].c_str();
      cmdlen[i] = cmd[i].size();
    }
    redisReply *reply = static_cast<redisReply*>
      (redisCommandArgv(con, cmd.size(), &(cmdv[0]), &(cmdlen[0])));
    if (reply->type == REDIS_REPLY_ARRAY && reply->elements == 2) { // blpop
      ret = atoi(reply->element[1]->str);
    }
    freeReplyObject(reply);
    return ret;
  }
  void set() {
    run_redis(cmd_set);
  }
  void alive() {
    run_redis(cmd_alive);
  }
  void del() {
    run_redis(cmd_del);
  }
  int blpop() {
    return run_redis(cmd_blpop);
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
