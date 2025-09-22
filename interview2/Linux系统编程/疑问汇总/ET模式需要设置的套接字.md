在使在使用 **Edge Triggered（ET）模式** 时，**所有参与 I/O 的套接字都必须设置为非阻塞（non-blocking）模式**，否则会导致**事件无法再次触发、死循环或阻塞**。

---

### ✅ 必须设置为非阻塞的套接字包括：

| 套接字类型                 | 是否必须非阻塞 | 原因                                                |
| --------------------- | ------- | ------------------------------------------------- |
| `listenfd`（监听套接字）     | ✅ 必须    | 避免多个连接建立后只触发一次 `EPOLLIN`，未完全 `accept()` 的连接无法再次触发 |
| `connfd`（连接套接字）       | ✅ 必须    | 避免 `recv()`、`send()` 时阻塞，ET 模式下不会再次通知             |
| 管道 socket / eventfd 等 | ✅ 推荐    | 如果你用 socketpair 管道与子进程通信，也应非阻塞，防止写满后阻塞或读不全        |

---

### ⚠️ 为什么需要非阻塞？

ET 模式下，**内核只在状态从“无数据”到“有数据”发生变化时通知你一次**，如果你没有一次性读完数据，就不会再收到通知了。

例如：

```cpp
// 错误用法：阻塞式 read（仅适用于 LT 模式）
int n = read(fd, buf, 1024);
```

```cpp
// 正确用法：ET 模式 + 非阻塞 fd + 循环读
while (true) {
    ssize_t n = read(fd, buf, 1024);
    if (n == -1) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            break; // 读完了，退出循环
        else
            perror("read");
    } else if (n == 0) {
        // 对方关闭连接
        break;
    } else {
        // 正常读取数据
    }
}
```

---

### ✅ 如何设置非阻塞？

```cpp
void setNonBlocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}
```

在 `accept` 后对 `connfd` 调用它，对 `listenfd` 也必须调用一次。

---

### 🧠 总结

| 套接字类型                   | 设置非阻塞的必要性 |
| ----------------------- | --------- |
| `listenfd`              | ✅ 必须      |
| `connfd`（客户端连接）         | ✅ 必须      |
| 与子进程通信的 socketpair/pipe | ✅ 推荐      |

**ET 模式 + 非阻塞 + 循环读写** 是固定组合，否则你会发现程序只读一次、连接丢失、卡住不动、CPU 占用飙高等各种诡异问题。

需要我帮你写一个“ET 模式 + 非阻塞 + 正确处理”的模板也可以告诉我。
用 **Edge Triggered（ET）模式** 时，**所有参与 I/O 的套接字都必须设置为非阻塞（non-blocking）模式**，否则会导致**事件无法再次触发、死循环或阻塞**。

---

### ✅ 必须设置为非阻塞的套接字包括：

| 套接字类型                 | 是否必须非阻塞 | 原因                                                |
| --------------------- | ------- | ------------------------------------------------- |
| `listenfd`（监听套接字）     | ✅ 必须    | 避免多个连接建立后只触发一次 `EPOLLIN`，未完全 `accept()` 的连接无法再次触发 |
| `connfd`（连接套接字）       | ✅ 必须    | 避免 `recv()`、`send()` 时阻塞，ET 模式下不会再次通知             |
| 管道 socket / eventfd 等 | ✅ 推荐    | 如果你用 socketpair 管道与子进程通信，也应非阻塞，防止写满后阻塞或读不全        |

---

### ⚠️ 为什么需要非阻塞？

ET 模式下，**内核只在状态从“无数据”到“有数据”发生变化时通知你一次**，如果你没有一次性读完数据，就不会再收到通知了。

例如：

```cpp
// 错误用法：阻塞式 read（仅适用于 LT 模式）
int n = read(fd, buf, 1024);
```

```cpp
// 正确用法：ET 模式 + 非阻塞 fd + 循环读
while (true) {
    ssize_t n = read(fd, buf, 1024);
    if (n == -1) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            break; // 读完了，退出循环
        else
            perror("read");
    } else if (n == 0) {
        // 对方关闭连接
        break;
    } else {
        // 正常读取数据
    }
}
```

---

### ✅ 如何设置非阻塞？

```cpp
void setNonBlocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}
```

在 `accept` 后对 `connfd` 调用它，对 `listenfd` 也必须调用一次。

---

### 🧠 总结

| 套接字类型                   | 设置非阻塞的必要性 |
| ----------------------- | --------- |
| `listenfd`              | ✅ 必须      |
| `connfd`（客户端连接）         | ✅ 必须      |
| 与子进程通信的 socketpair/pipe | ✅ 推荐      |

**ET 模式 + 非阻塞 + 循环读写** 是固定组合，否则你会发现程序只读一次、连接丢失、卡住不动、CPU 占用飙高等各种诡异问题。

需要我帮你写一个“ET 模式 + 非阻塞 + 正确处理”的模板也可以告诉我。


# 为什么监听socket也要设置为非阻塞

当然可以，我来给你举一个非常具体的例子，来说明为什么在 **ET（Edge Triggered）模式** 下，`listenfd`（监听套接字）**必须设置为非阻塞模式**，否则可能会**漏掉连接请求**，导致 **accept() 之后新连接没人处理**。

---

### 🌐 场景模拟：

假设你是服务器（`listenfd`），有人排队找你办事（客户端连接）。

你用了 ET 模式，但 **没有设置 listenfd 为非阻塞**，代码大概是这样：

```cpp
if (events[i].data.fd == listenfd) {
    // 只处理一次 accept
    int connfd = accept(listenfd, ...);
    // 没有用循环 accept，也没设置非阻塞
}
```

---

### 🧨 问题出现：

1. 有 **5 个客户端几乎同时连接**服务器，全部连接已到达 `listenfd` 的连接队列（backlog）中。
2. 内核通知你：`listenfd` 可读（即 EPOLLIN 事件发生）。
3. 你的程序收到事件后调用 `accept()` —— 只 accept 第一个客户端。
4. 因为你 **没有设置 listenfd 为非阻塞模式**，accept 之后，如果连接队列里还有连接，**内核不会再触发 EPOLLIN** 事件了！
5. 剩下的 **4 个连接再也得不到处理**，直到程序重新调用 `epoll_wait()` 并有人再次连接时才可能触发。
6. 客户端连上服务器后被“冷落”，长时间没有响应。

---

### ✅ 正确做法

你要：

1. 把 `listenfd` 设置为非阻塞：

   ```cpp
   fcntl(listenfd, F_SETFL, O_NONBLOCK);
   ```

2. 在 ET 模式下，**使用 while 循环不停 accept**，直到队列空、返回 `EAGAIN` 为止：

   ```cpp
   while (true) {
       int connfd = accept(listenfd, ...);
       if (connfd == -1) {
           if (errno == EAGAIN || errno == EWOULDBLOCK)
               break; // 没有更多连接了，退出
           else {
               perror("accept error");
               break;
           }
       }
       // 处理 connfd...
   }
   ```

---

### 🧠 总结一句话：

> 在 **ET 模式下，内核不会重复提醒你“还有连接没 accept”**，所以必须你自己写 `while` 把连接接完，而且还要 **设置 listenfd 为非阻塞**，否则 `accept()` 会卡住你，后面的逻辑完全跑不了。

---

需要我给你写一份最小的 demo 程序模拟这个现象也可以。你会更直观地看到“为什么只 accept 一次不够”。
