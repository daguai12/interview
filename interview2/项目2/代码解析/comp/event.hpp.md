下面把 `event.hpp` 完整拆解说明：它实现了一个**一次性（one-shot）事件**原语，支持协程等待并在事件被触发时**一次性唤醒所有等待者**。另外还提供了携带返回值的版本 `event<T>` 与一个 RAII 工具 `event_guard`。

---

# 整体设计

* `detail::event_base`：无类型事件的核心，包含**原子状态机**与**等待者链表**的无锁注册/唤醒逻辑。
* `event<T>`：在 `event_base` 基础上添加一个结果容器（通过继承 `detail::container<T>`），允许 `set(value)` 时把值分发给所有等待协程。
* `event<void>`：无返回值特化。
* `event_guard`：RAII，作用域结束时自动 `set()` 该事件。

这个事件是**单次触发**的：一旦 `set_state()` 成功，“事件已触发”的状态会保持为**已触发**，后续新的等待者会**立即通过**（不再挂起）。头文件里没有 `reset()`，因此它语义上更像 C++20 的 `std::latch` 或“手动复位事件的**单次**版本”。

---

# 关键数据结构与状态机

```cpp
std::atomic<awaiter_ptr> m_state{nullptr};
```

这里把 `m_state` 设计为**三态**：

1. `nullptr`：尚未触发，当前没有等待者。
2. 指向 `awaiter_base` 的指针：尚未触发，但有等待者，指针是**等待者单链表的表头**（侵入式：每个 awaiter 自带 `m_next`）。
3. `this`（event 对象自身指针）：**已触发**。通过把 `m_state` 置为 `this` 来表示“事件处于 set 状态”。

> 这也是为什么 `is_set()` 写成：
>
> ```cpp
> m_state.load(memory_order_acquire) == this
> ```
>
> 返回 true 即表示事件已触发。

---

# `event_base::awaiter_base` 等待者

```cpp
struct awaiter_base
{
    awaiter_base(context& ctx, event_base& e) noexcept
      : m_ctx(ctx), m_ev(e) {}

    awaiter_base*           m_next{nullptr};
    std::coroutine_handle<> m_await_coro{nullptr};
    context&  m_ctx;   // 捕获创建 awaiter 时的上下文
    event_base& m_ev;   // 关联事件
};
```

* **为什么要捕获 `context&`？**
  事件触发时需要恢复（`resume`）协程。该实现选择“把被唤醒的协程回投到**它原来所属的 context**”，以保持线程亲和性/调度策略的一致；因此 awaiter 在创建时就保存了 `local_context()`。

* `m_next`：用于把多个等待者串成**单向链表**；注册时采用**CAS push**（LIFO），触发时会把整条链表取出并逐个提交回 context 以恢复。

---

# 协程挂起/恢复流程（`await_ready/await_suspend/await_resume`）

> 具体实现写在 `.cpp`，但从接口可推断典型语义如下：

1. `await_ready()`

   * 通常实现为 `return m_ev.is_set();`
   * 若事件已经 set，则**不挂起**，`co_await` 立即就绪并直接进入 `await_resume()`。

2. `await_suspend(std::coroutine_handle<> h) -> bool`

   * 保存 `m_await_coro = h`。
   * 调用 `m_ev.register_awaiter(this)` 尝试把自己入队（原子地把自己 push 到 `m_state` 链表头）。
   * 如果注册**成功**（事件尚未触发），返回 `true`，协程**挂起**。
   * 如果注册**失败**（多半是事件刚好被 set，`m_state == this`），返回 `false`，表示**不要挂起**，随后直接进入 `await_resume()`。

3. `await_resume()`

   * 基类版本是空实现；
   * 在 `event<T>::awaiter` 中重载为：先调用基类 `await_resume()`，再 `return static_cast<event&>(m_ev).result();`，也就是把 `T` 返回出去。

---

# 设置事件：`set_state()` & `resume_all_awaiter(...)`

`set_state()` 负责**原子地把状态切到“已触发”**并把**当时所有等待者链表一次性取出**，然后调用 `resume_all_awaiter(head)` 把它们逐个恢复：

* **典型流程（推断）**：

  1. `old = m_state.exchange(this, memory_order_acq_rel);`
  2. 如果 `old == this`，说明已经触发过，直接返回（幂等）。
  3. 如果 `old == nullptr`，说明没有等待者，也直接返回。
  4. 否则 `old` 指向等待者链表头：遍历链表，依次把保存的 `m_await_coro` 提交回对应的 `m_ctx`（通常是 `submit_to_context(...)`）以恢复协程。

> 由于注册是 LIFO push，遍历通常会以**近后先出**的顺序恢复（除非实现里反转）。这会影响公平性（不是严格 FIFO），但实现简单且内存局部性好。

---

# 将返回值与事件结合：`event<T>`

