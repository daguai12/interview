 `struct HookIniter`

你给出的这段代码是 Sylar 框架中 Hook 模块的初始化逻辑，它的核心目的是：

> **在程序 `main()` 执行前，自动调用 `hook_init()` 函数，完成 hook 函数的初始化（比如用 dlsym 获取原始系统调用的地址）。**

---

我们逐行进行详细解释：

---

```cpp
// static variable initialisation will run before the main function
```

✅ 这是一句注释，意思是：

> **C++ 中的全局/静态变量在 `main()` 函数执行之前会被初始化**，且这些初始化按照**定义顺序**执行（在同一个翻译单元内）。

---

```cpp
struct HookIniter
{
	HookIniter()
	{
		hook_init();
	}
};
```

这段代码定义了一个结构体类型 `HookIniter`，它：

* 没有成员变量；
* 定义了一个构造函数，在这个构造函数中调用了 `hook_init()` 函数。

### 🎯 意图：

创建 `HookIniter` 类型对象时，会调用构造函数，从而执行 `hook_init()`。

---

```cpp
static HookIniter s_hook_initer;
```

这行代码创建了一个 **静态全局对象**，名为 `s_hook_initer`，类型是我们刚定义的 `HookIniter`。

因为是 **静态全局变量**，所以它会在 `main()` 之前被初始化。

---

## 🔁 所以完整行为是：

1. 程序启动（`main()` 未开始）；
2. 全局静态对象 `s_hook_initer` 初始化；
3. `s_hook_initer` 的构造函数被调用；
4. `hook_init()` 函数被自动执行；
5. `hook_init()` 会用 `dlsym` 加载所有原始系统调用函数指针；
6. 之后程序中就可以使用 `read_f()`、`write_f()` 等指针来访问真实系统调用。

---

## 🔍 为什么用这种方式？

这种“自动初始化”的写法是 **依赖 static 对象构造顺序特性**：

* 避免开发者手动调用初始化；
* 防止忘记初始化导致崩溃；
* 类似机制也常用于日志库（比如 `static LogIniter g_log_initer`）等。

---

## 🔐 安全提示

由于不同编译单元（.cpp 文件）中的全局对象初始化顺序不固定，因此：

* `hook_init()` 不应依赖其他翻译单元的静态变量；
* 应尽量只依赖 C 标准库或本模块内的资源；

---

## ✅ 总结

| 部分              | 说明                                          |
| --------------- | ------------------------------------------- |
| `HookIniter`    | 定义了一个构造时调用 `hook_init()` 的类型                |
| `s_hook_initer` | 是一个静态全局对象，会在程序启动时初始化                        |
| 作用              | 自动调用 `hook_init()`，初始化原始系统调用函数指针，启用 hook 功能 |


# `struct timer_info`

你给出的这一段代码：

```cpp
struct timer_info 
{
    int cancelled = 0;
};
```

是一个非常简洁的结构体定义，它定义了一个名为 `timer_info` 的结构体，其中只包含一个成员变量：

```cpp
int cancelled = 0;
```

---

## 🧠 它的作用是什么？

这个结构体的核心目的通常是：
**用于协程/异步定时器的取消状态标记。**

也就是说，这个结构体的实例，**通常会作为某个定时器任务的“附加信息”或“共享状态”使用，表示该定时器是否被取消了。**

---

## 🔧 举例说明其使用场景：

我们设想一个协程等待超时的场景，例如 socket 连接带有超时参数：

```cpp
std::shared_ptr<timer_info> tinfo(new timer_info);

auto timer = timer_manager->addTimer(timeout_ms, [tinfo, fiber]() {
    if (tinfo->cancelled) return;
    // resume the fiber if timeout occurs
    scheduler->schedule(fiber);
});
```

如果这时 socket 提前成功连接（没有超时），那么我们可以手动标记：

```cpp
tinfo->cancelled = 1; // 表示这个超时回调已经无效，不应被触发
```

然后在回调触发时就可以判断：

```cpp
if (tinfo->cancelled) return; // 如果已经取消，就直接退出回调
```

---

## ✅ 总结

| 项目   | 内容                                               |
| ---- | ------------------------------------------------ |
| 名称   | `struct timer_info`                              |
| 成员   | `int cancelled = 0;` —— 表示定时器是否被取消（1 = 已取消）      |
| 常见用法 | 配合异步定时器或协程超时机制，用于判断是否还需要执行回调                     |
| 类型   | 通常以 `std::shared_ptr<timer_info>` 形式传递，实现跨回调共享状态 |

# `do_io(...)`


### 函数原型：

```cpp
template<typename OriginFun, typename... Args>
static ssize_t do_io(int fd, OriginFun fun, const char* hook_fun_name, uint32_t event, int timeout_so, Args&&... args)
```

#### 含义逐步解释：

* `template<typename OriginFun, typename... Args>`
  → 这是一个**函数模板**，用于泛化 read/write/recv/send 等多个 IO 系统调用函数。

  * `OriginFun`：原始系统调用函数类型（例如 `read`, `recv`, `send` 等）。
  * `Args...`：变参模板，用于接受任意数量和类型的参数。

* `static ssize_t do_io(...)`
  → 一个静态函数，返回值为 `ssize_t`（有符号字节数），表示 IO 操作的结果（比如成功读取的字节数或失败返回 -1）。

* 参数：

  * `int fd`：文件描述符（socket fd）。
  * `OriginFun fun`：实际执行 IO 的函数指针，比如原始的 `::read`。
  * `const char* hook_fun_name`：该 hook 函数的名字，用于调试输出。
  * `uint32_t event`：期望等待的事件类型（READ/WRITE）。
  * `int timeout_so`：用于指定超时类型，如 SO\_RCVTIMEO 或 SO\_SNDTIMEO。
  * `Args&&... args`：传给系统调用的真实参数，通过完美转发传递。

---

### 第一步：判断是否启用 hook

