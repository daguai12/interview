好的，我们来非常非常详细地讲解 C++11 引入并成为现代 C++ 重要组成部分的 `noexcept` 关键字。

-----

### **目录**

1.  **`noexcept` 是什么？—— 核心承诺**
2.  **为什么要引入 `noexcept`？—— `throw()` 的失败与性能的追求**
      * 回顾被废弃的 `throw()`
      * `noexcept` 带来的编译期优化
3.  **`noexcept` 的两种形式：说明符与操作符**
      * `noexcept` 说明符 (Specifier)
      * 违反 `noexcept` 承诺的后果：`std::terminate`
      * `noexcept` 操作符 (Operator)
4.  **王牌应用：条件 `noexcept` 与移动语义**
      * `noexcept` 如何影响 `std::vector` 等容器的行为
      * 一个实际的例子：编写 `noexcept` 安全的移动构造函数
5.  **`noexcept` 与其他语言特性的交互**
      * 析构函数
      * `constexpr` 函数
6.  **最佳实践：什么时候该用，什么时候不该用？**
7.  **总结**

-----

### **1. `noexcept` 是什么？—— 核心承诺**

`noexcept` 是一个 C++ 关键字，用于**向编译器和调用者做出一个承诺：这个函数保证不会抛出任何异常**。

它是一个函数接口的一部分，就像 `const` 一样，用于传达函数的重要信息。

```cpp
// 这个函数可能会抛出异常
int might_throw();

// 这个函数承诺绝不会抛出异常
int will_not_throw() noexcept;

// 在函数定义中
void MyClass::do_something() noexcept {
    // ... 实现代码 ...
}
```

这个承诺非常严肃。如果一个被声明为 `noexcept` 的函数最终还是抛出了异常，程序不会像常规那样去寻找 `catch` 块，而是会**立即调用 `std::terminate()` 终止整个程序**。

### **2. 为什么要引入 `noexcept`？—— `throw()` 的失败与性能的追求**

要理解 `noexcept` 的价值，必须先了解它的前辈——动态异常说明 `throw()`。

#### **回顾被废弃的 `throw()`**

在 C++11 之前，有一个类似的语法 `throw()` 用于表明函数不抛异常。

```cpp
void old_func() throw(); // C++03 风格：表示不抛出任何异常
void old_func_specific() throw(std::bad_alloc); // 表示只可能抛出 bad_alloc
```

`throw()` 有几个致命的缺点：

1.  **运行时检查**：它是在**运行时**检查异常类型的。如果函数抛出了一个不在 `throw(...)` 列表里的异常，程序会调用 `std::unexpected()`，这套机制复杂且性能不佳。
2.  **性能惩罚**：因为是运行时检查，编译器必须生成额外的代码来包裹函数调用，以便在异常抛出时进行匹配。这意味着，即使函数从未抛出异常，也可能为这个“保证”付出性能代价。
3.  **对模板不友好**：在泛型编程中，很难确定一个模板函数会抛出哪些具体类型的异常。

由于这些原因，`throw()` 被认为是一个失败的设计，在 C++11 中被废弃，并在 C++17 中被正式移除（`throw()` 仍被保留作为 `noexcept(true)` 的别名，但应避免使用）。

#### **`noexcept` 带来的编译期优化**

`noexcept` 的设计目标完全不同。它主要是一个**给编译器的优化提示**。

当编译器知道一个函数是 `noexcept` 时，它可以生成更小、更快的代码，因为它**不需要考虑异常处理的路径**。

主要的优化点在于**栈展开 (Stack Unwinding)**：

  * **普通函数**：当函数 `A` 调用函数 `B`，`B` 又调用 `C` 时，如果 `C` 抛出异常，程序需要“展开”调用栈，依次销毁 `C` 和 `B` 中已构造的局部对象，然后回到 `A` 寻找 `catch` 块。编译器必须为此生成大量额外的代码来跟踪对象的生命周期。
  * **`noexcept` 函数**：如果 `B` 是 `noexcept` 的，编译器在调用 `B` 时就知道，它不需要为 `B` 准备那套复杂的栈展开代码。因为 `B` 承诺了不会有异常逃逸出来，也就无需为异常路径做任何准备。这可以显著减少代码体积并提升性能，尤其是在调用链很长或循环中频繁调用的情况下。

