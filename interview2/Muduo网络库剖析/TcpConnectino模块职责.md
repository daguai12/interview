
## TcpConnection成员变量
```c++
EventLoop *loop_; //这里绝对不是baseLoop, 因为TcpConnection都是在subLoop里面管理的
const std::string name_;
std::atomic_int state_;
bool reading_;

std::unique_ptr<Socket> socket_;
std::unique_ptr<Channel> channel_;

const InetAddress localAddr_;
const InetAddress peerAddr_;

ConnectionCallback connectionCallback_;
MessageCallback messageCallback_;
WriteCompleteCallback writeCompleteCallback_;
HighWaterMarkCallback highWaterMarkCallback_;
CloseCallback closeCallback_;

size_t highWaterMark_;

Buffer inputBuffer_; // 接受数据的缓冲区
Buffer outputBuffer_; // 发送数据的缓冲区
```

- `loop_` 所属的EventLoop(subLoop)指针，这条连接的所有IO和事件处理都交给这个EventLoop管理，保证IO安全所有IO操作都必须在这个loop的线程中执行。
- `socket_` 封装这条连接的`socket fd`
- `Channel` 封装监听这条连接的 Channel,负责把IO事件（读、写、异常、关闭）注册到Poller,触发时调用`handleRead()`,`handleWrite()`,`handleClose()`,`handleError()`。
- `localAddr_`