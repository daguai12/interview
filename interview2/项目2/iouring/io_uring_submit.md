`io_uring_submit` 是 `io_uring` 框架中用于将提交队列（Submission Queue, SQ）中的任务提交到内核执行的核心函数。

### 函数作用
当你通过 `io_uring_get_sqe` 获取空闲的 SQE（提交队列项）并填充好 I/O 操作参数后，需要调用 `io_uring_submit` 通知内核处理这些任务。该函数会将 SQ 中所有已准备好的任务提交给内核，由内核异步执行对应的 I/O 操作。

### 代码解析
```c
return io_uring_submit(&m_uring);
```

- **参数**：`&m_uring` 是指向已初始化的 `struct io_uring` 实例的指针，即要提交任务的 io_uring 对象。
- **返回值**：
  - 成功时，返回实际提交的任务数量（大于 0）。
  - 失败时，返回负数错误码（如 `-EBUSY` 表示队列正被使用，`-EINVAL` 表示参数无效）。

### 工作流程
1. 应用程序通过 `io_uring_get_sqe` 获取 SQE 并填充 I/O 操作信息（如读/写、文件描述符、缓冲区等）。
2. 调用 `io_uring_submit` 将 SQ 中所有已准备好的 SQE 提交给内核。
3. 内核接收任务后，异步执行对应的 I/O 操作，完成后将结果放入完成队列（CQ）。

### 注意事项
- 提交的任务会异步执行，函数返回不代表 I/O 操作完成，需通过 `io_uring_wait_cqe` 等函数获取完成事件。
- 若返回值为 0，通常表示没有可提交的任务（SQ 为空）。
- 高并发场景下，可结合 `io_uring_submit_and_wait` 等函数，提交后阻塞等待部分任务完成，减少系统调用次数。

`io_uring_submit` 是连接应用程序与内核异步 I/O 处理的关键接口，决定了任务何时进入内核执行流程。