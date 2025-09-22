## EPollPoller 结构&作用
`EPollPoller`是 `Poller` 的子类，封装了 `epoll` 系统调用。

**核心作用：**
- 管理 fd 及其感兴趣的事件
- 调用 `epoll_wait()`等待事件发生
- 将发生的事件对应的 `Channel` 放入 `EventLoop` 的 `activeChannels`

## 成员变量作用

```c++

using EventList = std::vector<struct epoll_event>;
int epollfd_;
EventList events_;

// 在父类 Poller.h 中定义，子类 EPollPoller 通过继承获取该变量
using ChannelMap = std::unordered_map<int,Channel*>;
ChannelMap channels_;
```
- epollfd_ : 保存 `epoll_create()` 返回的 epoll实例句柄
- events_ : 存放 `epoll_wait()` 返回的活跃事件数组
- channels_ : `Poller` 父类维护的 `map<int,Channel*>`

## 成员函数剖析

### 1. `poll()`
**作用:** 调用 `epoll_wait() `等待事件，返回活跃 `Channel `给 `EventLoop`
**步骤：**
1. 调用 `epoll_wait()`
2. 有事件，调用 `fillActiveChannels()`，把活跃 `Channel `填入 `activeChannels`
3. 超时时，返回当前时间戳
```c++
int numEvents = ::epoll_wait(epollfd_, &*events_.begin(), events_.size(), timeoutMs);
fillActiveChannels(numEvents, activeChannels);
```

### 2. `fillActiveChannles()`
**作用：** 把 `epoll_wait()` 返回的事件对应 `Channel` ，填入 `activeChannels`
**流程:**


### 3. `updateChannel()`

**作用**：更新 epoll 中监听的 `fd` 和事件

**流程**：

* 判断 `Channel::index_`

  * `kNew` 或 `kDeleted`：调用 `EPOLL_CTL_ADD`
  * `kAdded`：

    * 若监听事件为空：`EPOLL_CTL_DEL`
    * 否则：`EPOLL_CTL_MOD`
* 调用 `update()`

```cpp
if (index == kNew || index == kDeleted)
{
  update(EPOLL_CTL_ADD, channel);
}
else
{
  update(EPOLL_CTL_MOD, channel);
}
```


### 🔸 `removeChannel()`

**作用**：将某 `fd` 从 epoll 中移除

**流程**：

* 断言 `Channel` 已注册
* 从 `channels_` 中删除
* 若 `index == kAdded`，调用 `update(EPOLL_CTL_DEL)`
* 将 `index_` 设为 `kNew`

### 🔸 `update()`

**作用**：封装 `epoll_ctl()`，执行 ADD、MOD、DEL 操作

**核心代码**

```cpp
event.events = channel->events();
event.data.ptr = channel;
::epoll_ctl(epollfd_, operation, fd, &event)
```


##  模块交互关系剖析


### 📌 `EventLoop` 与 `EPollPoller`

**EventLoop::loop()**
👉 调用 `Poller::poll()`
👉 `EPollPoller::poll()`
👉 `epoll_wait()`
👉 填充 `activeChannels`
👉 遍历 `activeChannels`，执行 `Channel::handleEvent()`

---

### 📌 `Channel` 与 `EPollPoller`

* 每个 `Channel` 表示一个 fd 的抽象，记录 fd、感兴趣事件、实际发生事件、回调函数
* `EPollPoller` 中维护 `map<fd, Channel*>`
* `epoll_event.data.ptr` 绑定 `Channel*`
* `fillActiveChannels()` 设置 `Channel::revents_`
* `EventLoop` 遍历 `activeChannels`，调用 `Channel::handleEvent()`

---

### 📌 `Poller` 与 `EPollPoller`

* `Poller` 是抽象接口
* `EPollPoller` 实现 `poll() / updateChannel() / removeChannel()`
* `EventLoop` 只依赖 `Poller` 基类指针，做到 I/O 多路复用器可替换（如 `PollPoller`）


## 📈 补充：调用时序图（文字版）

```
EventLoop::loop()
  ├──> EPollPoller::poll()
  │       └──> epoll_wait()
  │       └──> fillActiveChannels()
  │             └──> Channel::set_revents()
  │             └──> activeChannels->push_back()
  │
  └──> 遍历 activeChannels
         └──> Channel::handleEvent()
               └──> 调用绑定的回调
```
