# `GetThis`

这个函数的目的是：
 **获取当前线程正在运行的协程（Fiber）对象**，没有的话就自动**创建一个主协程**并返回。


##  函数目的总结一句话：

> 这个函数确保了：**每个线程在第一次使用协程系统时，都会创建一个“主协程”作为根协程**，并设置全局线程局部变量，便于后续切换和调度。

##  逐行详解：

```cpp
std::shared_ptr<Fiber> Fiber::GetThis()
```

### 返回值：

返回一个 `shared_ptr<Fiber>`，指向当前正在运行的协程。


###  第一步：判断当前线程是否已有协程正在运行

```cpp
if(t_fiber)
{
    return t_fiber->shared_from_this();
}
```

* `t_fiber` 是当前线程的**当前运行协程指针（裸指针）**
* 如果它不为 `nullptr`，说明线程已经有协程在运行，那就直接返回它（通过 `shared_from_this()` 提升为 `shared_ptr`）

####  为什么要用 `shared_from_this()`？

因为类继承了 `std::enable_shared_from_this<Fiber>`，通过它可以从类内部获得一个共享指针，**确保引用计数是正确的**。


###  第二步：当前线程还没协程，创建“主协程”

```cpp
std::shared_ptr<Fiber> main_fiber(new Fiber());
```

* 创建一个新的 `Fiber` 协程对象。
* 注意这里调用的是无参构造函数 `Fiber::Fiber()`，表示它是**主协程**（也叫根协程、线程协程）。

> 主协程没有独立栈空间，它就是当前线程函数运行的上下文。只用于作为其他协程的切换目标。


###  设置全局线程局部变量

```cpp
t_thread_fiber = main_fiber;
t_scheduler_fiber = main_fiber.get();
```

这两个变量的意义如下：

* `t_thread_fiber` 是当前线程的主协程（用 `shared_ptr` 保存，控制生命周期）
* `t_scheduler_fiber` 是调度器协程（调度器在调度其他协程时，会用这个作为返回目标）


###  再次确认设置正确

```cpp
assert(t_fiber == main_fiber.get());
```

这个断言非常关键，用于验证 `t_fiber` 已经在主协程的构造函数中被设置：

在 `Fiber::Fiber()` 构造函数里，有：

```cpp
SetThis(this); // 即 t_fiber = this;
```

所以这里确保：我们刚刚创建的主协程确实已经设置成当前运行协程。


###  最后返回当前协程对象

```cpp
return t_fiber->shared_from_this();
```

此时 `t_fiber` 就是 `main_fiber.get()`，返回它的 `shared_ptr`。


## 补充思考

###  为什么主协程不能提前创建？

因为协程是按需使用的——只有当线程真正使用协程系统（比如想切到一个Fiber）时，才需要创建主协程，否则白白浪费内存。


### 🧠 为什么用 `shared_ptr<Fiber>` 来管理主协程？

因为协程需要参与调度，并且有些协程会在函数退出前自动释放自己，所以必须使用智能指针来管理生命周期。


## ✅ 函数行为图解：

```text
第一次调用 Fiber::GetThis() 时
┌────────────────────────┐
│  t_fiber == nullptr？   │──No──┐
└────────────────────────┘      │
        Yes                      ↓
创建主协程 main_fiber       返回 t_fiber->shared_from_this()
↓
设置：
- t_thread_fiber
- t_scheduler_fiber
- t_fiber (在构造函数里)
↓
返回 shared_ptr<Fiber>
```

# `Fiber()`

这段代码是 `Fiber` 类的 **无参构造函数**，它是 **线程主协程（main fiber）** 的专用构造方法。

在整个协程系统中：

* 每个线程**首次使用协程**时，会通过 `Fiber::GetThis()` 调用该构造函数，
* 创建出一个**主协程**：不具有独立的栈空间，只代表**当前线程的运行栈上下文**。


##  函数作用总结一句话：

> `Fiber::Fiber()` 创建的是**主协程对象**，其上下文是当前线程的运行状态，它**没有独立的栈空间**，用于调度其他协程切换回来时的“默认执行位置”。


##  逐行详细解析：

```cpp
Fiber::Fiber() {
```

> 这是 **无参构造函数**，仅用于初始化线程的主协程（即线程第一次使用 Fiber 系统时）。


