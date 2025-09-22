# `Timer::cancel()`

### 🔍 函数定义

```cpp
bool Timer::cancel() 
```

该函数用于 **取消当前 `Timer` 定时器**，将其从 `TimerManager` 中移除，防止其对应的回调函数在未来被调用。

---

### 1️⃣ 加锁以保证线程安全

```cpp
std::unique_lock<std::shared_mutex> write_lock(m_manager->m_mutex);
```

* `TimerManager` 中的 `m_timers` 是一个红黑树（`std::set` 实现），可能同时被多个线程读写（例如添加定时器和取消定时器）。
* 因此使用 `std::shared_mutex`：

  * 读操作使用 `shared_lock`
  * 写操作使用 `unique_lock`
* 这里我们要**删除一个定时器**，属于写操作，使用 `unique_lock` 上写锁，防止其他线程同时访问该容器。

---

### 2️⃣ 回调函数为空，则说明已取消

```cpp
if(m_cb == nullptr) 
{
    return false;
}
```

* 如果当前定时器的回调 `m_cb` 为 `nullptr`：

  * 说明当前定时器已经被取消过了，或者本来就无效。
  * 因此直接返回 `false`，表示取消失败（已经是取消状态了）。

---

### 3️⃣ 设置回调为空，逻辑上等价于“取消”

```cpp
else
{
    m_cb = nullptr;
}
```

* 将回调函数清空，表明该定时器已“取消”，即便其还在 `m_timers` 中也不会再被执行。
* 这是个 **重要语义**：如果之后未成功从 `m_timers` 删除（理论上不太可能），逻辑上也已经无效。

---

### 4️⃣ 从时间堆中查找并移除自身

```cpp
auto it = m_manager->m_timers.find(shared_from_this());
if(it!=m_manager->m_timers.end())
{
    m_manager->m_timers.erase(it);
}
```

* `shared_from_this()` 获取当前对象的 `std::shared_ptr<Timer>`。
* 在 `TimerManager` 中查找当前定时器是否还在 `m_timers` 中。

  * `m_timers` 是一个 `std::set<std::shared_ptr<Timer>, Comparator>`，以 `m_next` 超时时间进行排序。
* 如果找到了，执行 `erase(it)`，将该定时器从时间堆中彻底移除。

  * 删除后意味着它不会再被 `epoll_wait + getNextTimer()` 唤醒。

---

### 5️⃣ 返回取消成功

```cpp
return true;
```

* 无论是通过逻辑（`m_cb = nullptr`）取消，还是成功从堆中删除，总之任务已经不会再执行了，返回 `true` 表示取消成功。

---

### ✅ 小结

| 步骤       | 作用                       |
| -------- | ------------------------ |
| 获取写锁     | 保证线程安全，防止并发修改            |
| 判断回调是否为空 | 空则视为已取消，直接失败             |
| 清空回调     | 表明该定时器不会再触发              |
| 从堆中删除    | 防止 `getNextTimer()` 再次处理 |
| 返回结果     | 表示取消成功与否                 |

# `Timer::refresh()`

## 🧠 函数目的：刷新定时器

```cpp
bool Timer::refresh();
```

该函数用于**刷新当前 `Timer` 的超时时间**（保持 `m_ms` 不变，但将 `m_next` 设置为“现在 + m\_ms”），并重新调整在 `TimerManager` 中的排序位置。
这是为了**延长**当前定时器的生命周期，常用于长连接、心跳等场景。

---

## ✅ 步骤详解

### 1️⃣ 获取写锁，保证线程安全

```cpp
std::unique_lock<std::shared_mutex> write_lock(m_manager->m_mutex);
```

* 对 `TimerManager` 内部成员 `m_timers` 加写锁。
* `m_timers` 是 `std::set<std::shared_ptr<Timer>, Timer::Comparator>` 实现的**时间堆**。
* 因为要对其进行修改（删除再插入），所以必须使用 **独占写锁（`unique_lock`）**。

---

### 2️⃣ 如果没有回调，说明 Timer 无效，不能刷新

```cpp
if(!m_cb) 
{
    return false;
}
```

* 如果该 `Timer` 的回调已经被清空（例如 `cancel()` 之后），说明它已经**无效或已取消**。
* 无法刷新一个无效的 `Timer`，所以返回 `false` 表示刷新失败。

---

### 3️⃣ 在 `TimerManager` 的定时器集合中查找自己

```cpp
auto it = m_manager->m_timers.find(shared_from_this());
if(it == m_manager->m_timers.end())
{
    return false;
}
```

