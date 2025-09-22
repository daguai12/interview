`io_uring_wait_cqe` 是 `io_uring` 框架中用于阻塞等待完成队列（Completion Queue, CQ）出现新完成项的函数，用于获取异步 I/O 操作的执行结果。

### 函数作用
当应用程序提交异步 I/O 任务后，可通过该函数阻塞等待，直到完成队列（CQ）中有新的完成队列项（CQE）出现（即有 I/O 操作完成）。它是同步等待异步操作结果的核心接口。

### 代码解析
```c
io_uring_wait_cqe(&m_uring, &cqe);
```

- **参数**：
  - `&m_uring`：指向已初始化的 `struct io_uring` 实例的指针，即要等待的 io_uring 对象。
  - `&cqe`：输出参数，用于存储指向 `struct io_uring_cqe` 结构体的指针。当有 I/O 操作完成时，该指针会指向对应的 CQE。

- **返回值**：
  - 成功获取到 CQE 时返回 `0`，此时 `cqe` 指向有效的完成项。
  - 失败时返回负数错误码（如 `-EINTR` 表示被信号中断，`-EINVAL` 表示参数无效）。

### 工作机制
- 函数会阻塞当前线程，直到 CQ 中有至少一个 CQE 可用（即有异步 I/O 操作完成）。
- 若调用时 CQ 中已有未处理的 CQE，则函数会立即返回该 CQE，不会阻塞。

### `struct io_uring_cqe` 关键信息
获取 CQE 后，可通过以下字段获取操作结果：
- `res`：操作结果。`0` 表示成功，负数为错误码（如 `-EIO` 表示 I/O 失败）。
- `user_data`：提交 SQE 时设置的自定义数据，用于将完成事件与原始请求关联（例如区分不同的 I/O 任务）。

### 使用流程
1. 提交异步 I/O 任务（通过 `io_uring_submit`）。
2. 调用 `io_uring_wait_cqe` 阻塞等待任务完成。
3. 处理 `cqe` 中的结果（根据 `res` 判断成功与否，通过 `user_data` 关联原始请求）。
4. 调用 `io_uring_cqe_seen` 标记该 CQE 为已处理，释放 CQ 空间。

### 注意事项
- 若需非阻塞检查 CQ，应使用 `io_uring_peek_cqe`。
- 若需等待多个 CQE 或设置超时，可使用 `io_uring_wait_cqes`（支持等待多个项和超时参数）。
- 函数可能被信号中断（返回 `-EINTR`），实际使用中需处理此类情况。

`io_uring_wait_cqe` 是同步等待异步 I/O 结果的基础接口，适用于需要严格按顺序处理完成事件的场景。