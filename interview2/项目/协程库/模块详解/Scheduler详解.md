```cpp
static thread_local Scheduler* t_scheduler = nullptr;
```

`t_scheduler`是一个线程局部变量（TLS Thread_Local_Storage)，保证所有线程的该指针都是唯一的，且都指向同一个`Scheduler(调度器)`实例。


# `GetThis()和SetThis()`


`GetThis()`: 为一个静态方法用于线程获取当前调度器的指针。

`SetThis()`: 设置每一个线程的`t_scheduler`指针指向一个调度器。

# `Scheduler::Scheduler`

##  函数定义

```cpp
Scheduler::Scheduler(size_t threads, bool use_caller, const std::string &name)
    : m_useCaller(use_caller), m_name(name)
```

构造 `Scheduler` 类对象：

* `threads`：要创建的工作线程数量。
* `use_caller`：是否把当前主线程（调用 `Scheduler::start()` 的线程）也当作一个工作线程。
* `name`：调度器名称，用于日志或线程命名。


##  第一步：断言线程数合理 + 保证当前线程没有已有调度器

```cpp
assert(threads > 0 && Scheduler::GetThis() == nullptr);
```

含义：

1. `threads > 0`：至少需要 1 个工作线程。
2. `Scheduler::GetThis() == nullptr`：防止一个线程同时绑定多个调度器（通过 TLS 实现线程独立）。



##  第二步：设置线程名称（可用于调试）

```cpp
Thread::SetName(m_name);
```

作用：

* 调用静态方法为当前线程设置名称（Linux/POSIX 下可用 `pthread_setname_np`）。
* 有助于调试线程或查看线程状态。


##  第三步：如果使用主线程作为工作线程

```cpp
if(use_caller)
```

这块逻辑表示当前线程会作为协程调度器的一部分，负责执行调度任务。


### ➤ 1. 工作线程数减一

```cpp
threads--;
```

* 因为主线程本身也参与调度了，就不用再为它创建一个线程。


### ➤ 2. 初始化主线程的主协程

```cpp
Fiber::GetThis();
```

* 保证当前线程有主协程（`t_thread_fiber` 被创建）；
* 否则 `Fiber::resume/yield()` 等函数将无法正确工作。

### ➤ 3. 设置当前线程的调度器为自己(当主线程作为工作线程的时候)

```cpp
    t_scheduler = this;
```

* 设置线程局部变量 `t_scheduler`（通常是 `thread_local Scheduler*`）指向当前调度器对象；
* 方便之后用 `Scheduler::GetThis()` 获取当前线程所属的调度器实例。

### ➤ 4. 创建“调度器协程”

```cpp
m_schedulerFiber.reset(new Fiber(std::bind(&Scheduler::run, this), 0, true));
```

作用：

* 为当前主线程创建一个新的协程，用于执行调度器的 `run()` 主循环；
* 通过 `std::bind` 将成员函数绑定为函数对象；
* 最后一个参数 `false` 表示这个协程**不运行在调度器中**，也就是说它会在退出时返回给 `main` 线程。

### ➤ 5. 设置当前线程的调度协程

```cpp
Fiber::SetSchedulerFiber(m_schedulerFiber.get());
```

说明：

* 设置 `t_scheduler_fiber = m_schedulerFiber.get();`；
* 为当前线程打上“调度协程”的标签，方便 `Fiber::resume/yield` 切换回这个协程。

### ➤ 6. 设置“根线程”信息

```cpp
m_rootThread = Thread::GetThreadId();
m_threadIds.push_back(m_rootThread);
```

* 记录当前线程的 ID 作为根线程 ID；
* 添加到 `m_threadIds` 中，表示它是调度线程之一。


##  第六步：记录需要创建的线程数

```cpp
m_threadCount = threads;
```

此时：

* 如果 `use_caller = false`：`m_threadCount = 原始 threads`；
* 如果 `use_caller = true`：`m_threadCount = threads - 1`，主线程将会是第一个调度线程。


##  最后：调试输出（可选）

```cpp
if(debug) std::cout << "Scheduler::Scheduler() success\n";
```


## 整体执行流程总结图

```text
构造 Scheduler 对象
     │
     ├── 设置线程局部变量 t_scheduler
     ├── 设置当前线程名称
     ├── 如果 use_caller == true：
     │     ├── 主线程也作为调度线程
     │     ├── 初始化主协程（Fiber::GetThis）
     │     ├── 创建调度协程 run()
     │     ├── 设置 t_scheduler_fiber
     │     └── 记录主线程 ID
     └── 保存 thread 数量（m_threadCount）
```


