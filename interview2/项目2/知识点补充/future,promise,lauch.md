好的，我们来详细讲解一下 C++ 中的 `std::promise` 和 `std::future`。它们是 C++11 引入的工具，用于在不同线程之间轻松地传递一次性数据，是现代 C++ 并发编程中非常重要的组成部分。

### 核心概念：一次性的异步通信通道

想象一下，你在一个线程（我们称之为“生产者”）里需要计算一个结果，而另一个线程（“消费者”）需要这个结果才能继续执行。`std::promise` 和 `std::future` 就是为此设计的，它们共同创建了一个一次性的通信通道。

  * **`std::promise` (承诺)**：代表**生产者**。它“承诺”会在未来的某个时刻提供一个值。你可以把它看作是一个写入端。
  * **`std::future` (未来)**：代表**消费者**。它持有一个“未来”才会知道的值。你可以把它看作是一个读取端，用来等待并获取 `std::promise` 设置的值。

一个 `std::promise` 只能和一个 `std::future` 配对。一旦 `promise` 设置了值，这个通信就完成了。

### `std::promise` 和 `std::future` 的基本用法

下面我们通过一个简单的例子来了解它们的基本流程。

**流程概览:**

1.  **创建 `std::promise` 对象**：在生产者线程中，或者在启动生产者线程之前。
2.  **从 `promise` 获取 `std::future` 对象**：这个 `future` 对象将被传递给消费者线程。`get_future()` 成员函数只能被调用一次。
3.  **生产者设置值**：生产者线程完成计算后，通过 `promise.set_value()` 方法将结果存入共享状态中。
4.  **消费者获取值**：消费者线程在需要结果的地方调用 `future.get()`。
      * 如果此时生产者已经通过 `promise` 设置了值，`get()` 会立即返回该值。
      * 如果值还未被设置，`get()` 会**阻塞**当前线程，直到 `promise` 设置了值为止。
      * `get()` 只能被调用一次。

#### 示例代码 1：基本数据传递

```cpp
#include <iostream>
#include <thread>
#include <future>
#include <chrono>

// 一个模拟耗时计算的函数
void perform_calculation(std::promise<int> p) {
    std::cout << "计算线程开始工作..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(2)); // 模拟耗时计算
    int result = 42;
    std::cout << "计算完成，设置结果。" << std::endl;
    p.set_value(result); // 将结果放入 promise
}

int main() {
    // 1. 创建一个 promise 对象，它承诺会提供一个 int 类型的值
    std::promise<int> my_promise;

    // 2. 从 promise 获取 future 对象
    std::future<int> my_future = my_promise.get_future();

    // 3. 启动一个新线程，并将 promise 的所有权转移给它
    // 注意：std::promise 不能被拷贝，只能被移动 (move)
    std::thread calculation_thread(perform_calculation, std::move(my_promise));

    std::cout << "主线程等待结果..." << std::endl;

    // 4. 在主线程中，通过 future 等待并获取结果
    // get() 会阻塞，直到 promise 的 set_value() 被调用
    int result = my_future.get();

    std::cout << "主线程获取到结果: " << result << std::endl;

    // 等待子线程结束
    calculation_thread.join();

    return 0;
}
```

**代码讲解:**

  * `std::promise<int> my_promise;` 创建了一个 `promise`，它承诺未来会有一个 `int` 类型的值。
  * `my_future = my_promise.get_future();` 将 `promise` 和 `future` 关联起来。
  * `std::thread(perform_calculation, std::move(my_promise));` 启动新线程，并将 `my_promise` **移动**到线程函数中。因为 `promise` 代表了对共享状态的唯一写入权，所以它不能被复制。
  * `my_future.get();` 阻塞了 `main` 函数的执行，直到 `perform_calculation` 函数调用 `p.set_value(42);`。
  * `calculation_thread.join();` 确保在 `main` 函数退出前，子线程已经执行完毕。

### 异常处理

如果生产者线程在计算过程中发生了异常怎么办？`std::promise` 也可以传递异常。

**流程:**

1.  在生产者线程中，使用 `try...catch` 块捕获异常。
2.  在 `catch` 块中，调用 `promise.set_exception()` 并传入捕获到的异常。
3.  消费者线程在调用 `future.get()` 时，如果 `promise` 设置的是异常，`get()` 会重新抛出该异常。

#### 示例代码 2：传递异常