* 使用 `shared_from_this()` 构造自身的 `std::shared_ptr`，因为 `m_timers` 是 `set<shared_ptr<Timer>>` 类型。
* `m_timers.find()`：查找当前定时器在 `TimerManager` 的时间堆中是否存在。
* 如果找不到，表示该定时器已经被移除（例如已经触发或被取消），刷新失败。

---

### 4️⃣ 删除旧的定时器记录

```cpp
m_manager->m_timers.erase(it);
```

* `std::set` 是**基于红黑树**实现的有序集合，其排序依据是定时器的 `m_next` 时间（通过 `Comparator` 实现）。
* 为了更改 `m_next`，必须先删除旧值再插入新值，因为 `set` 中的元素排序是只读的。
  * **不能直接修改 key 的值，否则 `set` 结构会被破坏。**

---

### 5️⃣ 更新下次超时时间

```cpp
m_next = std::chrono::system_clock::now() + std::chrono::milliseconds(m_ms);
```

* 将 `m_next` 设置为当前时间 + 定时间隔。
* `m_ms` 不变，只是“重新定一个新的过期时间点”。

---

### 6️⃣ 重新插入到时间堆中，更新排序位置

```cpp
m_manager->m_timers.insert(shared_from_this());
```

* 将定时器以新的超时时间插入回时间堆。
* 保证 `TimerManager` 中的定时器集合仍然按照超时时间升序排列。

---

### 7️⃣ 返回刷新成功

```cpp
return true;
```

* 表示本次刷新成功，定时器的生效时间被成功延长了。

---

## 🧩 整体流程图解

```text
+-------------------+
|    refresh()      |
+-------------------+
        |
        v
1. 写锁保护 TimerManager（定时器线程安全）
        |
        v
2. 如果定时器被取消（m_cb == nullptr）-> return false
        |
        v
3. 查找 Timer 是否在 TimerManager 的定时器集合中
        |
        v
4. 删除原位置（因为 m_next 要修改）
        |
        v
5. 设置新的 m_next = now + m_ms
        |
        v
6. 插入新的 Timer 到时间堆（排序位置更新）
        |
        v
7. return true 成功
```

---

## 🔚 总结

| 步骤    | 作用                  |
| ----- | ------------------- |
| 加锁    | 防止并发冲突，保护定时器堆       |
| 判断回调  | 定时器必须有效             |
| 删除旧记录 | 修改排序键（m\_next）前必须删除 |
| 更新时间  | 延长定时器超时             |
| 插入新记录 | 放入新排序位置             |
| 返回值   | 表示刷新是否成功            |


# `Timer::reset()`

## 🧠 函数功能：

```cpp
bool Timer::reset(uint64_t ms, bool from_now);
```

### 功能：

重新设置当前 `Timer` 的超时时间 `m_ms` 和绝对过期时间 `m_next`，并将其在 `TimerManager` 中重新定位排序。

---

## ✅ 函数完整分析：

### 🔹 第一步：提前返回判断

```cpp
if(ms == m_ms && !from_now)
{
    return true;
}
```

* 如果你传入的新的超时时间 `ms` 和当前的一样 `m_ms`，且 `from_now == false`，说明没有任何更新需求。
* 直接返回 `true`，表示“已重设”（虽然实际上没有修改）。

---

### 🔹 第二步：加写锁、验证合法性

```cpp
{
    std::unique_lock<std::shared_mutex> write_lock(m_manager->m_mutex);

    if(!m_cb) 
    {
        return false;
    }

    auto it = m_manager->m_timers.find(shared_from_this());
    if(it == m_manager->m_timers.end())
    {
        return false;
    }

    m_manager->m_timers.erase(it);
}
```

* 括号用于限定写锁作用域，后面重新插入时会重新加锁。
* 若 `m_cb` 已被取消（为空），定时器无效，返回 `false`。
* 用 `shared_from_this()` 查找 `Timer` 是否还在 `TimerManager` 中。
* 找不到说明已经被取消/触发了，也返回 `false`。
* 找到后，**从时间堆中删除当前定时器**，因为你接下来要修改 `m_next`。

---

### 🔹 第三步：更新过期时间点

```cpp
auto start = from_now ? std::chrono::system_clock::now() : m_next - std::chrono::milliseconds(m_ms);
m_ms = ms;
m_next = start + std::chrono::milliseconds(m_ms);
```

这个逻辑是整个函数最核心的部分。