###  设置当前正在运行的协程

```cpp
SetThis(this);
```

* 把当前构造的协程对象指针设置为线程局部变量 `t_fiber`。
* 实际调用：

  ```cpp
  static void SetThis(Fiber* f) { t_fiber = f; }
  ```

 表示：当前线程此刻运行的是这个主协程。


###  设置状态为运行中

```cpp
m_state = RUNNING;
```

* 主协程一旦创建就处于运行状态，因为它本身**就是当前线程函数的执行体**。
* 用户协程初始状态是 `READY`，而主协程没有 resume 步骤，天然 `RUNNING`。


###  保存当前上下文状态

```cpp
if (getcontext(&m_ctx)) {
    std::cerr << "getcontext error" << std::endl;
}
```

* `getcontext(&m_ctx)` 会将当前线程的 CPU 寄存器、栈指针、程序计数器等状态保存到 `m_ctx`。
* 主协程本身就是当前函数的栈，因此这里获取上下文是为了**允许将来可以切回这里**（通过 `swapcontext`）。


###  更新协程总数与ID

```cpp
++s_fiber_count;
m_id = s_fiber_id++;  // 协程id从0开始，用完加1
```

* `s_fiber_id` 是协程 ID 的全局原子计数器，用于唯一标识每个协程。
* `s_fiber_count` 是当前存在的协程总数（创建时加1，析构时减1）

 即使主协程也被视作一个协程，有编号、有生命周期计数。


###  可选调试日志

```cpp
if(debug) std::cout << "Fiber::Fiber(): main id = " << m_id << std::endl;
```

如果启用了 `debug` 标志，会打印协程的创建信息，便于调试。


##  总结：主协程的构造特点

| 特性          | 说明                        |
| ----------- | ------------------------- |
| 没有栈分配       | 使用线程当前栈，不能 `malloc` 栈     |
| 状态为 RUNNING | 因为此时就是在运行                 |
| 保存上下文       | 调用 `getcontext`，为了能将来切换回来 |
| 用于调度其他协程    | 是协程系统的“基点”，所有协程最终都切回来这里   |


##  对比：主协程 vs 用户协程构造

| 特征       | 主协程（Fiber()）      | 用户协程（Fiber(cb, stack, flag)） |
| -------- | ----------------- | ---------------------------- |
| 是否分配栈    | 否，用当前线程栈          | 是，手动 malloc                  |
| 状态初始化    | RUNNING           | READY                        |
| 是否保存上下文  | 是，getcontext      | 是，getcontext + makecontext   |
| 是否设置入口函数 | 否                 | 是，设置为 `MainFunc()`           |
| 使用时机     | 第一次调用 `GetThis()` | 用户主动创建协程对象                   |


## 延伸问题：为什么主协程不用 `makecontext` 设置函数入口？

因为主协程代表的是“当前线程已经在执行”的上下文，**不是一个被唤醒执行的协程**，不需要一个“入口函数”。

而用户协程是 resume 时第一次切入，需要 `makecontext` 设置执行入口为 `MainFunc()`。


# Fiber有参构造函数


## 🧠 这段代码的总体作用：

> 创建一个可独立调度的协程，它拥有**自己的栈空间**，将来可以 `resume()` 恢复执行，执行完毕后切回主协程或调度协程。


##  分行详细讲解

```cpp
Fiber::Fiber(std::function<void()> cb, size_t stacksize, bool run_in_scheduler)
    : m_cb(cb)
    , m_runInScheduler(run_in_scheduler)
```

### 初始化成员变量

* `m_cb`：协程的**回调函数**，协程被执行时就调用这个函数。
* `m_runInScheduler`：表示这个协程是否是被调度器调度的（`true`）还是用户线程直接创建的（`false`）。这会影响 `resume/yield` 的上下文切换方式。

```cpp
m_state = READY;
```

###  协程初始状态设置为 READY

* 表示协程**尚未开始执行**，准备被 `resume()` 启动。


```cpp
m_stacksize = stacksize ? stacksize : 128000;
```

###  设置协程栈大小

* 如果传入参数 `stacksize` 不为 0，就使用它；
* 否则，使用默认大小 `128000` 字节（约 128KB）。


```cpp
m_stack = malloc(m_stacksize);
```

###  为协程分配独立栈空间