```cpp
#include <iostream>
#include <thread>
#include <future>
#include <stdexcept>

void may_throw_exception(std::promise<std::string> p) {
    try {
        // 模拟一个可能失败的操作
        bool operation_failed = true;
        if (operation_failed) {
            throw std::runtime_error("计算失败！");
        }
        p.set_value("计算成功");
    } catch (...) {
        // 捕获任何异常，并通过 promise 传递出去
        p.set_exception(std::current_exception());
    }
}

int main() {
    std::promise<std::string> my_promise;
    std::future<std::string> my_future = my_promise.get_future();

    std::thread t(may_throw_exception, std::move(my_promise));

    std::cout << "主线程等待结果..." << std::endl;

    try {
        // 当调用 get() 时，如果 promise 设置了异常，这里会抛出
        std::string result = my_future.get();
        std::cout << "结果: " << result << std::endl;
    } catch (const std::exception& e) {
        std::cout << "主线程捕获到异常: " << e.what() << std::endl;
    }

    t.join();

    return 0;
}
```

**代码讲解:**

  * 在 `may_throw_exception` 中，我们捕获了抛出的 `std::runtime_error`。
  * `p.set_exception(std::current_exception());` 将当前捕获的异常存储在与 `promise` 关联的共享状态中。`std::current_exception()` 会获取一个指向当前异常的智能指针 `std::exception_ptr`。
  * 在 `main` 函数中，`my_future.get()` 的调用被放在 `try...catch` 块里。当 `get()` 执行时，它检查到共享状态中存储的是一个异常，于是就在当前线程（主线程）中重新抛出了这个异常，然后被 `catch` 块捕获。

### `void` 类型的特殊情况

有时候，我们不关心返回的具体值，只关心某个任务是否已经完成。这时，可以使用 `std::promise<void>`。

```cpp
#include <iostream>
#include <thread>
#include <future>
#include <chrono>

void task_notifier(std::promise<void> p) {
    std::cout << "任务线程正在执行..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));
    std::cout << "任务完成！" << std::endl;
    p.set_value(); // 通知 future，任务已完成
}

int main() {
    std::promise<void> my_promise;
    std::future<void> my_future = my_promise.get_future();

    std::thread t(task_notifier, std::move(my_promise));

    std::cout << "主线程等待任务完成..." << std::endl;
    my_future.get(); // 阻塞，直到 promise::set_value() 被调用
    std::cout << "主线程确认任务已完成，继续执行。" << std::endl;

    t.join();

    return 0;
}
```

对于 `std::promise<void>`，`set_value()` 不需要参数，而 `future.get()` 的返回类型也是 `void`。它纯粹起到了一个线程同步的信令作用。

### 与 `std::async` 的比较

你可能会发现，`std::async` 也能实现类似的功能，并且代码更简洁。

```cpp
#include <iostream>
#include <future>

int calculate_something() {
    return 42;
}

int main() {
    // std::async 自动处理线程创建、promise 和 future 的设置
    std::future<int> result_future = std::async(std::launch::async, calculate_something);
    
    // ... 做其他事情 ...
    
    int result = result_future.get();
    std::cout << "结果是: " << result << std::endl;
    
    return 0;
}
```

**那么为什么还需要 `std::promise` 和 `std::future`？**

  * **更灵活的控制**：`std::async` 将任务的执行和结果的传递紧密绑定。而使用 `promise/future`，你可以在任何你需要的时候，在任何逻辑分支里去设置值或异常。例如，一个任务的结果可能依赖于多个外部事件，你可以等到所有事件都完成后再 `set_value`。
  * **非线程环境**：`promise` 和 `future` 的通信机制不一定非要和 `std::thread` 绑定。你可以在任何能够传递 `promise` 或 `future` 对象的地方使用它们，比如在回调函数、事件驱动模型等场景中。
  * **解耦**：`promise` 的创建者和 `future` 的使用者可以完全不知道对方的存在。它们只通过这两个对象进行通信，这有助于降低代码的耦合度。

### 总结

| 特性 | `std::promise` | `std::future` |
| :--- | :--- | :--- |
| **角色** | 数据的**生产者**（写入端） | 数据的**消费者**（读取端） |
| **所有权** | 独占写入权，不可拷贝，只能移动 | 通常是独占读取权，但可移动 |
| **核心操作** | `set_value()`: 设置正常结果\<br\>`set_exception()`: 设置异常结果 | `get()`: 阻塞等待并获取结果/异常\<br\>`wait()`: 只阻塞等待，不获取结果\<br\>`wait_for()`: 带超时的等待 |
| **生命周期** | 在设置值或异常后，其使命通常就完成了 | 在调用 `get()` 获取值后，其状态变为无效 |

`std::promise` 和 `std::future` 是 C++ 并发编程中实现线程间一次性数据同步和通信的强大工具。通过将值的“承诺”与“未来”的获取分离，它们提供了一种类型安全、清晰且灵活的异步编程模型。