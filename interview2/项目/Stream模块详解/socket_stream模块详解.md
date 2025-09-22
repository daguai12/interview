#  `read()`


这是 `SocketStream` 类中的成员函数，它是 `Stream` 抽象类中纯虚函数 `read(ByteArray::ptr, size_t)` 的具体实现，用于**将 socket 接收到的数据读入 ByteArray 中**。

### 📌 函数原型

```cpp
int SocketStream::read(ByteArray::ptr ba, size_t length)
```

* **参数说明**：

  * `ByteArray::ptr ba`：表示要写入的目标缓冲区，类型是 `ByteArray` 的智能指针。
  * `size_t length`：表示希望读取的最大数据长度。

* **返回值说明**：

  * `>0`：实际读取的字节数。
  * `=0`：对端关闭了连接（读到 EOF）。
  * `<0`：出错（比如连接断开、底层 socket 错误等）。

---

## ✅ 步骤逐行讲解：

---

### 🔹 第1行：检查连接是否存在

```cpp
if(!isConnected()) {
    return -1;
}
```

#### 含义：

* `isConnected()` 是 `SocketStream` 提供的成员函数（内部应该是检测 `m_socket->isConnected()`）。
* 如果底层 socket 已断开或未连接，则直接返回 -1 表示读取失败。

#### 为什么要加这个判断？

* 防止调用 `recv()` 造成未定义行为或崩溃。
* 优化逻辑：避免不必要的系统调用。

---

### 🔹 第2行：准备 iovec 缓冲区数组

```cpp
std::vector<iovec> iovs;
ba->getWriteBuffers(iovs, length);
```

#### 含义：

* 创建一个空的 `std::vector<iovec>` 用于存放内核分散写的缓冲区结构。
* `ByteArray::getWriteBuffers()` 会根据当前 `ByteArray` 的写指针位置和 `length`，
  填充若干个 `iovec` 结构，用于将数据写入 `ByteArray` 的空闲区域中。

#### 📌 `iovec` 结构简介：

```cpp
struct iovec {
    void*  iov_base; // 起始地址
    size_t iov_len;  // 长度
};
```

* 是 Linux 中 scatter/gather IO 的结构体。
* 用于 `readv()`、`writev()` 等函数的参数。

#### 举例：

如果 ByteArray 的缓冲区是由多个内存块组成（比如链式内存结构），
那么 `getWriteBuffers()` 会将这些分散的空闲区域组成多个 `iovec`，
一次性传入 `recv()`，避免多次拷贝。

---

### 🔹 第3行：执行底层接收

```cpp
int rt = m_socket->recv(&iovs[0], iovs.size());
```

#### 含义：

* 调用 `Socket` 封装的 `recv()` 方法，它支持读取多个 `iovec` 的版本（即多缓冲区接收）。
* `&iovs[0]`：传入 `iovec` 数组首地址。
* `iovs.size()`：缓冲区数量。

#### 说明：

* 本质上这是对系统调用 `readv()` 的封装。
* 如果底层 `recv()` 成功读取了一些数据，会自动写入 `ByteArray` 的空闲空间。

---

### 🔹 第4\~6行：更新 ByteArray 的写位置

```cpp
if(rt > 0) {
    ba->setPosition(ba->getPosition() + rt);
}
```

#### 含义：

* `ByteArray::getPosition()`：获取当前写指针的位置。
* `setPosition(...)`：将写指针向后移动 `rt` 字节。

#### 说明：

* 一旦有数据读入 ByteArray，就必须更新它的写入位置，否则下次再写时会覆盖原有数据。
* `ByteArray` 就像一个可变大小的缓冲流，维护了当前写入/读取的指针位置。

---

### 🔹 第7行：返回接收结果

```cpp
return rt;
```

* `rt` 就是本次读取的数据长度（可能是 0 或负数）：

  * > 0：成功读取的字节数；
  * \=0：远程关闭连接；
  * <0：发生错误（如 errno 设置为 ECONNRESET 等）。

---

## ✅ 总结整个函数逻辑：

| 步骤  | 动作                                           |
| --- | -------------------------------------------- |
| 1️⃣ | 检查 socket 是否已连接                              |
| 2️⃣ | 根据 `length` 获取 ByteArray 空闲内存的多个缓冲段（`iovec`） |
| 3️⃣ | 调用 socket 的 `recv()` 方法读取数据填入这些 `iovec`      |
| 4️⃣ | 若成功，更新 ByteArray 的写入位置                       |
| 5️⃣ | 返回实际接收到的数据字节数                                |