## ✅ 该构造函数的作用总结

| 功能点       | 作用                           |
| --------- | ---------------------------- |
| 参数校验      | 确保线程数大于 0，防止线程绑定多个调度器        |
| 状态初始化     | 记录调度器名称、使用主线程与否等配置           |
| 调度协程初始化   | 如果主线程也参与调度，则为其创建调度协程 `run()` |
| 主协程初始化    | 确保有主协程，用于 resume/yield 切换    |
| 根线程 ID 记录 | 如果使用主线程，则记录主线程 ID            |
| 成员变量初始化   | 为启动 `start()` 函数做好准备         |




# `Scheduler::start()`

当然可以！我们来逐行详细讲解这个调度器的 `Scheduler::start()` 函数，它的作用是：

> **启动线程池，创建调度线程，并为每个线程运行调度主循环 `Scheduler::run()`。**

##  函数作用

```cpp
void Scheduler::start()
```

###  用于启动调度器，主要做三件事：

1. **线程安全地检查是否已停止**；
2. **分配线程池资源**；
3. **为每个线程创建一个调度线程，执行 `run()` 函数。**

##  逐行讲解

### 1️⃣ 加锁保护共享资源

```cpp
std::lock_guard<std::mutex> lock(m_mutex);
```

* `m_threads`、`m_threadIds` 是共享变量，可能会被其他线程访问（如 `stop()` 里清理线程）；
* 因此需要加锁防止并发修改。

### 2️⃣ 已停止则不再启动

```cpp
if(m_stopping)
{
    std::cerr << "Scheduler is stopped" << std::endl;
    return;
}
```

* 如果 `m_stopping == true`，说明 `stop()` 已被调用，调度器处于“终止流程中”；
* 此时启动是非法操作，直接退出。

### 3️⃣ 防止重复启动

```cpp
assert(m_threads.empty());
```

* 调度器只能启动一次；
* 如果已经有线程存在，则不允许再次启动；
* `assert` 是开发期的检查手段，防止误用。


### 4️⃣ 分配线程池容器空间

```cpp
m_threads.resize(m_threadCount);
```

* 初始化 `m_threads` 数组，长度为 `m_threadCount`；
* 每个元素是一个 `shared_ptr<Thread>`，稍后填充。

### 5️⃣ 创建线程并执行 `Scheduler::run()`

```cpp
for(size_t i=0;i<m_threadCount;i++)
{
    m_threads[i].reset(new Thread(std::bind(&Scheduler::run, this), m_name + "_" + std::to_string(i)));
    m_threadIds.push_back(m_threads[i]->getId());
}
```

#### ➤ 每次循环做的事情：

1. `Thread(std::bind(&Scheduler::run, this), name)`

   * 创建一个新线程，线程入口函数是 `this->run()`；
   * `Thread` 是自定义线程类，类似 `std::thread`，但带有命名功能；
   * 第二个参数是线程名，用于调试标识，比如 `"Scheduler_0"`。

2. `.reset(...)`

   * 用智能指针托管新线程对象，防止内存泄露。

3. `m_threadIds.push_back(...)`

   * 保存该线程的线程 ID，用于识别任务是否应该运行在某个特定线程上（任务有 thread 参数时）。


### 6️⃣ 打印调试信息（可选）

```cpp
if(debug) std::cout << "Scheduler::start() success\n";
```

* 输出一行日志，说明线程池启动成功。


##  执行流程图解

```text
Scheduler::start()
 ├── 加锁（保护共享状态）
 ├── 如果已停止，则直接退出
 ├── 断言未重复启动
 ├── 初始化线程容器 m_threads[]
 └── 创建线程 Thread[i]
      ├── 入口函数是 Scheduler::run()
      ├── 线程名设为 "Scheduler_i"
      └── 存储线程 ID
```

## ✅ 总结功能

| 步骤      | 功能描述                | 关键变量            |
| ------- | ------------------- | --------------- |
| 加锁      | 保证线程安全              | `m_mutex`       |
| 检查      | 调度器是否已被停止           | `m_stopping`    |
| 初始化     | 分配线程容器空间            | `m_threads`     |
| 启动线程    | 每个线程运行 `run()` 调度循环 | `Thread::run()` |
| 保存线程 ID | 用于任务指定线程执行          | `m_threadIds`   |