* 协程是用户态的调度单元，必须自己拥有一段栈空间，否则不能保存/恢复执行状态。


```cpp
if(getcontext(&m_ctx))
{
    std::cerr << "Fiber(...) failed\n";
    pthread_exit(NULL);
}
```

###  获取当前上下文，准备构造新的上下文

* `getcontext(&m_ctx)` 会保存当前 CPU 寄存器、程序计数器、信号掩码等状态到 `m_ctx`。
* **必须先 `getcontext` 才能 `makecontext`**！


```cpp
m_ctx.uc_link = nullptr;
```

###  设置后继上下文为空

* `uc_link` 指定该协程结束后要恢复哪个上下文。
* 设置为 `nullptr` 表示协程函数退出后不自动恢复其他上下文。
* 实际上这里会在协程函数执行完之后手动调用 `yield()`。

```cpp
m_ctx.uc_stack.ss_sp = m_stack;
m_ctx.uc_stack.ss_size = m_stacksize;
```

###  设置协程上下文的栈信息

* 将栈地址和大小设置到 `m_ctx`，这是协程真正运行时的栈环境。


```cpp
makecontext(&m_ctx, &Fiber::MainFunc, 0);
```

###  设置协程入口函数为 `MainFunc`

* `makecontext` 是真正设置协程逻辑入口的地方。
* 当使用 `resume()` 切换到这个协程时，**会从 `MainFunc()` 开始执行**。

#### ⚠️ 注意：

* `MainFunc` 内部会调用 `m_cb()`，即协程用户指定的逻辑。
* 参数个数是 `0`，所以不能传递动态参数给协程函数。


```cpp
m_id = s_fiber_id++;
++s_fiber_count;
```

###  为该协程分配唯一 ID，并更新协程数量统计

* `s_fiber_id` 是原子类型，用来生成递增 ID。
* `s_fiber_count` 是当前活跃协程总数。


```cpp
if(debug) std::cout << "Fiber(): child id = " << m_id << std::endl;
```

###  打印调试信息（可选）

* 如果打开了全局变量 `debug = true`，将输出协程 ID，便于追踪日志。


##  总结：该构造函数完成了什么？

| 步骤            | 内容                                     |
| ------------- | -------------------------------------- |
| 1️⃣ 设置协程函数    | 保存了 `std::function<void()> cb` 作为协程执行体 |
| 2️⃣ 分配栈空间     | 使用 `malloc` 动态申请，避免冲突共享                |
| 3️⃣ 初始化上下文    | 用 `getcontext` 获取上下文，准备调度              |
| 4️⃣ 设置执行入口    | 通过 `makecontext` 设置为 `MainFunc()`      |
| 5️⃣ 设置状态 & 计数 | 设置为 READY，ID 唯一，统计计数+1                 |


##  使用该构造函数创建协程的典型流程：

```cpp
Fiber::GetThis(); // 确保主协程存在

std::shared_ptr<Fiber> f(new Fiber([]{
    std::cout << "Hello from fiber" << std::endl;
}, 128000, false));

f->resume();  // 切换执行
```


# `resume()`

##  函数作用一句话总结：

> **将当前 Fiber 切换为运行状态，并将控制权从主协程或调度器协程切换到该 Fiber 的上下文中（执行协程代码）**。


##  逐行详细解释

```cpp
void Fiber::resume()
{
```

这表示该函数是 Fiber 的成员方法，用于恢复当前协程的执行。调用这个方法会切换到该协程并运行其绑定的函数。


###  状态检查：协程必须处于 READY 状态

```cpp
    assert(m_state==READY);
```

* `resume()` 的前提是协程处于 `READY` 状态。
* 也就是说该协程尚未开始执行，或者是执行过后 `reset()` 成 READY。

> 如果你尝试 resume 一个已经 `RUNNING`、`HOLD`、`TERM` 的协程，这是逻辑错误，程序直接断言崩溃。

###  设置协程状态为 RUNNING

```cpp
    m_state = RUNNING;
```

表示该协程马上将要获得 CPU 时间并执行代码。


###  判断协程是在调度器中运行还是用户线程直接创建

```cpp
    if(m_runInScheduler)
```

* `m_runInScheduler` 为 `true`，表示这个协程是由调度器（如多线程的线程池）管理的。
* 否则，它是普通线程中创建的协程。

