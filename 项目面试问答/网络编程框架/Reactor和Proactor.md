# Practor模式
好的，我们来非常详细地讲解一下 **Proactor（前摄器）模式**。这是一个在高性能网络编程和并发设计中至关重要的设计模式。

为了让你彻底理解，我会从以下几个方面进行剖析：

1.  **核心思想：Proactor 是什么？**
2.  **关键角色/组件**
3.  **详细的执行流程**
4.  **Proactor vs. Reactor：最重要的对比**
5.  **现实世界中的实现范例**
6.  **优点与缺点**
7.  **代码伪代码示例**
8.  **总结**

-----

### 1\. 核心思想：Proactor 是什么？

Proactor 模式是一种**异步事件处理模式**，其核心思想是**将 I/O 操作本身也异步化**。

为了更好地理解，我们用一个生动的比喻：去餐厅点餐。

  * **同步阻塞模式**：你走到前台，点一份汉堡。然后你就**一直站在那儿等着**，直到汉堡做好，你拿到汉堡才能离开去做别的事。这期间你被“阻塞”了。
  * **Reactor（反应器）模式**：你走到前台，点一份汉堡。服务员给你一个取餐器，说：“取餐器响的时候，就说明你的汉堡**可以取了**，你再过来取。” 于是你找个座位坐下玩手机。当取餐器响起（事件就绪），你**自己**走到前台，从厨师手里接过汉堡。
      * **关键点**：Reactor 告诉你“何时可以进行 I/O 操作而不会阻塞”，但**执行 I/O 操作（比如 `read` 数据）的动作仍然是由你自己（应用程序线程）完成的**。
  * **Proactor（前摄器）模式**：你走到前台，点一份汉堡，并告诉服务员你的座位号。服务员说：“好的，汉堡做好后，我**会直接给你送到座位上**。” 于是你回到座位玩手机，完全不用关心汉堡什么时候做好、什么时候去取。当汉堡做好后，服务员直接把汉堡端到你面前。
      * **关键点**：Proactor 模式中，你（应用程序）只需要发起一个 I/O 操作（比如 `async_read`），并提供一个“处理器”（Completion Handler）和一个数据缓冲区。然后你就可以完全不管了。**操作系统（或框架）会帮你完成整个 I/O 操作**，并将结果（读取到的数据）放入你提供的缓冲区。当一切**完成后**，Proactor 会调用你提供的“处理器”，告诉你“操作已完成，数据在这里”。

**一句话总结 Proactor 核心思想**：应用程序只管发起异步 I/O 操作，而真正的 I/O 过程由操作系统或框架在后台完成。完成后，再通知应用程序来处理结果。应用程序从“等待就绪”和“执行 I/O”中彻底解放出来，只需关心“发起”和“处理结果”。

-----

### 2\. 关键角色/组件

![[Pasted image 20251010090149.png]]
一个完整的 Proactor 模式通常包含以下几个关键角色：

1.  **Asynchronous Operation Processor (异步操作处理器)**：

      * 这是模式的核心，通常由操作系统内核实现（例如 Windows 的 IOCP、Linux 的 io\_uring）。
      * 它负责执行异步操作，并在操作完成后，将结果放入一个完成事件队列中。

2.  **Asynchronous Operation (异步操作)**：

      * 指具体的 I/O 操作，如 `read`, `write`, `accept`, `connect` 等。这些操作都是以非阻塞方式启动的。

3.  **Completion Handler (完成处理器)**：

      * 这是由应用程序定义的函数或对象，用于处理异步操作完成后的结果。
      * 每个异步操作都会关联一个 Completion Handler。例如，一个 `async_read` 操作会关联一个“读取完成处理器”。
      * 它就像你告诉餐厅服务员的“送到座位上”这个指令，是操作完成后的回调逻辑。

