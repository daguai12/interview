# `bind()`
### 🔧 函数声明

```cpp
bool TcpServer::bind(const std::vector<Address::ptr>& addrs,
                     std::vector<Address::ptr>& fails,
                     bool ssl)
```

#### ✅ 参数含义：

* `addrs`：传入的多个监听地址（可能监听多个端口/IP），是 `Address` 类的智能指针。
* `fails`：引用传出参数，用于收集绑定失败的地址。
* `ssl`：是否使用 SSL，即是否创建加密连接。

#### ✅ 返回值：

* `true` 表示所有地址绑定并监听成功；
* `false` 表示至少有一个地址绑定或监听失败。

---

## 🔍 函数实现分析

---

### Step 1：保存 `ssl` 标志位

```cpp
m_ssl = ssl;
```

* 将传入的 `ssl` 参数保存为成员变量 `m_ssl`，供后续使用（例如创建 Socket、打印日志、条件分支等）。

---

### Step 2：遍历每个地址并尝试绑定监听

```cpp
for(auto& addr : addrs) {
```

遍历用户传入的每一个地址 `addr`，尝试执行绑定监听流程。

---

#### Step 2.1：根据是否使用 SSL 创建 TCP Socket

```cpp
Socket::ptr sock = ssl ? SSLSocket::CreateTCP(addr) : Socket::CreateTCP(addr);
```

* 如果启用了 `ssl`，调用 `SSLSocket::CreateTCP()` 创建一个支持 SSL 的 TCP Socket；
* 否则调用普通的 `Socket::CreateTCP()`。
* 创建的 socket 对象是智能指针 `Socket::ptr` 类型（包含 RAII 自动管理资源销毁）。

---

#### Step 2.2：尝试绑定该地址

```cpp
if(!sock->bind(addr)) {
```

* 使用该 socket 绑定地址（即调用系统 `bind` 函数）。
* 如果绑定失败：

```cpp
SYLAR_LOG_ERROR(g_logger) << "bind fail errno="
    << errno << " errstr=" << strerror(errno)
    << " addr=[" << addr->toString() << "]";
fails.push_back(addr);
continue;
```

* 打日志（包括失败原因和地址）；
* 把失败地址加入 `fails` 列表；
* 跳过当前 socket，不再尝试 listen，继续下一地址。

---

#### Step 2.3：如果绑定成功，尝试监听

```cpp
if(!sock->listen()) {
```

* 调用系统 `listen` 函数让 socket 开始监听客户端连接。
* 如果失败：

```cpp
SYLAR_LOG_ERROR(g_logger) << "listen fail errno="
    << errno << " errstr=" << strerror(errno)
    << " addr=[" << addr->toString() << "]";
fails.push_back(addr);
continue;
```

* 同样记录日志；
* 把失败地址加入 `fails`；
* 跳过此 socket。

---

#### Step 2.4：成功绑定并监听，将 socket 加入 `m_socks`

```cpp
m_socks.push_back(sock);
```

* 将成功绑定监听的 socket 存入成员变量 `m_socks`（用于后续接收连接）。

---

### Step 3：检查是否存在失败绑定

```cpp
if(!fails.empty()) {
    m_socks.clear();
    return false;
}
```

* 如果 `fails` 不为空，说明至少有一个地址绑定或监听失败；
* 清空已成功绑定的 `m_socks`（防止部分绑定成功产生混乱）；
* 返回 `false` 表示整体绑定失败。

---

### Step 4：打印成功日志

```cpp
for(auto& i : m_socks) {
    SYLAR_LOG_INFO(g_logger) << "type=" << m_type
        << " name=" << m_name
        << " ssl=" << m_ssl
        << " server bind success: " << *i;
}
```

* 遍历成功绑定的所有 socket；
* 打印服务器类型、名称、是否使用 SSL、绑定 socket 信息（重载了 `operator<<`）。

---

### Step 5：返回成功

```cpp
return true;
```

