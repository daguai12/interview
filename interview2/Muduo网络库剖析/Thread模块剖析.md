## Thread模块作用
Thread类是对 `pthread` 的封装。

## Thread成员变量剖析

```c++
public:

    using ThreadFunc = std::function<void()>;

private:

	bool started_;
	bool joined_;
	std::shared_ptr<std::thread> thread_;
	ThreadFunc func_;
	pid_t tid_;
	std::string name_;
	static std::atomic_int32_t numCreated_;
```

- `started` 标记线程是否启动。
- `joined`  标记线程是否调用`join()`函数，可以再线程结束时自动释放所持有的资源。
- `thread_` 使用智能指针托管创建的线程对象
- `func_` 要在线程中所执行的回调函数
- `tid_` 保存线程再 Linux 系统中真实的 id
- `name_` 设置线程的姓名
- `numCreated_` 保存创建线程的个数（static变量，所有Thread类都共享同一个static变量）。

## Thread核心成员函数
```c++
public:

	explicit Thread(ThreadFunc,const std::string& name = std::string());
	~Thread();
	void start();
	void join();
	bool started() const { return started_; }
	pid_t tid() const { return tid_; }
	const std::string& name() const { return name_; }
	static int numCreated() { return numCreated_; }

private:

    void setDefaultName();
	
```

### started()

```c++
void Thread::start()
{
    started_ = true;
    sem_t sem;
    sem_init(&sem,false,0);

    //开启线程
    thread_ = std::shared_ptr<std::thread>(new std::thread([&](){
        //获取线程的tid值
        tid_ = CurrentThread::tid();
        sem_post(&sem);
        //开启一个新线程，专门执行该线程函数
        func_();
    }));

    // 这里必须等待获取上面新创建的线程的tid值
    sem_wait(&sem);
}
```

`started()`用于创建一个新的线程，在函数中使用信号量，防止主线程先于子线程获取 `tid_` 的值(0)。

**为什么会出现这种状况？**

>由于 `std::thread` 一旦启动，主线程和子线程时**异步并发执行的**。如果 `start()` 不阻塞，直接返回，主线程可能早于子线程获取到 `tid_`。此时，如果**Thread类**外部调用 `tid()`获取线程ID，值还没初始化，导致数据不一致。

**举个例子**

```cpp
Thread t(func);
t.start();
pid_t id = t.tid(); // ⚠️ 如果不等子线程，id 可能还是 0

```

如果 t.start() 立即返回，子线程可能还没执行到 tid_ = CurrentThread::tid() 这行，
这时候 t.tid() 拿到的就是未初始化的 tid_，数据是错的。