4.  **Proactor (前摄器/分发器)**：

      * 负责从 Asynchronous Operation Processor 的完成事件队列中取出事件。
      * 根据事件的类型，调用（dispatch）与之关联的那个特定的 Completion Handler。
      * 它充当了内核与应用程序回调之间的桥梁。

5.  **Initiator (发起者)**：

      * 这是应用程序的主体部分，负责创建异步操作、提供数据缓冲区和 Completion Handler，并通过 Proactor 将它们提交给 Asynchronous Operation Processor。
      * Initiator 发起操作后，不会等待操作完成，而是立即返回继续执行其他任务。

-----

### 3\. 详细的执行流程

我们以一次异步读取（`async_read`）为例，看看 Proactor 模式的完整工作流程：

1.  **发起（Initiation）**

      * 应用程序（Initiator）创建一个缓冲区用来存放即将到来的数据。
      * 应用程序创建一个 Completion Handler，用于定义数据读取完成后该如何处理。
      * 应用程序调用一个异步读接口（如 `socket.async_read(buffer, handler)`），将操作、缓冲区和处理器注册到 Proactor。

2.  **分发与执行（Dispatch & Execution）**

      * Proactor 将这个异步读请求转发给内核（Asynchronous Operation Processor）。
      * 应用程序的调用线程**立即返回**，不会被阻塞，可以去处理其他任务。
      * 内核开始监听网络，等待数据到达。当数据到达时，内核**自动将数据从网络硬件拷贝到应用程序提供的那个缓冲区中**。这个过程完全不需要应用程序线程的参与。

3.  **完成通知（Completion Notification）**

      * 当内核完成数据读取（例如，缓冲区已满或对方关闭连接），它会生成一个“完成事件”。
      * 这个完成事件被放入一个系统的完成队列中。

4.  **回调处理（Callback Handling）**

      * Proactor 在一个独立的线程（或线程池）中等待完成队列。
      * 当 Proactor 从队列中取出一个完成事件时，它会解析这个事件，找到与之关联的那个 Completion Handler。
      * Proactor 调用该 Completion Handler，并将操作结果（如读取的字节数、错误码等）作为参数传入。
      * 应用程序在 Completion Handler 中开始处理已经准备好的数据（例如，解析协议、执行业务逻辑等）。

-----

### 4\. Proactor vs. Reactor：最重要的对比

这是理解 Proactor 的关键，也是面试和技术讨论中的高频问题。

| 特性            | Reactor (反应器)                                  | Proactor (前摄器)                                      |
| :------------ | :--------------------------------------------- | :-------------------------------------------------- |
| **核心关注点**     | **I/O 就绪 (Readiness)**                         | **I/O 完成 (Completion)**                             |
| **通知时机**      | 当 Handle (文件描述符) **可以**进行非阻塞 I/O 操作时通知。        | 当 I/O 操作已经**完成**时通知。                                |
| **I/O 操作执行者** | **应用程序线程**（收到就绪通知后，自己调用 `read`/`write`）。       | **内核或框架**（应用程序只需发起，无需执行）。                           |
| **数据流**       | 应用程序 `read`: 内核 -\> 应用程序；`write`: 应用程序 -\> 内核。 | `read`: 内核直接读入用户缓冲区；`write`: 内核直接从用户缓冲区写出。          |
| **应用程序角色**    | **主动**地去执行 I/O 操作。                             | **被动**地等待 I/O 操作完成的通知。                              |
| **同步/异步**     | I/O 操作本身是**同步非阻塞**的，事件通知是异步的。                  | I/O 操作本身是**真正异步**的。                                 |
| **平台依赖**      | 依赖 `select`, `poll`, `epoll` 等就绪选择机制，跨平台性好。    | 强依赖操作系统对异步 I/O 的支持，如 Windows IOCP, Linux io\_uring。 |
| **优点**        | 模型相对简单，易于理解，跨平台支持良好。                           | 性能更高，并发能力更强，应用层逻辑更简单（只需关心结果）。                       |
| **缺点**        | 高并发下，应用层仍需处理 I/O，可能成为瓶颈。                       | 模型相对复杂，依赖平台特性，调试难度稍大。                               |

