下面把 `latch.hpp` 拆开讲清楚：它实现了一个**一次性（one-shot）异步栅栏**，语义类似 C++20 的 `std::latch`，但等待方式是返回一个可 `co_await` 的 awaiter（依赖你前面实现的 `event<>`）。

# 这是什么

* `latch` 持有一个原子计数 `m_count` 和一个事件 `m_ev`。
* 多个任务并发调用 `count_down()` 把计数减到 0（或以下）时，`m_ev.set()` 被触发，**一次性**唤醒所有等待者。
* `wait()` 不阻塞线程，而是返回 `event<>::awaiter`，供协程 `co_await l.wait()` 使用。

# 成员与构造

```cpp
std::atomic<std::int64_t> m_count;
event<> m_ev;
```

构造：

```cpp
latch(std::uint64_t count) noexcept
  : m_count(count), m_ev(count <= 0) {}
```

* `m_count` 初始为 `count`。
* `m_ev` 初始是否已触发：`count == 0` 时立即置为已触发（`count` 是无符号，只有 0 会让 `count <= 0` 成立），因此**零计数**的 latch，`wait()` 会立刻就绪。

⚠️ 一个小细节：形参是 `uint64_t`，成员是 `int64_t`。若传入值大于 `INT64_MAX` 会**窄化/溢出**。通常不实用到那么大，但更稳妥是统一为相同的有符号类型或在构造时做范围检查。

# count\_down()

```cpp
if (m_count.fetch_sub(1, std::memory_order::acq_rel) <= 1) {
    m_ev.set();
}
```

* 使用 `fetch_sub(…, acq_rel)` 返回**旧值**。当旧值 `<= 1` 时，说明这次减法把计数从 1→0（或已经≤0，继续减少），触发事件。
* 触发后再次调用 `count_down()` 不会有副作用（`event<>` 是 one-shot；多次 `set()` 等价于一次）。
* `acq_rel` 的语义：

  * **release**：发布当前线程在 `count_down()` 之前完成的写入，使等待者在看到事件触发（`m_ev.set()` 内部 `exchange(acq_rel)`）后以 **acquire** 读取到这些写入。
  * **acquire**（失败路径不涉及）：这里用于与其他线程的 `exchange` 建立同步，整体与 `event` 的 `set_state()`/`register_awaiter()` 的内存序配合达成“先做事，后唤醒，唤醒后可见”的保障。

关于 `<= 1`：

* 旧值为 `1`：这次变为 0，理应触发。
* 旧值为 `0` 或负数：说明之前已经触发过或被“多减”，再次 `set()` 也安全（`event` 幂等）。

# wait()

```cpp
auto wait() noexcept -> event_t::awaiter { return m_ev.wait(); }
```

* 返回 `event<>` 的 awaiter，协程里 `co_await l.wait()` 即可。
* 若 `m_ev` 已触发（计数已达 0），`await_ready()` 为真，立即通过；否则注册到 `event` 的等待链上。

# latch\_guard（RAII）

```cpp
class latch_guard {
public:
    latch_guard(latch& l) noexcept : m_l(l) {}
    ~latch_guard() noexcept { m_l.count_down(); }
private:
    latch& m_l;
};
```

* 作用域退出（无论正常/异常）自动 `count_down()` 一次，常用于“并发 N 份工作，任一工作完成就把栅栏计数 -1”。

⚠️ 建议把 `latch_guard` 也 **禁用拷贝/移动**（像 `latch` 一样），否则不小心复制会导致**多次析构、多次 `count_down()`**：

```cpp
latch_guard(const latch_guard&) = delete;
latch_guard& operator=(const latch_guard&) = delete;
latch_guard(latch_guard&&) = delete;
latch_guard& operator=(latch_guard&&) = delete;
```

# 线程安全与一次性语义

* `count_down()` 可被多个线程/协程并发调用；`fetch_sub` 保证原子性。
* `wait()` 通过 `event<>` 的无锁栈注册/唤醒；`event` 是**一次性**，没有 `reset()`，所以 `latch` 也天然是一次性的：计数到 0 后永久处于已触发状态，后来的 `wait()` 会**立即就绪**。

# 使用示例

```cpp
coro::latch l(3);

task<void> worker() {
    coro::latch_guard g{l};   // 作用域结束自动 -1
    // ... do work ...
    co_return;
}

task<void> waiter() {
    co_await l.wait();        // 等到 3 个 worker 都结束
    // ... continue ...
    co_return;
}
```

# 典型边界/注意点

1. **大计数**：前面提到的 `uint64_t -> int64_t` 的窄化风险，最好统一类型或限制范围。
2. **过度递减**：若外部逻辑错误多次 `count_down()`，计数会变为负数，但 `event` 已经触发，不会影响正确性（只是暴露出逻辑 bug）。
3. **生命周期**：不要在还有等待者时销毁 `latch`/`event` 对象；一旦触发并确保没有外部保留 awaiter，就安全。
4. **可见性**：如需保障“生产者写入 → 调用 `count_down()` → 等待者醒来后能看到写入”，当前 `acq_rel` + `event` 的 `exchange(acq_rel)`/`compare_exchange(acq_rel/acquire)` 的搭配已经满足。

# 小结

* `latch` 是用 `atomic<int64_t> + event<>` 组合出的**可协程等待的一次性栅栏**。
* 计数到 0 时 `event` 被触发，唤醒所有等待者；`wait()` 在协程里自然 `co_await`。
* 建议的小改动：`latch_guard` 禁止拷贝/移动；构造形参与成员类型统一，避免极端值窄化。
