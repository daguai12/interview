## EventLoop的定义
EventLoop是事件循环.
## EventLoop的作用
- 通过调用 `Poller模块` 来监听和分发事件

在Muduo中，每个 `EventLoop` 通常对应一个线程，**实现了"一个线程对应一个loop**的模型。

**核心职责**

1. **IO复用**
	-  通过 `epoll_wait()` 等待文件描述符的 IO 事件发生。
	- 事件发生以后，调用 `Channel` 中的回调函数。
	

## 成员变量详解
```c++
using ChannelList = std::vector<Channel*>;

std::atomic_bool looping_; /*atomic*/
std::atomic_bool quit_;

const pid_t threadId_;

Timestamp pollReturnTime_;
std::unique_ptr<Poller> poller_;

int wakeupFd_;
std::unique_ptr<Channel> wakeupChannel_;

ChannelList activeChannels_;

std::atomic_bool callingPendingFunctors_; 
std::vector<Functor> pendingFunctors_; 
std::mutex mutex_;

```

- `looping_:` 标示是否处于事件循环中
- `quit_:` 表示是否退出事件循环
- `threadId_`:
- `pollReturnTime_`
- `poller_:` 封装 `epoll` 操作的类
- `wakeupFd:` 
- `wakeupChannel_`
- `activeChannels_`
- `callingPendingFunctors_:` 判断是否正在执行回调函数
- `pendingFunctors_`

## 成员函数详解
### 1. createEventfd()

```c++
int createEventfd()
{
    int evtfd = ::eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
    if (evtfd < 0)
    {
        LOG_FATAL("eventfd error:%d \n", errno);
    }
    return evtfd;
}
```

这个函数的作用是：

> **创建一个 `eventfd` 文件描述符**，用于**线程间唤醒（event notification）机制**，然后返回它。

* `eventfd` 是 Linux 提供的轻量级**事件通知机制**
* 常用于**多线程或多进程之间的事件唤醒**
* 在 Muduo 里用来**唤醒 EventLoop 所在线程**，比如在 `queueInLoop()` 里，如果其他线程要往 `EventLoop` 线程扔任务，就用 `eventfd` 来唤醒 `poll()` 或 `epoll_wait()` 阻塞中的 EventLoop。

>`eventfd()`介绍

- write() 给这个 fd 写入值，counter += 写入值
- read() 从这个 fd 读取值，counter → 0，并返回之前的值
- 支持 EFD_NONBLOCK 非阻塞
- epoll 可以监控这个 fd 的可读事件


### 2. wakeup() 和 handleRead()
这俩函数配套用来实现：

> **通过 eventfd 唤醒正在 epoll\_wait 的 EventLoop 所在线程**

* `wakeup()`：**别的线程或自己调用，向 `eventfd` 写数据，触发可读事件**
* `handleRead()`：**EventLoop 线程自己调用，读取 eventfd，把事件清掉**


eventfd 是一个 64 位无符号整数：

* `write()` 增加这个值
* `read()` 返回当前值并清零
* `epoll` 可以监视 eventfd，**只要这个值不为 0 就是可读**

**注意：eventfd 的 read/write 都是 8 字节（uint64\_t）**


#### 🔵 `wakeup()`

```cpp
void EventLoop::wakeup()
{
    uint64_t one = 1;
    ssize_t n = write(wakeupFd_, &one, sizeof one);
    if (n != sizeof one)
    {
        LOG_ERROR("EventLoop::wakeup() writes %lu bytes instead of 8 \n", n);
    }
}
```

#### 👉 作用：

**向 `wakeupFd_` 写入 1，触发 epoll 中注册的 wakeupFd 的可读事件，从而唤醒正在 `epoll_wait()` 的 EventLoop 线程。**

#### 👉 为什么写 `uint64_t one = 1`？

eventfd 规定：每次 `read/write` 都是 8 字节（64 位无符号整数）

#### 👉 为什么要唤醒？

因为别的线程调用了 `queueInLoop()` 往 `EventLoop` 扔了回调函数，得通知 EventLoop 醒一醒，执行 `doPendingFunctors()`

#### 👉 为什么要判断 `n != sizeof one`？