-----

### 5\. 现实世界中的实现范例

  * **Windows IOCP (I/O Completion Ports)**: 这是 Proactor 模式的经典和原生实现。在 Windows 平台上进行高性能服务器开发，IOCP 是不二之选。
  * **Boost.Asio (C++)**: 这是一个非常流行的 C++ 网络库。它非常聪明，在 Windows 上，它默认使用 IOCP（纯正的 Proactor）；在 Linux 上，它使用 `epoll` 来**模拟** Proactor 模式。也就是说，它对外提供统一的 Proactor 风格的异步接口（`async_read`, `async_write`），但在底层，它自己扮演了那个“执行 I/O”的角色，从而让用户感觉像在使用 Proactor。
  * **Linux io\_uring**: 这是 Linux 内核近年推出的一个革命性的异步 I/O 接口。它提供了真正的内核级异步 I/O，并且性能极高，是实现 Proactor 模式的理想选择，正在逐步取代传统的 AIO。
  * **Linux AIO (aio\*)**: Linux 早期提供的异步 I/O 接口（`aio_read`, `aio_write`），但存在诸多限制（如对文件 I/O 支持较好，对网络 Socket 支持不佳，有性能问题），因此在高性能网络领域用得不多。

-----

### 6\. 优点与缺点

#### 优点

1.  **更高的性能和并发性**：线程可以从繁重的 I/O 等待和操作中解放出来，去执行其他计算任务，大大提高了 CPU 的利用率。线程不用在 I/O 上阻塞，可以处理更多的并发连接。
2.  **简化的应用层逻辑**：应用程序的逻辑被清晰地分为两部分：发起 I/O（业务触发）和处理 I/O 结果（回调）。代码结构更清晰，避免了复杂的同步控制和状态管理。
3.  **更好的并行性**：读写操作由内核并行完成，可以充分利用多核 CPU 和硬件的能力。

#### 缺点

1.  **实现复杂**：要从零开始实现一个 Proactor 框架非常复杂，需要深入理解操作系统底层的异步机制。
2.  **平台依赖性强**：完美的 Proactor 模式依赖于操作系统提供高效的异步 I/O 支持。如果操作系统不支持，模拟实现的 Proactor 性能会打折扣。
3.  **调试困难**：基于回调的编程模型使得程序的执行流程被分割开来，不再是线性的。跟踪一个完整的业务流程可能会跨越多个回调函数，这给调试和定位问题带来了挑战（所谓的 "Callback Hell"）。
4.  **内存管理**：由于 I/O 操作是异步的，在发起操作和操作完成之间的这段时间，必须保证用作 I/O 的缓冲区（Buffer）是有效的，不能被释放或修改，这对内存管理提出了更高的要求。

-----

### 7\. 伪代码示例

这里用一个类似 Boost.Asio 风格的 C++ 伪代码来展示 Proactor 的使用感受。