这会影响下面 **从哪个上下文切换到本协程**。


###  切换上下文

####  情况一：由调度器切入本协程

```cpp
        SetThis(this); // 设置当前运行的协程为 this

        if(swapcontext(&(t_scheduler_fiber->m_ctx), &m_ctx))
```

* `t_scheduler_fiber` 是调度器控制协程的上下文（一般在协程调度器中是一个无限循环）。
* `swapcontext(from, to)` 表示保存当前上下文到 `from` 并跳转执行 `to` 对应的上下文。
* 所以这里的行为是：

  * **保存调度协程的上下文**到 `t_scheduler_fiber->m_ctx`
  * **切换到当前协程的上下文** `m_ctx`
  * 实际运行 `makecontext` 设置的函数 `MainFunc()`，然后间接执行 `m_cb()`

#### ⚠️ 错误处理

```cpp
            std::cerr << "resume() to t_scheduler_fiber failed\n";
            pthread_exit(NULL);
```

* 如果 `swapcontext` 失败，说明协程切换异常，直接打印错误并退出线程（终止执行）。


####  情况二：从主协程（用户线程）切入

```cpp
        SetThis(this);
        if(swapcontext(&(t_thread_fiber->m_ctx), &m_ctx))
```

* 和上面一样逻辑，只是这时协程是由主线程直接创建的，没有调度器。
* `t_thread_fiber` 是主协程上下文。


##  整体流程图：

```text
   [当前上下文]
       │
       ▼
  (assert READY)
       │
   状态 -> RUNNING
       │
判断是否在调度器中
   │                 │
是                    否
 │                    │
t_scheduler_fiber   t_thread_fiber
 │                    │
swapcontext 保存当前 → 切入协程 m_ctx
       ▼
    协程开始执行（MainFunc → m_cb()）
```
---

## 💡 关键点小结：

| 点       | 内容                                                   |
| ------- | ---------------------------------------------------- |
| ✅ 状态检查  | 协程必须是 READY 状态才能 resume                              |
| ✅ 状态转换  | 调用前 READY，调用后设为 RUNNING                              |
| ✅ 上下文切换 | `swapcontext` 保存当前、切换到目标                             |
| ✅ 上下文来源 | 根据 `m_runInScheduler` 决定从哪里切入                        |
| ✅ 调度入口  | 实际执行的是 `makecontext()` 指定的 `MainFunc()`，再调用 `m_cb()` |


## 为什么要区分是调度器还是线程切换？

因为：

* 在线程池里，一个线程可能调度多个 Fiber，因此要从调度器协程 `t_scheduler_fiber` 进行 `swapcontext`。
* 普通线程手动 `new Fiber` 并调用 `resume()`，是从主协程 `t_thread_fiber` 进行 `swapcontext`。


## 🧠 举个简化例子（非调度器版）

```cpp
Fiber::GetThis(); // 初始化主协程（线程上下文）

std::shared_ptr<Fiber> f(new Fiber([]{
    std::cout << "Hello Fiber\n";
}, 128000, false));

f->resume();  // 执行该 Fiber 的 m_cb 函数
```

这时会：

* 从主协程 `t_thread_fiber` 切换到 `f` 的上下文
* 执行 `f->MainFunc()`，再执行 `m_cb()`
* 然后该协程 yield 回 `t_thread_fiber`


# 'yield()'

##  总体作用总结：

> 当前协程主动**让出执行权**，切换回“上一个协程” —— 要么是调度器协程（`t_scheduler_fiber`），要么是主协程（`t_thread_fiber`）。

你可以把它理解为：**我这个协程执行完一部分了，要“暂停”一下，把控制权还回去，等以后有机会再继续。**


##  逐行详细解释

```cpp
void Fiber::yield()
```

这个函数没有返回值，作用是**将当前协程挂起，并切换回之前的调度点**。

###  状态断言检查

```cpp
assert(m_state == RUNNING || m_state == TERM);
```

* `yield()` 只能在：

  * 协程正在运行（`RUNNING`）
  * 或者协程已经运行完了（`TERM`）

 防止错误地在 `READY` 状态或未初始化状态调用 `yield()`。

###  如果不是已终止（TERM），设置为 READY

