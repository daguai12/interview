# Scheduler（`scheduler.hpp`）详解

下面我把这个头文件按职责、数据结构、接口与生命周期、并发细节、以及风险/改进建议分块讲清楚——既解释“它做什么”，也指出实现时要注意的坑。尽量贴近源码语义并给出可操作的建议。

---

## 概览 — Scheduler 的角色

`coro::scheduler` 是整个运行时的**全局调度器单例**，职责大致是：

* 管理若干 `context`（每个 `context` 含有一个 `engine` 和一个工作线程）。
* 用 `dispatcher` 按策略把提交的任务分配到某个 `context`。
* 跟踪每个 `context` 是否“有活”，通过一组原子 stop-flag（`m_ctx_stop_flag`）与整体 stop token（`m_stop_token`）实现“是否可以停止整个系统”的判定。
* 提供静态便捷接口（`init/loop/submit`）给上层调用，隐藏单例实现细节。
* （可选）包含内存分配器（`ENABLE_MEMORY_ALLOC` 时）。

它本身是一个单例：`get_instance()` 返回静态的 `scheduler sc;`。

---

## 关键类型与成员解释

### 静态/公共接口

* `init(size_t ctx_cnt = std::thread::hardware_concurrency())`
  根据 `ctx_cnt` 数量初始化 scheduler（默认用硬件并发数）。内部调用 `get_instance()->init_impl(ctx_cnt)`。

* `loop()`
  启动或运行调度器主循环（实现里通常会阻塞直到系统终止或回收所有 contexts）。

* `submit(...)`（有三种重载）
  提交 `task<void>`（rvalue / lvalue）或直接 `std::coroutine_handle<>`。最终调用 `get_instance()->submit_task_impl(handle)`。

这些都是静态方法，方便全局调用：`scheduler::submit(...)`。

---

### 私有成员（状态）

* `size_t m_ctx_cnt{0};`
  上下文（context）数量。

* `detail::ctx_container m_ctxs;`
  存放 `context` 的容器（类型由 `detail` 定义，可能是 `std::vector<std::unique_ptr<context>>` 或类似）。

* `detail::dispatcher<coro::config::kDispatchStrategy> m_dispatcher;`
  负责**选择目标 context** 的策略（例如 round-robin、least-loaded、hash-based、本地优先等）。它把调度策略从 scheduler 解耦。

* `stop_flag_type m_ctx_stop_flag;`
  `using stop_flag_type = std::vector<detail::atomic_ref_wrapper<int>>;`
  这是一个每个 context 对应一个整型“状态槽”（封装在 `atomic_ref_wrapper<int>` 里以便能放进 `std::vector` 同时避免伪共享）。含义：值为 0 表示该 context 当前“空闲且无挂账”；非 0 表示该 context“有工作/有挂账”。
  注意：要通过 `std::atomic_ref<int>` 操作这些槽（不能直接普通写）。

* `stop_token_type m_stop_token;`
  `using stop_token_type = std::atomic<int>;`
  全局计数器（或标志集合），头文件注释写：“当 stop\_token 等于 0 时，所有 context 完成工作，scheduler 可以停止”。由上下文的状态变化来增加/减少该计数，或者由 scheduler 在停止过程设置。

* `m_mem_alloc`（在 `ENABLE_MEMORY_ALLOC` 时）
  可选的内存分配器实例，用作运行时的自定义/高性能分配。

---

## 典型生命周期（从 `init` 到 `loop` 到 `stop`）

虽然实现细节在 `.cpp`，但可以合理推断 `init_impl/ start_impl/ loop_impl/ stop_impl/ submit_task_impl` 的职责：

1. **init\_impl(ctx\_cnt)**

   * 分配 `m_ctxs`、为每个 context 初始化 `m_ctx_stop_flag`（长度 = ctx\_cnt），初始化 dispatcher（告知 context 数量），初始化 `m_stop_token`（可能设为 ctx\_cnt 的总和或 0 视策略）。
   * 可能会调用 `context::start()`（创建工作线程并进入 run）。

2. **start\_impl()**

   * 把所有 `context` 的线程启动（若 `init_impl` 没做）。也可能把 scheduler 注册到 `dispatcher`。