```cpp
if(!sylar::t_hook_enable) 
{
    return fun(fd, std::forward<Args>(args)...);
}
```

#### 分析：

* `t_hook_enable` 是一个线程局部变量（`thread_local`）：

  * 用于标志是否启用“协程 Hook”机制。
  * 如果关闭了 hook（即当前不是协程环境，或者是普通线程），就直接调用原始系统函数执行，不做任何拦截。
* `fun(...)` 是传入的原始系统调用函数，通过完美转发参数执行。

---

### 第二步：获取 FdCtx（fd 上下文）

```cpp
std::shared_ptr<sylar::FdCtx> ctx = sylar::FdMgr::GetInstance()->get(fd);
if(!ctx) 
{
    return fun(fd, std::forward<Args>(args)...);
}
```

#### 分析：

* 通过 `FdMgr::GetInstance()->get(fd)` 获取 `fd` 对应的上下文 `FdCtx` 对象。
* 若获取失败（返回空指针），说明该 fd 无法管理或无效，直接执行原始系统函数。

---

### 第三步：检查 fd 的状态

```cpp
if(ctx->isClosed()) 
{
    errno = EBADF;
    return -1;
}
```

#### 分析：

* 若该 `fd` 已经被关闭（`isClosed()` 返回 true），那么直接返回错误：

  * 设置 `errno` 为 `EBADF`（Bad file descriptor）。
  * 返回 `-1` 表示系统调用失败。

---

### 第四步：判断是否需要 hook 当前调用

```cpp
if(!ctx->isSocket() || ctx->getUserNonblock()) 
{
    return fun(fd, std::forward<Args>(args)...);
}
```

#### 分析：

* 若该 `fd`：

  * 不是一个 socket（可能是普通文件，管道等），
  * 或者是用户主动设置为非阻塞的 fd（user-nonblock），
* 则不 hook，直接执行系统调用。

这段是为了**避免对不需要 hook 的场景（如非 socket fd）进行干扰**。

---

### 第五步：获取超时时间

```cpp
uint64_t timeout = ctx->getTimeout(timeout_so);
```

#### 分析：

* 从 `FdCtx` 中获取该 IO 类型对应的超时时间：

  * `timeout_so` 传入的是 `SO_RCVTIMEO` 或 `SO_SNDTIMEO`。
  * 返回的是以毫秒为单位的超时时间（uint64\_t）。

---

### 第六步：创建一个 timer\_info 用于记录取消状态

```cpp
std::shared_ptr<timer_info> tinfo(new timer_info);
```

#### 分析：

* `timer_info` 是一个简单结构体，包含一个 `cancelled` 标志：

  * 初始为 `0`，表示未取消。
  * 若被定时器取消，则设为 `ETIMEDOUT`。

---

### 第七步：第一次尝试系统调用

```cpp
retry:
ssize_t n = fun(fd, std::forward<Args>(args)...);
```

#### 分析：

* 使用 `goto retry:` 标签，尝试调用实际的 IO 系统函数。

```cpp
while(n == -1 && errno == EINTR) 
{
    n = fun(fd, std::forward<Args>(args)...);
}
```

* 若返回值是 `-1` 且 `errno == EINTR`（被信号中断），则重试系统调用。

---

下一步我们将详细解释 **等待事件就绪的机制（epoll注册、协程挂起、定时器取消）**，继续输出👇


接下来继续解释 `do_io` 中最核心的部分：**事件就绪等待机制、定时器处理、协程挂起与恢复逻辑**。

---

### 第八步：判断是否需要等待 IO 准备好（例如 EAGAIN）

```cpp
if(n == -1 && errno == EAGAIN) 
```

#### 含义：

* `EAGAIN` 表示资源暂时不可用，当前 fd 没有准备好读/写：

  * 对于非阻塞 IO，通常会出现这种情况。
  * 这种情况下我们不能返回失败，而应该将当前协程挂起，等待事件触发（READ/WRITE 就绪）。

---

### 第九步：获取当前 IOManager 实例

```cpp
sylar::IOManager* iom = sylar::IOManager::GetThis();
```

* 获取当前线程绑定的 `IOManager` 实例，用于注册 IO 事件。
* `IOManager` 是调度器 Scheduler 的子类，具备协程调度和 IO 事件管理能力。

---

### 第十步：添加定时器（用于超时取消）

```cpp
std::shared_ptr<sylar::Timer> timer;
std::weak_ptr<timer_info> winfo(tinfo);

if(timeout != (uint64_t)-1) 
{
    timer = iom->addConditionTimer(timeout, [winfo, fd, iom, event]() 
    {
        auto t = winfo.lock();
        if(!t || t->cancelled) 
        {
            return;
        }

        t->cancelled = ETIMEDOUT;

        iom->cancelEvent(fd, (sylar::IOManager::Event)(event));
    }, winfo);
}
```

#### 逐步解释：

1. 构造 `weak_ptr` 是为了避免闭包中的 shared\_ptr 形成循环引用。
2. 若设置了超时时间（不是 `(uint64_t)-1`）：

   * 添加一个 **条件定时器**，绑定 `winfo` 条件。
   * 到达超时时间后，执行 lambda：

     * 如果 `timer_info` 未被取消（`cancelled == 0`），将其设置为超时错误码 `ETIMEDOUT`。
     * 调用 `IOManager::cancelEvent()`，触发 epoll 事件，使协程唤醒。
     * 此时 `do_io` 下面的 `yield()` 处的协程就会恢复。

这段代码是实现超时控制的关键。

---

### 第十一步：注册事件到 epoll 并将当前协程挂起

```cpp
int rt = iom->addEvent(fd, (sylar::IOManager::Event)(event));
```

* 调用 `IOManager::addEvent()`：

  * 将 `fd` 与事件类型（READ/WRITE）注册到 epoll。
  * 注册成功后，**会将当前协程绑定到该事件**。

