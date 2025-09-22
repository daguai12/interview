## Poller模块的作用和职责
在`muduo`网络库中，`Poller`模块所扮演的角色为`IO多路复用器`

它的职责为：
- **监听所有感兴趣的文件描述符(fd)事件。**
- **当文件描述符fd上有I/O事件发生时，通知对应的Channel。
- **通过EventLoop调用Poller。

## Poller模块与其他模块的交互

![[Pasted image 20250517144449.png]]

- EventLoop: 事件循环线程（一个线程对应一个EventLoop)。
- Poller: 负责管理多个Channel，通过epoll/poll等系统调用检测 I/O 事件的发生。
- Channel: 执行fd所对应的回调函数。

## Poller模块代码详解
###  1. 保存所有监听 fd 的 Channel

```c++
class Poller : noncopyable
{
public:
    using ChannelMap = std::unordered_map<int,Channel*>;
    ChannelMap channels_;
};
```

- `Key`是文件描述符(fd)。
- `Value`是fd所对应的Channel。
- `ChannelMap`当监听/更新/删除某个fd的I/O事件时，Poller负责管理这张表。

### 2.实现IO多路复用
```c++
class Poller : noncopyable
{
public:
    // 存储活跃的 Channel* 指针表
    using ChannelList = std::vector<Channel*>;
    virtual Timestamp poll(int timeoutMs,ChannelList* activeChannels) = 0;
};
```

`Poller`为一个纯虚函数，在派生类`EpollPoller`中，最终会调用`epoll_wait()` `poll()` `select()` 等系统调用函数。

作用：
- 阻塞等待所有已注册fd的 I/O 事件。
- 收集所有发生事件的`Channel`，将活跃fd对应的`Channel`指针放入 `activeChannels` 中，供 `EventLoop` 分发。

### 3.更新监听事件
```c++
class Poller : noncopyable
{
public:
    // 修改channel所监听的事件
    virtual void updateChannel(Channel* channel) = 0;
    // 移除channel所监听的事件
    virtual void removeChannel(Channel* channel) = 0;
};
```

-  当某个 `Channel` 修改了他感兴趣的事件（比如从只监听度变成监听读+写），`Poller`负责更新内核中的 `epoll_ctl` 表。

### 4.移除Channel
```c++
class Poller : noncopyable
{
public:
    // 修改channel所监听的事件
    virtual void updateChannel(Channel* channel) = 0;
    // 移除channel所监听的事件
    virtual void removeChannel(Channel* channel) = 0;
}
```

- 当某 `Channel` 不在需要监听时，`Poller`会：
	- 从 `channels_`中移除
	- 从 epoll/poll 中移除该 fd 的监听。

### 5.保证线程安全
Poller 和 EventLoop 是一一对应的 。
```c++
class Poller : noncopyable
{
private:
	EventLoop* ownerLoop_;
}
```

所有Poller的操作都必须在它所属的 `EventLoop` 线程中执行。
- 保证线程安全，避免多线程下的竞争条件。

## Poller子类（真正实现多路复用）

Poller 并没有直接实现 `poll` `epoll` , 而是定义了统一的 Poller 接口，然后用不同的子类来实现（ EpollPoller，PollPoller）。

通过静态工厂方法 `newDefaultPoller()` 来创建对应的子类。

```c++
#include "Poller.h"

Poller* Poller::newDefaultPoller(EventLoop* loop)
{
    if(::getenv("MUDUO_USE_POLL"))
    {
        // return new PollPoller(loop);
    }
    else
    {
        // return new EPollerPoller(loop);
    }
}
```

**重点:**

这里并没有将 `newDefaultPoller()`的实现编写在 `Poller.cc`。如果在 `Poller.h` 中直接 `#include "EpollPoller.h"`，就会让 `Poller.h` 依赖于具体实现，导致：
- 编译依赖膨胀
- 增加头文件的耦合，稍微修改 epoll 的实现 ， 其他所有引用 Poller.h 的文件都要重新编译，代价大
- 扩展性不好


```text
       EventLoop::loop()
               │
               │
        调用 Poller::poll()
               │
               ▼
    系统调用 (epoll_wait/poll)
               │
   ┌───────────┴────────────┐
   │ 有事件发生               │ 没有事件（超时）
   │                       │
   ▼                       ▼
 返回活跃 fd 列表       返回空
   │
 根据 fd 找到 Channel
   │
 将活跃 Channel 放入 activeChannels
   │
 EventLoop 分发事件，调用 Channel 回调

```

