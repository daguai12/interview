好问题 👍。
C++11 就引入了 lambda 表达式（闭包），C++14 在此基础上做了很关键的增强，使得 lambda 更加灵活和实用。下面我给你整理一下 **C++14 新增的 lambda 特性**：

---

## 1. **泛型 lambda (Generic lambda)**

### C++11：

```cpp
auto f = [](int a, int b) { return a + b; };
```

参数类型必须写死，想支持多个类型，就得用模板函数。

### C++14：

参数可以用 **`auto`**，lambda 会被编译器翻译成模板化的 `operator()`：

```cpp
auto f = [](auto a, auto b) { return a + b; };

std::cout << f(1, 2) << "\n";     // int
std::cout << f(1.5, 2.3) << "\n"; // double
std::cout << f(std::string("hi "), "there") << "\n"; // string + const char*
```

📌 原理：编译器生成的闭包类 `operator()` 是个模板：

```cpp
struct __Lambda {
    template<typename T1, typename T2>
    auto operator()(T1 a, T2 b) const { return a + b; }
};
```

---

## 2. **捕获初始化 (Lambda capture initializers / generalized capture)**

C++14 允许在捕获列表里直接写初始化表达式，相当于“在捕获时定义新变量”。

### 例子：

```cpp
int x = 10;

// 捕获时初始化一个新的变量 y
auto f = [y = x + 1]() {
    return y;
};

std::cout << f() << "\n"; // 输出 11
```

### 更强大的用法：移动捕获

在 C++11 中，lambda 只能捕获拷贝或引用，没法捕获一个只能移动的对象（比如 `std::unique_ptr`）。

C++14 解决了这个问题：

```cpp
#include <memory>
#include <iostream>

int main() {
    auto ptr = std::make_unique<int>(42);

    // 通过捕获初始化 + std::move，把 unique_ptr 移动进 lambda
    auto f = [p = std::move(ptr)]() {
        return *p;
    };

    std::cout << f() << "\n"; // 42
}
```

这里 `p` 成为 lambda 内部的成员变量（unique\_ptr），原始的 `ptr` 已经为空。

---

## 3. **返回类型推导**

### C++11：

如果 lambda 的返回类型复杂，或者涉及到 `auto` 推导，需要手动写：

```cpp
auto f = [](int a, int b) -> double { return a + b + 0.5; };
```

### C++14：

和普通函数一样，lambda 的返回类型可以自动推导（只要所有 `return` 语句返回类型一致）：

```cpp
auto f = [](int a, int b) { return a + b + 0.5; }; // 自动推导为 double
```

---

## 4. **总结表**

| 特性        | C++11               | C++14                       |
| --------- | ------------------- | --------------------------- |
| 参数 `auto` | ❌ 不支持               | ✅ 泛型 lambda                 |
| 捕获时初始化    | ❌ 只能 `[x]` / `[&x]` | ✅ `[y = expr]`              |
| 移动捕获      | ❌ 不能捕获 `unique_ptr` | ✅ 支持 `[p = std::move(obj)]` |
| 返回类型      | ❌ 必须显式写（除非很简单）      | ✅ 自动推导                      |

---

## 5. 小结

C++14 的 lambda 特性重点有三点：

1. **泛型 lambda** → 参数能写 `auto`，相当于模板化 `operator()`。
2. **捕获初始化** → 捕获时可以写初始化表达式，支持移动捕获。
3. **返回类型自动推导** → 不用再写冗余的 `-> decltype(...)`。

---

要不要我帮你写一段 **综合例子**，把 C++14 lambda 的三大新特性（泛型、移动捕获、返回类型推导）结合起来演示？
