# ucontext初步接触

简单例子：

```cpp
#include <stdio.h>
#include <sys/ucontext.h>
#include <ucontext.h>
#include <unistd.h>

int main(int argc,const char* argv[])
{
    ucontext_t context;

    getcontext(&context);
    puts("Hello world");
    sleep(1);
    setcontext(&context);
    return 0;
}
```

程序运行结果：

```
daguai@daguai-VMware-Virtual-Platform:~/coroutine$ ./example 
Hello world
Hello world
Hello world
Hello world
Hello world
Hello world
Hello world
```

程序持续不断的输出“Hello world",是因为`getcontext`保存了一个上下文，然后输出”Hello world",再通过`setcontext`恢复到`getcontext`的地方，重新执行代码，所以导致不断的输出"Hello world"。

# ucontext组件到底是什么

```cpp
typedef struct ucontext {
	struct ucontext *uc_link;
	sigset_t uc_sigmask;
	stack_t uc_stack;
	mcontext_t uc_mcontext;
} ucontext_t;
```

## `uc_link`

- 含义：指向下一个要恢复的上下文（context）的指针。
- 作用：
	- 当当前上下文（由`makecontext()`创建的）执行完毕后，会自动切换回`uc_link`所指向的上下文。
	- 如果为`NULL`，当前上下文执行完后直接终止程序。

## `uc_sigmask`

- 含义：当前上下文中阻塞`屏蔽`的信号集合。
- 作用：
	- 保存当前上下文中的信号屏蔽字，表示在该上下文中哪些信号会被屏蔽。
	- 当恢复该上下文时候（比如`setcontext()`),内核会恢复这个信号掩码。

## `stack_t uc_stack`

- 含义：当前上下文的栈信息（栈空间、大小等）。
- 结构体定义：
```cpp
typedef struct {
	void *ss_sp; //栈底地址
	int ss_flags; //标志位（一般为0）
	size_t ss_size; //栈大小
}stack_t;
```
- 作用：
	- 为该上下文分配并指定栈空间，用于函数执行和局部变量的存储等。
	- 通常`makecontext()`前需要设置`uc_stack`。

## `mcontext_t uc_mcontext`

- 含义：保存CPU寄存器的状态（如PC、SP、寄存器等）。
- 作用：
	- 描述该上下文中，CPU的状态，包含指令指针、栈指针、通用寄存器、浮点寄存器等。
	- 用于在上下文切换时保存/恢复执行点。

- 用处：
	- `swapcontext()`时，将当前上下文的`mcontext_t`保存，再加载目标上下文的`mcontext_t`。


## 四个函数详细介绍

```cpp
int getcontext(ucontext_t* ucp);
```

- 功能：将当前线程的上下文保存到`ucp`指向的`ucontext_t`结构中。
- 作用: 保存当前CPU的执行状态：
	- 寄存器
	- 程序计数器
	- 栈信息
- 特点：
	- 它只会保存当前上下文，并不会改变执行流。
	- 保存完后程序继续往下执行。

```cpp
int setcontext(const ucontext_t* ucp)
```

- 功能：设置当前上下文为`ucp`所指向的上下文，**直接跳转并恢复上下文**。
- 特点：
	- 如果`ucp`是通过`getcontext()`得到的，则程序会从原来`getcontext()`调用处继续执行。
	- 如果`ucp`是通过`makecontext()`构造的，则从其指定的`func()`函数开始执行。
	- 如果`func()`返回：
		- 会自动跳转到`ucp->uc_link`指向的上下文；
		- 如果`uc_link`未`NULL`,当前线程将退出。
- 返回值：
	- 如果成功切换过程，它不会返回；
	- kk如果失败（比如非法指针），返回`-1`并设置`errno`。

```cpp
void makecontext(ucontext_t* ucp,void (*func)(),int argc, ...)
```

- 功能：构造一个可以执行`func`的上下文对象`ucp`。通常用于创建协程或"线程”的入口。
- 使用前提：
	- 必须先对`ucp`调用`getcontext()`初始化上下文信息，特别是栈相关的字段。
- 参数说明：
	- ucp：通过`getcontext`初始化的上下文结构。
	- func：当`ucp`被激活时要执行的函数。
	- arg: `func`函数参数个数。
	- ...: `func`函数的参数值（可变参数）。
- 注意：
	- 必须先设置`ucp->uc_stack`（分配栈空间），否则会奔溃。
	- 必须设置`ucp->uc_link`：当`func`执行完毕后跳转的上下文。
		- 如果为`NULL`，程序将`exit()`。
- 示例：
```cpp
ucontext_t uc; //定义一个ucontext_t变量
getcontext(&uc); //初始化uc
uc.uc_stack.ss_sp = stack; //指定栈地址
uc.uc_stack.ss_size = size; //栈大小
uc.uc_link = &main_context: //func执行完后跳回到主上下文
makecontext(&uc,func,2,arg1,arg2) //指定func和其参数
```

```cpp
int swapcontext(ucontext_t* oucp,ucontext_t* ucp);
```
- 功能：
	- 保存当前上下文到`oucp`，并切换到`ucp`上下文中去执行（执行`ucp`的`func()`函数或从`getcontext()`处继续执行)。
- 行为：
	- 将当前执行状态保存到`oucp`;
	- 跳转执行`ucp`所代表的上下文。
- 返回值：
	- 第一次调用返回时，程序是从`ucp`的上下文开始执行；
	- 当以后再次切回`oucp`，该函数会返回`0`。
- 使用场景：
	- 两个协程/线程之间来回切换。
	- 比如：`协程A`调用`swapcontext(&A,&B)`,执行`B`,`B`再切回`A`，`A`从`swapcontext`之后继续。


# 使用ucontext组件实现线程切换

