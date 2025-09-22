很好，这个测试文件是专门用来验证 **`wait_group`** 的语义是否正确的。我们一步一步来拆解。

---

## 1. 文件包含

```cpp
#include "coro/coro.hpp"
#include "coro/comp/wait_group.hpp"
#include "gtest/gtest.h"
```

* **`coro/coro.hpp`**：统一包含库的主要接口（调度器、任务系统等）。
* **`coro/comp/wait_group.hpp`**：就是你实现的 `wait_group`。
* **GoogleTest**：测试框架。

---

## 2. main 函数

```cpp
int main(int argc, char** argv)
{
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
```

标准 gtest 入口，负责运行所有测试。

---

## 3. WaitgroupTest 测试夹具

```cpp
class WaitgroupTest : public ::testing::TestWithParam<std::tuple<int, int, int>>
```

* 使用 `TestWithParam`：说明测试是**参数化测试**，即用不同的 `(thread_num, done_num, wait_num)` 组合运行相同逻辑。
* 内部变量：

  * `wait_group m_wg;`：测试的核心对象。
  * `std::atomic<int> m_id;`：一个全局递增的计数器，用来验证协程的执行顺序。
  * `std::vector<int> m_done_vec;`：记录所有调用 `wg.done()` 的任务的执行次序。
  * `std::vector<int> m_wait_vec;`：记录所有等待 `wg.wait()` 的任务的执行次序。

### 生命周期

* **SetUp()**：初始化 `m_id = 0`。
* **TearDown()**：这里没做事。

---

## 4. 协程函数

### 4.1 `done_func`

```cpp
task<> done_func(wait_group& wg, std::atomic<int>& id, int* data)
{
    *data = id.fetch_add(1, std::memory_order_acq_rel);
    wg.done();
    co_return;
}
```

作用：

* 给 `*data` 赋值一个唯一的 id（记录执行顺序）。
* 调用 `wg.done()`：表示一个任务完成，可能触发等待者恢复。

### 4.2 `wait_func`

```cpp
task<> wait_func(wait_group& wg, std::atomic<int>& id, int* data)
{
    co_await wg.wait();
    *data = id.fetch_add(1, std::memory_order_acq_rel);
}
```

作用：

* `co_await wg.wait();`：挂起，直到所有 `done()` 调用完。
* 恢复后才写入 `*data`。

⚠️ 所以 **所有 `done_func` 的 id 必须在 `wait_func` 之前**。

---

## 5. 测试用例

```cpp
TEST_P(WaitgroupTest, DoneAndWait)
```

每组参数都会执行这个测试。

### 5.1 参数解析

```cpp
int thread_num, done_num, wait_num;
std::tie(thread_num, done_num, wait_num) = GetParam();
scheduler::init(thread_num);
```

* `thread_num`：调度器线程数。
* `done_num`：要执行多少个“完成任务”。
* `wait_num`：要执行多少个“等待任务”。

---

### 5.2 提交任务

```cpp
m_done_vec = std::vector(done_num, 0);
m_wait_vec = std::vector(wait_num, 0);

for (int i = 0; i < wait_num; i++)
    submit_to_scheduler(wait_func(m_wg, m_id, &(m_wait_vec[i])));

for (int i = 0; i < done_num; i++)
{
    m_wg.add(1);
    submit_to_scheduler(done_func(m_wg, m_id, &(m_done_vec[i])));
}
```

* 先提交所有等待任务 → 它们会挂起，等待 `done`。
* 再提交所有完成任务：

  * 每次提交前 `m_wg.add(1)` → 表示 `wait_group` 中要等待的任务数量+1。
  * 任务完成时 `done()` → 计数减1。
  * 当计数归零时 → 所有 `wait_func` 被恢复。

---

### 5.3 跑调度器

```cpp
scheduler::loop();
```

执行调度循环直到所有任务完成。

---

### 5.4 验证逻辑

```cpp
std::sort(m_done_vec.begin(), m_done_vec.end());
std::sort(m_wait_vec.begin(), m_wait_vec.end());

ASSERT_LT(*m_done_vec.rbegin(), *m_wait_vec.begin());
for (int i = 0; i < done_num; i++)
    ASSERT_EQ(m_done_vec[i], i);
for (int i = 0; i < wait_num; i++)
    ASSERT_EQ(m_wait_vec[i], i + done_num);
```

验证点：

1. **执行顺序**

   * `*m_done_vec.rbegin()`：done 中的最大 id。
   * `*m_wait_vec.begin()`：wait 中的最小 id。
   * 断言 `max(done) < min(wait)` → 确保所有 `done_func` 先执行完，`wait_func` 才恢复。

2. **递增顺序**

   * `m_done_vec[i] == i` → done 的 id 必须从 0 开始依次递增。
   * `m_wait_vec[i] == i + done_num` → wait 的 id 必须接在 done 之后。