```cpp
if(rt) 
{
    std::cout << hook_fun_name << " addEvent("<< fd << ", " << event << ")";
    if(timer) 
    {
        timer->cancel();
    }
    return -1;
}
```

* 如果注册失败（如 fd 无效），取消定时器并直接返回失败。

---

### 第十二步：协程让出执行权，挂起等待事件

```cpp
sylar::Fiber::GetThis()->yield();
```

* 当前协程挂起，等待 `fd` 对应的事件触发或超时定时器触发。
* 等事件回来后，IOManager 调度器会重新唤醒该协程并恢复执行。

---

### 第十三步：恢复后处理取消状态

```cpp
if(timer) 
{
    timer->cancel();
}
```

* 协程恢复后，需要手动取消定时器，避免重复触发。

```cpp
if(tinfo->cancelled == ETIMEDOUT) 
{
    errno = tinfo->cancelled;
    return -1;
}
```

* 如果是被定时器唤醒（超时），则设置 `errno = ETIMEDOUT`，返回失败。

```cpp
goto retry;
```

* 否则不是超时，而是 IO 就绪，**重新调用系统函数执行 IO**，再次进入 `retry:` 标签处，重试系统调用。

---

### 第十四步：最终返回

```cpp
return n;
```

* 成功执行 IO 后，返回结果字节数。

---

### 总结（流程图风格）：

```text
                 ↓
   [是否启用hook?]——→ 否 → 原始系统函数
                 ↓
     [FdCtx是否有效?] → 否 → 原始系统函数
                 ↓
    [是否关闭 or 非socket?] → 是 → 原始系统函数
                 ↓
        ↓↓↓ 真正hook ↓↓↓
   执行系统函数 fun(fd, args...)
                 ↓
   [errno == EAGAIN?] ——→ 否 → 直接返回
                 ↓
     添加 IOManager 事件监听
                 ↓
     添加定时器（如果需要）
                 ↓
      协程 yield() 主动让出
                 ↓
       [唤醒后：是否超时?]
         ↓              ↓
       是               否
     设置 errno     重新 retry
       返回-1        尝试系统调用
```

如你还有 `addEvent()`、`cancelEvent()`、`yield()` 或 `addConditionTimer()` 的源码，我可以继续向下详细剖析调用链。

是否需要我帮你画出整个 do\_io 的协程控制流图？还是继续解析其它 Hook 实现函数？


# `sleep(unsigned int seconds)`

## 🔧 函数原型

```cpp
unsigned int sleep(unsigned int seconds)
```

这是对标准库函数 `::sleep(seconds)` 的“Hook版本”，其目的是：

> **将 sleep 转为“非阻塞的协程定时挂起”，从而不阻塞线程，提升并发性能。**

它本质上是用 `IOManager` + `Timer` + `协程切换机制` 来“模拟 sleep”，替代原本阻塞线程的行为。

---

## 🔍 第一部分：判断是否启用 hook

```cpp
if(!sylar::t_hook_enable)
{
    return sleep_f(seconds);
}
```

### 解释：

* `sylar::t_hook_enable` 是一个线程局部变量（`thread_local bool`），表示当前线程是否启用了协程 hook。
* 如果没有启用 hook：

  * 就直接调用原始的系统函数 `sleep_f()`（这是 `::sleep()` 的原始函数指针）。
  * `sleep_f(seconds)`：会真正阻塞当前线程 `seconds` 秒。
* ⚠️ 若不加判断，普通线程也走协程逻辑会出错（因为没有协程环境）。

---

## 🔍 第二部分：获取当前协程对象

```cpp
std::shared_ptr<sylar::Fiber> fiber = sylar::Fiber::GetThis();
```

### 解释：

* `Fiber::GetThis()`：返回当前运行的协程（Fiber）对象。
* `std::shared_ptr<sylar::Fiber>`：我们需要持有该协程的智能指针，使其在挂起期间不会被释放。
* ⚠️ 此时该协程即将挂起一段时间，因此我们必须确保调度器还能够在之后重新唤醒它。

---

## 🔍 第三部分：获取 IOManager 调度器

```cpp
sylar::IOManager* iom = sylar::IOManager::GetThis();
```

### 解释：

* `IOManager::GetThis()`：获取当前线程绑定的 IOManager 实例。
* IOManager 是 `Scheduler` 的子类，支持：

  * 协程调度。
  * 事件驱动（epoll/kqueue）。
  * 定时器机制。
* 我们将用 IOManager 来注册定时器，在超时后唤醒当前协程。

---

## 🔍 第四部分：添加一个定时器来唤醒当前协程

```cpp
iom->addTimer(seconds*1000, [fiber, iom](){iom->scheduleLock(fiber, -1);});
```

### 解释：

这是整段代码的核心逻辑，用协程调度器的定时器来模拟 `sleep`，具体含义如下：

#### 参数1: `seconds * 1000`

* 表示定时时长，单位为毫秒。
* 因为 `addTimer()` 接收的是毫秒，所以将 `seconds` 乘以 1000。

#### 参数2: Lambda 回调 `[fiber, iom](){ ... }`

```cpp
[fiber, iom](){ iom->scheduleLock(fiber, -1); }
```

* 闭包中捕获当前协程 `fiber` 和调度器 `iom`。
* 定时器触发后调用：

  * `iom->scheduleLock(fiber, -1);`
  * 这表示：将该协程重新放入调度器任务队列中，准备恢复运行。

#### `scheduleLock(fiber, -1)` 是什么？

* 作用：线程安全地将协程 `fiber` 放入任务队列。
* `-1` 表示不限目标线程，让 IOManager 自行决定分配哪个线程来执行。

#### 总结：

> 💡 这段代码的意思是：
>
> "我现在设置一个定时器 `X秒后触发`，触发时把当前协程扔回调度器队列，等待运行。"

---

## 🔍 第五部分：当前协程主动让出 CPU

```cpp
fiber->yield();
```

### 解释：

