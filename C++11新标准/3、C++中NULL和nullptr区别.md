好的，我们来详细梳理一下 C++ 中 `NULL` 和 `nullptr` 的区别。您提供的材料已经非常核心和准确，我将在此基础上进行组织、补充和说明，使其更具条理性和易读性。

-----

### C++ 中 NULL 和 nullptr 的区别

这是一个典型的 C++ 为了兼容 C 语言而产生的历史问题。简单来说，`NULL` 是一个来自 C 语言的宏，而 `nullptr` 是 C++11 引入的关键字，旨在提供一个更安全、更明确的空指针表示。

#### 1\. `NULL` 的“身世”与定义

`NULL` 并非 C++ 的原生概念，它继承自 C 语言。然而，它在 C 和 C++ 中的“身份”是不同的，这正是问题的根源。

  * **在 C 语言中**，`NULL` 通常被定义为 `((void*)0)`，它是一个通用的空指针。
  * **在 C++ 语言中**，由于对类型检查的要求更为严格，`void*` 类型的指针不能自由地、隐式地转换为其他类型的指针。因此，为了兼容性，C++ 标准妥协地将 `NULL` 直接定义为整数 `0`。

编译器中常见的 `NULL` 定义方式如下，通过宏 `__cplusplus` 来区分 C++ 和 C 环境：

```c++
#ifdef __cplusplus
    #define NULL 0
#else
    #define NULL ((void *)0)
#endif
```

#### 2\. `NULL` 在 C++ 中引发的问题：函数重载二义性

将 `NULL` 定义为整数 `0` 带来了一个严重的副作用：它无法与真正的整数 `0` 区分开来。当函数重载（Function Overloading）同时存在指针版本和整数版本时，问题就暴露了。

**示例代码：**

```c++
#include <iostream>

void fun(char* p) {
    std::cout << "调用了 fun(char*)" << std::endl;
}

void fun(int p) {
    std::cout << "调用了 fun(int)" << std::endl;
}

int main() {
    fun(NULL);
    return 0;
}
```

**运行结果：**

```
调用了 fun(int)
```

在这个例子中，程序员的意图很可能是想传递一个空指针来调用 `fun(char* p)`。但是，由于 `NULL` 就是 `0`，编译器根据最佳匹配原则，选择了 `fun(int p)` 这个版本，这与预期完全不符，并可能引入难以察觉的 bug。

#### 3\. `nullptr` 的出现：类型安全的空指针

为了根除 `NULL` 带来的二义性问题，C++11 引入了新的关键字 `nullptr`。

`nullptr` 是一个**指针字面量（pointer literal）**，它拥有自己独立的类型 `std::nullptr_t`。它的核心特性是：

  * **类型安全**：`nullptr` 的类型是 `std::nullptr_t`，它不是整数类型。
  * **可以隐式转换为任何指针类型**：它可以被自动转换为 `int*`, `char*`, `SomeClass*` 等任何指针类型。
  * **不能转换为非指针类型**：它不能被转换为整数、浮点数等非指针类型。

这些特性完美地解决了 `NULL` 的问题。如果我们用 `nullptr` 来调用上面的函数：

```c++
fun(nullptr);
```

编译器会明确地知道这是一个空指针，从而正确地匹配并调用 `fun(char* p)` 版本，输出 `调用了 fun(char*)`。

#### 4\. `nullptr` 并非万能：指针类型重载的局限性

`nullptr` 解决了“整数”和“指针”之间的混淆。但是，如果存在多个**不同指针类型**的函数重载，`nullptr` 本身也会导致二义性，因为它能被转换成**任何一种**指针。

**示例代码：**

```c++
#include <iostream>

void fun(char* p) {
    std::cout << "char* p" << std::endl;
}

void fun(int* p) {
    std::cout << "int* p" << std::endl;
}

void fun(int p) {
    std::cout << "int p" << std::endl;
}

int main() {
    // 语句1: 显式类型转换，意图明确
    fun((char*)nullptr); 

    // 语句2: 编译错误！存在二义性
    // fun(nullptr); 
    // 错误信息: call to 'fun' is ambiguous
    // 因为 nullptr 可以同时匹配 fun(char*) 和 fun(int*)

    // 语句3: NULL 是 0，匹配整数版本
    fun(NULL);

    return 0;
}
```

**运行结果分析：**

  * **语句1 `fun((char*)nullptr);`**：通过 `(char*)` 进行了显式类型转换，告诉编译器我们想调用 `char*` 版本。输出 `char* p`。
  * **语句2 `fun(nullptr);`**：此时编译器面临一个选择难题：`nullptr` 既可以转成 `char*` 也可以转成 `int*`，这两个匹配的优先级是相同的。由于无法确定调用哪个版本，编译器会直接报错，拒绝编译。
  * **语句3 `fun(NULL);`**：和之前一样，`NULL` 被当作 `0`，调用了 `fun(int)` 版本。输出 `int p`。

在这种情况下，如果想用空指针调用特定版本的重载函数，就必须像语句1那样，进行显式的类型转换 `(TargetType*)nullptr`，以消除二义性。

-----

### 总结

| 特性       | `NULL`                                        | `nullptr`                                           |
| :------- | :-------------------------------------------- | :-------------------------------------------------- |
| **本质**   | C++中是值为`0`的宏                                  | C++11引入的关键字，类型为`std::nullptr_t`                     |
| **类型安全** | 不安全，会与整数`0`混淆                                 | 安全，有自己独立的类型，与整数区分                                   |
| **重载表现** | 遇到`func(int)`和`func(char*)`重载时，会调用`func(int)` | 遇到`func(int)`和`func(char*)`重载时，会调用`func(char*)`     |
| **局限性**  | 无法区分整数和指针意图                                   | 遇到多个不同指针类型的重载时（如`func(int*)`, `func(char*)`），会导致二义性 |
| **使用建议** | **在现代C++代码中应避免使用**                            | **在C++11及以后的版本中，应始终使用`nullptr`表示空指针**               |
