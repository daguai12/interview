`clock_gettime` 是 Linux 系统中用于获取高精度时间的函数，配合 `timespec` 结构体使用，支持纳秒级时间精度，广泛用于性能测试、计时等场景。以下是详细介绍：


### 1. `timespec` 结构体
`timespec` 结构体用于存储时间，定义在 `<time.h>` 中，包含秒和纳秒两个成员：
```c
struct timespec {
    time_t tv_sec;   // 秒数（整数部分）
    long   tv_nsec;  // 纳秒数（小数部分，范围 0-999,999,999）
};
```
- **`tv_sec`**：时间的秒部分，类型为 `time_t`（通常是 64 位整数）。
- **`tv_nsec`**：时间的纳秒部分（1 纳秒 = 10^-9 秒），范围是 0 到 999,999,999，超过则需要进位到 `tv_sec`。

例如，`tv_sec=2`、`tv_nsec=500,000,000` 表示 2.5 秒。


### 2. `clock_gettime` 函数
#### 函数原型
```c
#include <time.h>
int clock_gettime(clockid_t clockid, struct timespec *tp);
```
- **功能**：获取指定时钟（`clockid`）的当前时间，存储到 `tp` 指向的 `timespec` 结构体中。
- **返回值**：成功返回 0，失败返回 -1 并设置 `errno`。


#### 时钟类型（`clockid_t`）
`clock_gettime` 支持多种时钟类型，常用的有：

| 时钟类型                       | 含义               | 特点                                  |
| -------------------------- | ---------------- | ----------------------------------- |
| `CLOCK_REALTIME`           | 系统实时时间（墙上时间）     | 受系统时间调整影响（如手动修改时间、NTP 同步），可能向前或向后跳变 |
| `CLOCK_MONOTONIC`          | 从系统启动开始的单调时间     | 不受系统时间调整影响，只能递增，适合测量时间间隔            |
| `CLOCK_PROCESS_CPUTIME_ID` | 当前进程消耗的 CPU 时间总和 | 仅统计进程实际使用的 CPU 时间（用户态 + 内核态），睡眠时不增加 |
| `CLOCK_THREAD_CPUTIME_ID`  | 当前线程消耗的 CPU 时间总和 | 仅统计当前线程的 CPU 时间，多线程程序中用于单独测量线程耗时    |


#### 使用示例
```c
#include <stdio.h>
#include <time.h>

int main() {
    struct timespec ts;
    
    // 获取实时时间（墙上时间）
    clock_gettime(CLOCK_REALTIME, &ts);
    printf("实时时间：%lld秒 %ld纳秒\n", 
           (long long)ts.tv_sec, ts.tv_nsec);
    
    // 获取单调时间（系统启动后流逝的时间）
    clock_gettime(CLOCK_MONOTONIC, &ts);
    printf("单调时间：%lld秒 %ld纳秒\n", 
           (long long)ts.tv_sec, ts.tv_nsec);
    
    return 0;
}
```


### 3. 典型应用场景
#### （1）测量程序执行时间
```c
struct timespec start, end;
clock_gettime(CLOCK_MONOTONIC, &start);  // 记录开始时间

// 待测量的代码段
for (int i = 0; i < 1000000; i++) {
    // ...
}

clock_gettime(CLOCK_MONOTONIC, &end);    // 记录结束时间

// 计算耗时（单位：秒）
double duration = (end.tv_sec - start.tv_sec) + 
                 (end.tv_nsec - start.tv_nsec) / 1e9;
printf("耗时：%.6f秒\n", duration);
```
- 推荐使用 `CLOCK_MONOTONIC` 测量时间间隔，避免系统时间调整的干扰。


#### （2）高精度定时
结合 `nanosleep` 函数实现纳秒级延迟：
```c
struct timespec delay = {.tv_sec = 0, .tv_nsec = 500000};  // 500微秒
nanosleep(&delay, NULL);  // 暂停500微秒
```


### 4. 注意事项
- **平台支持**：`clock_gettime` 是 POSIX 标准函数，在 Linux、macOS 等类 Unix 系统中可用，但 Windows 系统不直接支持（需通过 WSL 或第三方库模拟）。
- **精度限制**：实际精度受系统硬件和内核配置影响，不一定能达到理论上的纳秒级（通常至少为微秒级）。
- **时间计算**：处理 `tv_nsec` 时需注意溢出（例如，若 `end.tv_nsec < start.tv_nsec`，需从 `tv_sec` 借 1 秒，即 1e9 纳秒）。


### 总结
- `timespec` 结构体通过秒和纳秒存储高精度时间。
- `clock_gettime` 函数可获取多种时钟类型的时间，其中 `CLOCK_MONOTONIC` 适合测量时间间隔，`CLOCK_REALTIME` 适合获取实际日期时间。
- 广泛用于性能测试、定时器、日志时间戳等需要高精度时间的场景。