防止写失败或者写了不满 8 字节。按理说不会出问题，但这是防御性编程。

---

#### 🔵 `handleRead()`

```cpp
void EventLoop::handleRead()
{
  uint64_t one = 1;
  ssize_t n = read(wakeupFd_, &one, sizeof one);
  if (n != sizeof one)
  {
    LOG_ERROR("EventLoop::handleRead() reads %lu bytes instead of 8", n);
  }
}
```

#### 👉 作用：

**把 wakeupFd 中的数据读出来，避免 eventfd 的 counter 值累积，防止 epoll 重复触发可读事件。**

#### 👉 为什么读出来？

如果不读，eventfd 的 counter 会累积不清零，`epoll_wait` 之后每次都检测到可读，不停唤醒，造成空转。

#### 👉 为什么一样判断 `n != sizeof one`？

还是防御性编程，确保 read 操作正确完成。

#### 📌 结合 epoll 的工作流程图

### 📊 流程：

```text
其他线程：
queueInLoop(cb) 
→ 检查线程，不是本线程 或者 本线程正在 doPendingFunctors
→ wakeup()
→ write(wakeupFd_)

EventLoop 线程：
epoll_wait()
→ wakeupFd_ 可读
→ 调用 handleRead()
→ doPendingFunctors()
```

* `EventLoop::loop()` 里的 `epoll_wait` 监听了 wakeupFd\_
* `wakeup()` 写 wakeupFd\_
* epoll 检测到 wakeupFd\_ 可读，唤醒
* 执行 `handleRead()` 把 eventfd 的值清空
* 然后执行 `doPendingFunctors()` 处理队列里的任务

#### 📌 为什么不直接用信号、pipe？

| 方案        | 优点                  | 缺点           |
| :-------- | :------------------ | :----------- |
| `eventfd` | 高效、单 fd、内核实现轻量、简单安全 | 只支持 64 位整数读写 |
| `pipe`    | 通用，支持任意数据传递         | 两个 fd，效率略低   |
| 信号 signal | 复杂、信号可靠性差           | 易丢失、调度开销大    |
|           |                     |              |
### 3. queueInLoop()

```c++
void EventLoop::queueInLoop(Functor cb)
{
    {
        std::unique_lock<std::mutex> lock(mutex_);
        pendingFunctors_.emplace_back(cb);
    }

    // 唤醒相应的，需要执行上面回调操作的loop的线程了
    // || callingPendingFunctors_的意思是：当前loop正在执行回调，但是loop又有了新的回调
    if (!isInLoopThread() || callingPendingFunctors_) 
    {
        wakeup(); // 唤醒loop所在线程
    }
}

```

#### 📌 总体作用

**把某个回调函数（Functor）放入 `EventLoop` 的回调队列 `pendingFunctors_` 中，如果需要就唤醒 `EventLoop` 线程去执行它。**

这个方法的典型应用场景：

* 其他线程向 `EventLoop` 线程发送任务（回调）
* 自己线程在回调中继续追加回调


#### 📌 函数逐行详细解析

```cpp
{
    std::unique_lock<std::mutex> lock(mutex_);
    pendingFunctors_.emplace_back(cb);
}
```

#### 📌 作用：

* 加锁保护 `pendingFunctors_` 队列，防止多个线程同时访问
* 把传进来的回调 `cb` 加入 `pendingFunctors_`

#### 📌 为什么要加锁？

* `EventLoop` 的 `doPendingFunctors()` 和其他线程的 `queueInLoop()` 都会访问 `pendingFunctors_`
* 需要用 mutex 保证线程安全


```cpp
if (!isInLoopThread() || callingPendingFunctors_) 
```

#### 📌 作用：

判断是否需要唤醒 `EventLoop` 所在线程。

#### 📌 这俩条件什么意思？

##### ① `!isInLoopThread()`

* 如果 **当前线程不是 EventLoop 所在线程**
  → 说明是**其他线程**调用 `queueInLoop()`，而 `EventLoop` 线程可能正在 `epoll_wait()` 睡眠，需要唤醒它。

##### ② `callingPendingFunctors_`

