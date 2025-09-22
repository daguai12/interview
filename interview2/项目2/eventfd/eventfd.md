`eventfd` 是 Linux 内核提供的一个非常轻量级的事件通知机制。你可以把它想象成一个由内核维护的、非常高效的“计数器”。一个进程或线程向这个“计数器”写入一个值（“发信号”），另一个进程或线程读取这个值（“收信号”），从而实现同步或通信。

它的核心优势在于：

1.  **轻量级**：相比于管道（pipe）或套接字（socketpair），它的开销非常小，只有一个64位的无符号整数（`uint64_t`）大小的内核空间。
2.  **高效**：读写操作非常快，是简单的整数加法和读取。
3.  **与 `epoll/select/poll` 完美集成**：`eventfd` 创建的是一个文件描述符（file descriptor, fd），因此可以非常方便地被 `epoll`、`select`、`poll` 等I/O多路复用机制监控，这使得它在事件驱动的异步编程中非常有用。

-----

### `eventfd` 的核心 API

使用 `eventfd` 主要涉及三个系统调用：`eventfd()`, `write()`, 和 `read()`。

#### 1\. 创建 `eventfd` 对象：`eventfd()`

首先，你需要创建一个 `eventfd` 对象，这会返回一个与该对象关联的文件描述符。

**函数原型 (C/C++)**

```c
#include <sys/eventfd.h>

int eventfd(unsigned int initval, int flags);
```

  * **`initval`**：一个无符号整数，用于初始化 `eventfd` 内核计数器的初始值。如果你只是用它来通知事件发生，通常设置为 `0`。
  * **`flags`**：一个标志位，用于配置 `eventfd` 的行为。常用的标志有：
      * **`0`**：默认行为，`eventfd` 是阻塞的。
      * **`EFD_NONBLOCK`**：将 `eventfd` 的文件描述符设置为非阻塞模式。在读取计数值时，如果值为0，`read` 会立即返回 `EAGAIN` 而不是阻塞等待。
      * **`EFD_CLOEXEC`**：当程序执行 `exec` 系列函数（例如 `execl`, `execv`）加载新程序时，自动关闭这个文件描述符。这是一个推荐的安全实践，可以防止文件描述符泄露给新程序。
      * **`EFD_SEMAPHORE`**： (从 Linux 2.6.30 开始) 启用“信号量”模式。在此模式下，`read` 操作每次读取都会使计数器减 `1`。如果计数器为0，则 `read` 阻塞。后面会有详细例子。

**返回值**：

  * 成功：返回一个新的文件描述符。
  * 失败：返回 `-1`，并设置 `errno`。

#### 2\. 发送信号/增加计数器：`write()`

要通知一个事件或增加计数器的值，你只需要向 `eventfd` 的文件描述符写入一个 `uint64_t` 类型的值。

**操作**：

  * 内核会将你写入的 `uint64_t` 值 **加到** 内部的计数器上。
  * 例如，如果当前计数器是 3，你写入一个 5，那么计数器会变成 8。
  * **注意**：写入的值必须是 **大于等于1** 的 `uint64_t` 整数。你不能写入0。写入 `UINT64_MAX` (最大的64位无符号整数) 是一个错误。

**示例代码**：

```c
#include <sys/eventfd.h>
#include <unistd.h>
#include <stdint.h> // for uint64_t

// ... efd 是 eventfd() 返回的文件描述符 ...
uint64_t u = 1;
ssize_t s = write(efd, &u, sizeof(uint64_t));
if (s != sizeof(uint64_t)) {
    // 处理错误
}
```

通常，我们每次只通知一个事件，所以习惯性地写入 `1`。

#### 3\. 接收信号/读取计数器：`read()`

等待事件的线程或进程通过读取 `eventfd` 的文件描述符来获取通知。

**`read()` 的行为取决于 `eventfd` 的配置**：

  * **默认模式 (非 `EFD_SEMAPHORE`)**：

      * 如果内核计数器 **大于0**：`read` 会立即返回，并将计数器的 **当前值** 拷贝到你的缓冲区，然后 **将内核计数器清零**。
      * 如果内核计数器 **等于0**：
          * **阻塞模式 (默认)**：`read` 会一直阻塞，直到其他线程/进程向 `eventfd` 写入一个非零值。
          * **非阻塞模式 (`EFD_NONBLOCK`)**：`read` 会立即失败，返回 `-1`，并设置 `errno` 为 `EAGAIN`。

  * **信号量模式 (`EFD_SEMAPHORE`)**：

      * 如果内核计数器 **大于0**：`read` 会立即返回，**值总是 `1`** 会被写入你的缓冲区，然后 **内核计数器减 `1`**。
      * 如果内核计数器 **等于0**：`read` 的行为与默认模式下计数器为0时相同（阻塞或返回 `EAGAIN`）。

**示例代码**：

```c
#include <sys/eventfd.h>
#include <unistd.h>
#include <stdint.h>

// ... efd 是 eventfd() 返回的文件描述符 ...
uint64_t u;
ssize_t s = read(efd, &u, sizeof(uint64_t));
if (s != sizeof(uint64_t)) {
    // 处理错误，比如在非阻塞模式下的 EAGAIN
} else {
    // 在默认模式下，u 是被清零前的计数值
    // 在信号量模式下，u 总是 1
    printf("Read from eventfd: %llu\n", (unsigned long long)u);
}
```