```cpp
// 假设我们有一个 socket 对象和一个 proactor_service 对象
// proactor_service 负责与内核的完成队列交互

class MyServer {
public:
    void start_accept() {
        // 1. 创建一个新的 socket 用于接受连接
        TCPSocket new_socket = create_socket();

        // 2. 发起一个异步接受操作
        // - new_socket: 用于接受新连接
        // - [this, new_socket](error_code ec) { ... }: 这是 Completion Handler (一个 lambda 函数)
        acceptor.async_accept(new_socket, [this, new_socket](const std::error_code& ec) {
            // 这是在未来某个时间点，当一个新连接被接受后，Proactor 会调用的代码
            if (!ec) {
                // 5. 连接成功，开始在这个新 socket 上进行异步读取
                start_read(new_socket);
            }

            // 6. 无论这次成功与否，都立即发起下一次的 accept，实现持续监听
            start_accept();
        });

        // 3. async_accept() 立即返回，当前线程不会阻塞
    }

    void start_read(TCPSocket socket) {
        // 分配一个缓冲区
        auto buffer = std::make_shared<std::vector<char>>(1024);

        // 4. 发起异步读取操作
        socket.async_read_some(*buffer, [this, socket, buffer](const std::error_code& ec, size_t bytes_transferred) {
            // 这是在未来某个时间点，当数据被成功读取到 buffer 后，Proactor 会调用的代码
            if (!ec && bytes_transferred > 0) {
                // 处理数据...
                process_data(*buffer, bytes_transferred);

                // 继续在这个 socket 上读取下一批数据
                start_read(socket);
            } else {
                // 发生错误或对方关闭连接
                socket.close();
            }
        });
    }

    // ... 其他成员 ...
};

int main() {
    ProactorService proactor_service;
    MyServer server(proactor_service);
    
    // 启动服务器，开始监听
    server.start_accept();

    // Proactor 服务进入事件循环，等待完成事件
    proactor_service.run(); // 这个调用会阻塞，直到服务停止

    return 0;
}
```

在这个例子中，你完全看不到 `select` 或 `epoll_wait`，也看不到手动的 `read` 或 `write` 调用。你只需要定义好“要做什么”（`async_accept`, `async_read_some`）和“做完后怎么办”（lambda 回调函数），然后启动事件循环即可。

-----

### 8\. 总结

Proactor 模式是实现高性能、高并发服务器的终极武器之一。它通过将 I/O 操作的执行和完成检测都委托给操作系统，使得应用程序线程能够最大限度地摆脱 I/O 束缚，专注于业务逻辑的处理。

虽然它的实现细节复杂且依赖平台，但其清晰的编程模型和卓越的性能表现，使其成为 Windows IOCP 和 C++ Boost.Asio 等现代网络框架的基石。理解 Proactor 和 Reactor 的核心区别——**谁来执行 I/O**——是掌握现代网络编程的关键。




# Reactor模式
好的，我们来非常详细地讲解一下 **Reactor（反应器）模式**。您提到的 "Rracotor" 应该是 "Reactor" 的笔误，这是一个与 Proactor 模式相对应的、同样至关重要的网络编程设计模式。

为了让您彻底理解，我将同样从以下几个方面进行深入剖析：

1.  **核心思想：Reactor 是什么？**
2.  **关键角色/组件**
3.  **详细的执行流程**
4.  **Reactor vs. Proactor：最重要的对比**
5.  **现实世界中的实现范例**
6.  **优点与缺点**
7.  **代码伪代码示例**
8.  **总结**

-----

### 1\. 核心思想：Reactor 是什么？

Reactor 模式是一种**同步 I/O 事件处理模式**，其核心思想是**等待 I/O 事件的就绪，然后将就绪的事件分发给对应的处理器**。

我们再次使用餐厅点餐的比喻来理解它，并与 Proactor 对比：

  * **同步阻塞模式**：你走到前台点餐，然后**一直站在那儿等着**，直到汉堡做好。你被“阻塞”了。

  * **Reactor（反应器）模式**：你走到前台点餐，服务员给你一个“取餐器”（Pager）。你拿着取餐器回到座位玩手机。当取餐器震动并闪烁时，它告诉你：“你的汉堡**已经准备好了，可以来取了**”。这时，你**必须亲自**从座位上站起来，走到前台，从厨师手中接过汉堡。

      * **核心点**：Reactor 模式通知你的是\*\*“事件已就绪”（Readiness）**。它告诉你现在可以去执行某个操作（比如 `read` 或 `accept`）并且**不会被阻塞\*\*。但**执行这个 I/O 操作的动作，仍然需要由你自己（应用程序线程）来完成**。

  * **Proactor（前摄器）模式**（回顾）：你点完餐，告诉服务员座位号，然后就什么都不用管了。服务员会**帮你把汉堡做好并亲自送到你的座位上**。

      * **对比关键**：Proactor 是通知你\*\*“操作已完成”（Completion）\*\*，连 I/O 操作本身都帮你做完了。