## 🔚 注意事项（重点）

* ❗ 如果你设置 `use_caller = true`，那么主线程会单独创建 `m_schedulerFiber`，主线程的调度协程不在这个 `start()` 中启动；
* ❗ 如果 `use_caller = false`，那么只有这些 `start()` 创建的线程会参与调度，主线程只是添加任务或最终调用 `stop()` 等待退出；
* ❗ 所有线程执行的调度函数是 `Scheduler::run()`，它会不断从任务队列 `m_tasks` 中取出任务并 `resume()`。


# `Scheduler::run()`


##  总览：`Scheduler::run()` 是干什么的？

> 每个调度线程都会执行这个函数。它会循环从任务队列中取出协程/回调函数，然后执行它们；如果没有任务，就执行 idle 协程保持“挂起”状态，直到被唤醒或调度器退出。

##  逐行详细解释


### 📌 1. 获取当前线程 ID，打印日志（可选）

```cpp
int thread_id = Thread::GetThreadId();
if(debug) std::cout << "Schedule::run() starts in thread: " << thread_id << std::endl;
```

获取当前线程编号，用于标识调度线程。


### 📌 2. 设置当前线程的调度器指针

```cpp
SetThis();
```

设置 `t_scheduler = this;`，即为线程局部变量绑定当前调度器对象，供后续调度操作中使用。

### 📌 3. 如果当前线程不是主线程，则需要初始化主协程

```cpp
if(thread_id != m_rootThread) {
    Fiber::GetThis();
}
```

* 主线程在构造 `Scheduler` 时就初始化了主协程；
* 所以只有**子线程**才需要调用 `Fiber::GetThis()`，为该线程创建主协程（用于 yield 切换）。

### 📌 4. 创建“空闲协程”

```cpp
std::shared_ptr<Fiber> idle_fiber = std::make_shared<Fiber>(std::bind(&Scheduler::idle, this));
```

这是一个 **专门执行 idle() 函数的协程**：

* 当线程没有任务要处理时，就会 `resume()` 这个 idle 协程；
* idle 协程通常是空转或等待任务，不会占用 CPU。

### 📌 5. 主循环开始

```cpp
ScheduleTask task;
while (true) {
```

每个调度线程一直在 `while(true)` 中执行调度任务，直到调度器被关闭。


### 📌 6. 初始化本次循环的任务对象

```cpp
task.reset();
bool tickle_me = false;
```

* `task` 是本轮准备要执行的协程/回调任务；
* `tickle_me` 表示是否需要通知其它线程有任务可执行（后面判断）。


### 📌 7. 加锁处理任务队列

```cpp
std::lock_guard<std::mutex> lock(m_mutex);
```

为了线程安全，访问共享的 `m_tasks` 任务队列时要加锁。


### 📌 8. 遍历任务队列，选择合适的任务

```cpp
auto it = m_tasks.begin();
while (it != m_tasks.end()) {
    if (it->thread != -1 && it->thread != thread_id) {
        it++;
        tickle_me = true;
        continue;
    }

    assert(it->fiber || it->cb);
    task = *it;
    m_tasks.erase(it);
    m_activeThreadCount++;
    break;
}
tickle_me = tickle_me || (it != m_tasks.end());
```

* 遍历 `m_tasks` 队列：
* 如果任务绑定了线程 `it->thread`，而这个线程不是当前 `thread_id`，就跳过。
* 找到符合的任务后，`m_tasks.erase(it)` 从队列中取出，交给 `task` 变量。
* `m_activeThreadCount++`：当前线程要执行任务了，标记它为活跃线程。
* 如果跳过了任务，设置 `tickle_me = true`，意味着需要叫醒其他线程处理。


### 📌 9. 如果需要唤醒其他线程，调用 `tickle()`

```cpp
if (tickle_me) {
    tickle();
}
```

此操作可能向其他线程发送事件或信号，提醒它们可以继续调度任务了（具体实现看 `tickle()` 函数内容）。


### 📌 10. 执行任务（协程或函数）

#### 🚀 10.1 如果任务是一个 Fiber

```cpp
if (task.fiber) {
    {
        std::lock_guard<std::mutex> lock(task.fiber->m_mutex);
        if (task.fiber->getState() != Fiber::TERM) {
            task.fiber->resume();
        }
    }
    m_activeThreadCount--;
    task.reset();
}
```

