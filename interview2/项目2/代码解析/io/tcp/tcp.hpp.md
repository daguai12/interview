下面把这个 `tcp.hpp` 逐块讲清楚：它提供了三类**面向协程的 TCP 封装**，把底层的 `io_awaiters`（`tcp_read_awaiter / tcp_write_awaiter / tcp_accept_awaiter / tcp_connect_awaiter / tcp_close_awaiter`）打包成更易用的对象接口，并且可选地启用 **io\_uring 注册文件（fixed files）** 来加速 I/O。

---

## 总览：三类对象的职责

* **`tcp_connector`**：对**已建立连接**的套接字提供 `read / write / close` 的协程友好接口。它在可用时自动把套接字注册为 **fixed fd**，使后续读写走 `IOSQE_FIXED_FILE`（减少 fd 查找开销）。
* **`tcp_server`**：包装监听 socket 的创建与 `accept()`。同样可把监听 fd 注册为 **fixed fd**，让 `accept` 使用 `IOSQE_FIXED_FILE`。
* **`tcp_client`**：包装客户端 socket 的建立与 `connect()` 的 awaiter 构造。

这三者都只是**轻量封装**，真正的异步提交/恢复由你之前的 awaiter + engine/context/scheduler 驱动。

---

## 共同背景：fixed fd 与 `m_sqe_flag`

* 通过 `detail::fixed_fds m_fixed_fd`，对象会在构造时尝试**借用注册文件槽位**（若池紧张借不到，则自动降级为普通 fd，不影响功能）。
* 借到后调用 `m_fixed_fd.assign(fd, m_sqe_flag)`：

  * 把真实 fd 写入注册表镜像；
  * 用注册表**索引**替换用户态 fd；
  * 在 `m_sqe_flag` 里 OR 上 `IOSQE_FIXED_FILE`；
  * 之后调用 awaiter 构造时，传入 `m_sqe_flag` 给 `io_uring_sqe_set_flags`，使本次 I/O 使用注册文件。
* 需要注意：**`close()` 必须使用“真实 fd”**，所以在 `tcp_connector` 里保留了 `m_original_fd` 专门给 close 用。

---

## 逐类详解

### 1) `tcp_connector`（面向已连接套接字）

```cpp
class tcp_connector
{
public:
    explicit tcp_connector(int sockfd) noexcept : m_sockfd(sockfd), m_original_fd(sockfd), m_sqe_flag(0)
    {
        m_fixed_fd.assign(m_sockfd, m_sqe_flag);
    }

    tcp_read_awaiter read(char* buf, size_t len, int io_flags = 0) noexcept
    {
        return tcp_read_awaiter(m_sockfd, buf, len, io_flags, m_sqe_flag);
    }

    tcp_write_awaiter write(char* buf, size_t len, int io_flags = 0) noexcept
    {
        return tcp_write_awaiter(m_sockfd, buf, len, io_flags, m_sqe_flag);
    }

    // close() must use original sock fd
    tcp_close_awaiter close() noexcept
    {
        m_fixed_fd.return_back();
        return tcp_close_awaiter(m_original_fd);
    }

private:
    int       m_sockfd;      // 提交给 io_uring 的“fd”：可能是注册索引
    const int m_original_fd; // 原始 fd，供 close 使用
    detail::fixed_fds m_fixed_fd;
    int               m_sqe_flag;
};
```

#### 关键点

* 构造：

  * `m_sockfd` 与 `m_original_fd` 都先设为传入的真实 fd。
  * `assign` 成功后：`m_sockfd` 会被改写成**注册索引**，`m_sqe_flag` 会带上 `IOSQE_FIXED_FILE`。
* `read / write`：

  * 直接返回对应 awaiter；把 `m_sockfd`（可能是索引）与 `m_sqe_flag` 传给 awaiter。
  * `io_flags` 会作为 `recv/send` 的 flags（如 `MSG_DONTWAIT` 等）。
