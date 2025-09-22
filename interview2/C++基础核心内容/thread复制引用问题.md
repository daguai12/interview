你的代码会**报错**，因为你将一个 `int` 类型的变量（`num`）传递给一个函数（`change_params`）的参数是 **`int&`（引用类型）**，而你在线程创建时并**没有显式使用 `std::ref`** 来传递引用，导致编译器试图用 `num` 复制构造出一个 `int&`（非法），因此会编译失败或运行行为错误。

---

## 🔍 我们来逐步分析：

### 👇 你的代码：

```cpp
void change_params(int& param) {
    param++;
}

void ref_oops() {
    int num = 100;
    std::cout << num << std::endl;

    std::thread t(change_params, num); // <-- 有问题
    t.join();

    std::cout << num << std::endl;
}
```

---

## 🚨 问题出在这里：

```cpp
std::thread t(change_params, num);
```

* 这里 `num` 是一个 **int**，你传入的是 **值（by value）**。
* 但函数 `change_params` 的参数类型是 `int&`，即**引用**。
* `std::thread` 会尝试 **复制参数到新线程上下文中**。
* 也就是说，`std::thread` 会尝试复制 `num`，然后传给 `change_params(int&)`，但这是 **非法的**，因为不能用一个右值（临时变量）来初始化一个 `int&` 参数（需要左值引用）。

---

## ✅ 正确方式：用 `std::ref`

你应该明确告诉 `std::thread` 要传递一个**引用**，方法是使用 `std::ref(num)`：

```cpp
std::thread t(change_params, std::ref(num));
```

这样 `std::thread` 知道不要复制 `num`，而是将其**按引用**传递给目标函数。

---

## ✅ 修改后的完整代码

```cpp
#include <iostream>
#include <thread>
#include <functional> // for std::ref

void change_params(int& param) {
    param++;
}

void ref_oops() {
    int num = 100;
    std::cout << "Before thread: " << num << std::endl;

    std::thread t(change_params, std::ref(num)); // 正确传引用
    t.join();

    std::cout << "After thread: " << num << std::endl;
}
```

输出：

```
Before thread: 100
After thread: 101
```

---

## 📌 总结：为什么要用 `std::ref`

* `std::thread` 默认按值复制传入的参数。
* 如果你要传**引用参数**，必须用 `std::ref` 显式包装。
* 否则会报错或者出现引用绑定到临时对象的未定义行为。

---

有需要我可以补充下底层模板推导过程或 `std::thread` 构造函数的实现机制。需要吗？

很好，那我们现在**深入底层分析 `std::thread(change_params, num)` 为什么不行**，以及为什么 `std::ref(num)` 就能让它正常工作。我们会从模板推导、类型推演、引用折叠等角度讲清楚。

---

## 🧠 一、背景知识：`std::thread` 的构造原理

### `std::thread` 的构造函数（核心签名）：

```cpp
template<class Function, class... Args>
explicit thread(Function&& f, Args&&... args);
```

这是一个 **完美转发构造函数**，它会将参数 `f` 和 `args...` 完美转发给线程执行函数。你可以这样理解它的核心机制：

```cpp
// 伪代码：std::thread 构造函数内部大概等价于
std::thread::thread(f, args...)
{
    // 开一个线程，调用：
    std::invoke(f, args...); // C++17 起使用 std::invoke
}
```

---

## 📦 二、你写的代码在干什么？

```cpp
int num = 100;
std::thread t(change_params, num); // ❌ 错误
```

这个等价于调用：

```cpp
thread::thread(void(&)(int&), int)
```

但你传的参数是 `num`（一个 `int`，值类型），而目标函数要求的是 `int&`。于是问题来了。

---

## ❌ 三、模板推导失败分析

### 函数签名：

```cpp
void change_params(int& param);
```

注意：这是一个**左值引用函数参数**，不能绑定右值（临时对象）。

---

### 推导过程：

```cpp
std::thread t(change_params, num);

// 展开后模板推导大致为：
template<typename F, typename... Args>
thread(F&& f, Args&&... args);

// 推导出：
F = void(&)(int&)     // 函数指针
Args = int            // 值类型
```

于是：等价于在新线程中调用：

```cpp
change_params(int(/*值*/)); // ❌ 错误：不能将 int 绑定到 int&
```

这就会导致**编译错误**：

```
no matching function for call to 'change_params(int)'
```

---

## ✅ 四、正确方式：使用 `std::ref`

你写：

```cpp
std::thread t(change_params, std::ref(num));
```

就变成：

```cpp
std::thread(change_params, std::reference_wrapper<int>(num));
```

这个 `reference_wrapper<int>` 是一个小型类，用于安全地**包装引用**。其内部重载了 `operator int&()`，可以在调用函数时自动转换为 `int&`。

于是：

```cpp
std::invoke(change_params, std::reference_wrapper<int>) // 自动转成 int&
=> change_params(int&); // ✔ 正确绑定引用
```

---

## 🧩 五、引用折叠 & 完美转发的陷阱

这一行：

```cpp
template<class F, class... Args>
thread(F&& f, Args&&... args);
```

是**完美转发模板**，其中：

* `F&&` 和 `Args&&` 实际是 **universal reference**（即可以绑定左值/右值）
* 但在调用 `std::invoke(f, args...)` 时，所有参数会被以 `std::forward` 方式转发

问题是：即使 `num` 是左值，它被推导为 `int`，然后传递给 `change_params(int&)` 时，仍然是按值传递，而 `change_params` 不能接受值。

> C++ 中不会自动把一个 `int` 绑定成 `int&`，除非你明确告诉编译器 “这是引用” —— 所以你就得用 `std::ref(num)`。

---

## 🔚 六、总结

| 写法                              | 推导参数                            | 能否绑定                |
| ------------------------------- | ------------------------------- | ------------------- |
| `std::thread(f, num)`           | `Args = int`                    | ❌ 无法绑定到 `int&`      |
| `std::thread(f, std::ref(num))` | `Args = reference_wrapper<int>` | ✅ 转换成 `int&` 自动绑定成功 |

### ✅ 使用 `std::ref` 是告诉 `std::thread`：“请**按引用传递**我这个参数，而不是复制一份。”

---

如果你感兴趣，我也可以带你看看 `std::reference_wrapper` 的源码实现，或者 `std::invoke` 的推导过程。需要吗？
