## EventLoopThreadPool模块的作用

**事件循环线程池**
它的作用是：
- 管理一组子线程，每个子线程都持有自己的 EventLoop
- 负责根据需要把事件/任务分发到不同的 EventLoop 上

## EventLoopThreadPool成员变量

```c++
EventLoop* baseLoop_;  // 主线程 EventLoop，Acceptor 使用的
std::string name_;
bool started_;
int numThreads_;       // 线程数量
int next_;             // 下一个要分发的 loop 编号
std::vector<std::unique_ptr<EventLoopThread>> threads_;
std::vector<EventLoop*> loops_; // 保存所有子线程 EventLoop 的指针
```


###  EventLoop\* baseLoop\_

👉 **作用**：

* 指向**主线程（Acceptor 所在线程）的 EventLoop 对象**
* 用于监听客户端新连接事件

👉 **为什么要有它**：

* **Acceptor 负责 accept 新连接，一般只在主线程的 EventLoop 上监听**
* 子线程不负责监听，只负责处理 I/O、读写事件

👉 **在 getNextLoop() 里的作用**：

* 如果线程池未启动（线程数为 0），或者没有子线程 EventLoop，直接返回 `baseLoop_`，在主线程里处理所有事件


###  std::string name\_

👉 **作用**：

* 给线程池起个名字，用于日志、调试、排查问题时区分不同线程池

👉 **应用场景**：

* 多个 TcpServer 或 EventLoopThreadPool 共存时，区分它们用的
* 生成每个子线程名字时用，比如：

  ```cpp
  snprintf(buf, sizeof buf, "%s%d", name_.c_str(), i);
  ```


###  bool started\_

👉 **作用**：

* 标志线程池是否已启动

👉 **为什么要有它**：

* 防止 `start()` 被调用多次
* 保证线程池只能启动一次，重复调用是无效甚至危险的

👉 **使用场景**：

```cpp
assert(!started_);
started_ = true;
```


###  int numThreads\_

👉 **作用**：

* 指定线程池中**要启动的子线程数量**

👉 **为什么要有它**：

* 动态配置线程池大小
* 用户可以根据机器 CPU 核心数、业务类型来调整线程池规模

👉 **使用场景**：

* 在 `start()` 中，根据 `numThreads_` 循环创建子线程
* 在 `TcpServer` 中：

  ```cpp
  server.setThreadNum(4); // 启动 4 个子线程 EventLoop
  ```


###  int next\_

👉 **作用**：

* 记录下一个要返回的 EventLoop 编号
* **用于 getNextLoop() 中实现轮询（Round Robin）算法**

👉 **为什么要有它**：

* 线程池管理的 EventLoop 数量有限，每次分配连接/任务要**均匀分布到不同线程**
* 防止某个线程过载，其他线程空闲

👉 **使用场景**：

```cpp
loop = loops_[next_];
++next_;
if (next_ >= loops_.size())
    next_ = 0;
```

### std::vector<std::unique_ptr<EventLoopThread\>>threads_

👉 **作用**：

* 保存所有子线程的 `EventLoopThread` 对象（用 unique\_ptr 管理内存）

👉 **为什么要有它**：

* 线程池管理子线程，避免泄露
* 便于统一销毁、析构时释放资源

👉 **设计细节**：

* 用 `unique_ptr` 自动管理内存，不用手动 delete
* 保证线程池销毁时，所有子线程都安全销毁

👉 **用法**：

* `start()` 中：

  ```cpp
  threads_.push_back(std::unique_ptr<EventLoopThread>(t));
  ```

##  std::vector\<EventLoop\*> loops\_

👉 **作用**：

* 保存所有子线程内的 EventLoop 指针，方便调度、分发任务、广播消息

👉 **为什么要有它**：

* EventLoopThread 负责管理线程，但 TcpServer 调用 `getNextLoop()` 或 `getAllLoops()` 时需要拿到子线程内的 EventLoop 才能分发任务
* **EventLoop 和 EventLoopThread 是一对一关系，但 TcpServer 只关心 EventLoop，不关心线程本身**

👉 **设计细节**：

* 每个 EventLoopThread 启动后调用 `startLoop()`，将子线程内 EventLoop 指针返回并加入 loops\_
* loops\_ 和 threads\_ 的顺序一一对应，轮询调度依靠 loops\_ 数组

**用法**：

```cpp
loops_.push_back(t->startLoop());
```


## EventLoopThreadPool成员函数

### start()

```c++
void EventLoopThreadPool::start(const ThreadInitCallback& cb)
{
    started_ = true;
    for (int i = 0; i < numThreads_; ++i)
    {
        char buf[name_.size() + 32];
        snprintf(buf, sizeof buf, "%s%d",name_.c_str(),i);
        EventLoopThread *t = new EventLoopThread(cb,buf);
        threads_.push_back(std::unique_ptr<EventLoopThread>(t));
        loops_.push_back(t->startLoop());
    }

    // 整个服务端只有一个线程，运行着baseloop
    if (numThreads_ == 0 && cb)
    {
        cb(baseLoop_);
    }
}
```


#### 作用概述：

**启动线程池：**

* 创建 `numThreads_` 个 `EventLoopThread`
* 每个线程都有独立的 `EventLoop`
* 启动子线程，子线程内部运行 `loop()`
* 主线程（Acceptor 所在线程）如果没有子线程，也可以自己执行回调



#### `started_ = true;`

👉 **作用**：

* 设置启动标志，说明线程池已经启动，后续不允许再调 `start()`


#### `for (int i = 0; i < numThreads_; ++i)`

👉 **作用**：

* 启动 `numThreads_` 个子线程 EventLoop

---

#### `snprintf(buf, sizeof buf, "%s%d", name_.c_str(), i);`

👉 **作用**：

* 生成子线程的名字，比如：

  ```
  "WorkerThread0"
  "WorkerThread1"
  ```

👉 **为什么**：

* 方便排查日志、调试定位哪个线程在跑


#### `EventLoopThread* t = new EventLoopThread(cb, buf);`

👉 **作用**：

* 创建一个 `EventLoopThread` 对象
* 线程启动后会在子线程里创建一个 `EventLoop`
* `cb` 是线程启动时要执行的初始化回调（可以为空）

👉 **参数含义**：

* `cb`：线程 EventLoop 创建后、loop 前执行的初始化函数
* `buf`：线程名字

#### `threads_.push_back(std::unique_ptr<EventLoopThread>(t));`

👉 **作用**：

* 用 `unique_ptr` 管理 `EventLoopThread` 内存，防止泄露，线程池析构时统一释放

---

#### `loops_.push_back(t->startLoop());`

👉 **作用**：

* 调用 `EventLoopThread::startLoop()`
* 这个函数：

  1. 创建一个子线程
  2. 子线程里创建 `EventLoop`
  3. 将子线程内的 `EventLoop*` 返回，加入 `loops_`

👉 **为什么要存 loops\_**：

* 方便后面 `TcpServer::getNextLoop()` 调用，轮询分发连接、任务到各线程 EventLoop

---

#### `if (numThreads_ == 0 && cb) cb(baseLoop_);`

👉 **作用**：

* 如果线程池线程数是 0（单线程模式）
* 而且提供了回调 `cb`，就直接在**主线程的 EventLoop** 上执行初始化回调

👉 **为什么**：

* 保证单线程模式下也能执行初始化配置，比如注册定时器、设置参数等