**一句话总结 Reactor 核心思想**：应用程序将所有要监听的 I/O 事件（句柄）注册到一个中心分发器上，然后阻塞等待。当任何一个事件就绪时，分发器被唤醒，并将这个就绪事件派发给预先注册好的处理器，由处理器来执行实际的 I/O 操作。

-----

### 2\. 关键角色/组件

![[Pasted image 20251010091923.png]]

一个完整的 Reactor 模式通常包含以下几个关键角色：

1.  **Handles (句柄)**：

      * 在操作系统层面，这是指可以进行 I/O 操作的资源，最常见的就是**文件描述符 (File Descriptor)**，例如 Socket、文件、管道等。
      * 它是事件的来源。

2.  **Synchronous Event Demultiplexer (同步事件多路复用器)**：

      * 这是 Reactor 模式的**内核**。它是一个系统调用，可以同时监听多个 Handle。
      * 当没有任何 Handle 就绪时，调用它的线程会被**阻塞**。一旦有一个或多个 Handle 就绪，它就会返回。
      * 典型的例子就是 `select()`, `poll()`, `epoll_wait()` (Linux) 以及 `kqueue()` (BSD/macOS)。

3.  **Reactor (反应器/分发器)**：

      * 模式的中心管理者。它内部封装了 Synchronous Event Demultiplexer。
      * 它提供接口让应用程序可以注册、删除感兴趣的 Handle 和对应的 Event Handler。
      * 它负责运行事件循环（Event Loop），调用 Demultiplexer 等待事件。
      * 当事件发生时，它负责“分发”（dispatch），即调用与事件关联的那个 Event Handler 的方法。

4.  **Event Handler (事件处理器)**：

      * 这是一个接口或抽象基类，定义了处理特定事件的方法，例如 `handle_read()`, `handle_write()`, `handle_error()` 等。

5.  **Concrete Event Handler (具体事件处理器)**：

      * 这是应用程序为每个 Handle 编写的、实现了 Event Handler 接口的类。
      * 它封装了**实际的业务逻辑**。例如，一个用于监听的 Socket，其 Concrete Event Handler 的 `handle_read()` 方法里会调用 `accept()` 来接受新连接；一个已连接的 Socket，其 `handle_read()` 方法里会调用 `read()` 或 `recv()` 来读取数据。

-----

### 3\. 详细的执行流程

我们以一个网络服务器为例，看看 Reactor 模式的完整工作流程：

1.  **初始化与注册 (Initialization & Registration)**

      * 服务器应用程序创建一个 `Reactor` 对象。
      * 服务器创建一个监听 Socket (Listen Socket)，并为它创建一个 `AcceptorHandler` (一个 Concrete Event Handler)。
      * 服务器将监听 Socket 的 Handle 和 `AcceptorHandler` **注册**到 `Reactor` 中，表示“我对这个 Handle 上的 `READ` 事件（即有新连接到来）感兴趣”。

2.  **事件循环 (Event Loop)**

      * 应用程序启动 `Reactor` 的事件循环（通常是调用一个 `reactor.handle_events()` 之类的方法）。
      * `Reactor` 调用 `Synchronous Event Demultiplexer` (例如 `epoll_wait()`)，并在此**阻塞**，等待事件发生。

3.  **事件就绪与分发 (Event Ready & Dispatch)**

      * 当一个客户端发起连接请求时，监听 Socket 变为“可读”状态，`epoll_wait()` 立即返回，并告知 `Reactor` 哪个 Handle 就绪了。
      * `Reactor` 收到通知，查找注册表，发现这个就绪的 Handle 对应的是 `AcceptorHandler`。
      * `Reactor` 立即**分发**事件，调用 `AcceptorHandler` 的 `handle_read()` 方法。

