下面把 `wait_group.hpp` 逐块讲清楚，并顺带指出它与 `latch` / `event` 的区别、典型用法、并发语义（尤其是无锁等待者链表）以及实现时需要注意的内存序与生命周期细节。

---

# 这个类型是干嘛的？

`wait_group` 是一个**可复用**的“等待一组任务完成”的原语，语义上对应 Go 的 `sync.WaitGroup`：

* 用 `add(n)` 增加待完成任务的计数。
* 每个任务完成时调用 `done()`（相当于 `add(-1)`）。
* `wait()` 返回一个可 `co_await` 的 awaiter：当计数归零时**同时**唤醒所有在 `wait()` 上挂起的协程。

与 `latch`（一次性栅栏）不同，`wait_group` **可多次使用**：当计数回到 0 后，还可以再 `add()` 进入下一轮。
与 `event`（一次性广播事件）不同，`wait_group` 的“已触发”状态不是永久的，而是**由 m\_count 是否为 0**动态决定。

---

# 成员结构

```cpp
std::atomic<int32_t>     m_count; // 剩余任务数
std::atomic<awaiter_ptr> m_state; // 等待者链表的头指针（侵入式单链）
```

* `m_count`：待完成任务的原子计数。大于 0 表示还有任务未完成；等于 0 表示可以唤醒等待者。
* `m_state`：用来维护**等待者单向链表**的“头指针”，类型是 `void*`（别名 `awaiter_ptr`）。通常用三种值表示三种状态：

  * `nullptr`：当前没有等待者（常见于 `m_count>0` 或计数刚好到 0 且没有人 wait）。
  * `指向 awaiter 的指针`：有至少一个协程在 `wait()` 上挂起，`m_state` 指向链表头。
  * （不像 `event` 用 `this` 当“已触发标记”，`wait_group` 不需要，因为它是**可复用**的，不能永久停在“已触发”。）

> 这种把“状态 + 链表头”合在一个原子指针里的做法，能用一次 CAS 完成“登记自己为新表头”，性能很好。

---

# 内部 `awaiter` 的角色

```cpp
struct awaiter
{
    context&                m_ctx;        // 等待者所在的调度上下文
    wait_group&             m_wg;         // 关联的 wait_group
    awaiter*                m_next{nullptr};    // 侵入式单链 next
    std::coroutine_handle<> m_await_coro{nullptr}; // 恢复用的协程句柄
};
```

* `awaiter` 封装了挂起/恢复一个等待协程所需的最少信息：

  * 恢复时通过 `m_ctx.submit_task(m_await_coro)` 把协程交回其原 context 执行；
  * `m_next` 用于把多个等待者串成单链表。

### awaiter 的三个协程钩子（语义）

```cpp
constexpr auto await_ready() noexcept -> bool { return false; }
```

* 返回 `false` 表示**总是尝试挂起**，真正要不要挂起由 `await_suspend` 决定（“再确认一次计数是否为 0”）。

```cpp
auto await_suspend(std::coroutine_handle<> handle) noexcept -> bool;
```

* 保存 `handle` 到 `m_await_coro`；
* 如果此刻 `m_count == 0`（已有/刚到 0），**不挂起**：返回 `false`，让编译器直接继续执行 `await_resume()`；
* 否则把自己用 **CAS push** 的方式挂到 `m_state` 链表头上，返回 `true` 表示**挂起**；
* 注意：这个函数里要做“竞态处理”，防止在读到 `m_count > 0` 和把自己挂入链表之间，别的线程已经把计数减到 0 并唤醒了等待者。

```cpp
auto await_resume() noexcept -> void;
```

* 挂起返回后的清理。若你有“等待计数”的统计（像 `event` 那样对 `context` 做 register/unregister），就要在这里做 `unregister`。

```cpp
auto resume() noexcept -> void;
```

* 供 `wait_group` 在计数到 0 时调用：通常实现为 `m_ctx.submit_task(m_await_coro)` 或等价逻辑，把等待协程提交回去恢复。

> 这里的接口表明 `wait_group` 不依赖 `event_base`，而是自己管理等待者链和恢复逻辑，更灵活，也便于实现“可复用”。

---

# 三个用户可见方法

### 1) `wait()`

```cpp
auto wait() noexcept -> awaiter { return awaiter(local_context(), *this); }
```

* 返回一个绑定到**当前上下文**和**此 wait\_group** 的 awaiter。
* 协程里 `co_await wg.wait()` 即可等待 `m_count` 归零。

### 2) `add(int count)`

* 用来**增加**（或减少，若为负） `m_count`。
* 典型实现：

  * `m_count.fetch_add(count, acq_rel)`；
  * 要求：**在有线程/协程等待时不要把计数加回正值**（或至少定义清楚语义）。Go 的 WaitGroup 要求使用者遵守“在有人 Wait 时不再 Add”（违反会触发 panic）。你也可以在 debug 版本里加断言。
* 若你希望允许“从 0 再加回去”开启新一轮，**一定要在 `m_count` 从 0 变正之前保证 `m_state == nullptr`**（即上一轮所有 Wait 要么没注册、要么已被唤醒并清空链表）。

### 3) `done()`