* 保护该协程对象的内部状态；
* 如果不是 `TERM` 状态，表示协程未结束，就恢复它；
* 执行完后减活跃线程数、清空任务。


#### 🔧 10.2 如果任务是一个回调函数（std::function）

```cpp
else if (task.cb) {
    std::shared_ptr<Fiber> cb_fiber = std::make_shared<Fiber>(task.cb);
    {
        std::lock_guard<std::mutex> lock(cb_fiber->m_mutex);
        cb_fiber->resume();
    }
    m_activeThreadCount--;
    task.reset();
}
```

* 将函数包装成协程执行；
* 这使得普通函数也可以作为调度任务被调度器处理。


###  11. 如果没有任务，执行 idle 协程

```cpp
else {
    if (idle_fiber->getState() == Fiber::TERM) {
        if (debug) std::cout << "Schedule::run() ends in thread: " << thread_id << std::endl;
        break;
    }
    m_idleThreadCount++;
    idle_fiber->resume();
    m_idleThreadCount--;
}
```

* `idle_fiber->resume()`：进入空转状态；
* 如果 idle 协程本身已经执行完毕（`TERM`），说明调度器正在关闭；
* 线程就跳出循环，退出 `run()`。


##  总结流程图

```text
Scheduler::run()
   │
   ├─ 初始化：当前线程设置调度器、创建主协程、idle协程
   │
   └─ 循环：
        │
        ├─ 从任务队列中获取匹配任务（带锁）
        │    └─ 若有其他线程更适合 → tickle()
        │
        ├─ 执行任务：
        │    ├─ task.fiber → resume()
        │    └─ task.cb → 包装成 fiber 后 resume()
        │
        └─ 没任务 → resume idle 协程（空转）
                   └─ idle 协程结束 → 退出 run()
```


# `Scheduler::stop()`

## 🎯 总体目的：

`stop()` 的主要功能：

1. 设置调度器为停止状态；
2. 通知所有调度线程退出等待；
3. 恢复主线程调度协程（若主线程参与调度）；
4. 等待所有线程退出，完成资源清理。


## 🧩 分步详细解释：

### ✅ 1. 打印开始日志（调试用）

```cpp
if(debug) std::cout << "Schedule::stop() starts in thread: " << Thread::GetThreadId() << std::endl;
```

说明当前是哪个线程正在尝试关闭调度器，便于调试。


### ✅ 2. 如果已经可以停止，直接返回

```cpp
if(stopping()) {
    return;
}
```

调用 `stopping()` 检查是否已经在退出流程中：

* `stopping()` 判断：

  * `m_stopping == true`
  * `m_tasks` 队列为空
  * 活跃线程为 0
* 如果已经满足条件，不再重复关闭。

### ✅ 3. 设置标志位 `m_stopping`

```cpp
m_stopping = true;
```

通知调度器准备进入终止状态，防止其他任务再次添加或继续调度。

### ✅ 4. 断言线程归属正确

```cpp
if (m_useCaller) {
    assert(GetThis() == this);
} else {
    assert(GetThis() != this);
}
```

这段代码用于**断言当前线程是否是调度器线程**：

* 如果主线程参与调度（`use_caller = true`），`GetThis()` 应该等于当前调度器；
* 否则（`use_caller = false`），`GetThis()` 不应该等于当前调度器（主线程不是调度器线程）。


### ✅ 5. 通知所有线程（唤醒 idle 协程）

```cpp
for (size_t i = 0; i < m_threadCount; i++) {
    tickle();
}
```

这里是通过 `tickle()` 函数向所有调度线程发信号，**唤醒处于 idle 状态的线程**，让它们去检查是否应该退出。


### ✅ 6. 如果主线程有调度协程，也唤醒它

```cpp
if (m_schedulerFiber) {
    tickle();
}
```

当 `use_caller = true` 时，主线程也有自己的调度协程 `m_schedulerFiber`，它也需要被唤醒。


### ✅ 7. 主线程参与调度：主动 resume 调度协程

```cpp
if(m_schedulerFiber) {
    m_schedulerFiber->resume();
    if(debug) std::cout << "m_schedulerFiber ends in thread:" << Thread::GetThreadId() << std::endl;
}
```

如果主线程参与调度，那它会一直运行在 `m_schedulerFiber` 协程里，因此需要主动恢复该调度协程，**让它退出 `run()` 主循环**，并返回到主线程的主协程。

否则主线程永远卡在 `Scheduler::run()` 里。