3. **submit\_task\_impl(handle)**

   * 使用 `m_dispatcher` 选择一个目标 context index。
   * 将任务提交到该 context（调用 `ctx.submit_task(handle)`）。
   * 在提交时需要更新 `m_ctx_stop_flag[index]`（例如 `fetch_add(1)`），并相应地调整 `m_stop_token`（如果 `stop_token` 表示活跃 context 数或活跃任务数的话）。
   * 可能会在提交后 `wake_up` 对应 context（如果需要）。

4. **loop\_impl()**

   * 可能做为 main thread 的“阻塞等待直至所有 context 完成”的接口。例如它可能 `start_impl()` 后轮询 `m_stop_token` 或使用某种同步（条件变量/atomic polling）等待 `m_stop_token == 0`，然后调 `stop_impl()`。
   * 也可能仅仅是“阻塞直到 scheduler 被显式停止”。

5. **stop\_impl()**

   * 请求所有 `context` 停止（调用 `context::notify_stop()`），等待 `join()`，清理资源，deinit allocator。

---

## `m_ctx_stop_flag` 与 `m_stop_token` 的设计意图（并发语义）

* 单个 `m_ctx_stop_flag[i]` 是一个 `int`，以**原子方式**表示某个 context 的“活跃计数”或“是否空闲”。举例语义：

  * 在 context 接受到任务或某个 IO 产生待处理项时，可能 `fetch_add(1)`；当对应任务/操作完成时 `fetch_sub(1)`。当该槽从非 0 变为 0，说明该 context 已无挂账。
* `m_stop_token` 则是 scheduler 级别的聚合量：可能等于所有 `m_ctx_stop_flag` 的“非零计数”之和、或直接是所有 context 活跃任务计数之和。头文件注释写法是：“当 stop\_token 等于 0，所有 context 完成所有工作，scheduler 可以 stop 所有 context”。
* **实现要点**：

  * 操作这些原子时务必使用合适的内存序（至少 `acq_rel` on update，`acquire` on read），以保证上下游对任务生命周期的可见性（见 `context::register_wait`/`unregister_wait` 的做法）。
  * `atomic_ref_wrapper<int>` 需要通过 `std::atomic_ref<int>` 来做原子加减（因为 wrapper 只是存放 `int`，而不是 `std::atomic<int>`）。

---

## dispatcher 的作用

`m_dispatcher`（模板参数使用 `coro::config::kDispatchStrategy`）决定**任务去哪个 context**。常见策略举例（dispatchers 通常实现）：

* round-robin（轮询）
* hash-based（基于协程/任务 id 的固定映射）
* least-loaded（选择 `m_ctx_stop_flag` 最小的 context）
* affinity/locality（优先选择提交线程本地或数据局部的 context）

**要点**：`dispatcher` 需要尽可能读取 `m_ctx_stop_flag` 的原子快照来做负载判断；若策略为 least-loaded，需要以合适的内存序读出每个 context 的计数并选择最小值。

---

## 并发/正确性注意事项（风险与建议）

1. **`std::vector<atomic_ref_wrapper<int>>` 的使用**

   * 因为 `atomic_ref_wrapper<int>::val` 只是普通 `int` 字段，**必须**使用 `std::atomic_ref<int> aref(m_ctx_stop_flag[i].val)` 来做原子操作（`fetch_add`/`fetch_sub`）。直接对 `.val` 普通写会造成数据竞争。
   * 记得为这些原子操作选择合适的 memory order（`acq_rel` 更新，`acquire` 读取）。

2. **聚合 `m_stop_token` 的语义**

   * 明确 `m_stop_token` 的含义（是“活跃 context 数”还是“活跃待办任务总数”）。不同语义会影响何时把它减为 0。
   * 推荐：把 `m_stop_token` 表示“活跃任务总数的原子计数”，每次 submit 增 1，每次任务最终完成时减 1。scheduler 的 `loop_impl()` 等待 `m_stop_token == 0`。这样逻辑简单且健壮。

3. **竞态：context 变为 idle 与 新任务同时到达**

   * 场景：某上下文刚把其 `m_ctx_stop_flag[i]` 减为 0（显得空闲），scheduler 看到整体变为可停并准备关停，但与此同时又有新的任务被提交到该 context。要避免 race 导致“错停/漏停”。
   * 解决办法：在决定“完全停掉”前先把一个“停止许可/状态”标记（atomic bool）加上，或者使用 compare-and-swap 把 `m_stop_token` 状态从 0 切换到 STOPPING，然后拒绝后续提交或转发到其它 context。简洁做法是：在正式停止之前把 scheduler 置为 “not accepting new tasks”，再等待 `m_stop_token` 归零。