* `close()`：

  * **先** `m_fixed_fd.return_back()` 归还注册槽位（防止正在使用的索引泄漏到后续他人），
  * **再** 用 `m_original_fd` 构造 `tcp_close_awaiter`。
* 生命周期与安全：

  * `fixed_fds` 是成员，确保在对象销毁或 `close()` 前不会释放槽位（RAII）；
  * 若在某些场景中 `read/write` 未完成就 `close`，需要由上层保证顺序（一般是先等待 I/O 完成或取消）。

#### 语义一致性

* 你的 IO awaiter 约定：

  * `read/write` 的 `await_resume()` 返回 `nbytes` 或负的 `-errno`；
  * `close` 返回 0 或负的 `-errno`。
* 这与 `tcp_connector` 的包装是对齐的。

---

### 2) `tcp_server`（监听与 accept）

```cpp
class tcp_server
{
public:
    explicit tcp_server(int port = ::coro::config::kDefaultPort) noexcept : tcp_server(nullptr, port) {}

    tcp_server(const char* addr, int port) noexcept;

    tcp_accept_awaiter accept(int io_flags = 0) noexcept;

private:
    int         m_listenfd;
    int         m_port;
    sockaddr_in m_servaddr;

    detail::fixed_fds m_fixed_fd;
    int               m_sqe_flag{0};
};
```

#### 预期职责（结合 cpp 实现常规套路）

* **构造**（`addr, port`）：

  * 创建 socket：`socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0)`；
  * `setsockopt`（`SO_REUSEADDR`/`SO_REUSEPORT` 可选）；
  * `bind` 到 `addr:port`（若 `addr == nullptr`，常用 `INADDR_ANY`）；
  * `listen`；
  * `m_fixed_fd.assign(m_listenfd, m_sqe_flag)` 尝试注册为 fixed fd。
* **accept**：

  * 返回 `tcp_accept_awaiter(m_listenfd, io_flags, m_sqe_flag)`；
  * 若启用 fixed files，则 `io_uring` 会使用索引 + `IOSQE_FIXED_FILE` 的方式做 accept。
  * **注意**：`accept` 产生的新连接 fd 是**新 fd**，不受监听 fd 的 fixed 注册影响；你可以把新 fd 封进 `tcp_connector`，让它对新 fd 再做一次 `assign`（这通常发生在 `accept` 之后，业务代码处）。

#### 注意点

* `accept` 的 awaiter 在之前我们讨论过：不要用共享静态的 `socklen_t`，建议 awaiter 内部有自己的 `sockaddr_storage`/`socklen_t` 成员（以避免并发竞态）。
* `tcp_server` 的 `close` 未在此类里出现：如果需要关闭监听 fd，可仿照 `tcp_connector::close()`（先 `return_back()` 再 close）。

---

### 3) `tcp_client`（主动连接）

```cpp
class tcp_client
{
public:
    tcp_client(const char* addr, int port) noexcept;

    tcp_connect_awaiter connect() noexcept;

private:
    int         m_clientfd;
    int         m_port;
    sockaddr_in m_servaddr;
};
```

#### 预期职责

* **构造**：

  * 创建 socket（一般 `AF_INET, SOCK_STREAM | SOCK_NONBLOCK`）；
  * 填 `m_servaddr`（`sin_family/addr/port`）；保存 `m_clientfd/m_port`。
* **connect**：

  * 直接返回 `tcp_connect_awaiter(m_clientfd, reinterpret_cast<sockaddr*>(&m_servaddr), sizeof(m_servaddr))`。
  * 这里**没有自动做 fixed fd 注册**（从你给的头文件看不到 `fixed_fds` 的成员），如果你也想把 connect 走 fixed files，可以像 `tcp_connector` 一样加入 `fixed_fds` 并在构造或 `connect()` 前 `assign`。

#### 返回语义（参考你之前 awaiter 的实现）