* 如果全部地址都绑定成功，函数返回 `true`。

---

## 📌 总结要点

| 关键点    | 说明                                             |
| ------ | ---------------------------------------------- |
| 支持多个地址 | 可以绑定多个地址/端口（如 `0.0.0.0:80`, `127.0.0.1:8080`）。 |
| SSL 支持 | 支持 SSL 加密监听，通过参数 `ssl` 决定。                     |
| 错误收集   | 所有绑定失败的地址会被加入 `fails`，可供调用者回溯失败原因。             |
| 安全回滚   | 一旦有失败地址，清除全部成功绑定，防止部分绑定带来的异常。                  |
| 异常日志   | 错误场景下会打印详细日志，包括 `errno` 和地址字符串，便于定位问题。         |

# `startAccept()`

当然，我们继续以**逐行逐句、详细分析**的方式解释 `TcpServer::startAccept()` 函数的实现。

这个函数是 Sylar 框架中 `TcpServer` 类的成员函数，其主要作用是：

> 在某个已经监听的 socket 上循环等待客户端连接请求，并为每个连接创建新的 socket，并把客户端连接的处理逻辑交给 IO 协程调度器去执行。

---

### 函数定义

```cpp
void TcpServer::startAccept(Socket::ptr sock) {
```

* 这是一个 `TcpServer` 类的成员函数。
* 参数是一个 `Socket::ptr`（智能指针），表示监听 socket。
* 这个函数不会返回，除非服务器被标记为停止（`m_isStop == true`）。

---

### 主体逻辑：循环等待客户端连接

```cpp
    while(!m_isStop) {
```

* 这是一个无限循环，只要服务器**未被停止**（`m_isStop == false`），就会不断执行。
* `m_isStop` 是 `TcpServer` 的成员变量，标志是否要终止服务器。

---

### 接收客户端连接

```cpp
        Socket::ptr client = sock->accept();
```

* 调用监听 socket 的 `accept()` 方法来**接受一个客户端连接**。
* 如果有客户端连接上来，这里就会返回一个新的 socket（`client`）。
* 如果失败（例如监听 socket 关闭或系统出错），会返回 `nullptr`。

---

### 判断连接是否成功

```cpp
        if(client) {
```

* 如果连接成功，就进入处理分支。
* 否则输出错误信息。

---

### 设置客户端 socket 的接收超时时间

```cpp
            client->setRecvTimeout(m_recvTimeout);
```

* 为新连接设置接收超时时间。
* `m_recvTimeout` 是服务器的成员变量（整型，单位可能是毫秒），用于控制 socket 在接收数据时的超时时间。
* 这样做是为了防止客户端长期不发送数据导致服务端卡死。

---

### 调度客户端处理逻辑

```cpp
            m_ioWorker->schedule(std::bind(&TcpServer::handleClient,
                        shared_from_this(), client));
```

* `m_ioWorker` 是一个协程调度器（通常是 `IOManager` 类型），负责处理 socket 的读写事件。
* 这里使用 `schedule()` 将处理客户端的逻辑函数**放入调度器任务队列中**，由后台 IO 协程线程去处理。

#### 解释 `std::bind(&TcpServer::handleClient, shared_from_this(), client)`

* `&TcpServer::handleClient`：是 `TcpServer` 类的成员函数指针，表示处理客户端连接的函数。
* `shared_from_this()`：`TcpServer` 继承了 `std::enable_shared_from_this`，可以安全获取自身的智能指针。
* `client`：传递新连接的 socket 给 `handleClient()`。
* 整体意思是把 “当前这个 `TcpServer` 实例去处理这个客户端连接” 封装成任务，提交给 IO 调度器。

---

### 接收失败处理

```cpp
        } else {
            SYLAR_LOG_ERROR(g_logger) << "accept errno=" << errno
                << " errstr=" << strerror(errno);
        }
```