```cpp
template<typename return_type = void>
class event : public detail::event_base, public detail::container<return_type>
{
public:
    struct awaiter : public detail::event_base::awaiter_base {
        auto await_resume() noexcept -> decltype(auto) {
            detail::event_base::awaiter_base::await_resume();
            return static_cast<event&>(m_ev).result();
        }
    };

    awaiter wait() noexcept { return awaiter(local_context(), *this); }

    template<typename value_type>
    void set(value_type&& value) noexcept {
        this->return_value(std::forward<value_type>(value));
        set_state();
    }
};
```

* `event<T>::set(value)` 做两件事：

  1. 把值存入 `container<T>`（即 `this->return_value(...)`）；
  2. 调用 `set_state()` 触发事件并唤醒所有等待者；
* 等待者在 `await_resume()` 里通过 `result()` 取出这个值（按值/按引用取决于 `container<T>` 的实现）。

### `event<void>` 特化

* 没有值容器，`set()` 直接 `set_state()`。

---

# RAII 工具：`event_guard`

```cpp
class event_guard
{
    using guard_type = event<>;
public:
    event_guard(guard_type& ev) noexcept : m_ev(ev) {}
    ~event_guard() noexcept { m_ev.set(); } // 析构即触发
private:
    guard_type& m_ev;
};
```

* `guard_type` 是 `event<>`，即 `event<void>`。
* 作用域结束（无论正常路径还是异常/早退）都会 `set()` 事件，常用于“**当这段代码块结束时通知外界**”。

---

# 并发与内存序

* 典型做法是：

  * **注册等待者**：CAS 把 `m_state` 从 `old` 改为 `this_waiter`，使用 `memory_order_acq_rel`；在成功路径上把 `m_next = old`（把自己接到表头）；
  * **触发事件**：`exchange(this, acq_rel)`，取到旧值作为链表头后恢复等待者；
  * `is_set()` 用 `acquire` 保证观察到“已 set”时后续读取可见；
* 这样可以保证：

  * 不会漏掉任何一个在 set 前成功注册的等待者；
  * set 之后再来的等待者会看到 `m_state == this`，`await_ready()` 返回 true，立即通过。

---

# 典型用法

## 1) 单次通知 + 返回值

```cpp
coro::event<int> ev;

task<void> producer() {
    // ... 计算 result
    ev.set(42);        // 唤醒所有等待者，传值 42
    co_return;
}

task<void> consumer() {
    int v = co_await ev.wait();  // 等待直到 set，拿到 42
    // ...
    co_return;
}
```

## 2) 等待某个异步回调

```cpp
coro::event<void> done;

task<void> job() {
    start_async_call([&]{
        // 回调里：
        done.set();   // 通知协程
    });
    co_await done.wait(); // 在此暂停
    // 继续执行
}
```

## 3) 用 `event_guard` 做“作用域完成”通知

```cpp
coro::event<void> scoped_done;

task<void> worker() {
    coro::event_guard g{scoped_done}; // 作用域结束自动 set
    // 做一些事（可能早退/异常）
    co_return;
}

task<void> waiter() {
    co_await scoped_done.wait();  // 等待作用域结束
    // ...
}
```

---

# 语义与注意事项

1. **一次性事件**：没有 `reset()`；一旦 `set_state()` 成功，`is_set()` 永远为真，后续 `wait()` 都会**立即就绪**。要可重复使用，需重新构造一个新 `event`。
2. **公平性**：注册是 LIFO，唤醒顺序也大概率是后注册先唤醒（除非实现里反转）。如果你有严格 FIFO 需求，需要改 `resume_all_awaiter` 做反转或改数据结构。
3. **上下文亲和**：等待者捕获 `context`，唤醒时投递回原 context，有利于保持线程局部性和避免数据竞争（比如不跨线程恢复一个只在本线程有效的对象）。
4. **返回值生存期**：`event<T>` 的值由 `detail::container<T>` 管理，通常在 `event` 对象生命周期内有效。等待者在 `await_resume()` 取值后即可使用。
5. **无锁但需小心**：多线程并发 `wait()` 与 `set()` 依赖正确的原子序；当前接口暗示 `.cpp` 实现已经用 acq\_rel/ acquire 做好了发布与可见性。

---

# 小结

* `event_base` 用一个 `std::atomic<void*>` 同时承担**状态标志**与**等待者栈**的角色，达成**无锁、一致、一次性**的事件语义；
* `event<T>` 把“通知”和“传值”合并，适合把外部回调式 API 整洁地封装为 `co_await`；
* `event_guard` 让“作用域结束时通知”变得自然。

如果你愿意，我可以补上 `.cpp` 的一个参考实现（`await_ready/await_suspend/register_awaiter/set_state/resume_all_awaiter` 的原子细节），或给出一个带 FIFO 唤醒的改造版本。