* `yield()` 的作用是：让当前协程主动挂起，进入就绪态（`READY`），暂停运行。
* 它不会销毁协程，而是挂起等待调度器下一次恢复。

那么下一次什么时候恢复它？

👉 就是在定时器回调中调用 `scheduleLock(fiber)` 后，它会被重新调度器恢复并运行。

---

## 🔚 第六部分：函数返回

```cpp
return 0;
```

### 解释：

* 和原始 `sleep()` 保持一致：返回值为剩余时间（秒）。
* 这里固定返回 0，代表没有被信号中断提前唤醒（如果要模拟中断返回可自行扩展）。

---

## ✅ 总结逻辑流程（图解）

```text
if(!hook_enable)
    ↓
 原始 sleep(seconds)
 阻塞线程 X 秒
-------------------------
else
    ↓
 获取当前协程 Fiber
 获取当前调度器 IOManager
 创建定时器 seconds 秒后执行:
     scheduleLock(fiber)
 当前协程 yield 挂起
    ↓↓↓
X 秒后回调被触发
   协程被重新调度运行
    ↓↓↓
sleep 返回 0
```

---

## 🧠 技术亮点

* 将阻塞 sleep → 转换为协程级挂起。
* 不影响线程的调度能力，可同时运行成百上千个协程。
* Hook 框架下核心“协程 + IOManager + 定时器”调度设计。


# `socket(int domain, int type,int protocol)`

我们来**逐行详细分析**这个 Hook 后的 `socket` 函数实现，保持与你之前要求一致的风格 —— **不省略任何代码、解释每一个变量、分析每一步设计意图**，即使需要多次输出也会完整讲清楚。

---

### 📌 函数签名

```cpp
int socket(int domain, int type, int protocol)
```

该函数是对系统调用 `::socket()` 的“Hook版本”。

目的在于：

> ✅ 在创建 socket 的同时，**记录和管理 fd 的元信息**，如：是否为 socket、是否关闭、是否是非阻塞等，以便协程调度器（IOManager）进行 IO hook、事件管理和非阻塞 IO 操作。

---

## 🔍 第一步：是否启用 hook

```cpp
if(!sylar::t_hook_enable)
{
    return socket_f(domain, type, protocol);
}
```

### ✨ 解释：

* `sylar::t_hook_enable`：这是一个线程局部变量（`thread_local bool`），表示当前线程是否启用了协程 Hook 功能。

  * 当 `false`：表示不能进行协程层的 IO 管理，回退原始行为。
* `socket_f(...)`：指向原生 `::socket()` 的函数指针，保存于全局变量中（避免递归调用 hook）。

🧠 **设计目的：**

当程序运行在普通线程上下文时（无协程环境），直接调用原生系统函数，不引入协程管理。

---

## 🔍 第二步：调用原始 socket 函数创建套接字

```cpp
int fd = socket_f(domain, type, protocol);
```

### ✨ 解释：

* 调用原生的 `::socket()` 系统调用创建 socket。
* 返回值 `fd` 为新创建的文件描述符（socket）。

可能的失败场景：

* 参数错误：如 `domain`, `type`, `protocol` 不匹配；
* 系统资源不足；
* 打开文件数量超过上限等。

---

## 🔍 第三步：判断是否创建成功

```cpp
if(fd==-1)
{
    std::cerr << "socket() failed:" << strerror(errno) << std::endl;
    return fd;
}
```

### ✨ 解释：

* 检查 `fd == -1`：表示 socket 创建失败。
* `strerror(errno)`：将系统错误码转为可读字符串。
* 直接输出错误日志，返回错误的 `-1`。

🧠 **注意：**

> Hook 函数也必须保留原始语义：失败时 `errno` 会设置，返回 -1。

---

## 🔍 第四步：注册 fd 上下文到 FdManager

```cpp
sylar::FdMgr::GetInstance()->get(fd, true);
```

### ✨ 解释：

* 这一步是 Hook 的 **核心补充行为**：对新建的 fd，建立 `FdCtx` 管理对象。

* `sylar::FdMgr::GetInstance()`：

  * 获取全局的 `FdManager` 单例对象。

* `.get(fd, true)`：

  * 查找或创建与 fd 相关的 `FdCtx`。
  * `true` 表示：如果没有，就创建（`auto_create == true`）。

---

## 🧠 为什么要这样做？

`FdCtx` 对象是对 **文件描述符（fd）** 的封装，记录了如下关键信息：

* 该 fd 是否是 socket；
* 是否处于非阻塞模式（系统/用户）；
* 超时时间（读/写）；
* 是否关闭；
* fd 初始化状态等。

这些信息在后续的 `read` / `write` / `connect` 等 IO 函数中都需要依赖：

> 如果 fd 是 socket，且是阻塞的，就可以通过协程挂起来进行 IO 等待（非阻塞式 IO + epoll 管理）。

---

## 🔚 第五步：返回文件描述符

```cpp
return fd;
```

* 成功创建 socket 后，返回文件描述符 `fd`。
* 后续 read/write/connect 等 IO 操作可以继续使用该 fd。

---

## ✅ 总结流程图

```text
调用 socket(domain, type, protocol)
   ↓
是否启用 hook？
 ├─ 否：直接调用系统 socket_f()，返回 fd
 └─ 是：
      ↓
   调用 socket_f() -> 得到 fd
      ↓
   若失败（fd == -1），打印错误并返回 -1
      ↓
   调用 FdMgr->get(fd, true)
     -> 创建 FdCtx 管理该 fd（如 socket 类型、非阻塞设置等）
      ↓
   返回该 fd
```

---

## 📎 关键技术设计总结：

| 技术点                        | 说明                                             |
| -------------------------- | ---------------------------------------------- |
| `t_hook_enable`            | 控制是否启用协程 Hook                                  |
| `socket_f`                 | 原始系统 socket 函数的指针                              |
| `FdManager::get(fd, true)` | 管理 socket 元信息，便于协程 IO hook                     |
| 非阻塞 IO                     | 后续操作（read/write）将结合 epoll + 协程 yield 来实现高性能 IO |

