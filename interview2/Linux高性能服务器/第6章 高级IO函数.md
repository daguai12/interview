# 6.1 pipe函数

 **📌 区别总结**

| 特性                    | `socketpair()`                         | `pipe()`        |
| --------------------- | -------------------------------------- | --------------- |
| **通信方式**              | **全双工**（双向通信）                          | **半双工**（单向通信）   |
| **文件描述符**             | 返回**一对** socket                        | 返回**两个文件描述符**   |
| **适用协议**              | 仅支持 **Unix domain sockets**（`AF_UNIX`） | 仅支持 **管道**      |
| **适用范围**              | 适用于 **本地进程间通信**                        | 适用于 **本地进程间通信** |
| **数据结构**              | **流式（SOCK_STREAM） 或 数据报（SOCK_DGRAM）**  | **字节流**         |
| **能否用于 select()**     | **可以**                                 | **可以**          |
| **能否用于 fork() 进程间通信** | **可以**                                 | **可以**          |
**📌  重点记忆**

- **管道是单向的**，`fd[0]` 只能读，`fd[1]` 只能写。
    
- **默认情况下 `read()` 和 `write()` 是阻塞的**：
    
    - 读端 **没数据** → `read()` **阻塞**。
        
    - 写端 **管道满了** → `write()` **阻塞**。
        
- **非阻塞模式（`O_NONBLOCK`）下**：
    
    - **`read()` 返回 `-1` 并设置 `errno = EAGAIN`**（无数据）。
        
    - **`write()` 返回 `-1` 并设置 `errno = EAGAIN`**（管道满）。
        
- **如果所有 `fd[1]` 关闭，`read()` 返回 `0`（EOF）。**
    
- **如果所有 `fd[0]` 关闭，`write()` 失败并触发 `SIGPIPE`。**

***
# 6.2 dup函数和dup2函数

dup和dup2可以复制文件描述符。

```c
int dup(int file_descriptor);
int dup2(int file_descriptor_one,int file_descriptor_two);
```

> 通过dup和dup2创建的文件描述符并不继承原文件描述符的属性，比如close-on-exec和non-blocking等。

***

# 6.3 writev函数和readv函数

**1. readv函数**

将文件描述符中的数据读取到不同块分散的内存中.

```c
ssize_t readv(int fd,const struct iovec* vector,int count);
```

**2. readv函数**

将多块分散的内存数据写入同一文件描述符中。

```c
ssize_t writev(int fd,const struct iovec* vector,int count);
```

**3.iovec结构体**

```c
struct iovec {
    void  *iov_base;  // 指向数据缓冲区的指针
    size_t iov_len;   // 缓冲区的长度（字节数）
};
```

HTTP应答包含一个状态行，多个头部字段，一个空行和文档的内容。前三个部分放在一个内存中，而文档内容则放在另外一个单独的内存中（可以使用read函数和mmap函数读出）。我们不需要把他们拼接在一起，而是可以使用writev函数同时写出。