-----

### 典型使用场景及示例

#### 场景一：线程间同步（生产者-消费者模型）

一个线程（生产者）产生数据后，需要通知另一个线程（消费者）来处理。

**代码示例 (C语言)**：

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/eventfd.h>
#include <pthread.h>
#include <stdint.h>

int efd; // eventfd 文件描述符

void *producer(void *arg) {
    printf("Producer: I will start producing in 3 seconds...\n");
    sleep(3);

    uint64_t counter_val = 1; // 每次通知一个事件
    printf("Producer: Notifying consumer...\n");

    // 向 eventfd 写入，增加计数器，这会唤醒正在 read() 的消费者
    if (write(efd, &counter_val, sizeof(uint64_t)) != sizeof(uint64_t)) {
        perror("write");
        exit(EXIT_FAILURE);
    }
    return NULL;
}

void *consumer(void *arg) {
    uint64_t counter_val;
    printf("Consumer: Waiting for a notification...\n");

    // 读取 eventfd，如果计数器为0，这里会阻塞
    if (read(efd, &counter_val, sizeof(uint64_t)) != sizeof(uint64_t)) {
        perror("read");
        exit(EXIT_FAILURE);
    }

    printf("Consumer: Received notification! Counter value was: %llu\n", (unsigned long long)counter_val);
    return NULL;
}

int main() {
    pthread_t producer_tid, consumer_tid;

    // 创建一个 eventfd 对象，初始值为0，默认阻塞模式
    efd = eventfd(0, 0);
    if (efd == -1) {
        perror("eventfd");
        return 1;
    }

    // 创建线程
    pthread_create(&consumer_tid, NULL, consumer, NULL);
    pthread_create(&producer_tid, NULL, producer, NULL);

    // 等待线程结束
    pthread_join(producer_tid, NULL);
    pthread_join(consumer_tid, NULL);

    close(efd);
    return 0;
}
```

**编译和运行**：

```bash
gcc -o eventfd_example eventfd_example.c -lpthread
./eventfd_example
```

**输出**：

```
Consumer: Waiting for a notification...
Producer: I will start producing in 3 seconds...
Producer: Notifying consumer...
Consumer: Received notification! Counter value was: 1
```

#### 场景二：与 `epoll` 结合，实现异步事件处理

这是 `eventfd` 最强大的用途之一。你可以将一个 `eventfd` 的文件描述符添加到 `epoll` 的监听集合中。当其他线程或进程需要唤醒 `epoll_wait` 时（例如，主线程需要通知I/O线程有新的任务），只需向这个 `eventfd` 写入一个值即可。`epoll_wait` 会立即返回，并报告该 `eventfd` 是可读的。

**伪代码逻辑**：

```c
// 主线程或信号处理函数
void notify_worker_thread() {
    uint64_t u = 1;
    write(eventfd_to_wakeup_epoll, &u, sizeof(u));
}

// I/O 工作线程
void worker_thread() {
    int epoll_fd = epoll_create1(0);
    int event_fd = eventfd(0, EFD_NONBLOCK);

    // 添加 eventfd 到 epoll 监听
    struct epoll_event ev;
    ev.events = EPOLLIN; // 监听可读事件
    ev.data.fd = event_fd;
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, event_fd, &ev);

    // ... 添加其他需要监听的 socket fd 等 ...

    while (1) {
        struct epoll_event events[MAX_EVENTS];
        int nfds = epoll_wait(epoll_fd, events, MAX_EVENTS, -1);

        for (int i = 0; i < nfds; ++i) {
            if (events[i].data.fd == event_fd) {
                // 是 eventfd 触发的！说明有通知到来
                uint64_t u;
                read(event_fd, &u, sizeof(u)); // 必须读取，否则会一直触发
                printf("Woken up by main thread! Processing new task...\n");
                // ... 处理新任务 ...
            } else {
                // 处理其他 socket 的 I/O 事件
            }
        }
    }
}
```

这种模式在高性能网络服务器（如 Nginx、Redis）和各种异步框架（如 `muduo`）中非常常见，用于解决“跨线程唤醒 `epoll`” 的问题。

-----

### 总结

| 特性 | 描述 |
| :--- | :--- |
| **创建** | `int efd = eventfd(initial_value, flags);` |
| **通知 (写)** | `write(efd, &val, sizeof(val));` 内核计数器 += `val`。 |
| **等待 (读)** | `read(efd, &buf, sizeof(buf));` |
| **默认模式** | `read` 成功后，内核计数器 **清零**。 |
| **信号量模式** | `read` 成功后，内核计数器 **减1**。 |
| **阻塞/非阻塞** | 通过 `EFD_NONBLOCK` 标志控制，影响计数器为0时的 `read` 行为。 |
| **核心用途** | 1. 线程/进程间轻量级同步和通信。 \<br\> 2. 与 `epoll` 等I/O多路复用机制结合，实现高效的事件通知和异步唤醒。 |

希望这个详细的讲解能帮助你理解和使用 `eventfd`。如果你有更具体的问题或场景，随时可以提出来！