# `connect_with_timeout()`

下面是对你提供的 `connect_with_timeout` 函数的**逐行详细解释**，本函数位于 Sylar 框架中的 Hook 模块中，作用是 **替代原始的 `connect()` 调用，并为其添加超时机制与协程调度控制**。

---

### 函数签名

```cpp
int connect_with_timeout(int fd, const struct sockaddr* addr, socklen_t addrlen, uint64_t timeout_ms)
```

* `fd`：要连接的 socket 文件描述符。
* `addr`：远程地址结构体指针。
* `addrlen`：地址结构体的长度。
* `timeout_ms`：连接的超时时间（单位：毫秒）。

---

### 第一步：Hook 控制判断

```cpp
if(!sylar::t_hook_enable) 
{
    return connect_f(fd, addr, addrlen);
}
```

* `sylar::t_hook_enable` 是一个线程局部变量，控制是否启用 hook 功能。
* 如果未启用 hook（比如当前线程未启用协程调度器），则直接调用系统原始 `connect` 函数（`connect_f` 是 `connect` 的原始函数指针备份）。

---

### 第二步：获取并检查 Fd 上下文

```cpp
std::shared_ptr<sylar::FdCtx> ctx = sylar::FdMgr::GetInstance()->get(fd);
if(!ctx || ctx->isClosed()) 
{
    errno = EBADF;
    return -1;
}
```

* `FdMgr::GetInstance()->get(fd)`：获取 fd 对应的 `FdCtx` 管理结构。
* 若 `ctx` 不存在或该 fd 已被关闭，则返回错误 `EBADF`（Bad file descriptor）。

---

### 第三步：非 socket 类型判断

```cpp
if(!ctx->isSocket()) 
{
    return connect_f(fd, addr, addrlen);
}
```

* 如果当前 `fd` 不是一个 socket（例如可能是普通文件或管道），不做 hook，直接调用原始 `connect`。

---

### 第四步：用户主动设置了非阻塞，直接连接

```cpp
if(ctx->getUserNonblock()) 
{
    return connect_f(fd, addr, addrlen);
}
```

* 若用户设置了非阻塞模式（`userNonblock = true`），代表用户自己希望处理 EAGAIN 等行为，此时 Sylar 不插手，交回给系统。

---

### 第五步：尝试连接

```cpp
int n = connect_f(fd, addr, addrlen);
if(n == 0) 
{
    return 0;
}
else if(n != -1 || errno != EINPROGRESS) 
{
    return n;
}
```

* `connect` 成功返回 `0`。
* 若失败但错误码不是 `EINPROGRESS`（即连接还在进行中），直接返回错误。
* 只有 `errno == EINPROGRESS` 才进入 IO 协程挂起处理。

---

### 第六步：准备协程事件调度控制

```cpp
sylar::IOManager* iom = sylar::IOManager::GetThis();
std::shared_ptr<sylar::Timer> timer;
std::shared_ptr<timer_info> tinfo(new timer_info);
std::weak_ptr<timer_info> winfo(tinfo);
```

* 获取当前线程的 IOManager 协程调度器实例。
* 创建一个 `timer_info` 对象，用于记录当前连接是否因超时被取消。
* `winfo` 是 `tinfo` 的弱引用，用于绑定到定时器里。

---

### 第七步：设置超时取消回调（如果设置了 timeout）

```cpp
if(timeout_ms != (uint64_t)-1) 
{
    timer = iom->addConditionTimer(timeout_ms, [winfo, fd, iom]() 
    {
        auto t = winfo.lock();
        if(!t || t->cancelled) 
        {
            return;
        }
        t->cancelled = ETIMEDOUT;
        iom->cancelEvent(fd, sylar::IOManager::WRITE);
    }, winfo);
}
```

* 如果设置了超时时间，则添加一个定时器。
* 定时器超时后：

  * 设置 `tinfo->cancelled = ETIMEDOUT`。
  * 调用 `IOManager::cancelEvent()` 来中断挂起的协程。

---

### 第八步：添加 WRITE 事件，挂起当前协程

```cpp
int rt = iom->addEvent(fd, sylar::IOManager::WRITE);
if(rt == 0) 
{
    sylar::Fiber::GetThis()->yield();
```

* 将 `WRITE` 事件添加到 epoll 中。
* 当前协程进入挂起状态，等待事件触发。

---

### 第九步：协程恢复后，清理定时器，并处理超时结果

```cpp
    if(timer) 
    {
        timer->cancel();
    }

    if(tinfo->cancelled) 
    {
        errno = tinfo->cancelled;
        return -1;
    }
```

* 如果定时器还存在，取消它（事件触发成功）。
* 若超时取消了事件，`tinfo->cancelled` 被设置为 `ETIMEDOUT`，设置 `errno` 并返回错误。

---

### 第十步：事件添加失败的处理

```cpp
} 
else 
{
    if(timer) 
    {
        timer->cancel();
    }
    std::cerr << "connect addEvent(" << fd << ", WRITE) error";
}
```

* 如果事件添加失败（`addEvent != 0`），则取消定时器并打印错误日志。

---

### 第十一步：检查连接结果（重要）

```cpp
int error = 0;
socklen_t len = sizeof(int);
if(-1 == getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len)) 
{
    return -1;
}
if(!error) 
{
    return 0;
} 
else 
{
    errno = error;
    return -1;
}
```

* 通过 `getsockopt(fd, SOL_SOCKET, SO_ERROR)` 查询连接结果。
* 若 `error==0`，表示连接成功。
* 否则连接失败，返回对应错误。

---

### 小结

| 步骤   | 功能                |
| ---- | ----------------- |
| 1\~4 | 检查 hook 状态、fd 合法性 |
| 5    | 调用原始 connect      |
| 6\~7 | 若阻塞，设置定时器、协程挂起等待  |
| 8\~9 | 事件完成后恢复协程，判断超时与否  |
| 10   | 异常日志输出            |
| 11   | 判断连接结果            |

