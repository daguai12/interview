`SIGUSR1` 和 `SIGUSR2` 是标准信号中专门留给用户自定义使用的两个信号，常用于进程间通信或触发特定逻辑（如日志切换、状态查询等）。以下是使用这两个信号的完整示例，包括信号注册、发送和处理的全过程：


### 1. 基础使用示例：注册信号处理器并发送信号
```c
#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

// SIGUSR1 处理器：打印提示信息
void handle_sigusr1(int sig) {
    printf("收到 SIGUSR1 信号（自定义逻辑：例如切换日志文件）\n");
}

// SIGUSR2 处理器：打印提示信息并退出
void handle_sigusr2(int sig) {
    printf("收到 SIGUSR2 信号（自定义逻辑：例如安全退出）\n");
    exit(EXIT_SUCCESS);
}

int main() {
    // 注册 SIGUSR1 处理器
    if (signal(SIGUSR1, handle_sigusr1) == SIG_ERR) {
        perror("signal(SIGUSR1) 失败");
        exit(EXIT_FAILURE);
    }

    // 注册 SIGUSR2 处理器
    if (signal(SIGUSR2, handle_sigusr2) == SIG_ERR) {
        perror("signal(SIGUSR2) 失败");
        exit(EXIT_FAILURE);
    }

    printf("进程 PID: %d\n", getpid());
    printf("发送 SIGUSR1: kill -USR1 %d\n", getpid());
    printf("发送 SIGUSR2: kill -USR2 %d\n", getpid());
    printf("等待信号...\n");

    // 无限循环等待信号
    while (1) {
        pause();  // 阻塞等待任何信号
    }

    return 0;
}
```

#### 编译与测试：
1. 编译代码：`gcc sigusr_demo.c -o sigusr_demo`  
2. 运行程序：`./sigusr_demo`，记录输出的 PID（例如 `12345`）  
3. 另开终端发送信号：  
   - 发送 `SIGUSR1`：`kill -USR1 12345`，程序会打印切换日志的提示  
   - 发送 `SIGUSR2`：`kill -USR2 12345`，程序会打印退出提示并终止  


### 2. 进阶使用：结合 `sigaction()` 实现可靠处理
`signal()` 存在历史语义差异，推荐使用 `sigaction()` 注册处理器，确保行为一致：

```cpp
#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

// 全局变量：记录SIGUSR1的接收次数
static volatile sig_atomic_t sigusr1_count = 0;

// SIGUSR1 处理器：使用sigaction，支持更多控制
void handle_sigusr1(int sig, siginfo_t *info, void *ucontext) {
    sigusr1_count++;
    printf("收到 SIGUSR1（第 %d 次），发送方 PID: %d\n", 
           sigusr1_count, info->si_pid);  // 获取发送方PID
}

// SIGUSR2 处理器：安全退出
void handle_sigusr2(int sig) {
    printf("收到 SIGUSR2，退出程序。SIGUSR1 共收到 %d 次\n", sigusr1_count);
    exit(EXIT_SUCCESS);
}

int main() {
    struct sigaction sa_usr1, sa_usr2;

    // 配置 SIGUSR1 处理器（使用SA_SIGINFO获取额外信息）
    sa_usr1.sa_sigaction = handle_sigusr1;  // 带额外参数的处理器
    sigemptyset(&sa_usr1.sa_mask);          // 处理器执行时不阻塞其他信号
    sa_usr1.sa_flags = SA_SIGINFO;          // 启用额外信息传递
    if (sigaction(SIGUSR1, &sa_usr1, NULL) == -1) {
        perror("sigaction(SIGUSR1) 失败");
        exit(EXIT_FAILURE);
    }

    // 配置 SIGUSR2 处理器
    sa_usr2.sa_handler = handle_sigusr2;    // 简单处理器
    sigemptyset(&sa_usr2.sa_mask);
    sa_usr2.sa_flags = 0;                   // 默认行为
    if (sigaction(SIGUSR2, &sa_usr2, NULL) == -1) {
        perror("sigaction(SIGUSR2) 失败");
        exit(EXIT_FAILURE);
    }

    printf("进程 PID: %d\n", getpid());
    printf("发送 SIGUSR1: kill -USR1 %d\n", getpid());
    printf("发送 SIGUSR2: kill -USR2 %d\n", getpid());
    printf("等待信号...\n");

    // 循环等待，避免使用pause()（可被其他信号打断）
    while (1) {
        sleep(1);  // 定期唤醒，降低阻塞时间
    }

    return 0;
}

```



#### 进阶特性说明：
- **获取发送方信息**：通过 `sigaction()` 的 `SA_SIGINFO` 标志，处理器可获取 `siginfo_t` 结构体，其中 `si_pid` 包含发送信号的进程 PID。  
- **计数功能**：用 `volatile sig_atomic_t` 类型的全局变量记录 `SIGUSR1` 接收次数（确保多线程/信号安全）。  
- **可靠语义**：`sigaction()` 避免了 `signal()` 的历史兼容性问题，确保处理器不会被自动重置，且可控制信号掩码。  


### 3. 进程间通信示例：父子进程通过 SIGUSR 信号交互
```c
#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>

// 父进程处理器：收到SIGUSR1后发送SIGUSR2给子进程
void parent_handler(int sig) {
    printf("父进程：收到子进程的 SIGUSR1，回复 SIGUSR2\n");
}

// 子进程处理器：收到SIGUSR2后退出
void child_handler(int sig) {
    printf("子进程：收到父进程的 SIGUSR2，退出\n");
    exit(EXIT_SUCCESS);
}

int main() {
    pid_t pid = fork();
    if (pid == -1) {
        perror("fork 失败");
        exit(EXIT_FAILURE);
    }

    if (pid == 0) {  // 子进程
        // 注册 SIGUSR2 处理器
        signal(SIGUSR2, child_handler);
        printf("子进程 PID: %d，向父进程（PID: %d）发送 SIGUSR1\n", getpid(), getppid());
        kill(getppid(), SIGUSR1);  // 向父进程发送SIGUSR1
        pause();  // 等待父进程的SIGUSR2
    } else {  // 父进程
        // 注册 SIGUSR1 处理器
        signal(SIGUSR1, parent_handler);
        pause();  // 等待子进程的SIGUSR1
        kill(pid, SIGUSR2);  // 向子进程发送SIGUSR2
        wait(NULL);  // 等待子进程退出
        printf("父进程：子进程已退出\n");
    }

    return 0;
}
```

#### 功能说明：
- 子进程启动后向父进程发送 `SIGUSR1`，父进程收到后回复 `SIGUSR2`，子进程收到后退出，实现简单的进程间同步。  


### 关键注意事项
1. **信号安全**：信号处理器中应只调用**异步信号安全函数**（如 `write()`、`_exit()`），避免使用 `printf()`（非线程安全，仅示例用）。  
2. **全局变量**：若在处理器中修改全局变量，需声明为 `volatile sig_atomic_t`，确保编译器不会优化该变量，且操作是原子的。  
3. **可移植性**：优先使用 `sigaction()` 而非 `signal()`，避免不同系统的语义差异。  

`SIGUSR1` 和 `SIGUSR2` 是实现自定义事件通知的轻量机制，适用于简单的进程间交互场景。