#### ➤ 如何计算新的 `m_next`？

1. `from_now == true`：

   * 使用当前时间 `now()` 作为新的计时起点。
   * `m_next = now + ms`

2. `from_now == false`：

   * 使用**上一次超时时间点**的起点（推算得到），然后更新为新时长。
   * 这个“起点”是：`旧的 m_next - 旧的 m_ms`

> 这样设计的目的是：
>
> * 如果你在定时器快要触发时去 reset，而且设置 `from_now == false`，那新的定时器会以**原来开始的时间**为基准继续向后延时，**不是“从现在开始重新倒计时”。**

#### ➤ 更新数据成员：

```cpp
m_ms = ms;
m_next = start + std::chrono::milliseconds(m_ms);
```

---

### 🔹 第四步：重新插入到定时器管理器中

```cpp
m_manager->addTimer(shared_from_this());
```

* 插入时调用 `TimerManager::addTimer()`，**在里面重新加锁**并调整时间堆。
* 这样可以确保定时器被重新排序，新的超时时间生效。

---

### 🔹 第五步：返回成功

```cpp
return true;
```

说明成功修改定时器。

---

## 🔁 举个例子

假设原定时器：

* `m_ms = 3000`，`m_next = 12:00:03`
* 当前时间是 `12:00:02.5`

#### 情况一：`reset(5000, false)`

* 起点是：`m_next - m_ms = 12:00:00`
* 新的 `m_next = 12:00:00 + 5000ms = 12:00:05`

#### 情况二：`reset(5000, true)`

* 起点是：`now = 12:00:02.5`
* 新的 `m_next = 12:00:02.5 + 5000ms = 12:00:07.5`

---

## 🧩 流程总结图

```text
+-----------------------------+
|       Timer::reset()       |
+-----------------------------+
        |
        v
1. 如果 m_ms 不变 且 from_now=false -> return true
        |
        v
2. 加写锁：验证回调合法性，是否存在于时间堆中
        |
        v
3. 从 m_timers 中移除
        |
        v
4. 根据 from_now 决定新的起点时间
        |
        v
5. 更新 m_ms 和 m_next
        |
        v
6. 调用 addTimer() -> 插入定时器
        |
        v
7. return true
```

---

## ✅ 总结表格

| 步骤                   | 动作       | 目的            |
| -------------------- | -------- | ------------- |
| 检查 `ms` 和 `from_now` | 早退出优化    | 避免不必要操作       |
| 加锁并验证定时器有效性          | 保证线程安全   | 防止无效重设        |
| 删除旧定时器               | 修改排序 key | 重新计算 `m_next` |
| 更新 m\_ms 和 m\_next   | 延迟触发时间   | 支持按需延时        |
| 重新加入 TimerManager    | 重新排序     | 新定时生效         |

# `Timer::Timer()`


## `Timer::Timer(...)` 构造函数

```cpp
Timer::Timer(uint64_t ms, std::function<void()> cb, bool recurring, TimerManager* manager)
    : m_recurring(recurring), m_ms(ms), m_cb(cb), m_manager(manager) 
{
    auto now = std::chrono::system_clock::now();
    m_next = now + std::chrono::milliseconds(m_ms);
}
```

### 🔍 解释：

这个构造函数用于创建一个定时器对象。

* `ms`：超时时间，单位毫秒。
* `cb`：超时触发时要执行的回调函数。
* `recurring`：是否是循环定时器。
* `manager`：该定时器归属的 `TimerManager`，用于后续操作（取消、插入等）。

### ⚙️ 初始化成员变量：

| 成员变量          | 含义                    |
| ------------- | --------------------- |
| `m_recurring` | 是否循环触发                |
| `m_ms`        | 每次超时时间（毫秒）            |
| `m_cb`        | 回调函数                  |
| `m_manager`   | 定时器归属的管理器             |
| `m_next`      | **绝对过期时间点**，即何时触发本定时器 |

```cpp
auto now = std::chrono::system_clock::now();
m_next = now + std::chrono::milliseconds(m_ms);
```

计算：从当前时间点加上 `ms`，得出定时器的“未来触发时间”。


# `Timer::Comparator::operator()`

## `bool Timer::Comparator::operator()(...)` 比较函数

```cpp
bool Timer::Comparator::operator()(const std::shared_ptr<Timer>& lhs, const std::shared_ptr<Timer>& rhs) const
{
    assert(lhs != nullptr && rhs != nullptr);
    return lhs->m_next < rhs->m_next;
}
```

