下面把这个 `condition_variable.hpp` 从**外到内、按职责**讲清楚：它实现了一个“协程友好”的条件变量，配合你自己的 `mutex` 使用；等待协程在 `co_await cv.wait(mtx[, pred])` 时会**释放互斥锁并挂起**，被 `notify_one/all()` 唤醒后，会在**重新获得互斥锁**后才从 `co_await` 返回，行为等价于传统条件变量（含谓词版本）的协程化版本。

---

# 顶层接口与类型

* `using cond_type = std::function<bool()>;`
  谓词（条件）类型。带谓词的 `wait`（类似 `wait(lock, pred)`）用它判断是否需要挂起，或被唤醒后是否满足条件。

* `class condition_variable final`
  协程条件变量。只支持**和你库里的 `mutex`** 搭配（不是 `std::mutex`）。

* `cv_awaiter`
  `co_await cv.wait(mtx[, cond])` 时产生的 awaiter 对象。它 **继承自 `mutex::mutex_awaiter`**，借用后者的“获取互斥锁并在获取后恢复协程”的通用机制，从而保证：

  * 挂起时释放 `mtx`；
  * 被唤醒（notify）后，在**重新拿到 `mtx`** 之前不会返回给用户代码。

---

# condition\_variable 的内部结构

```cpp
detail::spinlock m_lock;
cv_awaiter* m_head{nullptr};
cv_awaiter* m_tail{nullptr};
```

* 用一个**轻量自旋锁** `m_lock` 保护条件变量等待队列；
* `m_head/m_tail` 是单向链（FIFO），存放**等待在条件变量**上的 awaiter（不是等待在 `mutex` 上的）。

> 设计理念：
>
> * **挂起路径**：把等待者登记到 `cv` 的队列里，然后释放 `mutex`，再挂起。
> * **唤醒路径**：`notify` 从 `cv` 队列取出等待者，让它去竞争 `mutex`（拿到后再恢复协程）。
>   这样可以正确地对齐“释放锁 → 挂起”与“通知 → 竞争锁 → 恢复”的时序，避免丢通知。

---

# cv\_awaiter 关键字段与职责

```cpp
struct cv_awaiter : public mutex::mutex_awaiter {
    cond_type m_cond;      // 可选谓词
    cond_var& m_cv;        // 所属的condition_variable
    bool      m_suspend_state; // 记录是否真的挂起过（用于避免重复处理）
};
```

* 继承 `mutex_awaiter`：因此它已经有 `m_ctx / m_mtx / m_next / m_await_coro` 等字段与“恢复机制”，并可调用基类的“注册到互斥锁等待队列/尝试拿锁”的逻辑。
* `m_cond`：如果提供了谓词，**在 await\_suspend 前**会先判断；若已满足则**不挂起**（直接返回 false），跟标准 `cv.wait(lock, pred)` 的语义一致（条件满足则不等待）。
* `m_suspend_state`：标记本次 `co_await` 是否进入“等待状态”（真的排队并释放过锁）。用于确保后续 `notify`/`resume` 的流程只对“真的挂起”的协程生效，避免重复/错误处理。

---

# 关键方法及语义

> 注意：`cv_awaiter` **重写了** `await_suspend()`、`await_resume()`、`register_lock()`、`resume()`，并新增了 `register_cv()` 与 `wake_up()`。

## 1) `await_suspend(std::coroutine_handle<> handle)`

典型流程（符合条件变量语义）：

1. 记录句柄 `m_await_coro = handle`，并 `m_ctx.register_wait()`（上下文内引用计数 +1，表示当前 context 有协程在等待）。
2. 若配置了谓词 `m_cond` 且 **已经为真**：

   * **不挂起**，直接 `return false;`
   * 含义：条件已满足，继续执行协程，且仍**持有**传入的 `mtx`（因为没有释放）。
3. 否则（不带谓词，或谓词为假）：

   * `register_cv()`：把自己**加入到 `cv` 的等待队列**（受 `m_lock` 保护，FIFO）。
   * 释放 `mutex`（这一步通常放在 `register_lock` 的覆盖实现/或在 `await_suspend` 中直接调用 `m_mtx.unlock()`，实现细节在 `.cpp`；头文件留了 `register_lock()` 以便按需插入逻辑）。
   * 标记 `m_suspend_state = true`；
   * 返回 `true` → **挂起协程**。

> 结果：
>
> * 如果立即满足条件，不挂起，协程继续跑。
> * 如果需要等待，协程加入 `cv` 队列并释放锁，让别的协程有机会修改共享状态并 `notify`。

## 2) `notify_one()` / `notify_all()`

* `notify_one()`：

  * 取 `m_lock`，从 `m_head` 弹出**一个**等待者（FIFO）；
  * 对该等待者调用 `wake_up()`。
* `notify_all()`：

  * 取 `m_lock`，取出**整个链表**并清空头尾；
  * 依次对所有等待者调用 `wake_up()`。

## 3) `cv_awaiter::wake_up()`