# `accept()`

我们来对 Sylar 框架中的 `accept()` 函数进行**逐行逐句的详细解释**，涵盖其核心逻辑、设计动机、与协程调度和 fd 管理的结合方式。

---

## 📌 函数定义

```cpp
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen)
```

* 这是用户态替代的 `accept()` 实现。
* 参数与标准 `accept()` 系统调用一致。

  * `sockfd`：监听 socket 文件描述符。
  * `addr` / `addrlen`：用于接收客户端连接地址信息。

---

## ✅ 第一步：调用通用 IO Hook 处理模板 `do_io`

```cpp
int fd = do_io(sockfd, accept_f, "accept", sylar::IOManager::READ, SO_RCVTIMEO, addr, addrlen);
```

这行代码调用了 Sylar 框架中**封装的通用 IO 操作函数模板** `do_io<>()`，目的是统一管理所有带超时、非阻塞控制的 IO 函数行为。

### 参数逐一解释：

| 参数                       | 说明                                                      |
| ------------------------ | ------------------------------------------------------- |
| `sockfd`                 | 我们监听的 socket fd，即被 `epoll` 监听的描述符。                      |
| `accept_f`               | 原始的 `accept` 系统调用函数指针（通过 dlsym 保存的）                     |
| `"accept"`               | 当前 Hook 的函数名，传给 `do_io` 打日志使用。                          |
| `sylar::IOManager::READ` | 需要监听 `READ` 事件，表示等待有新连接到来。                              |
| `SO_RCVTIMEO`            | 获取接收数据超时（`recv timeout`）的 socket 选项键，控制 `accept` 的等待时长。 |
| `addr`, `addrlen`        | 原始参数传入，用于接收新连接地址。通过完美转发传入原始的系统调用中。                      |

> ⚠️ 注意：
> `do_io()` 内部逻辑会：
>
> * 判断是否启用了 hook。
> * 检查 `fd` 是否为 socket，是否已非阻塞。
> * 若需要阻塞且设置了超时，会用 `IOManager` 添加事件监听并挂起当前协程。
> * 若 IO 准备好或超时取消，将自动恢复当前协程并返回结果。

---

## ✅ 第二步：如果 `accept` 成功，新 fd 注册到 fd 管理器中

```cpp
if(fd >= 0)
{
    sylar::FdMgr::GetInstance()->get(fd, true);
}
```

* `accept()` 成功后，返回的新 socket fd 是服务端用来和客户端通信的连接 fd。
* 为了确保该连接 fd 后续也能被协程调度器统一管理（包括非阻塞处理、超时控制等），我们：

  ```cpp
  sylar::FdMgr::GetInstance()->get(fd, true);
  ```

  调用 `FdManager::get(fd, true)`：

  * 若不存在对应的 `FdCtx`，则自动创建（`auto_create = true`）。
  * 初始化后会：

    * 设置 fd 为非阻塞。
    * 记录是否为 socket。
    * 初始化读/写超时时间等。

---

## ✅ 第三步：返回结果

```cpp
return fd;
```

* 返回 `accept()` 的结果 fd（新连接的 fd）。
* 如果中间失败了（比如超时、EAGAIN），`do_io()` 会设置 `errno` 并返回 `-1`，上层根据 `errno` 处理即可。

---

## ✅ 总结与设计价值

| 步骤 | 操作                  | 说明                       |
| -- | ------------------- | ------------------------ |
| ①  | 使用 `do_io` 封装 IO 操作 | 自动挂起协程等待事件完成，支持超时取消      |
| ②  | 对新连接的 fd 做统一管理      | 通过 `FdCtx` 配合协程支持非阻塞与定时器 |
| ③  | 返回标准系统调用接口风格        | 完全兼容标准 `accept()` 的调用方式  |

---

## ✅ 拓展思考

* 该 Hook 实现使得阻塞的 `accept()` 在协程中**非阻塞运行**，不再占用线程资源。
* 若监听 socket 处于 **非阻塞模式 + 没有新连接**，那么协程会挂起在 `epoll_wait` 上，由 `IOManager` 负责调度恢复。
* 用户不用关注这些细节，调用方式和标准库一样，但效率却是协程级别的。

---


# `close(int fd)`

这个 `close()` 是 Sylar 协程系统下的 **文件描述符关闭 Hook 实现**，目的是在你关闭一个 fd 时，同时清理掉所有与这个 fd 相关的协程事件监听、超时、状态记录等内容。

## 🔧 函数原型

```cpp
int close(int fd)
```

和标准 POSIX 的 `close()` 一样，用于关闭一个文件描述符 `fd`。

---

## ✅ 1. 判断是否启用 Hook 功能

```cpp
if(!sylar::t_hook_enable)
{
    return close_f(fd);
}
```

### 解释：

* `sylar::t_hook_enable` 是线程局部变量（`thread_local bool`），用于指示当前线程是否启用了 Hook。
* 如果未启用 Hook，说明当前不是在协程环境中，直接调用系统原始 `close()` 函数（保存在 `close_f` 中）。
* 这个函数是通过 `dlsym(RTLD_NEXT, "close")` 获取的原始函数指针，用于绕过当前 Hook 层。

---

## ✅ 2. 通过 Fd 管理器获取 fd 的上下文

```cpp
std::shared_ptr<sylar::FdCtx> ctx = sylar::FdMgr::GetInstance()->get(fd);
```

### 解释：

* 获取当前 `fd` 对应的 `FdCtx`（fd 上下文对象）。
* `FdCtx` 是 Sylar 中用于记录每个 fd 的各种状态（是否 socket、是否关闭、是否非阻塞、超时设置等）。
* 若找不到，则说明该 `fd` 没被托管，无需特殊清理。

---

## ✅ 3. 取消所有相关的协程事件监听（如 IO/定时器）

