下面把这份基于 GoogleTest 的 `latch` 参数化测试逐段讲清楚，核心就是验证你实现的 **一次性栅栏 `latch`** 与协程事件 `event<>` 的配合是否正确：**所有等待者都在计数归零之后才被唤醒**，并且唤醒发生在所有倒计时任务之后。

---

## 文件结构与辅助任务

### `main`

```cpp
::testing::InitGoogleTest(&argc, argv);
return RUN_ALL_TESTS();
```

标准 GTest 启动入口。

### 测试夹具 `LatchTest`

* 成员：

  * `m_id`：`std::atomic<int>`，用来给每个任务分配一个**顺序号**（通过 `fetch_add(1)`）。
  * `m_countdown_vec`：记录所有 **countdown 任务** 写入的顺序号。
  * `m_wait_vec`：记录所有 **wait 任务** 写入的顺序号。
* `SetUp()` 把 `m_id` 复位为 0。

### 两个协程任务

1. `countdown_func(latch& lt, std::atomic<int>& id, int* data)`

```cpp
auto guard = latch_guard{lt};
*data = id.fetch_add(1, std::memory_order_acq_rel);
co_return;
```

* 构造 `latch_guard`（RAII），其析构时会对 `lt.count_down()`。
* 给 `*data` 赋值为当前序号（然后全局计数自增）。
* 这个协程**没有任何 `co_await`**，因此一旦被调度执行，会**一次跑到结尾**；到达函数末尾后，`guard` 立刻析构，从而对 `latch` 执行一次 `count_down()`。

2. `wait_func(latch& lt, std::atomic<int>& id, int* data)`

```cpp
co_await lt.wait();
*data = id.fetch_add(1, std::memory_order_acq_rel);
```

* 先在 `lt` 上等待：底层是 `event<>::wait()`，如果 `latch` 计数还没归零，这里会**挂起**。
* 只有当 `latch` 的计数通过所有倒计时任务的 `count_down()` 归零并触发事件 `set()` 之后，才会恢复并写入 `*data` 的序号。

> 两类任务都用同一个 `m_id` 做编号，因此**哪个任务先运行，谁拿到的编号就小**。我们就用这个来断言先后关系。

---

## 测试体 `CountdownAndWait`

整体流程：

1. 参数获取：`thread_num, countdown_num, wait_num`。
2. `scheduler::init(thread_num);`

   * 线程数为 0 时，内部会用 `std::thread::hardware_concurrency()`（参考你的 `scheduler.hpp` 实现）。
3. 构造 `latch lt(countdown_num);`

   * 计数为 `countdown_num`，即需要这么多次 `count_down()` 才会触发。
4. 分配结果数组：

   ```cpp
   m_countdown_vec = std::vector(countdown_num, 0);
   m_wait_vec      = std::vector(wait_num, 0);
   ```
5. **先提交所有等待者任务**（会阻塞在 `lt.wait()`）：

   ```cpp
   for (i : 0..wait_num-1)
       submit_to_scheduler(wait_func(lt, m_id, &m_wait_vec[i]));
   ```
6. **再提交所有倒计时任务**：

   ```cpp
   for (i : 0..countdown_num-1)
       submit_to_scheduler(countdown_func(lt, m_id, &m_countdown_vec[i]));
   ```
7. `scheduler::loop();`

   * 启动并等待所有 context 运行结束（即所有任务完成，事件/IO 清空，停止信号发出）。
8. 排序 & 断言：

   ```cpp
   std::sort(m_countdown_vec.begin(), m_countdown_vec.end());
   std::sort(m_wait_vec.begin(), m_wait_vec.end());

   ASSERT_LT(*m_countdown_vec.rbegin(), *m_wait_vec.begin());
   for (i) ASSERT_EQ(m_countdown_vec[i], i);
   for (i) ASSERT_EQ(m_wait_vec[i], i + countdown_num);
   ```

### 断言含义