4.  **处理器执行 I/O (Handler Performs I/O)**

      * 在 `AcceptorHandler` 的 `handle_read()` 方法内部，应用程序代码被执行。它**亲自调用 `accept()`** 来接受这个新连接，并得到一个新的连接 Socket (Connected Socket)。
      * 为了处理这个新连接上的数据，应用程序会为这个新的连接 Socket 再创建一个 `DataHandler`，并将其注册到 `Reactor` 中，表示“我对这个新 Socket 上的 `READ` 事件（有数据可读）感兴趣”。

5.  **循环往复**

      * `Reactor` 的事件循环继续。现在它同时监听着“监听 Socket”和新建立的“连接 Socket”。
      * 当客户端发送数据时，“连接 Socket”变为可读，`epoll_wait()` 返回。
      * `Reactor` 将事件分发给对应的 `DataHandler`，`DataHandler` 的 `handle_read()` 方法被调用，它在内部**亲自调用 `read()` 或 `recv()`** 来读取数据并处理。

-----

### 4\. Reactor vs. Proactor：最重要的对比

这个对比至关重要，能帮你彻底分清两者。

| 特性            | Reactor (反应器)                                                        | Proactor (前摄器)                                                 |
| :------------ | :------------------------------------------------------------------- | :------------------------------------------------------------- |
| **核心关注点**     | **I/O 就绪 (Readiness)**                                               | **I/O 完成 (Completion)**                                        |
| **通知时机**      | 当 Handle (文件描述符) **可以**进行非阻塞 I/O 操作时通知。                              | 当 I/O 操作已经**完成**时通知。                                           |
| **I/O 操作执行者** | **应用程序线程**（收到就绪通知后，自己调用 `read`/`write`）。                             | **内核或框架**（应用程序只需发起，无需执行）。                                      |
| **同步/异步**     | I/O 操作本身是**同步非阻塞**的，事件通知是异步的。                                        | I/O 操作本身是**真正异步**的。                                            |
| **数据流**       | 应用程序 `read`: 内核 -\> 应用程序；`write`: 应用程序 -\> 内核。**数据拷贝在 Handler 中发生**。 | `read`: 内核直接读入用户缓冲区；`write`: 内核直接从用户缓冲区写出。**数据拷贝在发起操作前就已安排好**。 |
| **平台依赖**      | 依赖 `select`, `poll`, `epoll` 等就绪选择机制，**跨平台性好**。                      | 强依赖操作系统对异步 I/O 的支持，如 Windows IOCP, Linux io\_uring。            |

-----

### 5\. 现实世界中的实现范例

Reactor 模式是当今绝大多数高性能网络框架的基石：

  * **Linux `epoll`**：`epoll` 本身就是 `Synchronous Event Demultiplexer` 的高效实现，是构建 Reactor 模式的核心。
  * **Java NIO**：Java 的 `java.nio` 包中的 `Selector` 和 `Channel` 机制，是 Reactor 模式的经典教科书式实现。
  * **Netty / Vert.x**：这两个流行的 Java 网络框架都是基于 Reactor 模式构建的。
  * **Node.js (libuv)**：Node.js 的单线程异步事件模型，其底层的 `libuv` 库就是 Reactor 模式的一个高效实现。
  * **Redis**：Redis 能够用单线程处理极高的并发请求，其核心就是基于 Reactor 模式的事件循环。
  * **Nginx**：Nginx 的 Worker 进程同样使用 `epoll` 实现了 Reactor 模式来高效地处理海量并发连接。

-----

### 6\. 优点与缺点

#### 优点