* 对 `m_count` 做 `fetch_sub(1, acq_rel)`，若旧值 `<= 1`，说明这次把计数从 1→0（或已经非正），应该**唤醒所有等待者**：

  * 先用 `exchange(nullptr, acq_rel)` **一次性摘下** `m_state` 链表头（得到等待者单链）；
  * 遍历链表，对每个 `awaiter` 调 `resume()`（通常是 `submit_task(handle)`）。
* 关键点：**先取 next 再恢复**，避免 `submit_task` 立刻恢复并销毁 awaiter 导致 UAF（这点在你 `event` 的讲解里已经提过）：

  ```cpp
  for (auto* p = head; p; ) {
      auto* next = p->m_next;       // 先拿 next
      p->resume();                   // 立刻可能销毁 p
      p = next;                      // 再推进
  }
  ```

---

# 典型实现的并发与内存序建议

1. **注册等待者（await\_suspend）**：

   * 读 `m_count`：`load(acquire)`；
   * 如果 `m_count == 0`：直接返回 `false`（不挂起）；
   * 否则用 **CAS push** 把自己挂到 `m_state`：

     ```cpp
     do {
         old = m_state.load(acquire);
         m_next = (awaiter*)old;
     } while (!m_state.compare_exchange_weak(
                  old, this,
                  std::memory_order_acq_rel,  // 成功发布：m_next 的写入对唤醒方可见
                  std::memory_order_acquire));
     ```
   * 再次**双检**（可选但更稳妥）：挂入后再看一眼 `m_count` 是否已经到 0，若是，需要把自己从头摘掉或“立即恢复”。常见简化是：把“到 0 的线程”负责唤醒**当时**已经在表上的所有等待者，竞态自然会覆盖。

2. **计数到 0（done）唤醒**：

   * `old = m_count.fetch_sub(1, acq_rel);`
   * `if (old <= 1)`（从 1→0 或已经非正）：

     ```cpp
     auto* head = (awaiter*) m_state.exchange(nullptr, std::memory_order_acq_rel);
     // 遍历 head 链，逐个 resume
     ```

3. **可见性保证**：

   * `acq_rel` 的组合确保如下顺序：

     * 任务线程在 `done()` 前做的写入 ——>（release） ——> 其他等待线程在被唤醒运行时能（acquire）看见；
     * `m_state` 链表 push 的 `m_next` 写入，对唤醒侧在 `exchange(acq_rel)` 之后可见。

---

# 与 `latch`、`event` 的区别

* **`latch`**：一次性原语。构造时给定固定计数，计数到 0 触发一次事件并永久保持触发；后续 `wait()` 都立即就绪。适合**单轮**场景。
* **`wait_group`**：可复用原语。`add()/done()` 动态改变计数，只要回到 0 就唤醒当前等待者；之后还可以再 `add()` 开启下一轮。适合**多轮**“一组任务全部完成再继续”的场景。
* **`event`**：一次性广播事件；没有计数概念。`set()` 后永久触发，不能 reset（除非你自己做 reset 版本）。

---

# 用法示例

```cpp
wait_group wg;

// 开启 3 个任务
wg.add(3);

for (int i = 0; i < 3; ++i) {
    submit_to_scheduler([&]() -> task<> {
        // ... do work ...
        wg.done();            // 每个任务完成后 -1
        co_return;
    }());
}

// 某处等待所有任务完成
task<> waiter = [&]() -> task<> {
    co_await wg.wait();       // 直到 m_count==0
    // ... 继续后续逻辑 ...
    co_return;
}();
submit_to_scheduler(std::move(waiter));
```

**下一轮**：当 `m_count` 变回 0 后，可以再次 `wg.add(n)` 开新一轮。

---

# 边界与约束（务必在实现/使用时明确）

* **禁止把 `m_count` 减到负值**（与 Go 类似，`Add(-x)` 累计超过已 Add 的总数会 panic）。可以在 `done()` 或 `add(负数)` 时加断言或返回错误。
* **强烈建议**规定：**有等待者时不允许再 `add()`**（或至少明确语义）。最安全的做法是：只在 `m_count == 0` 时开始新一轮 `add()`；否则可能出现“有一部分等待者已经恢复，但又被加回去”的竞态，语义复杂。
* 多个并发 `wait()` 是允许的，都会被一起唤醒。
* **UAF 风险**：唤醒时一定要**先读 next 再 resume**（如上所示），否则若调度器选择“立即执行/inline resume”，当前 `awaiter` 可能立刻被销毁，随后访问 `m_next` 会 UAF。
* 如果你像 `event` 那样对 `context` 维持“等待计数”（`register_wait()/unregister_wait()`），要在 `await_ready()/await_resume()` 里成对调用，便于调度器判断“系统是否空闲”。

---

# 小结

* `wait_group` 提供了**计数驱动 + 可复用**的等待机制，适合“批次工作”场景。
* 内部用一个原子计数和一个**无锁侵入式链表**来管理等待者注册与批量唤醒。
* 关键实现点：**CAS push 链表**、**count 从 1→0 的原子转变触发唤醒**、**正确的内存序**、以及**唤醒时避免 UAF**。
