`io_uring_peek_batch_cqe` 是 `io_uring` 框架中用于批量获取完成队列（CQ）中已完成事件（CQE）的非阻塞函数，允许一次性获取多个完成队列项，适用于高效处理批量异步 I/O 结果。

### 函数作用
该函数从完成队列（CQ）中“偷看”并获取最多 `num` 个已完成的 CQE（完成队列项），但不会阻塞等待新的 CQE 产生。如果 CQ 中存在未处理的 CQE，会将它们批量复制到用户提供的数组中，方便一次性处理多个结果。

### 代码解析
```c
return io_uring_peek_batch_cqe(&m_uring, cqes, num);
```

- **参数**：
  - `&m_uring`：指向已初始化的 `struct io_uring` 实例的指针，即要操作的 io_uring 对象。
  - `cqes`：用户提供的 `struct io_uring_cqe*` 数组，用于存储获取到的 CQE 指针。
  - `num`：最多希望获取的 CQE 数量（数组的长度上限）。

- **返回值**：
  - 成功时，返回实际获取到的 CQE 数量（0 到 `num` 之间）。
  - 失败时，返回负数错误码（如 `-EINVAL` 表示参数无效）。

### 工作机制
- 函数是非阻塞的，仅获取当前 CQ 中已存在的未处理 CQE，不会等待新的事件完成。
- 若 CQ 中没有未处理的 CQE，返回 `0`；若有，则返回实际获取的数量（不超过 `num`）。
- 获取的 CQE 仍属于 CQ 队列，需通过 `io_uring_cq_advance` 批量标记为已处理。

### 使用场景
适用于需要非阻塞批量检查和处理完成事件的场景，例如：
1. 结合事件通知（如 `eventfd`），当收到通知后批量获取所有已完成的 CQE 进行处理。
2. 定期轮询 CQ 时，一次性获取所有积累的 CQE，减少处理次数。

### 使用流程
1. 准备一个足够大的 `struct io_uring_cqe*` 数组（长度至少为 `num`）。
2. 调用 `io_uring_peek_batch_cqe` 获取批量 CQE，得到实际数量 `n`。
3. 循环处理数组中前 `n` 个 CQE，读取 `res`（结果）和 `user_data`（关联信息）。
4. 调用 `io_uring_cq_advance(&m_uring, n)` 批量标记这些 CQE 为已处理。

### 与类似函数的区别
- **`io_uring_peek_cqe`**：一次只能获取 1 个 CQE，适合单个处理。
- **`io_uring_peek_batch_cqe`**：一次可获取多个 CQE（最多 `num` 个），适合批量处理，效率更高。
- **`io_uring_wait_cqe_nr`**：阻塞等待至少 `num` 个 CQE，而本函数是非阻塞的，仅获取现有 CQE。

### 注意事项
- 数组 `cqes` 必须有足够空间存储 `num` 个 CQE 指针，否则可能导致内存越界。
- 即使返回 `0`（没有获取到 CQE），也属于正常情况，不代表错误。
- 处理完毕后必须调用 `io_uring_cq_advance` 释放对应数量的 CQE 位置，否则 CQ 会被耗尽。

`io_uring_peek_batch_cqe` 为批量非阻塞处理完成事件提供了高效接口，能减少高并发场景下的函数调用次数，提升整体处理性能。