```cpp
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <sys/uio.h>

#define BUFFER_SIZE 1024
static const char* status_line[2] = { "200 OK", "500 Internal server error" };

int main( int argc, char* argv[])
{
    if( argc <= 3 )
    {
        printf( "usage: %s ip_address port_number filename\n", basename( argv[0] ) );
        return 1;
    }
    const char* ip = argv[1];
    int port = atoi( argv[2] );
    const char* file_name = argv[3];

    struct sockaddr_in address;
    bzero( &address, sizeof( address ) );
    address.sin_family = AF_INET;
    inet_pton( AF_INET, ip, &address.sin_addr );
    address.sin_port = htons( port );

    int sock = socket( PF_INET, SOCK_STREAM, 0 );
    assert( sock >= 0 );

    int ret = bind( sock, ( struct sockaddr* )&address, sizeof( address ) );
    assert( ret != -1 );

    ret = listen( sock, 5 );
    assert( ret != -1 );

    struct sockaddr_in client;
    socklen_t client_addrlength = sizeof( client );
    int connfd = accept( sock, ( struct sockaddr* )&client, &client_addrlength );
    if ( connfd < 0 )
    {
        printf( "errno is: %d\n", errno );
    }
    else
    {
        char header_buf[ BUFFER_SIZE ];
        memset( header_buf, '\0', BUFFER_SIZE );
        char* file_buf;
        struct stat file_stat;
        bool valid = true;
        int len = 0;
        if( stat( file_name, &file_stat ) < 0 )
        {
            valid = false;
        }
        else
        {
            if( S_ISDIR( file_stat.st_mode ) )
            {
                valid = false;
            }
            else if( file_stat.st_mode & S_IROTH )
            {
                int fd = open( file_name, O_RDONLY );
                file_buf = new char [ file_stat.st_size + 1 ];
                memset( file_buf, '\0', file_stat.st_size + 1 );
                if ( read( fd, file_buf, file_stat.st_size ) < 0 )
                {
                    valid = false;
                }
            }
            else
            {
                valid = false;
            }
        }
        
        if( valid )
        {
            ret = snprintf( header_buf, BUFFER_SIZE-1, "%s %s\r\n", "HTTP/1.1", status_line[0]);
            len += ret;

            ret = snprintf( header_buf + len, BUFFER_SIZE-1-len, "Content-Type: text/html; charset=UTF-8\r\n" );
            len += ret;

            ret = snprintf( header_buf + len, BUFFER_SIZE-1-len, 
                             "Content-Length: %d\r\n", file_stat.st_size );
            len += ret;
            ret = snprintf( header_buf + len, BUFFER_SIZE-1-len, "%s", "\r\n" );
            struct iovec iv[2];
            iv[ 0 ].iov_base = header_buf;
            iv[ 0 ].iov_len = strlen( header_buf );
            iv[ 1 ].iov_base = file_buf;
            iv[ 1 ].iov_len = file_stat.st_size;
            ret = writev( connfd, iv, 2 );
      while(1){
        sleep(1);
      }
        }
        else
        {
            ret = snprintf( header_buf, BUFFER_SIZE-1, "%s %s\r\n", "HTTP/1.1", status_line[1] );
            len += ret;
            ret = snprintf( header_buf + len, BUFFER_SIZE-1-len, "%s", "\r\n" );
            send( connfd, header_buf, strlen( header_buf ), 0 );
        }
        close( connfd );
        delete [] file_buf;
    }

    close( sock );
    return 0;
}

```

***
# 6.4 sendfile函数

```c
ssize_t sendfile(int out_fd,int in_fd,off_t* offset,size_t count);
```

**sendfile** 函数在两个文件描述符之间直接传输数据，所有过程都在内核态完成，避免了内核态和用户态之间的拷贝，效率非常高。

**sendfile** 的 **in_fd** 参数必须是一个真实的文件，不可以是（管道和socket），out_fd必须是socket。

***
# 6.5 mmap函数和munmap函数

**📌 1. `mmap` 和 `munmap` 的定义**

```c
#include <sys/mman.h>

void* mmap(void *start, size_t length, int prot, int flags, int fd, off_t offset);
int munmap(void *start, size_t length);
```

- **`mmap` 用于申请内存空间**，可以用于进程间共享，也可以映射文件到内存中。
    
- **`munmap` 用于释放 `mmap` 创建的内存空间**。
    



**📌 2. `mmap` 参数解析**

|**参数**|**说明**|
|---|---|
|`start`|指定映射的起始地址（通常设为 `NULL` 让系统自动分配）。|
|`length`|映射的内存区域大小（必须是页大小的倍数，通常 `4096` 字节）。|
|`prot`|设置映射区域的访问权限。|
|`flags`|设置映射区域的属性，如是否共享、是否匿名映射等。|
|`fd`|被映射的文件描述符（若使用匿名映射，可设为 `-1`）。|
|`offset`|映射文件的偏移量，通常设为 `0`。|



 **📌 3. `prot`（访问权限）**

可选的 `prot` 取值：

- `PROT_READ`：可读
    
- `PROT_WRITE`：可写
    
- `PROT_EXEC`：可执行
    
- `PROT_NONE`：不可访问
    



**📌 4. `flags`（映射方式）**

可选的 `flags` 取值（部分值互斥）：

|**常用值**|**含义**|
|---|---|
|`MAP_SHARED`|共享映射，对映射区域的修改会同步到文件。|
|`MAP_PRIVATE`|私有映射，修改不会影响原文件，写时拷贝（COW）。|
|`MAP_ANONYMOUS`|匿名映射，不与文件关联（`fd` 需设为 `-1`）。|
|`MAP_FIXED`|强制使用 `start` 指定的地址（可能会失败）。|
|`MAP_HUGETLB`|使用大页映射，提高性能（依赖系统支持）。|



**📌 5. `mmap` 返回值**