* 表示**当前 EventLoop 正在执行 `doPendingFunctors()` 回调**
* 如果此时又有新的回调加入，就必须唤醒一次，保证新回调能被及时执行，而不是等下一次 `epoll_wait()` 唤醒。

### 📌 为什么要这个条件？

如果\*\*当前线程是 EventLoop 线程，但它正处在 `doPendingFunctors()` 中，\*\*而你又调用 `queueInLoop()` 加了新回调，不唤醒的话这次 `doPendingFunctors()` 可能就结束了，导致新回调不能及时执行。

#### 👉 唤醒一下，保证：

* **当前 doPendingFunctors 执行完**
* **epoll\_wait 会立即返回**
* **EventLoop 会再次进入 `doPendingFunctors()`**

```cpp
wakeup(); // 唤醒loop所在线程
```

### 📌 作用：

* 如果满足上面条件，就唤醒 EventLoop 所在线程
* 原理：`write()` 往 `eventfd` 写入数据，触发 `epoll` 的可读事件，`EventLoop` 被唤醒


### 📌 为什么不直接 `runInLoop()`？

`runInLoop(cb)` 通常是：

* 如果本线程是 `EventLoop` 线程，就**直接执行 cb**
* 否则调用 `queueInLoop(cb)`

`queueInLoop()` 就是**异步线程安全版**，适合其他线程调。

### 4.pendingFunctors_()
#### 📌 函数作用

👉 **把 pendingFunctors\_ 队列里的任务拿出来，依次执行它们**

这些 `Functor` 往往是其他线程通过 `queueInLoop()` 扔过来的“待执行任务”。

---

#### 📌 每行细节

```cpp
std::vector<Functor> functors;
```

定义一个**局部的 vector**，用来临时保存即将要执行的 Functor 回调。

```cpp
callingPendingFunctors_ = true;
```

设置状态：
👉 告诉 `EventLoop` 当前正在执行 pending 的 Functor 回调。
**防止其他线程在这个过程中做冲突操作**。

```cpp
{
    std::unique_lock<std::mutex> lock(mutex_);
    functors.swap(pendingFunctors_);
}
```

### ✅ 干了啥？

1. **上锁**：保证操作 `pendingFunctors_` 的线程安全
2. **交换数据**：

   * `functors.swap(pendingFunctors_)`
     👉 把 `pendingFunctors_` 里的所有回调，一次性交换到局部 `functors` 里
     👉 **pendingFunctors\_ 清空了**，局部 functors 接管任务
3. **释放锁**（出了作用域）

#### ✅ 为什么要 swap？

* 避免 holding 锁的时间过长！🔥
  如果直接在锁保护下遍历 `pendingFunctors_`，如果某个回调耗时，别的线程调用 `queueInLoop()` 时就阻塞在锁上了
  → **影响性能、可能死锁**

---

```cpp
for (const Functor &functor : functors)
{
    functor();
}
```

#### ✅ 干了啥？

* 遍历 functors 里的所有回调，逐个执行

```cpp
callingPendingFunctors_ = false;
```

恢复状态，表示执行完毕。


#### 📌 总结一句：

* **安全高效地取出所有 pendingFunctors\_**
* **在无锁状态下执行回调**
* **避免阻塞 queueInLoop() 的线程**
* **保证线程安全和高性能**


#### 📌 总结亮点：

✅ **锁粒度小**
✅ **执行回调不阻塞 queueInLoop()**
✅ **安全防止竞态**
✅ **状态变量 callingPendingFunctors\_ 防止递归冲突**


### 5. runInLoop()

#### 📌 作用：

👉 **判断当前调用线程是否是 EventLoop 所在线程**

* 是的话：直接执行回调
* 不是的话：通过 `queueInLoop()` 将回调加入 pendingFunctors\_，然后唤醒 EventLoop 线程执行

**目的**：确保所有和 IO 相关的操作都在 EventLoop 所属线程中完成，保证线程安全。

---

#### 📌 逐行详细解读：

```cpp
if (isInLoopThread())
```

👉 判断当前线程是否是 EventLoop 创建时所属的线程。
**怎么判断呢？**
`isInLoopThread()` 就是对比 `threadId_` 和 `CurrentThread::tid()`。
（`EventLoop` 构造的时候记录了自己在哪个线程）