4. **submit 在停止过程中的行为**

   * `submit_task_impl` 在 scheduler 进入停止阶段时应有清晰策略：要么拒绝新的 submit（返回/丢弃/报错），要么仍然接受并延迟停止。否则会出现不可预测行为。

5. **缓存行对齐与伪共享**

   * `atomic_ref_wrapper` 外层 `alignas(config::kCacheLineSize)` 用来避免不同 context 的 stop flags 互相伪共享。确保 `config::kCacheLineSize` 在目标平台上设置正确（通常 64）。否则伪共享会影响性能。

6. **内存/异常安全**

   * `init_impl` 分配 `m_ctxs` 和其它资源时如果抛异常（比如内存不足），要保持单例处于合理状态或回滚（虽然在嵌入式/服务代码里常规做法是进程终止）。

7. **阻塞策略**

   * `loop_impl()` 如果使用 busy-wait polling `m_stop_token`，会浪费 CPU。建议使用条件变量或 `std::stop_source`/`stop_token` 与 `wait` 配合，或者每次循环做短睡眠/自适应退避。

---

## 小建议与改进点（实践可采纳）

* **明确 `m_stop_token` 语义**：建议用它作为“活跃待处理任务总数”的计数器。所有 submit 增 1，任务最终 `clean()` 时减 1。这样 `loop_impl()` 只要等待 `m_stop_token == 0` 即可安全停机。
* **拒绝提交标志**：在准备停机时设置 `accepting_tasks = false`（atomic bool），`submit` 会检查并拒绝新任务，避免 race。
* **使用 `std::atomic<int>` 而不是 `atomic_ref_wrapper<int>`？**

  * `vector<std::atomic<int>>` 因不可复制/移动而麻烦；但你可以 `reserve()` 容量然后**在 place-new** 或 `emplace_back` 单独构造 `std::atomic<int>`；这会更直接且语义清晰。若为性能考虑且希望 cache-line 对齐，保留当前 `atomic_ref_wrapper` 方案并确保通过 `std::atomic_ref` 操作。
* **dispatch 时读负载用 `memory_order_relaxed` 也合法**（如果只是做近似选择），但若需要严格可见性（比如马上根据读到的零判断停机），使用 `acquire`/`acq_rel`。
* **日志与度量**：在 submit/stop/loop 路径记录关键事件（启动/停止/拒绝提交）便于排查 race 和性能问题。

---

## 一个简单的提交/停止交互示意（伪流程）

1. `scheduler::init(n)` 创建 `n` 个 context，`m_ctx_stop_flag` 初始化为 0，`m_stop_token` = 0。
2. 用户调用 `scheduler::submit(handle)`：

   * `dispatch` 选 ctx i；
   * 在提交前 `std::atomic_ref<int> ref(m_ctx_stop_flag[i].val); int old = ref.fetch_add(1, acq_rel);`
   * `m_stop_token.fetch_add(1, acq_rel);`
   * `ctx.submit_task(handle)`；（context 运行后，任务最终完成时）
   * 在任务完成的 cleanup 流程处做 `ref.fetch_sub(1, acq_rel); m_stop_token.fetch_sub(1, acq_rel);`
3. `scheduler::loop_impl()` 等待 `m_stop_token.load(acquire) == 0`（或使用条件变量唤醒），当为 0 且 scheduler 不再接受新任务时，执行 `stop_impl()` 来优雅结束所有 context。

---

## 总结（一句话）

`scheduler` 是一个单例式的全局调度控制器：负责创建/管理 `context`，通过 `dispatcher` 将任务分发到具体 context，并用 `m_ctx_stop_flag` 与 `m_stop_token` 的原子计数来判断“何时系统空闲可以停机”。实现要点是**正确使用 `atomic_ref_wrapper`（通过 `std::atomic_ref`）做原子更新**、明确 `m_stop_token` 的语义、防止提交与停机之间的竞态，并在 dispatch/stop 的边界上做明确策略（接受/拒绝/延迟）。

如果你想，我可以：

* 根据上面建议写出 `submit_task_impl` / `loop_impl` 的一个 **参考实现**（带内存序、条件变量及停止策略），或者
* 帮你把 `m_ctx_stop_flag` 的操作改写为 `std::atomic<int>` + place-new 版本，或给出一个更健壮的“停止前切换到拒绝提交”的流程代码样例。你想先看哪一种？