```cpp
if(m_state != TERM)
{
    m_state = READY;
}
```

* 如果协程还没执行完，只是想“中断”，就将状态设为 `READY`，表示**可以被调度器再次 resume()**。
* 如果协程已经结束（如 `MainFunc()` 末尾），状态应该是 `TERM`，不能再重新执行。


###  判断当前协程是否由调度器运行

```cpp
if(m_runInScheduler)
```

这个布尔值在构造协程时传入，决定协程运行在哪种场景：

| `m_runInScheduler` | 说明                    |
| ------------------ | --------------------- |
| `true`             | 协程由调度器（如线程池）调度        |
| `false`            | 协程由用户在线程中手动创建和 resume |

###  切换到调度器协程（scheduler fiber）

```cpp
SetThis(t_scheduler_fiber); // 当前运行协程设为调度器协程

if(swapcontext(&m_ctx, &(t_scheduler_fiber->m_ctx)))
```

* 将当前协程的上下文保存到 `m_ctx`
* 切换执行到调度器协程 `t_scheduler_fiber->m_ctx`
* 调度器就可以安排下一个协程运行了

###  切换到主协程（thread fiber）

```cpp
SetThis(t_thread_fiber.get());

if(swapcontext(&m_ctx, &(t_thread_fiber->m_ctx)))
```

* 与上面类似，只不过切换的是主协程 `t_thread_fiber`
* 这是**在非调度器场景下**，返回主线程的原始执行点


###  错误处理

```cpp
std::cerr << "yield() ... failed\n";
pthread_exit(NULL);
```

* 如果 `swapcontext` 失败（极少发生，除非非法上下文或栈已破坏），打印错误并终止线程。


##  控制流程示意图

```text
协程运行中
    ↓
调用 yield()
    ↓
状态变为 READY（或保持 TERM）
    ↓
调用 swapcontext()
    ↓
切回：
  └── 调度器（m_runInScheduler = true）
  └── 主协程（m_runInScheduler = false）
```

##  `yield()` 使用场景举例

1. **协程执行到一半，主动中断等待：**

```cpp
void task() {
    std::cout << "step 1\n";
    Fiber::GetThis()->yield(); // 暂停协程
    std::cout << "step 2\n";
}
```

调度器下次 resume 它时会从 `step 2` 继续执行。


2. **协程函数执行完，返回到主协程或调度器：**

```cpp
void Fiber::MainFunc() {
    std::shared_ptr<Fiber> curr = GetThis();
    curr->m_cb();        // 执行用户函数
    curr->m_state = TERM;

    auto raw_ptr = curr.get();
    curr.reset();        // 清除 shared_ptr
    raw_ptr->yield();    // 返回到调度器或主协程
}
```


##  `yield()` 和 `resume()` 的配对关系

| 调用者       | 调用函数       | 说明            |
| --------- | ---------- | ------------- |
| 主协程 / 调度器 | `resume()` | 切入某个用户协程      |
| 用户协程      | `yield()`  | 让出控制权回主协程/调度器 |


## ⚠️ 常见错误防护（通过断言和状态检查）