### ✅ 8. 等待其他线程退出（线程 join）

```cpp
std::vector<std::shared_ptr<Thread>> thrs;
{
    std::lock_guard<std::mutex> lock(m_mutex);
    thrs.swap(m_threads);
}

for(auto &i : thrs) {
    i->join();
}
```

这一步完成：

* 清空 `m_threads`，并将其内容交换到本地变量 `thrs`；
* 然后调用 `join()` 等待所有工作线程退出；
* 注意：这里不能在持锁状态下 `join()`，避免死锁。

---

### ✅ 9. 打印调度器退出日志

```cpp
if(debug) std::cout << "Schedule::stop() ends in thread:" << Thread::GetThreadId() << std::endl;
```

提示所有线程都已经退出，调度器停止成功。

---

## 🔚 总结流程图：

```text
Scheduler::stop()
 ├── if (stopping()) return;
 ├── m_stopping = true;
 ├── assert(线程归属正确)
 ├── for each thread:
 │     └── tickle() → 唤醒线程
 ├── if (m_schedulerFiber):
 │     ├── tickle()
 │     └── resume() → 退出调度协程
 ├── swap m_threads → join 所有线程
 └── 完成 stop
```


## 🧠 补充说明

### 🔔 为什么要 tickle()？

`tickle()` 的作用是唤醒正在等待的线程，比如 idle 协程正在空转，它必须收到通知才能发现：现在调度器已经准备停机了，赶紧退出。

### 🔔 为什么要 resume() 调度协程？

当主线程也参与调度时，它在 `m_schedulerFiber` 中跑着 `run()` 循环。除非你显式地 `resume()` 这个协程，它不会退出。


# `tickle()和idle()`

你现在的 `idle()` 协程是这样写的：

```cpp
void Scheduler::idle()
{
	while(!stopping())
	{
		if(debug) std::cout << "Scheduler::idle(), sleeping in thread: " << Thread::GetThreadId() << std::endl;	
		sleep(1);	
		Fiber::GetThis()->yield();
	}
}
```

## ✅ 总结这段代码行为：

* 当前线程如果没有可调度任务，就执行 `idle()`；
* 每次 `sleep(1)`，线程会休眠 1 秒，**即使任务已经来了，它也不能马上被唤醒，只能睡醒后再去检查任务**；
* `yield()` 把控制权还给调度器，再次回到 `run()` 函数中调度任务。


## ❓是否需要实现 `tickle()`？

### ✅ 答案：**如果你关心“响应延迟”或“线程调度效率”，**你**非常有必要**实现 `tickle()`。


## 🔍 为什么现在没用 `tickle()` 也能工作？

因为你用了 `sleep(1)`：

* 它会定期醒来检查任务；
* 即使你不主动唤醒它，线程每 1 秒自己醒一次，这叫\*\*“轮询”机制\*\*。

但这带来的问题是：

| 问题        | 描述                                        |
| --------- | ----------------------------------------- |
| ⏱️ 响应延迟   | 有新任务加入时，最多可能要等 1 秒 idle 协程才醒来             |
| 💰 资源浪费   | 线程不是真正空闲，而是周期性 wake-up，影响性能               |
| ⚠️ 多线程不可靠 | 如果所有线程都在 `sleep()`，新任务进来但没人被唤醒，就会卡住直到有人醒来 |


## 🧠 `tickle()` 的作用本质是：

> **不用等线程自己醒来，我直接告诉它醒一醒，有新任务来了！**

如果你改用 `condition_variable` 或 `eventfd` 等机制实现 `tickle()`，就可以做到：

* 新任务一加入；
* 调用 `tickle()` 唤醒某个 idle 线程；
* 它立即退出 `idle()`，开始处理任务；
* 整个调度系统立刻响应，低延迟高效率。


## ✅ 所以结论是：

| 是否建议你实现 `tickle()`？ | **是，强烈建议**                                |
| ------------------- | ----------------------------------------- |
| 你现在能跑？              | ✅ 是的，靠 `sleep()` 和 `yield()` 勉强跑          |
| 效率好吗？               | ❌ 不好，有响应延迟                                |
| 会不会卡住？              | ⚠️ 多线程下可能卡住或响应慢                           |
| 如何优化？               | ✅ 实现 `tickle()` 进行唤醒机制                    |
| 怎么实现？               | 用 `condition_variable`、`eventfd`、`pipe` 等 |


## ✅ Bonus：推荐你使用 `std::condition_variable`