### 🔍 解释：

这是给定时器 `std::set<Timer>` 的排序规则。

* 用于 `TimerManager::m_timers`，一个定时器的有序集合（类似时间最小堆）。
* 依据：哪个定时器的 `m_next`（过期时间）更早，就排前面。
* `assert(...)`：确保不为空指针。
* 返回值表示“左侧优先级是否更高”。

# `TimerManager::TimerManager()`

##  `TimerManager::TimerManager()` 构造函数

```cpp
TimerManager::TimerManager() 
{
    m_previouseTime = std::chrono::system_clock::now();
}
```

### 🔍 解释：

定时器管理器构造时，记录一下当前时间。

这个值后续可能用于检测系统时间是否回拨（`detectClockRollover()`）：

* 如果 `now < m_previouseTime`，说明系统时间被手动调回了。


# `TimerManager::~TimerManager()` 析构函数

```cpp
TimerManager::~TimerManager() 
{
}
```

* 空实现。
* 但由于成员变量中有智能指针容器，析构时会自动释放。

---

# `addTimer(uint64_t ms, std::function<void()> cb, bool recurring)` 方法

```cpp
std::shared_ptr<Timer> TimerManager::addTimer(uint64_t ms, std::function<void()> cb, bool recurring) 
{
    std::shared_ptr<Timer> timer(new Timer(ms, cb, recurring, this));
    addTimer(timer);
    return timer;
}
```

### 🔍 解释：

这是 **对外暴露的添加定时器的接口**。

* 创建一个 `shared_ptr<Timer>`，使用传入参数构造。
* 调用内部的 `addTimer(std::shared_ptr<Timer>)` 函数，将其加入时间堆（即 `m_timers`）。
* 返回这个定时器的智能指针，调用者可以后续操作（如取消、刷新、重置）。

---

## 🔁 整体调用流程小图示：

```text
[调用者]
   |
   | addTimer(ms, cb, recurring)
   v
[TimerManager 创建 Timer 对象]
   |
   | Timer 构造函数设置 m_next 绝对过期时间
   v
调用内部 addTimer(shared_ptr<Timer>)
   |
   v
[加入 m_timers 堆 + 触发 onTimerInsertedAtFront()]
```

---

## 🧠 总结：

| 函数 / 构造函数                       | 作用                       |
| ------------------------------- | ------------------------ |
| `Timer::Timer`                  | 创建单个定时器对象，设定超时触发时间点      |
| `Timer::Comparator::operator()` | 决定 Timer 在堆中的排序方式（谁更早执行） |
| `TimerManager::TimerManager()`  | 初始化 TimerManager 并记录当前时间 |
| `addTimer(ms, cb, recurring)`   | 创建定时器并添加到管理器堆中           |

# `OnTimer()`

##  函数`static void OnTimer(std::weak_ptr<void> weak_cond, std::function<void()> cb)`

### 📌 作用：

这个函数是用来处理“**条件触发**”的回调包装器。

### 🧠 场景理解：

在某些场景下，我们希望定时器回调只在**某个对象还活着**时才执行。
为了实现这个目的，我们传入一个 `std::weak_ptr<void>` 指向该对象。

---

### 🔍 逐行解释：

```cpp
std::shared_ptr<void> tmp = weak_cond.lock();
```

* `weak_cond` 是一个 **弱引用**，不会增加引用计数。
* 尝试将其锁定为 `shared_ptr`，如果对象还活着，就能成功。

```cpp
if(tmp)
{
    cb();
}
```

* 如果锁定成功（对象还活着），就执行传入的回调 `cb()`。
* 否则，定时器什么都不做（即条件不满足）。


# `TimerManager::addConditionTimer()`


```cpp
std::shared_ptr<Timer> TimerManager::addConditionTimer(
    uint64_t ms, 
    std::function<void()> cb, 
    std::weak_ptr<void> weak_cond, 
    bool recurring
) 
{
    return addTimer(ms, std::bind(&OnTimer, weak_cond, cb), recurring);
}
```

### 📌 作用：

添加一个**条件定时器**。这个定时器的触发行为依赖于 `weak_cond` 所指对象是否仍然存在。

---

### 🔍 逐行解释：

```cpp
return addTimer(
    ms,
    std::bind(&OnTimer, weak_cond, cb),
    recurring
);
```

#### 🔧 `std::bind(&OnTimer, weak_cond, cb)`