| 可能错误                        | 断言或处理                        |     |         |
| --------------------------- | ---------------------------- | --- | ------- |
| 非运行状态协程调用 `yield()`         | \`assert(m\_state == RUNNING |     | TERM)\` |
| 非 `READY` 状态协程调用 `resume()` | `assert(m_state == READY)`   |     |         |
| 协程执行出错                      | `swapcontext` 返回错误，终止线程      |     |         |


## 总结：`yield()` 做了什么？

| 步骤                         | 内容  |
| -------------------------- | --- |
| 1️⃣ 断言当前状态为 RUNNING 或 TERM |     |
| 2️⃣ 如果还没结束，状态设为 READY      |     |
| 3️⃣ 保存当前上下文并切换回调度器或主协程     |     |
| 4️⃣ 设置线程局部变量 t\_fiber 为返回者 |     |

# `MainFunc()`


```cpp
void Fiber::MainFunc()
```

##  总体作用一句话总结：

> `MainFunc()` 是协程的“入口函数”——它会在协程被 `resume()` 时开始执行，运行用户指定的 `m_cb()`，执行完后标记协程结束并 `yield()` 回去。

它通常通过 `makecontext(&m_ctx, &Fiber::MainFunc, 0)` 注册为上下文入口。

##  分行详细解释：


###  第一步：获取当前运行的协程对象

```cpp
std::shared_ptr<Fiber> curr = GetThis();
```

* `Fiber::GetThis()` 返回当前线程正在执行的协程对象（即 `t_fiber->shared_from_this()`）。
* 这个协程就是当前运行的上下文，也就是 `MainFunc()` 绑定的那个 Fiber。

###  校验非空

```cpp
assert(curr != nullptr);
```

* 如果 `curr` 是空的，那说明协程系统状态出错，程序应立即终止。
* 在合理使用下这不应失败（因为是在协程上下文中运行的）。

###  第二步：执行协程逻辑

```cpp
curr->m_cb();
```

* 调用协程对象中存储的 `std::function<void()>` 函数，即用户传入的业务逻辑代码。
* 这是协程真正的“工作”。


###  第三步：状态设置为终止

```cpp
curr->m_state = TERM;
```

* `TERM` 表示协程已经执行完毕，不能再次 `resume()`。
* 如果你再 `resume()` 它会触发断言错误（见 `resume()` 中状态检查）。


###  第四步：释放 shared\_ptr 引用

```cpp
auto raw_ptr = curr.get();
curr.reset();
```

#### 为什么这么做？

* `curr` 是 `shared_ptr`，如果你不主动 `reset()`，可能会导致协程无法释放（循环引用或外部还保留副本）。
* 但我们仍需要调用 `yield()`，而这个成员函数不是静态的，所以先用 `get()` 得到裸指针 `raw_ptr`。

###  第五步：让出执行权，返回调度器/主协程

```cpp
raw_ptr->yield();
```

* 协程运行完了，不能再继续，只能 `yield()` 回调度器或主协程。
* 这一句是协程生命周期的“结束信号”。

⚠️ 注意：**协程执行结束后必须手动切回去，否则执行流无法回到原处，程序就崩了！**


##  整体执行流程图：

```text
【协程被 resume() 】
       │
       ▼
  makecontext -> MainFunc()
       │
       ▼
1. 获取当前协程 Fiber 对象
2. 执行 m_cb() 回调函数（协程内容）
3. 设置状态为 TERM
4. 释放 shared_ptr 引用（避免悬挂）
5. yield() 切回主协程或调度器
```

##  为什么要用 `shared_ptr<Fiber> curr = GetThis();`？

因为：

* `shared_ptr` 会自动计数，避免内存泄漏。
* Fiber 继承了 `enable_shared_from_this`，可以在运行时安全地从裸指针获得 `shared_ptr`。
* 但 `MainFunc` 是通过 `makecontext()` 绑定的，系统只传了裸指针，必须从 `t_fiber` 中重建 `shared_ptr`。

## ⚠️ 注意事项：

| 行为                 | 目的或风险                     |
| ------------------ | ------------------------- |
| `curr->m_cb()`     | 运行用户逻辑，如果内部抛异常，这里不会 catch |
| `curr.reset()`     | 提前释放 `shared_ptr`，避免悬挂引用  |
| `raw_ptr->yield()` | 从当前协程切换回去；否则就“死”在这儿了      |
| 不 catch 异常         | 框架不处理协程异常，开发者需自定义封装处理     |

##  示例使用（调度器）

```cpp
// 调度器线程中：
Fiber::GetThis(); // 初始化主协程

std::shared_ptr<Fiber> fiber(new Fiber([]{
    std::cout << "协程开始\n";
    Fiber::GetThis()->yield();
    std::cout << "协程恢复\n";
}, 128000, true));

// 第一次调度
fiber->resume();  // -> MainFunc -> cb() 执行前半段 -> yield
fiber->resume();  // -> cb() 执行后半段 -> yield
```

##  总结：`MainFunc()` 完成了什么？

| 步骤  | 内容                         |
| --- | -------------------------- |
| 1️⃣ | 获取当前正在运行的协程对象（shared\_ptr） |
| 2️⃣ | 调用协程体函数 `m_cb()`，执行用户逻辑    |
| 3️⃣ | 将状态设置为 `TERM`，标记协程已终止      |
| 4️⃣ | 释放引用，避免泄漏                  |
| 5️⃣ | 调用 `yield()`，把控制权交还主协程或调度器 |