#### ✅ 是 EventLoop 所在线程

```cpp
cb();
```

👉 如果当前线程就是 EventLoop 所在线程，**直接执行 Functor**。

因为：

* 这是线程安全的
* 也避免了多余的 wakeup、队列操作

#### ✅ 不是 EventLoop 所在线程

```cpp
queueInLoop(cb);
```

👉 如果是**别的线程**调用了 `runInLoop()`，就调用 `queueInLoop(cb)`：

* 将 `cb` 加入 `pendingFunctors_`
* 并调用 `wakeup()`，唤醒 EventLoop 所在线程
* 最后 EventLoop 在 `doPendingFunctors()` 中统一处理这些回调

#### 📌 场景举例：

假设：

* `main thread` 是 EventLoop 所在线程
* `worker thread` 想要让 EventLoop 执行个任务
  就直接 `loop->runInLoop(cb)`

如果此时是 main thread 调用，cb 直接执行
如果是 worker thread 调用，cb 被 queue 到 pendingFunctors\_，然后唤醒 main thread 执行

#### 📌 为什么要这样设计？

👉 **保证线程安全，所有 IO 和回调都在 EventLoop 所属线程执行**
👉 **支持跨线程任务派发**

#### 📌 总结一句话：

* **runInLoop** 是个智能调度器
* **同线程立即执行**，**异线程丢队列唤醒执行**


### 6.quit()
## 📌 作用：

👉 安全、优雅地**让 EventLoop 退出循环**。

**注意：EventLoop 一般是个死循环 `while (!quit_) { ... }`**，要退出就得改掉这个条件，但同时要保证：

* 不管是**同线程**还是**其他线程调用 quit()**，都能正确让 EventLoop 及时退出。

---

## 📌 逐行解读：

```cpp
quit_ = true;
```

👉 将 `quit_` 置为 `true`。
EventLoop 中的主循环通常是：

```cpp
while (!quit_)
{
    poller_->poll();
    doPendingFunctors();
}
```

**置 true 之后，下次循环判断直接退出**

---

### ✅ 如果调用 quit() 的线程 **不是 EventLoop 所属线程**

```cpp
if (!isInLoopThread())
{
    wakeup();
}
```

👉 判断当前调用 quit() 的线程是否是 EventLoop 所在线程。

* **如果是**：不用唤醒，反正马上 EventLoop 的 poll() 或 epoll\_wait() 会超时或者检测到 quit\_
* **如果不是**：那当前 EventLoop 可能正在 `epoll_wait()` 阻塞中
  就需要通过 `wakeup()` 唤醒 EventLoop 所在线程，使它从 `epoll_wait()` 中返回，继续执行，检测到 quit\_，退出循环。

---

## 📌 为什么要唤醒？

👉 EventLoop 的事件循环核心是类似这样的：

```cpp
while (!quit_)
{
    activeChannels.clear();
    poller_->poll(timeout, &activeChannels);
    handleEvents();
    doPendingFunctors();
}
```

如果**别的线程调用了 quit()**，EventLoop 所在线程可能正在阻塞等事件，没办法及时退出。
这时候就靠 `wakeup()` 往 `eventfd` 写个值，触发可读事件，唤醒 `epoll_wait()`，这样循环继续，检测到 `quit_`，就能安全退出了。

---

## 📌 总结：

| 作用                 | 行为                         |
| :----------------- | :------------------------- |
| 设置退出标志             | `quit_ = true`             |
| 非 EventLoop 所属线程调用 | `wakeup()` 唤醒 EventLoop 线程 |
| 同 EventLoop 线程调用   | 不用唤醒，直接退出                  |

---

## 📌 图示：

```text
其他线程调用 quit()
      |
      v
  quit_ = true
      |
是否是 EventLoop 线程？
      |
  +---+---+
  |       |
是        否
  |        |
继续循环   wakeup()
检测 quit_  
退出
```

---

## 📌 核心目的：

👉 **线程安全地唤醒 EventLoop 并让它退出循环**

---

要不要我把 EventLoop 整个循环+唤醒+退出的**完整流程图**画一版给你？会更清楚这个机制是怎么无锁安全调度和优雅关闭的⚡️✨