* 这里使用了 `std::bind`，生成了一个函数对象：调用时会执行 `OnTimer(weak_cond, cb)`。
* 也就是：到时定时器触发的行为就是执行 `OnTimer`，而 `OnTimer` 又会检查 `weak_cond` 是否还有效。

#### 🧠 等效逻辑如下：

```cpp
if (weak_cond.lock()) {
    cb(); // only execute if the condition object is still alive
}
```

#### 🔄 `addTimer(...)`

* 调用标准 `addTimer` 方法将构造好的函数对象注册到定时器系统中。

---

## 🧠 应用场景示意

比如你希望：

* “如果 `Session` 对象还存在，就在 10 秒后执行一次断开逻辑。”

那你可以这样写：

```cpp
auto session_ptr = std::make_shared<Session>();
auto weak_session = std::weak_ptr<Session>(session_ptr);

timer_mgr->addConditionTimer(10000, [=]() {
    session_ptr->close();
}, weak_session);
```

这样：

* 如果 `session_ptr` 在 10 秒内被销毁，回调就不会执行，**避免了访问野指针**。
* 如果还活着，就正常执行。

---

## ✅ 总结表

| 函数名                      | 作用                         |
| ------------------------ | -------------------------- |
| `OnTimer(weak_cond, cb)` | 检查弱引用是否有效，有效则调用回调函数        |
| `addConditionTimer(...)` | 添加一个条件定时器，只有在指定对象仍存活时才执行回调 |
| 用途                       | 避免在定时器回调中访问已销毁的对象，提升安全性    |


# `TimerManager::getNextTimer()`

### ✅ 函数原型：

```cpp
uint64_t TimerManager::getNextTimer()
```

### 📌 功能概述：

> 获取**时间堆中最近一个定时器**的**相对超时时间（ms）**，如果已经到期则返回 0，如果没有定时器则返回 `~0ull`（表示无穷大，不会触发）。

---

## 🔍 逐行解释：

```cpp
std::shared_lock<std::shared_mutex> read_lock(m_mutex);
```

* 加读锁，保证**线程安全地读取时间堆 `m_timers`**。
* 因为只是读取，不修改内容，所以使用共享锁（`shared_lock`）比独占锁效率更高。

---

```cpp
m_tickled = false;
```

* 将 `m_tickled` 标志位重置为 false。
* 含义：**当前还没有通过 `tickle()` 主动唤醒调度线程**。
* 之后如果一个新的 Timer 插入到最前面，才会触发 `tickle()` 唤醒逻辑，避免冗余唤醒。

---

```cpp
if (m_timers.empty())
{
    return ~0ull;
}
```

* 如果时间堆为空，说明没有任何待处理的定时器。
* 返回一个极大的数（`~0ull` = 全 1，即 `std::numeric_limits<uint64_t>::max()`），表示“**不需要等待定时器事件**”。

---

```cpp
auto now = std::chrono::system_clock::now();
auto time = (*m_timers.begin())->m_next;
```

* 获取当前系统时间（`now`）。
* 获取时间堆中最近一个 timer 的超时时间（`m_next`）。

  * 时间堆是按 `m_next` 升序排列的 `std::set`，因此 `*m_timers.begin()` 就是最近即将触发的那个 timer。

---

```cpp
if(now >= time)
{
    return 0;
}
```

* 如果现在已经等于或超过该 timer 的超时时间，说明这个 timer **已经超时**，应该**立即处理**。
* 返回 `0`，表示：无需再等待。

---

```cpp
auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(time - now);
return static_cast<uint64_t>(duration.count());
```

* 否则，说明还没超时。
* 计算从现在到 `m_next` 之间的毫秒数，表示：**还要再等待多久**才能处理该 timer。
* 作为 `epoll_wait(timeout)` 的参数返回出去（间接决定 idle 协程挂起多久）。

---

## 🧠 举例说明

假设现在时间为 `now = 10000ms`，时间堆最早的定时器是 `m_next = 10050ms`。

* 那么 `getNextTimer()` 返回 `50`，表示还有 `50ms` 超时。
* `epoll_wait(epfd, ..., timeout=50)` -> 最多阻塞 `50ms`，或者期间有 I/O/tickle 唤醒。

如果：

* 当前时间为 `10000ms`，`m_next = 9990ms`
* 则说明已经过期了，返回 `0`，直接触发定时器执行。

---

## ✅ 总结：

