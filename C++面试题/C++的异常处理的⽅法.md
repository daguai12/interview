### 1\. 核心机制：`try`、`throw`、`catch`

这是C++异常处理的基石，它将**正常逻辑**与**错误处理逻辑**清晰地分离开来。

  * **`try` 块**：包裹可能会抛出异常的“受保护”代码。
  * **`throw` 表达式**：当错误发生时，使用 `throw` 来“抛出”一个异常。被抛出的可以**是任何类型**的对象（int, double, 自定义类等），但**最佳实践是抛出 `std::exception` 的派生类对象**。
  * **`catch` 块**：用于“捕获”并处理异常。程序会按照 `catch` 块的顺序，寻找第一个与抛出的异常**类型匹配**的处理程序。

**执行流程**：

1.  程序进入 `try` 块执行。
2.  如果没有 `throw` 发生，所有 `catch` 块都会被跳过。
3.  如果 `throw` 被执行，`try` 块中位于 `throw` 之后的代码将被**立即跳过**。
4.  程序开始**栈回溯（Stack Unwinding）**：从当前函数层层返回，并销毁所有已创建的局部对象（这是 **RAII** 资源管理的关键），直到找到一个能够匹配异常类型的 `catch` 块。
5.  第一个匹配的 `catch` 块被执行。执行完毕后，程序会继续执行最后一个 `catch` 块之后的代码。

**您的示例分析**：

```cpp
// ...
if (n == 0) throw -1; // 抛出了一个 int 类型的异常
// ...
catch (double d) { /* ... */ } // 类型不匹配，跳过
catch (...) { /* ... */ }      // “捕获所有”的 catch 块，类型匹配
// ...
```

您的示例中，`throw -1;` 抛出的是 `int` 类型，而第一个 `catch` 块期望的是 `double`，因此无法匹配。程序继续寻找，最终匹配了 `catch(...)`，所以执行结果是完全正确的。

**最佳实践**：

  * **按值抛出，按常量引用捕获**：`throw std::runtime_error("Error!");` 和 `catch (const std::exception& e)`。这可以避免不必要的对象拷贝和对象切割（slicing）问题。
  * **派生类在前，基类在后**：捕获异常时，如果异常类有继承关系，应先捕获派生类异常，再捕获基类异常。
  * `catch(...)` 应作为最后的安全网，用于捕获所有未预料到的异常，防止程序崩溃。

-----

### 2\. 函数异常声明：从 `throw()` 到 `noexcept` (重要更新)

您笔记中提到的 `throw(int, double)` 语法，被称为**动态异常规范（Dynamic Exception Specification）**。

**重要**：这个特性在 **C++11 中已被弃用（deprecated）**，并在 **C++17 中被完全移除**。它因为存在一些性能和实现上的问题，已经被现代C++所淘汰。

现代C++使用 **`noexcept`** 关键字来进行异常声明，它是一种**静态异常规范**。

  * **`noexcept`**：向编译器做出一个**承诺**，表示该函数**绝对不会**抛出任何异常。
    ```cpp
    void my_function() noexcept;
    ```
  * **`noexcept(false)` 或不写**：表示该函数**可能**会抛出异常（这是默认情况）。
    ```cpp
    void my_function(); // 可能会抛出异常
    void my_function() noexcept(false); // 与上面等价
    ```

**为什么 `noexcept` 很重要？**
`noexcept` 是一个重要的优化提示。如果编译器知道一个函数不会抛出异常，它就可以生成更简单、更高效的代码，因为它无需为该函数调用生成处理栈回溯的额外代码。此外，标准库中的一些操作（如 `std::vector` 的移动构造）会根据函数是否为 `noexcept` 来决定是采取移动还是拷贝操作，直接影响程序性能。

-----

### 3\. C++ 标准异常类

C++标准库在 `<stdexcept>` 和其他头文件中提供了一套标准的异常类层次结构，它们都派生自基类 `std::exception`。使用这些标准类可以让代码更具通用性和可读性。

`std::exception` 提供了一个重要的虚函数 `what()`，它返回一个 `const char*`，用于描述异常信息。

#### 主要的标准异常类别：

  * **`std::logic_error`**：逻辑错误。通常指可以在程序运行前通过代码检查发现的错误。

      * `std::invalid_argument`：无效参数。
      * `std::length_error`：长度错误（例如，创建一个过大的 `std::vector`）。
      * `std::out_of_range`：下标越界（例如，使用 `vector::at()` 或 `string::at()`）。

  * **`std.runtime_error`**：运行时错误。通常指那些难以预见、由外部因素导致的错误。

      * `std::overflow_error`：算术上溢。
      * `std::underflow_error`：算术下溢。

  * **其他重要异常**：

      * **`std::bad_alloc`**：由 `new` 内存分配失败时抛出。
      * **`std::bad_cast`**：由 `dynamic_cast` 对引用进行不安全的类型转换时抛出。
      * **`std::bad_typeid`**：由 `typeid` 对空指针解引用时抛出。

#### 代码示例（现代风格）

```cpp
#include <iostream>
#include <vector>
#include <stdexcept> // 包含标准异常类

// 使用 noexcept 声明此函数不会抛出异常
void safe_operation() noexcept {
    // ...
}

void process_vector(const std::vector<int>& vec, int index) {
    try {
        if (index < 0) {
            // 抛出具体的、有意义的异常类型
            throw std::invalid_argument("Index cannot be negative.");
        }
        // at() 会在越界时自动抛出 std::out_of_range
        int value = vec.at(index); 
        std::cout << "Value at index " << index << " is " << value << std::endl;
    }
    // 按常量引用捕获，先捕获派生类，再捕获基类
    catch (const std::invalid_argument& e) {
        std::cerr << "Logic Error: " << e.what() << std::endl;
    }
    catch (const std::out_of_range& e) {
        std::cerr << "Runtime Error: " << e.what() << std::endl;
    }
    catch (const std::exception& e) { // 捕获其他所有标准异常
        std::cerr << "An unexpected standard exception occurred: " << e.what() << std::endl;
    }
}

int main() {
    std::vector<int> my_vec = {10, 20, 30};
    process_vector(my_vec, 1);    // 正常执行
    process_vector(my_vec, -1);   // 捕获 std::invalid_argument
    process_vector(my_vec, 5);    // 捕获 std::out_of_range
    return 0;
}
```