- **成功**：返回映射的地址
    
- **失败**：返回 `MAP_FAILED`（即 `(void*)-1`），并设置 `errno`
    



 **📌 6. `munmap` 作用**

- **用于释放 `mmap` 申请的内存区域**。
    
- **成功返回 `0`，失败返回 `-1` 并设置 `errno`**。
    



**📌 7. `mmap` 的用途**

- **文件映射**（文件 I/O 加速）
    
- **匿名映射**（进程间共享内存）
    
- **实现用户态内存管理**
    
- **大页映射**（提升性能）
    


**📌 总结**

- `mmap` 用于 **创建内存映射**，可以用于 **文件映射** 或 **匿名共享**。
    
- `munmap` 用于 **释放映射的内存区域**。
    
- `prot` 参数用于设置访问权限，如 `PROT_READ`、`PROT_WRITE`。
    
- `flags` 参数决定映射行为，如 `MAP_SHARED`（共享映射）、`MAP_PRIVATE`（私有映射）。
    
- **文件映射时需提供 `fd`，匿名映射需设 `MAP_ANONYMOUS` 并将 `fd` 设为 `-1`**。
    


# **补充**

**📌 为什么会发生 `Bus Error`？**

- **`mmap` 映射的是一个文件**，但 **文件大小不足以覆盖 `mmap` 申请的区域**。
    
- 访问 `mmap` 申请但 **超出文件实际大小的地址** 时，**内存页不存在**，导致 **Bus Error**（而不是 Segmentation Fault）。
    


**📌 解决方案**

在 `mmap` 文件映射之前，使用 `ftruncate` **扩展文件大小**，确保 `mmap` 映射的区域是有效的：

 **✅ 正确的做法**

```c
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define FILE_PATH "testfile"
#define FILE_SIZE 4096  // 映射 4KB

int main() {
    int fd = open(FILE_PATH, O_RDWR | O_CREAT, 0666);
    if (fd == -1) {
        perror("open");
        exit(EXIT_FAILURE);
    }

    // **使用 ftruncate 预先分配文件大小**
    if (ftruncate(fd, FILE_SIZE) == -1) {
        perror("ftruncate");
        close(fd);
        exit(EXIT_FAILURE);
    }

    // **mmap 文件**
    void *addr = mmap(NULL, FILE_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (addr == MAP_FAILED) {
        perror("mmap");
        close(fd);
        exit(EXIT_FAILURE);
    }

    // 写入数据
    sprintf((char *)addr, "Hello mmap!");

    // 释放资源
    munmap(addr, FILE_SIZE);
    close(fd);

    return 0;
}

```

**📌 如果不使用 `ftruncate`，会发生什么？**

假设文件 `testfile` **是一个空文件**，但你直接 `mmap(4096)`，然后写入数据：

```c
void *addr = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
sprintf((char *)addr, "Hello mmap!");  // ❌ 可能触发 Bus Error
```

- **如果 `testfile` 文件大小小于 `4096` 字节**，访问超过文件大小的区域 **可能会触发 `Bus Error`**。
    
- 因为 `mmap` 映射文件 **不会自动扩展文件大小**，必须手动 `ftruncate` 扩展。
    


 **📌 `Bus Error` vs `Segmentation Fault`**

- **`Bus Error`（总线错误）**：访问 **不存在的内存页**（例如 `mmap` 超出文件大小）。
    
- **`Segmentation Fault`（段错误）**：访问 **无权限的内存区域**（例如 `NULL` 指针解引用）。
    


 **📌 结论**

- **`mmap` 映射文件时，必须确保文件大小足够，否则写入时可能会触发 `Bus Error`**。
    
- **使用 `ftruncate(fd, size)` 预先扩展文件大小，避免 `Bus Error`**。
***
在以下情况下，使用 `mmap` **不需要** 使用 `ftruncate` 预先扩展文件大小：



 **✅ 1. 仅进行文件读取（`PROT_READ`）**

如果你只是 **以只读方式** 映射文件，并且不修改它的内容，则 **不需要 `ftruncate`**，因为你不会尝试写入超出文件范围的内容：

```c
int fd = open("testfile", O_RDONLY);
void *addr = mmap(NULL, FILE_SIZE, PROT_READ, MAP_PRIVATE, fd, 0);
```

- **📌 为什么？**
    
    - 只读映射不会修改文件内容，因此不会产生访问超出文件大小的问题。
        
    - 但是，**如果尝试写入，只读映射会导致 `Segmentation Fault`**。
        