| 步骤                  | 含义                    |
| ------------------- | --------------------- |
| 加读锁                 | 保证线程安全读取时间堆           |
| `m_tickled = false` | 重置标志位，表示当前调度线程未被“戳醒”  |
| `m_timers.empty()`  | 如果没有定时器，返回最大值表示“无须等待” |
| `now >= m_next`     | 如果已经到期，返回 0，立刻处理      |
| 否则返回剩余毫秒数           | 表示还需挂起多久再检查           |



# `TimerManager::listExpiredCb()`

## ✅ 函数原型

```cpp
void TimerManager::listExpiredCb(std::vector<std::function<void()>>& cbs)
```

### 📌 功能说明：

该函数从时间堆（`m_timers`）中取出所有“**已经超时**”的定时器对象（`Timer`），并将它们的回调函数（`cb`）提取出来，**填入 `cbs` 向量**中，供调度器调度执行。

如果某个定时器是“**周期性的**”，就重新计算它的下一次到期时间，并重新加入时间堆中。

---

## 🔍 逐行解释

### 第 1 行

```cpp
auto now = std::chrono::system_clock::now();
```

* 获取当前系统时间。
* 用于判断哪些定时器已经超时。

---

### 第 2 行

```cpp
std::unique_lock<std::shared_mutex> write_lock(m_mutex);
```

* 加写锁，因为即将要**修改时间堆 `m_timers`**。
* `std::set`（时间堆）需要加锁保护，防止多线程并发读写冲突。

---

### 第 3 行

```cpp
bool rollover = detectClockRollover();
```

* 判断系统时间是否回退（例如：系统时间从将来被人为设置到过去）。
* 如果回退了，则不能继续依赖 `m_next` 做判断，应该**清空所有 timer**。

---

### 第 4-12 行：核心 while 循环

```cpp
while (!m_timers.empty() && rollover || !m_timers.empty() && (*m_timers.begin())->m_next <= now)
```

* **循环条件解释**：

  * 如果发生了时间回退（`rollover == true`）：

    * 那么所有 timer 都不可信，应该**全清理**。
  * 否则，只清理那些已经超时的 timer：

    * 判断最近的 timer 是否到期：`m_next <= now`

---

### 第 5 行：取出最早的 timer

```cpp
std::shared_ptr<Timer> temp = *m_timers.begin();
```

* 从 `set` 中取出最早的 timer（set 是按 `m_next` 升序排序的）。

---

### 第 6 行：从时间堆中移除

```cpp
m_timers.erase(m_timers.begin());
```

* 将这个已超时的 timer 从时间堆中移除。

---

### 第 7 行：将其回调加入回调队列

```cpp
cbs.push_back(temp->m_cb);
```

* 把 timer 的回调函数添加到外部传入的 `cbs` 列表中，供后续调用。

---

### 第 8-13 行：处理周期性定时器与一次性定时器

```cpp
if (temp->m_recurring) {
    temp->m_next = now + std::chrono::milliseconds(temp->m_ms);
    m_timers.insert(temp);
} else {
    temp->m_cb = nullptr;
}
```

#### 如果是周期性定时器：

* 重新计算下一次到期时间（当前时间 + 周期 ms）。
* 重新插入到时间堆中。

#### 如果是一次性定时器：

* 回调已经存入 `cbs`，定时器也已经从堆中移除。
* 现在将回调置空，**帮助资源释放（防止悬挂引用）**。

---

## ✅ 总结作用

| 步骤        | 内容             |
| --------- | -------------- |
| 获取当前时间    | 用于判断定时器是否到期    |
| 加写锁       | 修改时间堆需要线程安全    |
| 检查系统时间回退  | 若回退则清空所有 timer |
| 循环处理到期定时器 | 从时间堆取出并移除      |
| 提取回调函数    | 填入 `cbs` 中供调度  |
| 处理周期性定时器  | 重新设置下次到期并放回堆中  |
| 处理一次性定时器  | 清理回调函数释放资源     |

---

## 🧠 举个例子

假设当前时间为 10:00:00，时间堆中如下：

| Timer ID | 到期时间 (`m_next`) | 是否循环  |
| -------- | --------------- | ----- |
| A        | 09:59:59        | false |
| B        | 10:00:01        | true  |
| C        | 10:00:02        | false |

`listExpiredCb()` 执行时：

* 会触发 A（已超时），A 被移除，A 的回调存入 `cbs`。
* 不处理 B 和 C（未到期）。
* 如果 A 是循环 timer，会重新计算下一次 `m_next`，插回去。


# `TimerManager::addTimer()`

## ✅ 函数原型

