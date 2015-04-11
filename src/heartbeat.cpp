#include <Rcpp.h>
#include <tthread/tinythread.h>
// Unfortunately this makes compilation on OSX really nasty for some
// reason, but we do need a proper Redis client really.
#include <hiredis/hiredis.h>

// I don't like using these globals, but this is something that only
// exists once...
bool global_heartbeat_status = false;
std::string global_heartbeat_key;

class heartbeat {
public:
  redisContext *con;
  std::string host;
  int port;
  std::string key;
  int timeout;
  int expire;
  std::vector<std::string> cmd_set;
  std::vector<std::string> cmd_alive;

  heartbeat(std::string host_, int port_, std::string key_,
            int timeout_, int expire_)
    : host(host_), port(port_), key(key_), timeout(timeout_), expire(expire_) {
    cmd_set.push_back("SET");
    cmd_set.push_back(key);
    cmd_set.push_back("OK");
    cmd_alive.push_back("EXPIRE");
    cmd_alive.push_back(key);
    cmd_alive.push_back(std::to_string(expire));
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
  void run(const std::vector<std::string>& cmd) {
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
    freeReplyObject(reply);
  }
  void set() {
    run(cmd_set);
  }
  void alive() {
    run(cmd_alive);
  }
private:
  // add the copy constructor here to make this non copyable.
  heartbeat(const heartbeat&);                 // Prevent copy-construction
  heartbeat& operator=(const heartbeat&);      // Prevent assignment
};

void redis_heartbeat_worker(void * data) {
  heartbeat *r = static_cast<heartbeat*>(data);
  const int timeout = r->timeout;

  // First, try and connect to the database
  r->connect();
  // Then try and set the key
  r->set();
  // Now we're good to go so set the globals
  global_heartbeat_status = true;
  global_heartbeat_key    = r->key;

  // Round and round we go
  do {
    r->alive();
    tthread::this_thread::sleep_for(tthread::chrono::seconds(timeout));
  } while (global_heartbeat_status);

  r->disconnect();
  delete r;
}

// R interface:
// [[Rcpp::export]]
void heartbeat_start(std::string host, int port,
                      std::string key, int timeout, int expire) {
  heartbeat * data = new heartbeat(host, port, key, timeout, expire);
  tthread::thread t(redis_heartbeat_worker, data);
  t.detach();
}
// [[Rcpp::export]]
void heartbeat_stop() {
  // TODO: should we delete the key here perhaps?
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