### **3. `noexcept` 的两种形式：说明符与操作符**

`noexcept` 有两种身份，理解它们的区别至关重要。

#### **`noexcept` 说明符 (Specifier)**

这是我们最常见的用法，写在函数声明的末尾，用于**标记**一个函数。它本身可以带一个布尔常量表达式作为参数。

  * `noexcept` 等价于 `noexcept(true)`：承诺函数不抛异常。
  * `noexcept(false)`：明确指出函数**可能**会抛出异常。这看起来有点多余，但它在泛型编程中至关重要。

<!-- end list -->

```cpp
void f1() noexcept;        // 不抛异常
void f2() noexcept(true);  // 和 f1 完全一样
void f3() noexcept(false); // 可能会抛异常
```

#### **违反 `noexcept` 承诺的后果：`std::terminate`**

让我们通过一个例子看看违反承诺会发生什么。

```cpp
#include <iostream>
#include <stdexcept>

void thrower() {
    throw std::runtime_error("I am an exception!");
}

// a_liar 承诺不抛异常，但它调用的函数却抛了
void a_liar() noexcept {
    std::cout << "a_liar() is called. About to call thrower()." << std::endl;
    thrower();
    std::cout << "This line will never be reached." << std::endl;
}

int main() {
    try {
        a_liar();
    }
    catch (const std::exception& e) {
        // 这个 catch 块永远不会被执行！
        std::cout << "Caught exception: " << e.what() << std::endl;
    }
    return 0;
}
```

**编译并运行这段代码，你不会看到 "Caught exception..." 的输出。** 相反，程序会打印 "a\_liar() is called..."，然后立即异常终止。典型的输出可能是：

```
a_liar() is called. About to call thrower().
terminate called after throwing an instance of 'std::runtime_error'
  what():  I am an exception!
Aborted (core dumped)
```

这是因为当 `thrower()` 抛出的异常试图逃离 `a_liar()` 的作用域时，运行时系统检测到 `a_liar` 是 `noexcept` 的，于是立刻调用 `std::terminate()`。

#### **`noexcept` 操作符 (Operator)**

`noexcept` 也可以用作一个**编译时操作符**，它接受一个表达式，返回一个 `bool` 类型的 `constexpr` 值。

  * `noexcept(expression)`：**它并不会执行 `expression`**，而是在编译时判断 `expression` 是否**可能**抛出异常。如果表达式保证不抛异常，它返回 `true`；否则返回 `false`。

<!-- end list -->

```cpp
int i = 0;
void f() noexcept;
void g();

// noexcept 作为操作符的例子
static_assert(noexcept(i + 1), "i+1 should not throw");              // true
static_assert(noexcept(f()), "f() is declared noexcept");             // true
static_assert(!noexcept(g()), "g() is not declared noexcept");       // !false is true
static_assert(!noexcept(throw 1), "throw expression always throws"); // !false is true
```

### **4. 王牌应用：条件 `noexcept` 与移动语义**

将 `noexcept` 说明符和操作符结合起来，就构成了它最强大的用途：**条件 `noexcept`**。

语法：`void my_func() noexcept(noexcept(expression));`
含义：`my_func` 的 `noexcept` 状态（`true` 或 `false`）由 `expression` 的 `noexcept` 状态在编译时决定。

这在**移动构造函数**和**移动赋值运算符**中是**至关重要的**。

#### **`noexcept` 如何影响 `std::vector` 等容器的行为**

标准库容器（如 `std::vector`）在进行某些操作（如扩容 `push_back`）时，需要将元素从旧内存移动到新内存。为了保证**强异常安全**（即如果操作中发生异常，容器能恢复到操作开始前的状态），`vector` 会检查其元素的移动构造函数是否是 `noexcept` 的。

  * **如果移动构造函数是 `noexcept(true)`**：`vector` 会放心地使用**移动**操作。因为移动保证不会失败，所以整个扩容过程要么成功，要么不发生，满足强异常安全。这是最高效的方式。
  * **如果移动构造函数是 `noexcept(false)`**（或未标记）：`vector` 不敢冒险。因为它无法保证移动一半元素后不发生异常（这会导致容器数据一半在新位置，一半在旧位置，处于损毁状态）。为了安全，`vector` 会放弃移动，转而使用**拷贝**操作。拷贝是安全的，因为即使拷贝中途失败，旧数据仍然完好无损。