---

## 6. 参数化组合

```cpp
INSTANTIATE_TEST_SUITE_P(
    WaitgroupTests,
    WaitgroupTest,
    ::testing::Values(
        std::make_tuple(1, 1, 1),
        std::make_tuple(1, 1, 100),
        ...
        std::make_tuple(0, 100, config::kMaxTestTaskNum)));
```

测试覆盖面：

* **不同线程数**：`1` 和 `0`（0 应该表示用当前线程跑）。
* **不同任务规模**：

  * done 数量小/大（1, 100）。
  * wait 数量小/大（1, 100, 10000, kMaxTestTaskNum）。
* 目的是验证 `wait_group` 在各种组合下都能正确同步。

---

## 7. 总结

* 这个测试文件完整验证了 `wait_group` 的核心语义：

  1. **等待的任务必须在所有 done 任务完成之后恢复。**
  2. **done 与 wait 的执行顺序严格按照 ID 线性增长，确保同步正确性。**
* 测试同时覆盖单线程调度和多线程调度。
* 也验证了 `wait_group` 的高并发性能（比如 10k 甚至 `kMaxTestTaskNum`）。

---

要不要我帮你画一张 **`done_func / wait_func / wait_group` 交互流程图**，让你直观地看出调度和同步的时序关系？



好问题 👍，你抓到了这个实现里一个比较“迷惑”的点。
表面看上去确实：

```cpp
for (int i = 0; i < wait_num; i++)
    submit_to_scheduler(wait_func(m_wg, m_id, &(m_wait_vec[i])));
```

在 `wait_func` 里面：

```cpp
task<> wait_func(wait_group& wg, std::atomic<int>& id, int* data)
{
    co_await wg.wait();   // 等待
    *data = id.fetch_add(1, std::memory_order_acq_rel);
}
```

调用 `wg.wait()` 返回一个 `awaiter`，接着调用 `await_suspend`。
你觉得「这时候 `m_count` 还没增加，岂不是立刻返回 `false`，不会挂起吗？」

我们仔细拆解一下执行顺序：

---

### 1. 提交 `wait_func` 时的场景

* 这时还没调用 `m_wg.add(count)`，所以 **`m_count = 0`**。
* `co_await wg.wait()` → `awaiter.await_suspend(...)` 被调用。

代码逻辑是：

```cpp
if (m_wg.m_count.load(...) == 0) {
    return false;   // 直接不挂起，协程继续往下执行
}
```

所以，确实，**在 `add()` 之前提交的 `wait_func` 是不会挂起的**，而是直接继续执行 `*data = ...`。
这样它们并没有真的等到任务完成。

---

### 2. 那为什么测试能跑通？

因为测试代码里调用顺序是这样的：

```cpp
for (int i = 0; i < wait_num; i++)
    submit_to_scheduler(wait_func(...));

for (int i = 0; i < done_num; i++)
{
    m_wg.add(1);
    submit_to_scheduler(done_func(...));
}

scheduler::loop();
```

**关键点：**

* `submit_to_scheduler(...)` 只是把协程丢进调度器队列里，还没有真正执行。
* 真正执行是在 `scheduler::loop()` 里。

所以调度器第一次调度 `wait_func` 的时候，**此时 `done_num` 个 `add(1)` 已经调用过了**（因为提交 done\_func 的循环在 wait\_func 循环后面执行）。
因此：

* 当 `wait_func` 的 `await_suspend` 运行时，`m_wg.m_count > 0`。
* 它们就会走 `compare_exchange_weak`，把自己挂到 `m_state` 链表里，等待 `done()` 唤醒。

换句话说：
虽然 `wait_func` 代码写在前面，但因为调度顺序问题，**等它真的 `co_await` 的时候，`m_count` 已经被 add() 增加了**，所以才会正确挂起。

---

### 3. 结论

你问的「为什么不会挂起」其实是因为你默认 `submit_to_scheduler` 立即执行，但实际上：

* `submit_to_scheduler` 只是投递任务，不会立刻运行协程体。
* 真正执行时机是在 `scheduler::loop()` 里。
* 到那个时候，`add()` 已经增加了计数，所以 `wait_func` 会真的挂起。

---

要是换一种写法，比如：

```cpp
submit_to_scheduler(wait_func(...));
scheduler::loop();   // 提前 loop

m_wg.add(1);
submit_to_scheduler(done_func(...));
```

那就会触发你说的问题：`wait_func` 看到 `m_count == 0`，直接继续执行，不会等。

所以这份实现的 **正确用法要求：先 add() 再 loop()，保证 count 已经设置好**。
测试里正好遵循了这个模式，所以能跑通。

---

要不要我帮你画一个 **时间线执行顺序图**（调度器里 wait\_func、done\_func、count 变化过程），让整个流程更直观？