**✅ 2. 使用 `MAP_ANONYMOUS`（匿名映射，不依赖文件）**

如果使用 `mmap` **创建的是匿名映射**（即不基于文件，而是从 **虚拟内存** 申请空间），那么 **不需要 `ftruncate`**：

```c
void *addr = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
```

- **📌 为什么？**
    
    - **匿名映射** 直接从 **虚拟内存** 分配，不依赖文件，因此 **不存在超出文件大小的问题**。
        
    - 适用于 **进程间通信（IPC）或创建大块临时内存**。
        



 **✅ 3. 映射的文件本身已经足够大**

如果你映射的 **文件已经大于等于 `mmap` 需要的大小**，则不需要 `ftruncate` 预先扩展：

```c
// 假设 testfile 的大小 >= FILE_SIZE
int fd = open("testfile", O_RDWR);
void *addr = mmap(NULL, FILE_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
```

- **📌 为什么？**
    
    - 既然文件已经足够大，`mmap` 映射的区域不会超出文件大小，访问不会导致 **Bus Error**。
        
    - 但如果 `mmap` 尝试写入超出文件大小的内容，仍然可能导致 `Bus Error`。
        



**📌 总结**

| **情况**                    | **是否需要 `ftruncate`** | **原因**                        |
| ------------------------- | -------------------- | ----------------------------- |
| **只读映射（`PROT_READ`）**     | ❌ 不需要                | 只读不会修改文件内容，不会超出文件大小           |
| **匿名映射（`MAP_ANONYMOUS`）** | ❌ 不需要                | 内存来自虚拟地址空间，不依赖文件              |
| **文件大小足够**                | ❌ 不需要                | `mmap` 的区域不会超出文件大小            |
| **写入映射但文件过小**             | ✅ 需要                 | 避免 `Bus Error`，确保 `mmap` 区域有效 |

如果你是 **读文件** 或 **使用匿名映射**，`ftruncate` 不是必须的；但如果是 **写入文件映射**，就需要确保文件大小足够，以避免 `Bus Error`。


使用 `lseek` 设置新创建文件的大小的正确方法如下：



**🌟 使用 `lseek` + `write` 预分配文件大小**

`lseek` **不会直接改变文件大小**，但可以将文件指针移动到指定位置，然后用 `write` **写入一个字节** 来扩展文件：

```c
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

int main() {
    int fd = open("testfile.txt", O_RDWR | O_CREAT, 0666);
    if (fd == -1) {
        perror("open");
        return 1;
    }

    // 使用 lseek 移动到 1MB 位置（最后一个字节）
    if (lseek(fd, 1024 * 1024 - 1, SEEK_SET) == -1) {
        perror("lseek");
        return 1;
    }

    // 写入一个字节，强制扩展文件大小
    if (write(fd, "", 1) == -1) {
        perror("write");
        return 1;
    }

    close(fd);
    return 0;
}
```


 **📌 解释**

1. **`lseek(fd, 1024 * 1024 - 1, SEEK_SET)`**
    
    - 将文件指针移动到 **1MB - 1** 位置（即 **最后一个字节**）。
        
    - **⚠️ 只是移动指针，不会自动扩展文件！**
        
2. **`write(fd, "", 1)`**
    
    - 写入 **1 字节**（即 1MB 位置的字节）。
        
    - **💡 这样才会真正扩展文件大小**，否则 `lseek` **不会生效**！
        


### **🌟 `lseek` vs `ftruncate`**

|方法|作用|适用场景|
|---|---|---|
|**`lseek` + `write`**|**可扩展文件，但不能缩小**|适用于 **手动预分配空间**|
|**`ftruncate`**|**可增大或缩小文件大小**|**推荐**，更简洁高效|


 **🌟 `ftruncate` 更推荐**

更好的方法是 **使用 `ftruncate` 直接扩展文件**：

```c
#include <fcntl.h>
#include <unistd.h>

int main() {
    int fd = open("testfile.txt", O_RDWR | O_CREAT, 0666);
    if (fd == -1) {
        perror("open");
        return 1;
    }

    // 直接扩展文件到 1MB
    if (ftruncate(fd, 1024 * 1024) == -1) {
        perror("ftruncate");
        return 1;
    }

    close(fd);
    return 0;
}
```

✅ **`ftruncate` 直接修改文件大小，避免 `lseek` + `write` 的麻烦**。