1.  **解耦与模块化**：将事件分发逻辑（Reactor）与业务处理逻辑（Handler）完全分离，使得代码结构清晰，易于扩展和维护。
2.  **高并发处理能力**：允许单线程或少量线程管理大量的并发连接，避免了为每个连接创建一个线程的巨大开销。
3.  **可移植性好**：基于 `select`, `poll`, `epoll` 等机制，这些在绝大多数操作系统上都有良好支持。
4.  **模型相对直观**：相比 Proactor，其“就绪-执行”的流程更符合传统的编程思维。

#### 缺点

1.  **处理逻辑相对复杂**：应用程序需要自己处理 I/O 操作（`read`/`write`），包括处理“读不完”或“写不完”（即 `EAGAIN` / `EWOULDBLOCK`）等情况。
2.  **性能瓶颈**：在高负载下，当所有事件都就绪时，应用程序线程需要逐个执行 I/O 操作，这个过程本身可能会成为性能瓶颈，而 Proactor 模式则将这部分工作交给了内核。

-----

### 7\. 伪代码示例

这里用一个简化的 C++ 风格伪代码来展示 Reactor 的工作方式。

```cpp
// 事件处理器接口
class EventHandler {
public:
    virtual void handle_event() = 0;
    virtual Handle get_handle() const = 0;
};

// Reactor 核心类
class Reactor {
public:
    void register_handler(EventHandler* handler) {
        handlers[handler->get_handle()] = handler;
        demultiplexer.add(handler->get_handle());
    }

    void remove_handler(EventHandler* handler) {
        // ... remove from handlers and demultiplexer ...
    }

    // 事件循环
    void event_loop() {
        while (true) {
            // 1. 等待事件就绪，此
            auto ready_handles = demultiplexer.wait();

            // 2. 遍历所有就绪的事件
            for (Handle handle : ready_handles) {
                // 3. 查找对应的处理器并进行分发
                handlers[handle]->handle_event();
            }
        }
    }
private:
    std::map<Handle, EventHandler*> handlers;
    SynchronousEventDemultiplexer demultiplexer; // e.g., an epoll wrapper
};

// 具体的 Acceptor 处理器
class AcceptorHandler : public EventHandler {
public:
    AcceptorHandler(Handle listening_handle, Reactor* reactor) 
        : handle(listening_handle), owner_reactor(reactor) {}

    void handle_event() override {
        // 4. 事件就绪，应用程序亲自执行 I/O 操作
        Handle new_conn_handle = accept(handle, ...);
        if (new_conn_handle > 0) {
            // 为新连接创建一个新的处理器并注册到 Reactor
            EventHandler* data_handler = new DataHandler(new_conn_handle);
            owner_reactor->register_handler(data_handler);
        }
    }
    
    Handle get_handle() const override { return handle; }
private:
    Handle handle;
    Reactor* owner_reactor;
};

int main() {
    Reactor reactor;
    Handle listener = create_listening_socket(8080);
    
    // 创建处理器并注册到 Reactor
    reactor.register_handler(new AcceptorHandler(listener, &reactor));

    // 启动事件循环
    reactor.event_loop();
    
    return 0;
}
```

在这个例子中，`reactor.event_loop()` 负责等待，而具体的 `accept()` 调用则发生在 `AcceptorHandler::handle_event()` 内部，清晰地体现了 Reactor 模式的职责划分。

-----

### 8\. 总结

Reactor 模式是服务器端编程的基石，它通过一个中央的事件分发器和事件回调机制，实现了“一个线程（或少量线程）处理海量并发连接”的壮举。它关注的是“I/O 事件的就绪通知”。

与 Proactor 模式（关注“I/O 操作的完成通知”）相比，Reactor 模式将实际的 I/O 操作留给了应用程序自己，这使得它在实现上更具通用性和跨平台性。虽然在极限性能下可能不及纯粹的 Proactor，但其成熟、稳定和广泛的应用，使其成为构建高性能服务的首选模式之一。