* 你的 `tcp_connect_awaiter::callback`：

  * 若 `res != 0`，即失败，`result = res`（负错误码）；
  * 否则成功，把 `result = sockfd`（注意：与你的其它 awaiter返回 bytes/0 的风格不同）。
* 建议在文档中说明：**connect awaiter 成功时返回的是连接的 fd**。业务端可直接把这个 fd 交给 `tcp_connector` 来做后续 `read/write/close`。

---

## 典型用法示例

### 服务器（accept → per-connection echo）

```cpp
using namespace coro;
using namespace coro::io::net::tcp;

task<void> handle_conn(int cfd) {
    tcp_connector c{cfd};
    char buf[4096];

    for (;;) {
        int n = co_await c.read(buf, sizeof(buf));
        if (n <= 0) break;                 // 0=对端关闭; <0=错误
        int m = co_await c.write(buf, n);  // 可能需要循环写，这里简化
        if (m < 0) break;
    }

    co_await c.close();
    co_return;
}

task<void> server_main() {
    tcp_server s{/*addr=*/nullptr, /*port=*/8080};

    for (;;) {
        int cfd = co_await s.accept();     // 返回的是新连接 fd（或负错误）
        if (cfd < 0) continue;
        submit_to_scheduler(handle_conn(cfd));  // 交给调度器并发处理
    }
}

int main() {
    scheduler::init();
    scheduler::submit(server_main());
    scheduler::loop();
}
```

### 客户端（connect → write → read → close）

```cpp
using namespace coro;
using namespace coro::io::net::tcp;

task<void> client_main() {
    tcp_client cli{"127.0.0.1", 8080};
    int cfd = co_await cli.connect();      // 成功时返回 fd
    if (cfd < 0) co_return;

    tcp_connector c{cfd};
    const char* msg = "hello";
    int w = co_await c.write((char*)msg, std::strlen(msg));
    if (w >= 0) {
        char buf[128];
        int r = co_await c.read(buf, sizeof(buf));
        // 处理 r
    }
    co_await c.close();
}

int main() {
    scheduler::init();
    scheduler::submit(client_main());
    scheduler::loop();
}
```

---

## 设计优点与注意事项

**优点**

* 提供面向对象的“连接/服务器/客户端”三件套，语义直观；
* 与 awaiter 无缝拼接，`co_await` 使用简单；
* 在可能时自动使用 **fixed files** 优化 I/O 提交路径；
* `tcp_connector` 中把“提交用 fd（可能是索引）”与“真实 fd（用于 close）”拆开，避免踩坑。

**注意**

* `read/write` 的 `buf` 必须在 I/O 完成前保持有效（通常协程 frame 可保证）；
* `tcp_connector::close()` 前应确保没有在飞的 I/O（或允许 I/O 完成返回错误后再 close），业务上自行约束顺序；
* `tcp_client` 当前未使用 fixed files，如果需要可以对齐 `tcp_connector` 的方式加上；
* 确保 `tcp_accept_awaiter` 不使用共享的 `socklen_t` 静态变量（并发安全问题），在 awaiter 内做 per-instance 存储更稳妥。

---

## 小的改进建议（可选）

1. 给 `tcp_client` 增加 `fixed_fds` 支持（在 `connect()` 前 `assign`），与 `tcp_connector`/`tcp_server` 一致。
2. 在注释里**明确各 awaiter 的返回值语义**（尤其 `connect` 成功返回 fd 这点）。
3. 为 `fixed_fds` 明确禁用拷贝、允许移动，避免意外复制导致重复归还。
4. （若高并发）`tcp_server` 提供 `close()`（与 `tcp_connector` 风格相同），确保释放注册槽与监听 fd。

---

这样，这个 `tcp.hpp` 的设计目的、行为与使用方式就比较清楚了。需要我给 `tcp_client` 加上 fixed fd 的补丁版本吗？或者把 `tcp_accept_awaiter` 的静态 `len` 改成实例字段的安全实现也一并给你。