**📌 总结**

- **如果只是扩展文件，推荐 `ftruncate(fd, size)`** ✅
    
- **如果用 `lseek(fd, size-1, SEEK_SET)`，必须 `write(fd, "", 1)` 才会生效** ✅

***

# 6.6 splice函数

`splice` 是 Linux 特有的系统调用，用于 **在两个文件描述符（fd）之间零拷贝传输数据**，避免了用户空间与内核空间的多次拷贝，提高性能。

---

## **📖 函数原型**

```c
#include <fcntl.h>   // 头文件
#include <unistd.h>

ssize_t splice(int fd_in, off_t *off_in, 
               int fd_out, off_t *off_out, 
               size_t len, unsigned int flags);

```


---

## **⚡ 参数详解**

| 参数        | 说明                               |
| --------- | -------------------------------- |
| `fd_in`   | **输入文件描述符**，数据来源（管道、文件、socket）   |
| `off_in`  | **输入偏移量**（对管道必须为 `NULL`，否则会报错）   |
| `fd_out`  | **输出文件描述符**，数据写入目标（管道、文件、socket） |
| `off_out` | **输出偏移量**（对管道必须为 `NULL`，否则会报错）   |
| `len`     | **要传输的数据长度（字节）**                 |
| `flags`   | **可选标志**（详见下文）                   |

![[Pasted image 20250402202507.png]]

![[Pasted image 20250402202529.png]]

注意！
> fd_in 和 fd_out必须至少有一个是管道文件描述符。

# 补充（管道文件描述符和非管道文件描述符）

 **📌 管道文件描述符 vs. 非管道文件描述符**

### **1️⃣ 文件描述符（File Descriptor, FD）**

在 Linux/Unix 系统中，**文件描述符（FD）** 是一个 **整数索引**，用于表示打开的文件、套接字、管道等资源。

---

 **🌊 2️⃣ 管道文件描述符**

管道文件描述符是 **用于进程间通信（IPC）的文件描述符**，它们主要与 **管道（pipe）、匿名管道、命名管道（FIFO）、socketpair** 等机制相关。

 **🔹 常见的管道文件描述符**

|**类型**|**描述**|
|---|---|
|`pipe()`|创建一个 **匿名管道**，返回两个 FD（`fd[0]` 读端, `fd[1]` 写端）。|
|`socketpair()`|创建 **双向通信管道**（本质上是两个连接的 socket）。|
|**FIFO (命名管道)**|通过 `mkfifo()` 创建，进程间可以通过打开 FIFO 进行通信。|

 **📌 示例：创建匿名管道**

```cpp
#include <unistd.h>
#include <stdio.h>

int main() {
    int fd[2]; // fd[0] 读端, fd[1] 写端
    pipe(fd);

    write(fd[1], "Hello", 5);
    char buffer[10] = {0};
    read(fd[0], buffer, 5);
    
    printf("Received: %s\n", buffer);
    return 0;
}
```

✅ **特点**

- **管道文件描述符只能用于进程间通信**，不能用于普通文件操作。
    
- **管道是单向的**，`pipe()` 需要 `fd[0]` 读，`fd[1]` 写。
    

---

 **🚀 3️⃣ 非管道文件描述符**

**非管道 FD 指的是普通文件、网络套接字、终端、设备等文件描述符。**

**🔹 常见的非管道文件描述符**

| **类别**     | **函数/特性**                               |
| ---------- | --------------------------------------- |
| **标准 I/O** | `0` (stdin), `1` (stdout), `2` (stderr) |
| **普通文件**   | `open()`, `read()`, `write()`           |
| **网络套接字**  | `socket()`, `connect()`, `accept()`     |
| **设备文件**   | `/dev/null`, `/dev/tty`, `/dev/random`  |

 **📌 示例：打开文件**

```cpp
#include <fcntl.h>
#include <unistd.h>

int main() {
    int fd = open("test.txt", O_WRONLY | O_CREAT, 0644);
    write(fd, "Hello File", 10);
    close(fd);
}
```

✅ **特点**

- **普通文件的 FD 可以随机读写**，不像管道那样是流式的。
    
- **文件描述符可用于本地存储**，而管道主要用于进程间通信。
    

---

**🔍 4️⃣ 主要区别总结**

