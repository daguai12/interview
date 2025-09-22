## EventLoopThread的作用
`EventLoopThread` 是专门负责创建子线程 + 绑定一个EventLoop的线程类，实现 “一个线程一个EventLoop" 的模型。

- 它会在子线程中创建 `EventLoop`
- 并且提供接口 `startLoop()`，返回子线程中创建的呢个 `EventLoop*` 指针，供主线程调用。

## EventLoopThread成员变量

```c++
public:

using ThreadInitCallback = std::function<void(EventLoop*)>;

private:

EventLoop *loop_;
bool exiting_;
Thread thread_;
std::mutex mutex_;
std::condition_variable cond_;
ThreadInitCallback callback_;

```

- `loop_` 子线程中的 EventLoop 对象
- `exiting_` 标志当前线程是否退出
- `thread_` 线程对象
- `mutex_` 互斥锁，保护 loop_
- `cond_` 条件变量，主线程等待子线程创建好 loop 在返回
- `callback_` 创建好 EventLoop 后的初始化回调函数

## EventLoopThread成员函数

```c++
public:

EventLoopThread(const ThreadInitCallback &cb =    ThreadInitCallback(),
				const std::string &name = std::string());
~EventLoopThread();

EventLoop* startLoop();
private:
    void threadFunc();

```

### startLoop()

```c++
EventLoop* EventLoopThread::startLoop()
{
    thread_.start();

    EventLoop *loop = nullptr;
    {
        std::unique_lock<std::mutex> lock(mutex_);
        while ( loop_ == nullptr )
        {
            cond_.wait(lock);
        }
        loop = loop_;
    }
    return loop;
}
```

- 调用 `thread_.start()` 启动子线程。
- 主线程阻塞等待，知道子线程 `EventLoop` 创建完成并赋值到 `loop_`
- 返回 `loop_`，即子线程中的 `EventLoop*`

### threadFunc()

```cpp
void EventLoopThread::threadFunc()
{
    EventLoop loop;  // ① 子线程里创建一个 EventLoop，和这个线程是一一对应的

    if (callback_)   // ② 如果有用户传入的回调（比如设置一些初始状态）
    {
        callback_(&loop);
    }

    {
        std::unique_lock<std::mutex> lock(mutex_);
        loop_ = &loop;          // ③ 把子线程里创建的 EventLoop 地址赋给成员变量 loop_
        cond_.notify_one();     // ④ 通知主线程 EventLoop 已经创建好了
    }

    loop.loop();  // ⑤ 启动 EventLoop 的事件循环，阻塞在这，处理 I/O 事件、定时器、回调等

    {
        std::unique_lock<std::mutex> lock(mutex_);
        loop_ = nullptr;  // ⑥ 循环退出时，重置 loop_
    }
}
```

#### `EventLoop loop;`

**作用**：
在子线程的栈上创建一个 `EventLoop` 对象，这个 `EventLoop` 就是**这个子线程专属的事件循环**。

* 线程和 `EventLoop` 是一一对应的。
* 创建完成后，这个 `EventLoop` 后续会挂在 `loop.loop()` 上阻塞，等待 I/O 事件、定时器、跨线程回调等。


#### `if (callback_) callback_(&loop);`

**作用**：
如果用户在创建 `EventLoopThread` 时传入了一个回调函数 `ThreadInitCallback`，就在这里执行，参数是刚刚创建好的 `EventLoop*`。

👉 常用场景：

* 在 `EventLoop` 启动事件循环前，做一些初始化操作，比如注册定时器、I/O Channel 等。


#### 

```cpp
{
    std::unique_lock<std::mutex> lock(mutex_);
    loop_ = &loop;
    cond_.notify_one();
}
```

**作用**：

* **加锁保护 `loop_`**，保证主线程/子线程对 `loop_` 的读写互斥安全。
* **将刚创建的 `EventLoop` 地址赋值给 `loop_`**，这个 `loop_` 是 `EventLoopThread` 的成员变量，主线程通过它就能拿到子线程中的 `EventLoop*`。
* **调用 `cond_.notify_one()` 唤醒主线程**，告诉主线程：`EventLoop` 已经创建好了，可以放心用 `startLoop()` 里的 `loop_` 了。

⚠️ 为什么这里需要同步？
→ 因为主线程的 `startLoop()` 里是在等子线程把 `loop_` 赋值完成。

---

####  `loop.loop();`

**作用**：
启动事件循环，开始阻塞，等待：

* I/O 事件
* 定时器超时
* 跨线程回调

只有 `EventLoop::quit()` 被调用时，`loop()` 才会退出，线程继续往下执行。

**注意**：
这是一个**死循环**，除非外部主动调用 `quit()`。

---

#### 

```cpp
{
    std::unique_lock<std::mutex> lock(mutex_);
    loop_ = nullptr;
}
```

**作用**：

* 事件循环退出后，重置 `loop_` 指针，避免悬挂指针。
* 同时确保线程安全，加锁操作。

| 步骤  | 作用                                 |
| :-- | :--------------------------------- |
| 1   | 在子线程里创建 EventLoop                  |
| 2   | 如果有初始化回调，执行它                       |
| 3   | 加锁把 EventLoop 指针赋值给 `loop_`，并通知主线程 |
| 4   | 调用 `loop.loop()` 启动事件循环，阻塞在这里      |
| 5   | 事件循环退出，重置 `loop_`                  |

## 📌 📊 调用顺序图：

```plaintext
主线程：               子线程：
 startLoop()             |
    |                    |
    | --> thread_->start()|
                          |--> threadFunc()
                          |    |
                          |    |--> 创建 EventLoop
                          |    |--> callback_(&loop)
                          |    |--> loop_ = &loop
                          |    |--> cond_.notify_one()
                          |    |--> loop.loop() (阻塞)
    | (等待 cond)
    |<-- cond_.notify_one()
返回 EventLoop*

```