```cpp
if(ctx)
{
    auto iom = sylar::IOManager::GetThis();
    if(iom)
    {	
        iom->cancelAll(fd);
    }
```

### 解释：

* 若 fd 管理上下文存在，说明可能还挂着一些协程事件（如协程等待 `read`、`write`、`accept`、`connect` 的事件等）。
* 获取当前线程绑定的 `IOManager` 协程调度器。
* 调用 `IOManager::cancelAll(fd)`：

  * 从 `epoll` 中移除所有关于该 fd 的事件。
  * 唤醒那些等待该 fd 的协程，并设置错误状态（如 `ECANCELED` 或用户自定义错误码）。

#### ✅ 设计意义：

* 防止协程在你已经关闭 fd 后，还在等待它的读写事件。
* 非常关键的资源释放保障逻辑，避免**悬空协程**或死锁。

---

## ✅ 4. 删除 fd 管理信息

```cpp
    sylar::FdMgr::GetInstance()->del(fd);
}
```

### 解释：

* 无论是否有调度器都要清理 fd 状态。
* `FdMgr::del(fd)` 会从 `FdManager::m_datas` 中清除该 `FdCtx` 智能指针，释放内存。

---

## ✅ 5. 最终关闭 fd

```cpp
return close_f(fd);
```

* 使用原始系统调用 `close()` 真正关闭 fd。
* **Hook 函数最终都应调用系统函数完成本职工作**。

---

## 🔁 总结整个执行流程

| 步骤 | 操作           | 说明                        |
| -- | ------------ | ------------------------- |
| 1  | 判断是否启用 Hook  | 若未启用则不做协程事件处理             |
| 2  | 获取 Fd 上下文    | 如果 fd 被 Sylar 管理，则继续清理    |
| 3  | 取消所有协程事件     | `cancelAll(fd)` 取消调度器中的事件 |
| 4  | 删除 fd 状态记录   | `FdMgr` 中清除该 fd 的上下文      |
| 5  | 调用原始 close() | 真正关闭系统文件描述符               |

---

## 📌 设计价值总结

该 Hook 函数相比原生 `close()`：

* 加入了对协程系统中的 IO 事件的清理。
* 确保资源释放的正确性，避免协程泄漏、`epoll` 残留、fd 重用错误。
* 是协程 IO 系统健壮性的核心部分。


# `fnctl()`

## 🌟 函数整体结构

```cpp
int fcntl(int fd, int cmd, ... /* arg */ )
```

* 函数签名：hook 版本的 `fcntl` 函数，使用可变参数（`...`）来支持 `fcntl` 的不同命令需要不同参数的语义。
* 参数：

  * `fd`：文件描述符。
  * `cmd`：控制命令（如 `F_GETFL`、`F_SETFL` 等）。
  * `...`：对应 `cmd` 的参数，可能是 `int`、`struct flock*` 等。

---

### 👇 开始处理参数

```cpp
va_list va;
va_start(va, cmd);
```

* `va_list` 是 C/C++ 的处理可变参数的方式。
* `va_start` 用来初始化 `va`，为后续 `va_arg()` 做准备。

---

## 🌟 主体部分：处理不同的 `cmd` 命令

---

### 1️⃣ `F_SETFL`：设置文件状态标志（如非阻塞）

```cpp
case F_SETFL:
{
    int arg = va_arg(va, int);
    va_end(va);
```

* 读取参数：这个命令的参数类型是 `int`，表示新的 flag。

```cpp
    std::shared_ptr<sylar::FdCtx> ctx = sylar::FdMgr::GetInstance()->get(fd);
```

* 获取该 `fd` 对应的 `FdCtx` 上下文对象，用于管理 IO Hook 的状态。

```cpp
    if(!ctx || ctx->isClosed() || !ctx->isSocket()) 
    {
        return fcntl_f(fd, cmd, arg);
    }
```

* 若没有对应的上下文，或者已关闭、非 socket 类型，就直接调用原始系统函数。

```cpp
    ctx->setUserNonblock(arg & O_NONBLOCK);
```

* 用户希望设置非阻塞，则记录下来（不修改系统，只是记录意图）。

```cpp
    if(ctx->getSysNonblock()) 
    {
        arg |= O_NONBLOCK;
    } 
    else 
    {
        arg &= ~O_NONBLOCK;
    }
```

* 这里决定**最终传入系统的行为**：

  * 如果系统是强制非阻塞（`sysNonblock=true`），确保系统调用也非阻塞。
  * 否则（比如非 socket），就不要带上 `O_NONBLOCK`。

```cpp
    return fcntl_f(fd, cmd, arg);
}
```

* 最终调用原始系统函数。

---

### 2️⃣ `F_GETFL`：获取文件状态标志

```cpp
case F_GETFL:
{
    va_end(va);
    int arg = fcntl_f(fd, cmd);
```

* 获取当前系统设定的标志位。

```cpp
    std::shared_ptr<sylar::FdCtx> ctx = sylar::FdMgr::GetInstance()->get(fd);
    if(!ctx || ctx->isClosed() || !ctx->isSocket()) 
    {
        return arg;
    }
```

* 同样，若无效 `FdCtx`，直接返回原始结果。

```cpp
    if(ctx->getUserNonblock()) 
    {
        return arg | O_NONBLOCK;
    } 
    else 
    {
        return arg & ~O_NONBLOCK;
    }
}
```

* 关键点是：**返回给用户的是用户设置的状态**，不一定是系统真实状态。

  * 这就实现了 hook 的“伪装”效果，用户看到自己设置的 flag。

---

### 3️⃣ 其他只带一个 `int` 参数的命令

```cpp
case F_DUPFD:
case F_DUPFD_CLOEXEC:
case F_SETFD:
case F_SETOWN:
case F_SETSIG:
case F_SETLEASE:
case F_NOTIFY:
#ifdef F_SETPIPE_SZ
case F_SETPIPE_SZ:
#endif
```