|**对比项**|**管道文件描述符**|**非管道文件描述符**|
|---|---|---|
|**用途**|进程间通信（IPC）|文件、网络、终端等|
|**示例**|`pipe()`, `socketpair()`|`open()`, `socket()`|
|**访问模式**|**单向（pipe）或双向（socketpair）**|**可读可写**|
|**数据存储**|**临时，依赖内核缓冲区**|**持久，存储在磁盘**|

---

 **📌 总结**

- **管道 FD（pipe、socketpair、FIFO）** 主要用于 **进程间通信**，数据存储在 **内核缓冲区**，是 **流式** 的。
    
- **非管道 FD（普通文件、套接字、设备文件）** 主要用于 **存储、网络、终端交互**，可以 **随机读写**。
    

如果你要 **在进程之间传输数据，使用管道文件描述符**；如果你要 **读写磁盘文件或网络通信，使用普通文件描述符或 socket**。 🚀

***

# 6.7tee函数

 **📌 `tee` 函数详细介绍**

`tee` 是 **Linux 特有的系统调用**，用于 **在两个管道文件描述符之间复制数据**，**不消耗数据**，即：

- **数据不会被消耗**，多个进程/线程可以同时读取数据。
    
- 适用于 **日志记录、数据监控** 等场景。
    

---

**📖 `tee` 函数原型**

```c
#include <fcntl.h>   // 头文件
#include <unistd.h>

ssize_t tee(int fd_in, int fd_out, size_t len, unsigned int flags);
```

---

**⚡ 参数详解**

|参数|说明|
|---|---|
|`fd_in`|**输入管道文件描述符**（必须是管道）|
|`fd_out`|**输出管道文件描述符**（必须是管道）|
|`len`|**要复制的数据长度（字节）**|
|`flags`|**可选标志（一般为 0，或 `SPLICE_F_NONBLOCK` 以非阻塞方式操作）**|
|**返回值**|**成功**：返回复制的字节数；**失败**：返回 `-1` 并设置 `errno`|

---

 **✅ `tee` 的工作原理**

1. **从 `fd_in` 读取数据，并复制到 `fd_out`**，但数据 **不会从 `fd_in` 中删除**（不像 `splice` 那样 "搬运" 数据）。
    
2. 适用于 **多个进程/线程需要同时读取管道数据**。
    
3. **`fd_in` 和 `fd_out` 必须是管道**，不能是普通文件或 socket。
    

---

 **🔹 示例：在两个管道间复制数据**

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

int main() {
    int pipefd1[2], pipefd2[2];
    pipe(pipefd1);  // 创建管道 1
    pipe(pipefd2);  // 创建管道 2

    // 向 pipefd1[1] 写入数据
    write(pipefd1[1], "Hello, tee!", 12);

    // 使用 tee 复制数据 pipefd1[0] → pipefd2[1]
    tee(pipefd1[0], pipefd2[1], 12, 0);

    char buf1[12], buf2[12];

    // 分别从两个管道读取数据
    read(pipefd1[0], buf1, 12);
    read(pipefd2[0], buf2, 12);

    printf("Pipe 1: %s\n", buf1);
    printf("Pipe 2: %s\n", buf2);

    close(pipefd1[0]);
    close(pipefd1[1]);
    close(pipefd2[0]);
    close(pipefd2[1]);

    return 0;
}
```

✅ **输出**

```
Pipe 1: Hello, tee!
Pipe 2: Hello, tee!
```

数据 **同时被多个管道读取**，但原始数据并不会被销毁。

---

 **📌 `tee` vs `splice`**

|**功能**|`tee`|`splice`|
|---|---|---|
|**作用**|复制数据|移动数据|
|**数据是否消耗**|❌ 不消耗|✅ 消耗|
|**是否支持文件**|❌ 仅支持管道|✅ 支持文件、socket、管道|
|**用途**|数据镜像、日志|高效数据搬运（零拷贝）|

---

 **📌 适用场景**

- **日志监控**（同时发送数据到日志系统和另一个进程）。
    
- **数据复制**（多个进程同时消费同一份数据）。
    
- **Shell 命令实现 `tee` 命令功能**（将标准输入复制到多个输出）。
    

---

 **🚀 总结**

- `tee` **复制** 数据，而 **不消耗** 数据，多个进程可以同时读取。
    
- 只能在 **管道** 之间工作，不能用于文件或 socket。
    
- 适用于 **日志监控、数据广播** 等场景。
    

如果你想 **高效地在文件、socket、管道间移动数据**，请使用 `splice`！