```cpp
// 添加到类中
std::condition_variable m_cv;
std::mutex m_idleMutex;
```

### idle 线程等待：

```cpp
void Scheduler::idle() {
    std::unique_lock<std::mutex> lock(m_idleMutex);
    while (!stopping()) {
        if(debug) std::cout << "Scheduler::idle(): waiting\n";
        m_cv.wait(lock);  // 被 tickle 唤醒
        Fiber::GetThis()->yield();
    }
}
```

### tickle 唤醒：

```cpp
void Scheduler::tickle() {
    if(debug) std::cout << "Scheduler::tickle(): notifying one idle thread\n";
    m_cv.notify_one();
}
```

> 如果此时有任务来了，idle线程如何变为工作线程的。以及，如果idle函数里没有sleep(1)会发什么什么事情

## ❓1. **如果有任务来了，idle 线程如何变为工作线程？**

> 简单说：任务来了 → `tickle()` 发出唤醒信号 → idle 线程退出 `idle()` → 去执行任务。

你当前的 `idle()` 函数是：

```cpp
void Scheduler::idle()
{
	while(!stopping())
	{
		sleep(1);                      // 等 1 秒
		Fiber::GetThis()->yield();     // 放弃 CPU，返回调度器
	}
}
```

### 执行流程如下：

1. 当前线程无任务可执行 → 调度器 `run()` 进入 `idle()` 协程；
2. `idle()` 每轮 `sleep(1)`，休眠 1 秒 → `yield()` 回到调度器主协程；
3. 主协程继续调度，看任务队列里有没有任务；
4. 如果此时 **其他线程添加任务了**，并调用 `tickle()`，就应该唤醒这个线程；
5. 被唤醒的线程重新进入 `run()`，从 `m_tasks` 中取任务，执行；
6. idle 状态 → active 状态 ✅完成状态切换！

> ⚠️ 你现在没有真正的 `tickle()` 实现，所以线程并不会被“及时唤醒”，只能靠 `sleep(1)` 自己醒来检测。

---

## ❓2. 如果 `idle()` 中没有 `sleep(1)` 会发生什么？

你写的是：

```cpp
while (!stopping()) {
    Fiber::GetThis()->yield();
}
```

### 会发生两件关键事情：

#### ✅ 优点：

* idle 协程变成**协程级别的忙等（busy waiting）**；
* 因为 `yield()` 会 `swapcontext()`，让出执行权，这里**不会占用 CPU**；
* 整个线程变成“短暂停歇 → 回调度器看任务 → idle 再 yield”，很快响应任务添加。

#### ⚠️ 缺点：

* **高频率地切换上下文（`swapcontext`）**，CPU 开销变高；
* 会造成**协程调度器的空转频率过高**；
* 即使没有任务，线程也在不停做切换操作，可能对性能有影响。

### 举例说明：

```text
线程空闲 → idle() → yield() → 回到 run() → 没任务 → idle() → yield() → 回到 run() ...
```

这个循环会 **以最快速度跑完一轮又一轮的“检测 + yield”流程**，导致线程实际没做事但 CPU 被浪费了上下文切换。


## ✅ 最推荐的做法：

> 使用阻塞机制 + tickle 唤醒：

```cpp
void Scheduler::idle() {
    std::unique_lock<std::mutex> lock(m_idleMutex);
    while (!stopping()) {
        m_cv.wait(lock);  // 阻塞直到被 tickle 唤醒
        Fiber::GetThis()->yield();
    }
}

void Scheduler::tickle() {
    m_cv.notify_one();  // 通知某个 idle 协程醒来
}
```

这样：

* 没有任务 → idle 协程真的阻塞；
* 有任务 → tickle 唤醒；
* 响应及时，资源高效，性能好。


## ✅ 总结回答你的两个问题：

| 问题                              | 答案                                                  |
| ------------------------------- | --------------------------------------------------- |
| 有任务来了，idle 线程如何变成工作线程？          | 调度器把线程切回主协程 → 检查到新任务 → 执行 resume()，线程进入工作状态         |
| 如果 `idle()` 里没有 `sleep(1)` 会怎样？ | 会进入协程级别的 busy waiting：高频率切换上下文，不占 CPU，但浪费调度性能，效率低下。 |


如你愿意，我可以帮你改造 `idle()` + `tickle()`，让你的调度器变成**支持线程唤醒机制的高性能实现**。是否需要我写一版示例？