```cpp
void TimerManager::addTimer(std::shared_ptr<Timer> timer);
```

### 📌 作用说明：

* 将一个定时器对象 `Timer` 插入到定时器管理器 `TimerManager` 的\*\*时间堆（红黑树实现）\*\*中。
* 如果新插入的定时器是当前最早到期的定时器，那么需要**通知调度器线程**更新其等待超时时间（通过 `onTimerInsertedAtFront()`）。

---

## 🔍 逐行解释

---

### 第 1 行

```cpp
bool at_front = false;
```

* 标记变量，表示新加入的定时器是否在**堆顶**（即最早到期）。
* 如果是，则可能要唤醒某个线程更新它的 `epoll_wait` 超时等待时间。

---

### 第 2 - 9 行：加锁 + 插入定时器

```cpp
{
    std::unique_lock<std::shared_mutex> write_lock(m_mutex);
    auto it = m_timers.insert(timer).first;
    at_front = (it == m_timers.begin()) && !m_tickled;

    // only tickle once till one thread wakes up and runs getNextTime()
    if(at_front)
    {
        m_tickled = true;
    }
}
```

#### 🔒 第 3 行

```cpp
std::unique_lock<std::shared_mutex> write_lock(m_mutex);
```

* 时间堆 `m_timers` 是一个共享资源，需要加写锁以防止并发修改。
* 所有写操作（插入、删除）都必须加写锁。

---

#### ⬇️ 第 4 行：插入定时器

```cpp
auto it = m_timers.insert(timer).first;
```

* 将 `timer` 插入到 `m_timers`（一个红黑树 / `std::set`）中，自动按 `m_next`（到期时间）排序。
* 返回的 `it` 是插入后的位置迭代器。

---

#### 🏁 第 5 行：判断是否在堆顶

```cpp
at_front = (it == m_timers.begin()) && !m_tickled;
```

* 判断条件：

  1. `it == m_timers.begin()`：说明这个定时器插入到了最前面，是当前最早要执行的 timer。
  2. `!m_tickled`：避免重复唤醒多个线程。

> 💡 为什么 `!m_tickled`？
>
> * 在 `getNextTimer()` 调用前只需要 tickle 一次，避免同一个 timer 插入时被多个线程同时响应。
> * 保证**只唤醒一个线程去重新设置 epoll\_wait 超时时间**。

---

#### 第 6-8 行：设置 m\_tickled

```cpp
if(at_front)
{
    m_tickled = true;
}
```

* 如果真的需要 tickle（唤醒线程），就把 `m_tickled` 标志位置为 true。

---

### 第 11-14 行：必要时唤醒调度线程

```cpp
if(at_front)
{
    // wake up 
    onTimerInsertedAtFront();
}
```

#### ✅ 调用 `onTimerInsertedAtFront()`：

* 虚函数，由 `IOManager` 实现为：

```cpp
void IOManager::onTimerInsertedAtFront() {
    tickle();
}
```

* 它的本质是：**唤醒阻塞在 `epoll_wait()` 上的 IO 调度线程**，让它重新调用 `getNextTimer()`，更新等待时间。

---

## ✅ 函数核心逻辑总结图

```text
                插入 Timer
                     ↓
        ┌──────────────────────────────┐
        │ 加锁，插入 timer 到 m_timers │
        └──────────────────────────────┘
                     ↓
         判断是否最早要执行的 timer？
                     ↓
               是            否
             ┌──────┐     ┌──────┐
             │at_front=true│     │ 不唤醒
             └──────┘     └──────┘
                     ↓
        ┌──────────────────────────────┐
        │ 设置 m_tickled = true（只唤醒一次）│
        └──────────────────────────────┘
                     ↓
        ┌────────────────────────────┐
        │ onTimerInsertedAtFront() → tickle() │
        └────────────────────────────┘
                     ↓
        IO线程从 epoll_wait 中苏醒
```

---

## ✅ 举例场景

假设原本只有一个定时器，10 秒后触发，现在新加入一个定时器 3 秒后触发：

* 新 timer 会插入堆顶。
* 当前 IO 调度线程在 `epoll_wait(timeout=10s)`。
* 因为更早的 timer 被插入了，调度线程需要**被 tickle 唤醒**，重新 `epoll_wait(3s)`。

---

## 📌 总结重点