**结论：一个不标记为 `noexcept` 的移动构造函数，可能会导致 `std::vector` 在扩容时放弃高效的移动，退化为低效的拷贝！**

#### **一个实际的例子：编写 `noexcept` 安全的移动构造函数**

```cpp
#include <vector>
#include <string>
#include <utility>

class MyData {
    std::string name;
    std::vector<int> data;
public:
    MyData(std::string s, std::vector<int> v) : name(std::move(s)), data(std::move(v)) {}

    // 移动构造函数
    // 我们的移动构造是否 noexcept，取决于其成员的移动构造是否 noexcept
    MyData(MyData&& other) noexcept(
        noexcept(std::string(std::move(other.name))) &&
        noexcept(std::vector<int>(std::move(other.data)))
    ) : name(std::move(other.name)), data(std::move(other.data)) 
    {
        // ...
    }
    
    // C++17 中可以使用类型萃余来简化
    // noexcept(std::is_nothrow_move_constructible_v<std::string> && 
    //          std::is_nothrow_move_constructible_v<std::vector<int>>)
};
```

这样，`MyData` 的移动构造函数的 `noexcept` 状态就和其成员的 `noexcept` 状态绑定了。由于 `std::string` 和 `std::vector` 的移动构造函数都是 `noexcept` 的，所以我们的 `MyData` 的移动构造函数也会被推导为 `noexcept(true)`，从而让标准库容器可以对其进行性能优化。

### **5. `noexcept` 与其他语言特性的交互**

#### **析构函数**

在 C++11 及以后，**析构函数默认是 `noexcept` 的**。这是因为在栈展开过程中，如果一个析构函数自己又抛出异常，会导致程序进入无法处理的混乱状态，所以标准规定此时应直接 `std::terminate()`。你应该极力避免让析构函数抛出异常。

#### **`constexpr` 函数**

`constexpr` 函数在其实现中不能包含可能抛出异常的操作，因此它们天然就是 `noexcept` 的。

### **6. 最佳实践：什么时候该用，什么时候不该用？**

**应该使用 `noexcept` 的情况：**

1.  **移动构造函数和移动赋值运算符**：除非它们真的会抛异常，否则都应该标记为 `noexcept`（最好是条件 `noexcept`）。
2.  **析构函数**：默认就是，无需手动添加，但要保证其实现不会抛异常。
3.  **交换函数 (`swap`)**：交换操作应该是 `noexcept` 的，这是许多算法正确工作的基础。
4.  **简单的 "Getter" 函数**：只返回一个成员变量的函数。
5.  **不会失败的底层操作**：例如，进行纯粹的数学计算、修改内置类型成员的函数。

**不应该（或谨慎）使用 `noexcept` 的情况：**

1.  **任何可能分配内存的函数**：因为 `new` 可能抛出 `std::bad_alloc`。
2.  **调用了不确定是否会抛异常的第三方库或老旧代码的函数**。
3.  **大部分“普通”函数**：不要盲目地给所有函数都加上 `noexcept`。它是一个严肃的承诺，滥用会导致程序在遇到可恢复的错误时直接崩溃。
4.  **接受回调函数并执行它的函数**：你无法保证传入的回调函数是 `noexcept` 的。

**黄金法则：只有在你 100% 确定一个函数在任何情况下都不会让异常逃逸出其作用域时，才将其标记为 `noexcept`。**

### **7. 总结**

`noexcept` 是 C++11 对异常规范的现代化改造，它从 `throw()` 的运行时检查机制，转变为一个强大的编译时优化工具。

  * 它是一个**承诺**，承诺函数不抛异常，违反承诺将导致程序**终止**。
  * 它的主要目的是**性能优化**，通过消除不必要的栈展开代码，让编译器生成更高效的机器码。
  * 它与**移动语义**紧密相连，正确使用 `noexcept` 是保证 `std::vector` 等容器能高效移动其元素，而不是退化为拷贝的关键。
  * 它同时是**说明符**和**操作符**，两者的结合实现了强大的**条件 `noexcept`**，是泛型编程和现代 C++ 库实现的重要基石。