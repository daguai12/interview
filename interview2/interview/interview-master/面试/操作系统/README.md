### [高频选择题](interview/interview-master/面试/操作系统/选择题.md)



## 操作系统理论知识

1.[什么是操作系统？请简要概述一下](interview/interview-master/面试/操作系统/OS/1.md)

1-1.[介绍一下中断](interview/interview-master/面试/操作系统/OS/1-1.md)

1-2.[结构体对齐和字节对齐](interview/interview-master/面试/操作系统/OS/1-2.md)

1-3[系统调用](interview/interview-master/面试/操作系统/OS/1-3.md)

2.[操作系统有哪些分类？](interview/interview-master/面试/操作系统/OS/2.md)

2-2.[大端小端](interview/interview-master/面试/操作系统/OS/2-2.md)

3.[什么是内核态和用户态](interview/interview-master/面试/操作系统/OS/3.md)

4.[如何实现内核态和用户态的切换？](interview/interview-master/面试/操作系统/OS/4.md)

5.[并发和并行的区别](interview/interview-master/面试/操作系统/OS/5.md)

6.[什么是进程？](interview/interview-master/面试/操作系统/OS/6.md)

7.[进程的基本操作](interview/interview-master/面试/操作系统/OS/7.md)

7-1.[子进程继承了父进程哪些东西](7-1.md)

7-2.[fork和vfork区别](7-2.md)

7-3.[fork,wait,exec](interview/interview-master/面试/操作系统/OS/7-3.md)

8.[简述进程间通信方法](interview/interview-master/面试/操作系统/OS/8.md)

9.[进程如何通过管道进行通信](interview/interview-master/面试/操作系统/OS/9.md)

9-1.[有名管道和无名管道](9-1.md)

10.[进程如何通过共享内存通信？](interview/interview-master/面试/操作系统/OS/10.md)

10-1.[共享内存为什么可以实现进程通信](interview/interview-master/面试/操作系统/OS/10-1.md)

10-2.[共享内存API](请你来说一下共享内存相关api.md)

11.[什么是信号](interview/interview-master/面试/操作系统/OS/11.md)

12.[如何编写正确且安全的信号处理函数](interview/interview-master/面试/操作系统/OS/12.md)

13.[进程调度的时机](interview/interview-master/面试/操作系统/OS/13.md)

14.[不能进行进程调度的情况](interview/interview-master/面试/操作系统/OS/14.md)

15.[进程的调度策略](interview/interview-master/面试/操作系统/OS/15.md)

16.[进程调度策略的基本设计指标](interview/interview-master/面试/操作系统/OS/16.md)

17.[进程的状态与状态转换](interview/interview-master/面试/操作系统/OS/17.md)

18.[孤儿进程、僵尸进程、守护进程](interview/interview-master/面试/操作系统/OS/18.md)

19.[什么是线程](interview/interview-master/面试/操作系统/OS/19.md)？

19-1.[线程需要保存哪些上下文](interview/interview-master/面试/操作系统/OS/19-1.md)

19-2.[有哪些线程模型](19-2.md)

19-3.[线程池](19-3.md)

20.[为什么需要线程](interview/interview-master/面试/操作系统/OS/20.md)？

21.[线程和进程的区别和联系](interview/interview-master/面试/操作系统/OS/21.md)

22.[进程和线程的基本API](interview/interview-master/面试/操作系统/OS/22.md)

23.[多线程模型](interview/interview-master/面试/操作系统/OS/23.md)

24.[进程同步的方法](interview/interview-master/面试/操作系统/OS/24.md)

25.[线程同步的方法](interview/interview-master/面试/操作系统/OS/25.md)

26.[进程同步与线程同步有什么区别](interview/interview-master/面试/操作系统/OS/26.md)

26-1.[多进程和多线程抉择](interview/interview-master/面试/操作系统/OS/26-1.md)

26-2.[协程](interview/interview-master/面试/操作系统/OS/26-2.md)

27.[死锁是怎样产生的](interview/interview-master/面试/操作系统/OS/27.md)？

28.[如何处理死锁问题](interview/interview-master/面试/操作系统/OS/28.md)？

29.[什么是虚拟地址，什么是物理地址](interview/interview-master/面试/操作系统/OS/29.md)？

29-1.[虚拟地址分布](29-1.md)

29-2.[常量区有哪些数据](29-2.md)

29-3[静态区](29-3.md)

29-4[虚拟内存和物理内存怎么对应](29-4.md)

30.[什么是虚拟内存](interview/interview/interview-master/面试/操作系统/OS/30.md)？

31.[为什么要引入虚拟内存](31.md)？

32.[常见的页面置换算法](32.md)

32-1.[缺页中断](32-1.md)

33.[请说一下什么是写时复制](33.md)？

34.[实时操作系统的概念](34.md)

35.[优先级反转是什么？如何解决](35.md)

36.[微内核和宏内核](36.md)



## Linux

#### 1.常用命令

* [netstat](netstat.md)
* [tcpdump](tcpdump.md)
* [ipcs](ipcs.md)
* [ipcrm](ipcrm.md)
* [awk](awk.md)
* [ps](interview/interview/interview-master/面试/操作系统/Linux/command/ps.md)
* [free](free.md)
* [df](df.md)
* [du](du.md)

1-1.[修改文件最大句柄数](interview/interview-master/面试/操作系统/Linux/1-1.md)

1-2.[链接](interview/interview-master/面试/操作系统/Linux/1-2.md)

#### 2.Linux的锁机制

* 4种锁机制
  * [mutex 互斥锁](interview/interview-master/面试/操作系统/Linux/lock/mutex.md)
  * [rwlock 读写锁](rwlock.md)	
  * [spinlock 自旋锁](spinlock.md)
  * [RCU 读-拷贝修改](RCU.md)
* [互斥锁和读写锁的区别](mutex和rwlock区别.md)
* [自旋锁与互斥锁的区别](mutex和spinlock区别.md)

#### 3.IO

* [5种IO模型](Linux/IO/five IO model.md)

#### 4.编译链接装载调试

* [gdb](gdb.md)

5.[Linux 内核的同步方式](interview/interview-master/面试/操作系统/Linux/5.md)

6.[Linux页表寻址](interview/interview-master/面试/操作系统/Linux/6.md)

#### 7.网络

* select
* poll
* [epoll](interview/interview-master/面试/操作系统/Linux/net/7-3.md)
* [select poll epoll 区别](7-4.md)
* [reactor和proactor](7-5.md)

8.[linux内核Timer机制](interview/interview-master/面试/操作系统/Linux/8.md)

### 9.进程调度算法和数据结构

[Linux内核浅析-进程调度的算法和数据结构](进程调度的算法和数据结构.md)

## Windows

1.[window消息机制](interview/interview-master/面试/操作系统/Windows/1.md)