| 名称                         | 作用                    |
| -------------------------- | --------------------- |
| `m_timers.insert()`        | 插入到定时器堆中              |
| `at_front`                 | 判断是否是堆顶 timer         |
| `m_tickled`                | 防止重复唤醒                |
| `onTimerInsertedAtFront()` | 唤醒 epoll\_wait 等待线程   |
| `tickle()`                 | 最终唤醒机制，由 IOManager 实现 |

# `TimerManager::detectClockRollover()`


## ✅ 函数原型

```cpp
bool TimerManager::detectClockRollover() 
```

### 📌 函数作用：

该函数用于**检测系统时间是否出现回退（Rollover）现象**。

---

## 🌟 场景背景

在定时器系统中，我们常用 `std::chrono::system_clock::now()` 获取当前时间点。如果系统时间被手动/自动地调整成过去时间（例如用户修改了系统时钟），就会导致 **定时器机制异常**：

* 已设置的定时器本来“还没到”，因为系统时间被“倒拨了”，它们会**永远不会触发**。
* 因为堆顶的 timer（最小的 `m_next`）可能比现在“未来得多”。

为避免这种**时间倒流问题**对 timer 系统的影响，我们需要对系统时钟进行监控，一旦发现有显著的时间回退（比如回退一小时），则主动触发策略（比如清空所有 timers、立刻重置等）。

---

## 🧩 函数逐行解释

---

### 第 1 行

```cpp
bool rollover = false;
```

* 设置标志变量，表示是否检测到系统时间回退。

---

### 第 2 行

```cpp
auto now = std::chrono::system_clock::now();
```

* 获取当前系统时间点，类型是 `std::chrono::time_point`。
* 这是一个**高精度的绝对时间点**，通常基于系统时间戳。

---

### 第 3\~5 行：核心检测逻辑

```cpp
if(now < (m_previouseTime - std::chrono::milliseconds(60 * 60 * 1000))) 
{
    rollover = true;
}
```

#### 💡 逻辑解释：

* 条件含义：**当前时间比上次记录的时间早了超过 1 小时**。
* 也就是说，**系统时间回退了超过一小时**。

#### ⚠️ 这个判断非常宽容（1 小时容忍区间），为什么不是一秒钟？

* 系统时间可能因为 NTP、BIOS 或系统设置发生轻微跳动（比如几十毫秒）。
* 所以要设置一个比较大的容忍时间窗口，**避免误判**。
* 超过一小时通常是用户手动调时间、虚拟机调整、时间同步错误等严重问题。

---

### 第 6 行

```cpp
m_previouseTime = now;
```

* 更新 `m_previouseTime` 为当前时间。
* 下一次再调用 `detectClockRollover()` 时，会将这次的 `now` 作为对比基准。

---

### 第 7 行

```cpp
return rollover;
```

* 返回是否检测到回退。
* 如果 `true`，上层逻辑（如 `listExpiredCb()`）会据此作出清理策略。

---

## 📊 时序图示意

```text
时间线 ↑

              |<- 允许最大回退时长（1小时）->|
              |                               |
prevTime ---> |-----------------------------→|
              |
              ↓
             now   --> 如果 now < prevTime - 1小时 ==> rollover = true
```

---

## 🚨 使用位置分析

### 主要使用点在：

```cpp
void TimerManager::listExpiredCb(std::vector<std::function<void()>>& cbs)
```

其中的：

```cpp
bool rollover = detectClockRollover();
while (!m_timers.empty() && (rollover || m_timers.begin()->m_next <= now))
```

也就是说：

* 如果发生回退（rollover == true），就认为当前所有 timer 都“过期”了（强制触发回调）。
* 否则正常按时间判断 `m_next <= now`。

---

## 🔄 示例举例说明

1. 正常情况：

   * 上一次 `m_previouseTime = 2025-06-29 14:00:00`
   * 当前 `now = 2025-06-29 14:10:00`
   * 条件：`14:10 < 14:00 - 1h` = ❌ false

2. 时间倒拨：

   * 上一次 `m_previouseTime = 2025-06-29 14:00:00`
   * 当前 `now = 2025-06-29 11:50:00`
   * 条件：`11:50 < 14:00 - 1h = 13:00` = ✅ true → rollover

---

## ✅ 总结重点

| 名称                            | 作用                          |
| ----------------------------- | --------------------------- |
| `m_previouseTime`             | 上一次检测时系统时间                  |
| `now < m_previouseTime - 1小时` | 判断时间是否回退                    |
| `m_tickled`                   | 与此无关，只用于定时器插入控制             |
| `rollover==true` 时的作用         | listExpiredCb 中将“强制”触发所有定时器 |


