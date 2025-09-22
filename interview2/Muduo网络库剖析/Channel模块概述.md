## Channel的定义
### 官方定义：
> Channel 是对一个文件描述符（fd）及其感兴趣的 I/O 事件的封装，同时保存了对应事件发生时要执行的回调函数。

### 通俗说：
- Channel 就是 fd 的 "事件分发器"
Channel并不关注 I/O 多路复用（由Poller负责），也不关注事件循环（EventLoop负责）。
它只负责：
**当Poller通知Channel fd 有事件，Channel执行对应的回调函数。

### Channel的作用
| 功能               | 说明                                                |
| :--------------- | :------------------------------------------------ |
| 封装 fd            | 保存一个文件描述符（socket 或 eventfd 等）                     |
| 管理关注事件           | 记录当前关注的事件（如可读、可写、关闭、错误）                           |
| 保存回调函数           | 当事件发生时执行的回调（readCallback、writeCallback 等）         |
| 与 Poller 配合管理 fd | Poller 监听 Channel 中的 fd，Channel 负责事件回调处理          |
| 与 EventLoop 配合   | EventLoop 调用 Poller，得到活跃 Channel，再交给 Channel 执行回调 |
## Channel代码解析
### 1. 保存fd和关注的事件

```c++
int fd_;
int events_;       // 关注的事件
int revents_;      // Poller 返回的活跃事件
```

例如：
- events_ = EPOLLIN | EPLLOOUT 关注可读、可写事件。
- revetns_ = EPOLLIN 表示当前可读事件发生。

### 2. 注册回调函数

```cpp
std::function<void()> readCallback_;
std::function<void()> writeCallback_;
std::function<void()> closeCallback_;
std::function<void()> errorCallback_;
```

当对应的事件发生的时候，执行对应的回调函数。
TcpConnection可以给 Channel 设置回调函数。

### 3. 设置关注事件的接口

```cpp
void enableReading()  { events_ |= kReadEvent; update(); }
void enableWriting()  { events_ |= kWriteEvent; update(); }
void disableWriting() { events_ &= ~kWriteEvent; update(); }
void disableAll()     { events_ = kNoneEvent; update(); }
```

- `events_`是Channel当前关注的事件
- 每次关注事件变化之后，调用 `update()` 通知 Poller 更新 epoll_ctl
- kReadEvent / KWriteEvent 是 epoll 的事件掩码值。
### 4. 和Poller交互

```cpp
void update();
void remove();
```

- update(): 当 Channel 关注的事件发生变化的时候，通知 EventLoop，EventLoop 在调用 Poller 的 `updateChannel(this)`
- remove(): Channel 不在使用时，从Poller中删除。

### 5. 和 EventLoop 交互

```cpp
void handleEvent(Timestamp receiveTime);
```

- 当 Poller 检测到 fd 活跃，把活跃 Channel 交给 EventLoop
- EventLoop 调用 Channel 的 `handleEvent()`, 执行对应的回调


## `void tie(shared_ptr<void>&` 详解

该函数是 Channel 里的一个成员函数，用来：

> 将一个 `shared_ptr` 和当前 Channel 关联
> 保证在**Channel 执行回调函数过程中，它所属的 TcpConnection 对象不会被提前销毁**

### 为什么需要tie?
**问题：**
- TcpConnection 的 `handleRead()` 方法是注册在 Channel 的回调里的
- 如果事件触发时，TcpConnection 已经被用户释放掉了，但是事件还没有执行
	- 会造成**悬空指针引用，程序奔溃**

### 解决方法：tie + weak_ptr

Muduo 在 TcpConnection 和 Channel 建立绑定：
- TcpConnection 创建 Channel 时，调用 Channel::tie，把 `shared_from_this()` 传进去

```cpp
void TcpConnection::connectEstablished()
{
  channel_->tie(shared_from_this());
  ...
}

```

**tie 的作用：**

- Channel 保存一个 `std::weak_ptr<void>`（叫 tie_）
    
- 在事件分发的时候，临时提升为 `shared_ptr`，如果能提升成功，说明对象还活着，可以安全执行回调
    
- 如果提升失败，说明对象已经销毁，不执行回调，避免悬空引用


### tie函数

```cpp
void Channel::tie(const std::shared_ptr<void>& obj)
{
  tie_ = obj;
  tied_ = true;
}
```

- 保存 `shared_ptr` 到 `tie_` (实际上是 `weak_ptr<void>`)
- `tied_` 标志设为true,表示这个 Channel和某个对象绑定过

### 使用方法

```cpp
void Channel::handleEventWithGuard(Timestamp receiveTime)
{
  if (tied_)
  {
    std::shared_ptr<void> guard = tie_.lock();
    if (guard)
    {
      // 对象还活着，安全执行回调
      if (revents_ & EPOLLIN)  readCallback_();
      ...
    }
    // guard 提升失败，对象已销毁，什么也不做
  }
  else
  {
    // 没绑 tie，直接执行
  }
}

```

## 事件分发详细流程

```text
客户端发来消息（触发 socket 可读事件）
          │
          ▼
 epoll_wait() 返回 fd=5, revents=EPOLLIN
          │
          ▼
Poller 找到 Channel(fd=5)，加入 activeChannels
          │
          ▼
EventLoop 拿到 activeChannels
          │
          ▼
遍历 activeChannels，调用 channel->handleEvent()
          │
          ▼
根据 revents_ 执行 readCallback_()
（其实就是 TcpConnection::handleRead）
          │
          ▼
读取数据、业务逻辑处理
 ```
 