* 核心：把“等待在 `cv` 队列”的协程转移到**互斥锁的获取阶段**。
* 典型做法：调用（覆盖的）`register_lock()`，尝试**原子注册到 mutex 等待队列**或直接抢到锁：

  * 如果**立即获得了 `mutex`**（`register_lock()` 返回 `false`，语义沿用 `mutex_awaiter`：false=不挂起/已拿到锁）：
    → 直接 `resume()`（见下），让协程继续执行；它会持锁进入 `await_resume()`。
  * 如果**没拿到 `mutex`**（返回 `true`，表示已排进互斥锁的等待队列，等待 `unlock()` 唤醒）：
    → 不立即恢复；等 `mutex::unlock()` 把它从互斥锁等待队列中取出并调用 `resume()`。

> 这一步保证了：**被 notify 的协程在返回用户代码前，必须先重新拿到 `mutex`**。这与标准条件变量的强约束一致。

## 4) `cv_awaiter::resume()`

* 覆盖 `mutex_awaiter::resume()`，通常会在“已经拥有互斥锁”的前提下把协程**投递回 context 执行**（`m_ctx.submit_task(m_await_coro)`）。
* 注意你的 `engine::submit_task` 里有“栈深限制 + 可能直接执行”的 fast-path，因此此处设计时要保证 **awaiter 生命周期**合法（awaiter 存在于协程帧中，`await_suspend` 返回后编译器仍保留，通常是安全的；但跨组件调用顺序要注意不要在 `await_suspend` 尚未返回时就同步 resume 同一个协程，以免出现早前你提到的潜在 UAF 场景）。

## 5) `cv_awaiter::await_resume()`

* 当协程真正被恢复并且**已拿到 `mutex`** 时调用。
* 调用基类 `mutex_awaiter::await_resume()` → `m_ctx.unregister_wait()`，把“等待计数”减回去。
* 返回 `void`：即 `co_await cv.wait(...)` 表达式本身不产生值；若用谓词版本，用户应在 `co_await` 之后假定“锁已持有 + 条件为真”。

---

# `wait(...)` 的三个重载

```cpp
auto wait(mutex& mtx) noexcept -> cv_awaiter;
auto wait(mutex& mtx, cond_type&& cond) noexcept -> cv_awaiter;
auto wait(mutex& mtx, cond_type&  cond) noexcept -> cv_awaiter;
```

* 不带谓词：**总是**进行条件等待（除非在 `await_suspend` 的实现中检测到某些优化条件）。
* 带谓词（左/右值都可）：如果 `cond()` 已经为真，`await_suspend` 直接返回 `false`，协程不会挂起且继续**持锁**往下执行；否则按条件变量语义等待，并在被唤醒后重新持锁返回。

> 典型用法（与标准 CV 一致）：
>
> ```cpp
> auto g = co_await mtx.lock_guard();
> co_await cv.wait(mtx, [&]{ return ready; }); // 这里会在等待前释放锁，被唤醒后再持锁返回
> // 此处：持有 mtx，且 ready == true
> ```

---

# 内存与并发注意点

* `m_lock` 只保护 **条件变量的等待队列**；`mutex` 的等待队列是 `mutex` 自己管理。
  notify 的开销基本只在链表操作和把等待者转交给互斥锁这一步，锁竞争公平性由互斥锁一侧来保证。
* `m_suspend_state` 防止重复唤醒/错误路径（例如尚未真正挂起就被 notify）。
* **避免丢通知**：`await_suspend` 的关键步骤是“**先把自己放进 cv 队列，再释放互斥锁**”，而 `notify` 在同一队列上取出；这保证了要么你还没入队、要么你已在队列里，notify 不会漏掉你（与标准 CV 相同的并发契约）。
* **伪唤醒**（spurious wakeup）：实现层面可能不会“无缘无故”唤醒，但 API 仍提供谓词版本，鼓励使用 `wait(mtx, pred)` 避免写手动循环；如果使用不带谓词版本，依然建议用户**自行检查共享条件**——这与标准 CV 的最佳实践一致。

---

# 析构与禁复制移动

```cpp
~condition_variable() noexcept;
CORO_NO_COPY_MOVE(condition_variable);
```

* 禁止拷贝/移动，防止把内部队列、指针搬来搬去导致悬挂等待者。
* 析构函数在 `.cpp` 中通常会断言队列为空或执行清理（头文件里没展开，但语义应如此）。

---

# 与自定义 `mutex` 的配合关系（关键点）

* `cv_awaiter` 继承 `mutex_awaiter` 是这份实现的**核心技巧**：

  * **等待时**释放 `mutex`，进入 `cv` 队列；
  * **唤醒时**先转移到 `mutex` 的获取阶段（如拿不到则排在 `mutex` 等待队列）；
  * **真正恢复到用户代码时**已经拿到了 `mutex`，与标准条件变量保持一致的强保证。

---

如果你愿意，我可以基于这个头文件，手绘一张“时间线 + 状态机”的小图，清晰标出：

1. `co_await cv.wait(mtx, pred)` 的每一步（入队、释放锁、挂起）
2. `notify_one/all` 如何把等待者转移到 `mutex`
3. `mutex::unlock` 如何最终 `resume` 等待者，从而回到用户代码时已持锁。