* 如果 `accept()` 返回失败，会记录错误日志。
* `errno`：系统错误码。
* `strerror(errno)`：将错误码转换为可读字符串，例如 “Connection reset”。

---

### 总结

这个函数的完整流程如下：

1. 不断在监听 socket 上等待客户端连接（使用 `accept()`）。
2. 每当成功接收到客户端连接：

   * 为其设置超时；
   * 将连接的处理逻辑封装为任务，交给 `IOManager` 去异步调度执行；
3. 如果接收失败，记录错误日志。


# `start()`


## 🔧 函数声明与作用

```cpp
bool TcpServer::start()
```

* 这是 `TcpServer` 类的成员函数，用于启动 TCP 服务器。
* 它的任务是：**启动所有监听 socket 的 accept 逻辑**，即监听客户端连接并开始接收。
* 返回值是 `bool`，表示是否启动成功。

---

## ✅ 第一步：判断服务器是否已启动

```cpp
    if(!m_isStop) {
        return true;
    }
```

* `m_isStop` 是 `TcpServer` 的成员变量，类型是 `bool`，用于标记服务器当前是否是“停止状态”。
* 如果 `m_isStop == false`，说明服务器已经在运行，此时无需重复启动，直接 `return true;` 表示“启动成功”（虽然其实什么都没做）。
* 否则才会继续执行后续的启动流程。

---

## ✅ 第二步：标记为“运行中”

```cpp
    m_isStop = false;
```

* 将 `m_isStop` 设置为 `false`，表示服务器**从“停止”状态切换为“运行”状态**。

---

## ✅ 第三步：调度每个监听 socket 的 `startAccept` 操作

```cpp
    for(auto& sock : m_socks) {
```

* `m_socks` 是 `TcpServer` 的成员变量，类型是 `std::vector<Socket::ptr>`，表示当前服务器的**所有监听 socket 列表**。
* 这是因为支持绑定多个 IP 地址或端口，例如同时监听 `127.0.0.1:8080` 和 `192.168.1.1:8080`。
* 使用 `range-based for` 遍历所有监听 socket。

---

```cpp
        m_acceptWorker->schedule(std::bind(&TcpServer::startAccept,
                    shared_from_this(), sock));
```

* `m_acceptWorker` 是一个 `IOManager::ptr`，表示**接收连接的调度器线程池**。
* 通过 `schedule()` 向 `m_acceptWorker` 提交任务：对每个 socket 启动 `startAccept()`。

#### 🧠 std::bind 的作用：

```cpp
std::bind(&TcpServer::startAccept, shared_from_this(), sock)
```

等价于：

```cpp
[this, sock]() {
    this->startAccept(sock);
}
```

也就是说，它生成一个可调用对象，绑定了当前服务器对象（`shared_from_this()`）和对应 socket，形成一个任务体，用于后续调度。

这样做的好处是：

* 不会阻塞当前线程；
* 让 `startAccept()` 在线程池中异步执行；
* 每个 socket 的 accept 逻辑独立运行在不同协程或线程中。

---

## ✅ 第四步：返回 true 表示成功

```cpp
    return true;
```

无论是单 socket 还是多 socket，都返回 `true`，表示服务器已经开始监听连接。

---

## 🔁 总结流程

```cpp
if already running:
    return true;

set running state;
for each listening socket:
    schedule startAccept on acceptWorker;
return true;
```

换句话说：

1. 如果服务器已经在运行，什么都不做。
2. 否则，切换为运行状态。
3. 遍历所有监听的 socket，为每一个 socket 在 `m_acceptWorker` 上调度一个 `startAccept()` 协程或线程。
4. 返回启动成功。

---

## 🔍 延伸说明：为什么使用调度器？

* `startAccept()` 是一个**阻塞等待客户端连接**的逻辑（调用 `accept()`），需要放在线程池或协程中执行；
* 这就是 `m_acceptWorker->schedule()` 的作用 —— **非阻塞主线程**，并充分利用异步模型。