* `ASSERT_LT(max(countdown_vec), min(wait_vec))`

  * **所有倒计时任务的编号都小于任何一个等待任务的编号**。
  * 这直接证明：**等待任务都是在所有倒计时任务之后才开始执行写入编号**——也就是 `latch` 的唤醒晚于全部 `count_down()`。
* `countdown_vec` 排序后应为 `0..countdown_num-1`：

  * 倒计时任务一共拿到 `countdown_num` 个最小的编号。
* `wait_vec` 排序后应为 `countdown_num..countdown_num+wait_num-1`：

  * 所有等待者拿到后续的编号，且数量为 `wait_num`。

> 尽管提交顺序是“先 wait 再 countdown”，但等待者会被 `lt.wait()` 挂起直到事件触发，因此它们的编号**一定排在倒计时任务之后**，测试正是用 `m_id` 的全局递增编号来验证这个时序。

---

## 参数化用例

```cpp
INSTANTIATE_TEST_SUITE_P(
    LatchTests,
    LatchTest,
    ::testing::Values(
        std::make_tuple(1, 1, 1),
        std::make_tuple(1, 1, 100),
        std::make_tuple(1, 1, 10000),
        std::make_tuple(1, 100, 1),
        std::make_tuple(1, 100, 100),
        std::make_tuple(1, 100, 10000),
        std::make_tuple(0, 1, 1),
        std::make_tuple(0, 1, 100),
        std::make_tuple(0, 1, 10000),
        std::make_tuple(0, 100, 1),
        std::make_tuple(0, 100, 100),
        std::make_tuple(0, 100, 10000),
        std::make_tuple(0, 100, config::kMaxTestTaskNum)));
```

* 覆盖两类线程配置：

  * `thread_num = 1`：单 context/线程。
  * `thread_num = 0`：让调度器自选 `hardware_concurrency()`，多线程并发环境。
* 倒计时与等待数量做**组合爆破**：

  * 倒计时：`1` 或 `100`；
  * 等待：`1`、`100`、`10000`，以及更大的 `config::kMaxTestTaskNum`。
* 目的：在**不同并发度与规模**下都验证相同的先后断言，确保 latch 的语义稳定。

---

## 关于行为细节 & 正确性要点

* **为什么先提交 wait 也没问题？**
  `wait_func` 会在 `lt.wait()` 处挂起，直到 `countdown_num` 次 `count_down()` 全部完成，`event` 被 `set()` 一次性唤醒所有等待者。
* **为什么要排序再断言？**
  多线程调度下，任务被调度的先后不可预期。排序后只关心**编号集合**与**区间**，不依赖具体 interleave。
* **`latch_guard` 的价值**
  即便后续改动 `countdown_func` 逻辑（提前 `co_return` 或异常），`latch_guard` 也能在作用域结束时保证 `count_down()` 必被调用，避免死等。
* **`m_id.fetch_add` 的内存序**
  用 `acq_rel` 够用，这里主要是获取全局递增编号；即使用 `relaxed` 也能得到单调编号，但保持 `acq_rel` 与整体事件发布/获取语义一致更稳妥。
* **零计数的讨论**
  测试里 `countdown_num` ≥ 1。若构造 `latch(0)`，你的 `latch` 会把 `event` 初始置为已触发，`wait()` 将**立即通过**，这是与 `std::latch` 一致的“零计数即满足”。

---

## 小结

这组测试通过一个**全局递增编号**的技巧，稳健地验证了：

1. 所有倒计时任务先于所有等待任务完成（`max(countdown) < min(wait)`）；
2. 倒计时任务和等待任务分别“占据”两个连续区间 `[0, countdown_num)` 与 `[countdown_num, countdown_num + wait_num)`；
3. 以上性质在单线程和多线程（`thread_num=0`）下都成立，且适用于不同规模。

这基本覆盖了 `latch` + `event` 的关键行为：**一次触发、广播唤醒、等待者只在计数归零后恢复**。
