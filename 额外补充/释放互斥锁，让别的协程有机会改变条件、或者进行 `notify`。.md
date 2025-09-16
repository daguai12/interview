好问题 👍，你问得非常关键：

在 `condition_variable.cpp` 里确实有多次 `m_mtx.unlock()`，比如 `cv_awaiter::register_lock()` 和 `cv_awaiter::resume()`。你疑惑的是：
既然这里解锁了 `mutex`，那在哪里有“加锁”的地方？

---

### 1. 背景：这个 `mutex` 不是普通互斥锁，而是 **协程感知的异步 mutex**

* `cv_awaiter` 继承自 `mutex::mutex_awaiter`
* 也就是说，这个 `condition_variable` 的等待者，本质上是拿着一把 `mutex` 的协程锁。
* **加锁过程**不是在 `condition_variable` 内部完成的，而是在调用 `co_await mtx.lock()` 或 `co_await cv.wait(mtx)` 之前完成的。

换句话说：

```cpp
co_await mtx.lock();          // 加锁（这里会挂起直到获取锁）
co_await cv.wait(mtx, cond);  // 等待条件，并在 wait 内部释放锁
// 协程恢复时：wait 内部帮你自动重新加锁成功，resume 时才继续执行
```

---

### 2. 为什么 `wait()` 内要 `unlock`？

因为 **条件变量的经典用法** 就是：

1. 你先持有锁进入 `wait()`。
2. `wait()` 里面检查条件，如果条件不满足，就把自己挂到条件变量队列上，然后 **释放锁**。

   * 这样其他线程/协程可以修改共享数据，并调用 `notify` 唤醒等待者。
3. 唤醒后，`wait()` 会帮你 **重新获得锁**，保证恢复执行时仍然是“持锁状态”。

   * 这样就可以安全地检查条件、继续访问共享数据。

所以：

* 加锁操作是在调用 `cv.wait(mtx)` 之前由调用者完成的。
* `cv.wait(mtx)` 内部调用 `m_mtx.unlock()`，是把锁还给别人用。
* 等待被唤醒时，会重新去尝试 `lock()`（在 `resume()` / `wake_up()` 里）。

---

### 3. 对应代码路径举例

```cpp
// 1. 用户先上锁
co_await mtx.lock();

// 2. 进入 condition_variable::wait
co_await cv.wait(mtx, cond);

// ↓ 内部逻辑展开 ↓

// cv_awaiter::register_lock()
if (cond 不满足) {
    m_ctx.register_wait();
    m_suspend_state = true;

    register_cv();    // 把自己放进等待队列
    m_mtx.unlock();   // 🔑释放锁，让别人能修改条件
    return true;      // 这里挂起
}

// 3. 当 notify_one/all 被调用时
cur->wake_up();  // 唤醒等待者

// wake_up -> resume()
if (条件依然不满足) {
    register_cv();
    m_mtx.unlock();   // 再次释放锁，继续等待
    return;
}

// 如果条件满足 -> mutex_awaiter::resume()
// resume 内部会重新上锁，然后协程继续运行
```

---

✅ 总结：

* **加锁** 在进入 `cv.wait()` 之前，用户通过 `co_await mtx.lock()` 完成。
* **解锁** 在 `cv.wait()` 内部发生，让其他协程可以修改条件、发通知。
* **重新加锁** 在被唤醒的 `resume()` 里，由 `mutex_awaiter::resume()` 负责。

所以 `condition_variable` 的核心就是：**wait 时释放锁，notify 时唤醒并重新获得锁**。

---

要不要我帮你画一张 **协程版 condition\_variable 的时序图**（包括加锁、解锁、挂起、唤醒的完整路径），这样你就能直观地看到为什么必须在 `wait()` 内调用 `m_mtx.unlock()`？