```cpp
{
    int arg = va_arg(va, int);
    va_end(va);
    return fcntl_f(fd, cmd, arg); 
}
```

* 获取 `int` 参数，直接调用原始函数。

---

### 4️⃣ 无参数命令

```cpp
case F_GETFD:
case F_GETOWN:
case F_GETSIG:
case F_GETLEASE:
#ifdef F_GETPIPE_SZ
case F_GETPIPE_SZ:
#endif
```

```cpp
{
    va_end(va);
    return fcntl_f(fd, cmd);
}
```

* 无额外参数，直接调用。

---

### 5️⃣ 参数为 `struct flock*`

```cpp
case F_SETLK:
case F_SETLKW:
case F_GETLK:
{
    struct flock* arg = va_arg(va, struct flock*);
    va_end(va);
    return fcntl_f(fd, cmd, arg);
}
```

---

### 6️⃣ 参数为 `struct f_owner_exlock*`

```cpp
case F_GETOWN_EX:
case F_SETOWN_EX:
{
    struct f_owner_exlock* arg = va_arg(va, struct f_owner_exlock*);
    va_end(va);
    return fcntl_f(fd, cmd, arg);
}
```

---

### 7️⃣ 默认处理

```cpp
default:
    va_end(va);
    return fcntl_f(fd, cmd);
```

---

## ✅ 总结

| 功能                       | 实现作用                                    |
| ------------------------ | --------------------------------------- |
| `F_SETFL`, `F_GETFL`     | 拦截设置/获取非阻塞标志，结合协程调度                     |
| 其他命令                     | 按类型透传给原始系统 `fcntl`                      |
| `FdCtx` 与 `FdManager` 集成 | 管理 `fd` 的状态上下文，如是否为 socket、是否关闭、用户非阻塞标志 |
| 与 IO Hook 配合使用           | 保证用户看到的是用户设置的行为，系统底层按框架需要进行调度优化         |

# `setsockopt()`

## 📌 函数定义

```cpp
int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen)
```

这个函数是对 Linux 标准的 `setsockopt()` 系统调用的 Hook 重载版本。

* `sockfd`: 目标 socket 的文件描述符。
* `level`: 设置选项的协议层级（如 `SOL_SOCKET`）。
* `optname`: 要设置的 socket 选项（如 `SO_RCVTIMEO`, `SO_SNDTIMEO`）。
* `optval`: 指向设置值的指针。
* `optlen`: 设置值的长度。

---

## ✅ 代码详解

---

### 1️⃣ 是否启用 Hook 功能

```cpp
if(!sylar::t_hook_enable) 
{
    return setsockopt_f(sockfd, level, optname, optval, optlen);
}
```

* `sylar::t_hook_enable` 是一个线程局部变量，表示当前线程是否启用了 hook 功能。
* 如果未启用，直接调用原始系统函数 `setsockopt_f`（`_f` 代表的是原生函数指针）。

---

### 2️⃣ 检查是否为 socket 层级的选项

```cpp
if(level == SOL_SOCKET) 
{
```

* `SOL_SOCKET` 表示 socket 层级设置，即对套接字本身的选项进行配置（而不是 TCP、IP 等子协议）。

---

### 3️⃣ 是否设置的是超时时间

```cpp
    if(optname == SO_RCVTIMEO || optname == SO_SNDTIMEO) 
    {
```

* `SO_RCVTIMEO`：设置接收（`recv`）操作的超时时间。
* `SO_SNDTIMEO`：设置发送（`send`）操作的超时时间。
* Sylar 会对这两个选项做特殊处理（将超时时间记录到内部 `FdCtx` 中）。

---

### 4️⃣ 获取对应的 Fd 上下文对象

```cpp
        std::shared_ptr<sylar::FdCtx> ctx = sylar::FdMgr::GetInstance()->get(sockfd);
```

* 通过 `FdMgr` 获取该 `sockfd` 对应的上下文 `FdCtx`，以便设置其内部的超时时间字段。
* `FdMgr` 是 `FdCtx` 的统一管理类，类似句柄表。

---

### 5️⃣ 将 timeval 转换为毫秒，并设置到上下文中

```cpp
        if(ctx) 
        {
            const timeval* v = (const timeval*)optval;
            ctx->setTimeout(optname, v->tv_sec * 1000 + v->tv_usec / 1000);
        }
```

* 若上下文存在，则取出 `optval`，强转为 `timeval*`（Linux 超时结构）。
* 将秒 `tv_sec` 和微秒 `tv_usec` 转换为 **毫秒**。
* 调用 `ctx->setTimeout()` 设置到内部字段：

  * 如果 `optname == SO_RCVTIMEO` → 设置接收超时 `m_recvTimeout`。
  * 如果 `optname == SO_SNDTIMEO` → 设置发送超时 `m_sendTimeout`。

---

### 6️⃣ 始终执行系统调用

```cpp
return setsockopt_f(sockfd, level, optname, optval, optlen);	
```

* 无论是否拦截并记录了超时时间信息，最终都要将设置同步给系统调用。

---

## 📘 总结

| 步骤                     | 作用                                    |
| ---------------------- | ------------------------------------- |
| 检查 `t_hook_enable`     | 判断当前是否启用了 Hook 系统调用                   |
| 识别 `SOL_SOCKET` + 超时选项 | 对 `SO_RCVTIMEO` 和 `SO_SNDTIMEO` 做特殊处理 |
| 转换 timeval 为毫秒         | 使用统一的时间单位毫秒存储                         |
| 更新 `FdCtx`             | 记录每个 fd 的超时配置，供协程 IO 调度使用             |
| 调用系统 `setsockopt_f`    | 仍保证对底层 socket 生效                      |

---

### ✅ 用处

这个 hook 版本的 `setsockopt` 能让协程框架感知应用设置的 `recv` / `send` 超时时间，并通过 `do_io()` 统一函数来实现定时取消等待操作，实现真正的**非阻塞协程式超时控制**。

---