---

### 💡 设计意图亮点：

* 使用 `ByteArray` 管理接收缓冲，可以做到灵活、高效的内存使用；
* 使用 `iovec` 零拷贝方式，减少内存复制，提高性能；
* 设计上清晰地将 socket 与 stream 数据抽象解耦。


# `write()`


### 📌 函数定义

```cpp
int SocketStream::write(ByteArray::ptr ba, size_t length)
```

#### ✅ 参数说明：

* `ba`: `ByteArray::ptr` 类型，表示一个指向 `ByteArray` 对象的智能指针，这个类封装了一块可变大小的二进制数据缓冲区，支持高效的内存管理与读写。
* `length`: 要写入的数据长度（字节数）。

#### ✅ 返回值说明：

* `>0`: 实际写入 socket 的字节数；
* `=0`: 对端关闭了 socket；
* `<0`: 写入失败（如网络错误、连接断开等）。

---

### 🔍 函数实现分析

#### 🔹 第一步：判断是否连接

```cpp
if(!isConnected()) {
    return -1;
}
```

* `isConnected()` 用于判断底层 `m_socket` 是否处于有效连接状态。
* 如果 socket 不可用，直接返回 `-1` 表示写入失败。

---

#### 🔹 第二步：准备写入缓冲区

```cpp
std::vector<iovec> iovs;
ba->getReadBuffers(iovs, length);
```

* 创建一个 `std::vector<iovec>` 类型的变量 `iovs`，用来存放多个缓冲区片段。
* `iovec` 是 Linux 系统中的结构体，用于**分散/聚集 I/O**（scatter/gather I/O）：

  ```cpp
  struct iovec {
      void  *iov_base; // 数据地址
      size_t iov_len;  // 数据长度
  };
  ```
* `ba->getReadBuffers(iovs, length)`：

  * 从 `ByteArray` 中读取**最多 `length` 字节的可读数据片段**，填充到 `iovs` 中。
  * 支持不连续内存，因此可以高效地从多个缓冲区拼接数据。

---

#### 🔹 第三步：调用底层 socket 发送函数

```cpp
int rt = m_socket->send(&iovs[0], iovs.size());
```

* 调用 `m_socket->send()` 方法，把数据通过 socket 发送出去。
* 参数：

  * `&iovs[0]`: `iovec` 数组的起始地址；
  * `iovs.size()`: `iovec` 数组的元素数量；
* `send()` 本质上是基于 Linux 的 `sendmsg()` 或 `writev()` 系统调用实现的，可以一次性发送多个内存片段。

---

#### 🔹 第四步：更新 ByteArray 的读指针

```cpp
if(rt > 0) {
    ba->setPosition(ba->getPosition() + rt);
}
```

* `rt > 0` 说明成功写入了 `rt` 字节。
* 需要同步更新 `ByteArray` 的读取位置指针（position）：

  * `ba->getPosition()` 获取当前读指针；
  * `ba->setPosition(...)` 更新读指针，表示这部分数据已经写出。
* 这样确保下一次发送从上次未发送的数据继续，避免重复。

---

#### 🔹 第五步：返回写入结果

```cpp
return rt;
```

* 返回实际写入的字节数 `rt`（可能小于 `length`，因为系统调用不保证全部写完）。

---

### 🧠 总结这个函数的作用

* `SocketStream::write(ByteArray::ptr ba, size_t length)` 的核心任务是：

  > 将 `ByteArray` 中的**二进制数据**以高效、批量的方式发送到 TCP socket 通信通道中。

* 它利用了：

  * `ByteArray` 的**分片缓冲区管理**；
  * `iovec` 结构 + `writev/sendmsg` 的**聚集写**机制；
  * `m_socket` 的面向对象封装，使得 socket 操作更高层、便于扩展。

---

### ✅ 延伸知识：writev 示例

假如你有两个数据段：

```cpp
char part1[] = "hello ";
char part2[] = "world!";
```

使用传统写法需两次 write：

```cpp
write(fd, part1, 6);
write(fd, part2, 6);
```

使用 `iovec` + `writev`：

```cpp
struct iovec iovs[2];
iovs[0].iov_base = part1;
iovs[0].iov_len  = 6;
iovs[1].iov_base = part2;
iovs[1].iov_len  = 6;

writev(fd, iovs, 2);
```

Sylar 的 `ByteArray` + `Socket::send` 就是在做这种 **高效数据聚合写入**。

