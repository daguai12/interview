## Acceptor模块作用
**Acceptor**的作用：
- 创建、配置监听套接字
- 将监听套接字绑定到事件循环（EventLoop）里
- 接收新连接事件
- 并在新连接到来时，通过回调通知 TcpServer

它只负责监听和接收新连接，不负责数据读写，读写是 TcpConnection 干的。

## Acceptor类成员变量详解

```c++
private:
EventLoop *loop_; //Accept用的就是用户自定义的呢个baseLoop, 也称作mainLoop
Socket acceptSocket_;
Channel acceptChannel_;
NewConnectionCallback newConnectionCallback_;
bool listenning_;
```

- `loop_` Acceptor所依附的 EventLoop(mainLoop/baseLoop)
- `acceptSocket_` 封装监听 socket 的类
- `acceptChannel_` 封装监听 socket 的Channel，监控可读事件
- `newConnectionCallback_` 新连接到来时通知 `TcpServer` 的回调
- `listening_` 标志是否监听

## Acceptor类成员函数

### 构造函数

```c++
Acceptor(EventLoop *loop, const InetAddress &listenAddr, bool reuseport);
```

- `loop` Acceptor关联的EventLoop(baseLoop)
- `listenAddr` 服务器监听的IP端口
- `reuseport` 是否开启 `SO_REUSEPORT` `SO_REUSEADDR`

函数执行过程：
- 创建 acceptSocket_ (`socket()`)
- 设置 SO_REUSEADDR 和 SO_REUSEPORT (`setsocketopt()`)
- bind 到 listenAddr (`bind()`)
- 创建 acceptChannel_，监听 acceptSocket_ 的读事件 (`accept()`)
- 设置 handleRead() 作为新连接到来时的回调 

### setNewConnectionCallback
```c++
void setNewConnectionCallback(const NewConnectionCallback &cb)
```

- 让`TcpServer`给`Acceptor`安装一个新连接回调
- 当有新连接时，Acceptor 就用这个回调通知`TcpServer`

### listen
```cpp
void listen();
```
- 调用`acceptSocket_.listen()`
- 设置`listenning_=true`
- 把`acceptChannel_`加入`Poller`，关注可读事件
当有新连接时，Poller会通知Channel，调用`handleRead()`

### handleRead()
```cpp
void handleRead();
```

- 当监听套接字可读（说明有新连接）时被调用
- 调用`acceptSocket_.accept()`得到客户端连接的 fd 和地址
- 然后执行`newConnectionCallback_`，把新连接交给`TcpServer`

## Acceptor在服务器启动流程中的作用
1️⃣ TcpServer 创建 Acceptor  
2️⃣ 调用 `Acceptor::listen()`，Poller 开始监听监听套接字的读事件  
3️⃣ 客户端连接到来，Poller 检测到监听 fd 可读，通知 `acceptChannel_`  
4️⃣ `acceptChannel_` 调用 `Acceptor::handleRead()`  
5️⃣ `handleRead()` 调用 `accept()`，获得新连接 fd 和客户端地址  
6️⃣ 调用 `newConnectionCallback_`，交给 `TcpServer` 创建 `TcpConnection`