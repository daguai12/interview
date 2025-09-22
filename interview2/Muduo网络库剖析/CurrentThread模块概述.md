## CurrentThread模块的作用

`CurrentThread` 模块是 **当前线程信息的快速访问工具**，可以用于：
- 获取当前线程的 `tid`（线程ID)

## CurrentThread代码解析
### 1. 线程的局部变量(__thread)

```c++
extern __thread int t_cachedTid; 
extern __thread char t_tidString[32];
extern __thread int t_tidStringLength;
extern __thread const char* t_threadName;
```

> `extern` 的作用是**声明**变量，而不是定义变量。
> 它告诉编译器：“这个变量在其他源文件定义，这里只是引用它。"

> `__thread` 关键字：
> 线程的局部存储修饰符，**每个线程都有独立的一个副本，互不不干扰。**

### 2.线程ID缓存机制

```c++
inline int tid()
{
  if (__builtin_expect(t_cachedTid == 0, 0)) //__builtin_expect为优化函数
  {
    cacheTid();
  }
  return t_cachedTid;
}

void cacheTid()
{
	if (t_cachedTid == 0)
	{
		// 通过linux系统调用，获取当前线程的tid值
		t_cachedTid = static_cast<pid_t>(::syscall(SYS_gettid));
	}
}

```

- 如果 `t_cachedTid` 为0表示该线程没有获取过 `tid`。
- 调用 `cacheTid()`，通过 `syscall(SYS_gettid)` 获取线程ID，并缓存到 `t_cachetid`。此后每次调用 `tid()` 都是通过缓存 `t_cachetid` 来获取 `tid` ，而不是调用 `syscall(SYS_gettid)`，减少 `syscall(SYS_gettid)` 的调用，避免系统调用开销影响高性能。


