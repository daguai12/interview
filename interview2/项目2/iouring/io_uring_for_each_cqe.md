`io_uring_for_each_cqe` 是 `io_uring` 框架中用于遍历完成队列（CQ）中所有未处理完成项（CQE）的宏，提供了一种简洁的方式来迭代所有待处理的异步 I/O 完成事件。

### 宏的作用
该宏本质上是一个循环结构，用于遍历当前完成队列（CQ）中所有未被标记为“已处理”的 CQE（完成队列项）。它会自动处理队列的循环特性，简化了遍历逻辑，避免手动计算队列边界和索引。

### 代码解析
```c
io_uring_for_each_cqe(&m_uring, head, cqe) {
    // 处理 cqe 指向的完成项
    // 例如：检查 res、获取 user_data 等
}
```

- **参数**：
  - `&m_uring`：指向 `struct io_uring` 实例的指针，即要遍历的 io_uring 对象。
  - `head`：临时变量（通常为 `unsigned` 类型），用于内部记录当前遍历位置（无需手动初始化）。
  - `cqe`：`struct io_uring_cqe*` 类型的变量，在循环中依次指向每个未处理的 CQE。

### 工作机制
- 宏内部通过对比 CQ 的“已生产”指针（`cq->ktail`）和“已消费”指针（`cq->khead`），确定未处理 CQE 的范围。
- 循环过程中，`cqe` 会依次指向每个未处理的 CQE，直到所有未处理项都被遍历。
- 遍历的是**当前时刻**未处理的 CQE，若遍历过程中内核新增了 CQE，本次循环不会包含这些新项（需重新遍历）。

### 使用场景
适用于需要一次性处理所有积累的未完成 CQE 的场景，例如：
1. 收到 `eventfd` 通知后，遍历所有新增的 CQE 并处理。
2. 定期检查 CQ 时，批量处理所有未处理的完成事件。

### 使用流程
1. 使用 `io_uring_for_each_cqe` 循环遍历所有未处理的 CQE。
2. 在循环体内处理每个 `cqe` 的结果（如检查 `res`、通过 `user_data` 关联原始请求）。
3. 遍历结束后，调用 `io_uring_cq_advance` 并传入处理的 CQE 数量（通常是遍历的总数），批量标记为已处理。

### 示例代码
```c
unsigned head;
struct io_uring_cqe *cqe;
int count = 0;

// 遍历所有未处理的 CQE
io_uring_for_each_cqe(&m_uring, head, cqe) {
    // 处理当前 CQE
    printf("操作结果: %d, 用户数据: %llu\n", cqe->res, cqe->user_data);
    count++; // 统计处理数量
}

// 批量标记已处理的 CQE
if (count > 0) {
    io_uring_cq_advance(&m_uring, count);
}
```

### 注意事项
- 遍历过程中，`head` 是内部使用的临时变量，无需手动修改。
- 遍历结束后**必须**调用 `io_uring_cq_advance` 并传入处理的数量（`count`），否则 CQ 状态不会更新，已处理的 CQE 会被重复遍历。
- 该宏是非阻塞的，仅遍历当前已存在的未处理 CQE，不会等待新的事件完成。

`io_uring_for_each_cqe` 简化了批量遍历 CQ 的逻辑，是处理多个异步 I/O 完成事件的高效工具，尤其适合需要集中处理所有完成事件的场景。