在 Linux 下，`errno` 是一个全局变量（线程局部存储），用于表示最近一次系统调用失败的错误码。

---

## **1. `EINTR` (Interrupted system call, 错误码 4)**

**触发条件：**

- **当系统调用被信号中断**（如 `read()`、`write()`、`accept()`、`sleep()`）。
    
- 常见于 **同步阻塞调用**，如果进程在执行 **阻塞系统调用**（如 `read()`、`select()`、`epoll_wait()`）时收到 **信号（如 `SIGINT`）**，则系统调用会被打断，返回 `-1` 并设置 `errno = EINTR`。
    

**示例代码：**

```c
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>

void handler(int signo) {
    printf("Received signal %d\n", signo);
}

int main() {
    signal(SIGINT, handler);  // 设置信号处理函数

    printf("Reading...\n");
    char buf[10];
    int ret = read(STDIN_FILENO, buf, sizeof(buf));  // 这里如果收到 SIGINT 可能会中断
    if (ret == -1 && errno == EINTR) {
        perror("read interrupted");
    }

    return 0;
}
```

**📌 记忆技巧：**

- `EINTR` 代表 **E**xternal **INT**erruption（外部中断）。
    
- **记住它发生在** **阻塞调用** 被 **信号打断** 的情况。
    

---

## **2. `EAGAIN` (Resource temporarily unavailable, 错误码 11)**

**触发条件：**

- 当资源 **暂时不可用**，但 **稍后可能变得可用** 时发生，通常在 **非阻塞模式** (`O_NONBLOCK`) 下：
    
    - **`read()` 读取无数据**（如管道、socket 或文件描述符没有可读数据）。
        
    - **`write()` 写入缓冲区已满**（如管道满了）。
        
    - **`accept()` 没有新连接**。
        
    - **`connect()` 连接未完成**（用于非阻塞 TCP 连接）。
        
    - **`send()` / `recv()`** 发送或接收数据时，资源未准备好。
        

**示例代码：**

```c
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int main() {
    int fd[2];
    pipe(fd);

    // 设置写端为非阻塞模式
    fcntl(fd[1], F_SETFL, O_NONBLOCK);

    char buf[1024];
    while (write(fd[1], buf, sizeof(buf)) > 0);  // 写满管道

    if (write(fd[1], buf, sizeof(buf)) == -1 && errno == EAGAIN) {
        perror("write nonblocking pipe full");  // 这里会触发 EAGAIN
    }

    return 0;
}
```

**📌 记忆技巧：**

- `EAGAIN` 代表 **E**xpect **AGAIN**（稍后重试）。
    
- 发生在 **非阻塞模式下**，系统资源（缓冲区、连接等）**暂时不可用**，但稍后可能可用。
    

---

## **📌 `EINTR` vs `EAGAIN` 速记对比**

| **错误码**         | **触发原因**          | **常见系统调用**                                                      | **解决方案**                                               |
| --------------- | ----------------- | --------------------------------------------------------------- | ------------------------------------------------------ |
| **EINTR** (4)   | **信号中断系统调用**      | `read()` / `write()` / `accept()` / `select()` / `epoll_wait()` | 重新调用系统调用 (`while (read(...) == -1 && errno == EINTR)`) |
| **EAGAIN** (11) | **非阻塞模式下资源暂时不可用** | `read()` / `write()` / `accept()` / `connect()` / `recv()`      | 稍后重试，或者使用 `select()` / `poll()` 等                      |

---

## **📌 处理方式**

### **1. 处理 `EINTR`**

如果 `read()` / `write()` 被信号打断，我们可以让它 **自动重试**：

```c
ssize_t safe_read(int fd, void *buf, size_t count) {
    ssize_t ret;
    do {
        ret = read(fd, buf, count);
    } while (ret == -1 && errno == EINTR);  // 重新调用 read()
    return ret;
}
```

---

### **2. 处理 `EAGAIN`**

对于 **非阻塞 I/O**，我们可以使用 `select()` / `poll()` / `epoll_wait()` 等 **等待资源可用**：

```c
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/select.h>

int main() {
    int fd[2];
    pipe(fd);
    fcntl(fd[0], F_SETFL, O_NONBLOCK);  // 设为非阻塞

    char buf[10];
    fd_set rfds;
    FD_ZERO(&rfds);
    FD_SET(fd[0], &rfds);

    struct timeval tv = {5, 0};  // 5秒超时
    int retval = select(fd[0] + 1, &rfds, NULL, NULL, &tv);

    if (retval > 0) {
        read(fd[0], buf, sizeof(buf));
        printf("Read success: %s\n", buf);
    } else if (retval == 0) {
        printf("Timeout, no data available.\n");
    } else {
        perror("select()");
    }

    return 0;
}
```

---

## **📌 重点总结**

| 错误码      | 含义      | 触发条件                                                                    | 解决方案                             |
| -------- | ------- | ----------------------------------------------------------------------- | -------------------------------- |
| `EINTR`  | 被信号中断   | 阻塞调用 (`read()`, `write()`, `accept()`, `select()`, `epoll_wait()`) 收到信号 | 重新调用系统调用                         |
| `EAGAIN` | 资源暂时不可用 | **非阻塞模式** 下的 `read()` / `write()` / `accept()` 等                        | 稍后重试，或者用 `select()` / `poll()` 等 |

### **🚀 记忆口诀**

- **`EINTR`** 👉 "外部信号打断，需要重试"
    
- **`EAGAIN`** 👉 "资源暂时不可用，再等一等"
    

这样在遇到 `EINTR` 和 `EAGAIN` 时，你就能快速判断如何处理了！