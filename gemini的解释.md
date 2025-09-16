这段代码在循环次数巨大时导致栈溢出，其根本原因在于 `task` 类型的 `co_await` 实现了一种\*\*“非对称转换”（Asymmetric Transfer）\*\*，它通过直接的函数调用链（`resume()` 调用）来传递控制权，而不是将控制权返回给顶层的事件循环。

这导致每一次 `for` 循环都会增加调用栈的深度，最终形成无界递归。

-----

### \#\# 详细执行流程分析

让我们追踪一次循环中到底发生了什么，来理解调用栈是如何增长的。

**初始状态**：`main` 函数调用 `ex.sync_wait`，后者在 `while` 循环中。

1.  **`loop_synchronously` 执行 `co_await`**

      * `loop_synchronously` 协程开始第一次循环，遇到 `co_await completes_synchronously();`。
      * 这会调用 `completes_synchronously` 返回的 `task` 对象的 `operator co_await()`，创建一个 `task::awaiter`。

2.  **`task::awaiter::await_suspend` 被调用**

      * `await_ready` 返回 `false`，因此 `await_suspend` 被执行。
      * 此时，`await_suspend` 函数的栈帧被压入调用栈。
      * 在 `await_suspend` 内部，它做了两件事：
        1.  保存 `loop_synchronously` 的句柄作为“延续点”（continuation）。
        2.  **立即调用 `coro_.resume()`**，这里的 `coro_` 指的是 `completes_synchronously` 协程。

    **关键点**：这里的 `resume()` 是一个直接的函数调用。`await_suspend` 函数**还没有返回**，它的栈帧还在栈上。

3.  **`completes_synchronously` 执行并返回**

      * `completes_synchronously` 被恢复后，立即执行 `co_return;`。
      * 这会触发其 `promise` 的 `final_suspend()`。

4.  **`final_awaiter::await_suspend` 被调用**

      * `final_awaiter` 的 `await_ready` 返回 `false`，因此它的 `await_suspend` 被执行。
      * 此时，`final_awaiter::await_suspend` 的栈帧被压入调用栈，位于上一个 `task::awaiter::await_suspend` 的栈帧之上。
      * 在这个函数内部，它 **立即调用 `h.promise().continuation.resume()`**，这个 `continuation` 正是我们在第 2 步保存的 `loop_synchronously` 的句柄。

    **关键点**：这又是一个直接的函数调用。现在我们有两个 `await_suspend` 的栈帧都还存活在调用栈上。

5.  **控制权回到 `loop_synchronously`**

      * `loop_synchronously` 被恢复，`co_await` 表达式执行完毕。
      * 它继续执行 `for` 循环的下一次迭代。

-----

### \#\# 调用栈的增长模式

这个过程形成了一个递归调用链。让我们看一下调用栈的样子：

**第一次循环后，在 `loop_synchronously` 内部：**

```
[ ... main ... ]
[ ... sync_wait ... ]
[ loop_synchronously's code ]
  [ task::awaiter::await_suspend (for completes_synchronously) ]
    [ completes_synchronously's code ]
      [ final_awaiter::await_suspend (for completes_synchronously) ]
        [ -> control is inside loop_synchronously again ]
```

当 `loop_synchronously` 开始第二次循环时，它会再次 `co_await` 一个新的 `completes_synchronously` 实例，整个过程会重复一遍，在现有调用栈的**顶端**再次添加 `task::awaiter::await_suspend` 和 `final_awaiter::await_suspend` 的栈帧。

**第二次循环后，调用栈会变成：**

```
[ ... main ... ]
[ ... sync_wait ... ]
[ loop_synchronously's code ]
  [ task::awaiter::await_suspend_1 ]
    [ completes_synchronously_1's code ]
      [ final_awaiter::await_suspend_1 ]
        [ loop_synchronously's code ]
          [ task::awaiter::await_suspend_2 ]
            [ completes_synchronously_2's code ]
              [ final_awaiter::await_suspend_2 ]
                [ -> control is inside loop_synchronously again ]
```

每进行一次循环，调用栈就会增加几个栈帧的深度。当循环次数达到 `1,000,000` 次时，这个调用栈会变得非常深，最终耗尽所有栈空间，导致栈溢出（Stack Overflow）崩溃。

-----

### \#\# 为什么会这样设计？（以及如何修复）

这种立即恢复的“非对称转换”模型适用于那些**真正**需要挂起并等待异步操作完成的场景。在这种情况下，`await_suspend` 会启动一个 I/O 操作然后**立即返回**，将控制权交还给事件循环（`manual_executor::drain`），从而解开调用栈。

但在这个例子中，`completes_synchronously` 是一个同步完成的协程，它并不需要挂起等待。控制权的转移是通过函数调用递归地进行的，而不是通过返回到 `sync_wait` 的主循环。

**如何修复（对称转换）**

正确的、可扩展的协程模型应该使用\*\*“对称转换”（Symmetric Transfer）**。这意味着 `await_suspend` 不会直接调用 `resume()`，而是将要恢复的协程句柄**调度\*\*到执行器（executor）上，然后立即返回，让调用栈得以解开。

修复后的 `await_suspend` 逻辑看起来会是这样（概念性代码）：

```cpp
// 在 final_awaiter::await_suspend 中
void await_suspend(coroutine_handle<promise_type> h) noexcept {
    // 不要直接 resume！
    // h.promise().continuation.resume();
    
    // 而是把要执行的任务交给 executor
    executor.schedule(h.promise().continuation);
}
```

通过将任务调度给执行器，控制权会返回到 `sync_wait` 的 `while` 循环中，调用栈被清空。然后 `drain()` 方法会从任务队列中取出下一个任务并执行它。这样，无论循环多少次，调用栈的深度都保持在一个很小的常数水平，从而避免了栈溢出。