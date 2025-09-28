好嘞 👍
C++14 相比 C++11 并不是一个“大版本”，它更像是 **C++11 的一个小修订**，解决了一些“语法坑”和“使用痛点”，同时加了一些实用的小特性。

面试、写代码时，以下这些 **C++14 新特性** 是最值得掌握的：

---

# 🌟 C++14 必学新特性清单

## 1. **泛型 Lambda**

### 📌 特性

* 在 C++11 中，lambda 参数必须写具体类型。
* C++14 支持 **lambda 参数用 `auto`**，从而实现“泛型 lambda”。

```cpp
auto f = [](auto x, auto y) {
    return x + y;
};

std::cout << f(1, 2) << std::endl;     // int 相加
std::cout << f(1.5, 2.5) << std::endl; // double 相加
```

✅ 作用：大幅提升 lambda 的泛用性。
👉 面试高频考点。

---

## 2. **返回类型推导（函数 return type deduction）**

### 📌 特性

* C++11 中 `auto` 只能用于变量，函数必须写返回类型，或者写 `-> decltype(expr)`。
* C++14 允许函数直接用 `auto` 推导返回类型。

```cpp
auto add(int a, int b) {
    return a + b;  // 返回类型自动推导为 int
}
```

✅ 作用：让函数声明更简洁。
👉 面试时经常和 C++11 对比考。

---

## 3. **`decltype(auto)`**

### 📌 特性

* 单独的 `auto` 会“丢掉引用性”。
* C++14 引入 `decltype(auto)`，保留表达式的精确类型（包括引用）。

```cpp
int x = 42;
int& ref = x;

auto a = (ref);        // a 是 int，引用性丢失
decltype(auto) b = (ref); // b 是 int&，引用性保留
```

✅ 作用：更准确的类型推导。
👉 模板 & 泛型编程常考。

---

## 4. **变量模板 (Variable Templates)**

### 📌 特性

* 可以为 **常量 / 值** 定义模板。

```cpp
template<typename T>
constexpr T pi = T(3.141592653589793);

std::cout << pi<double> << std::endl;
std::cout << pi<float> << std::endl;
```

✅ 作用：让“常量泛型化”，取代大量的宏。
👉 模板元编程常见。

---

## 5. **别名模板支持默认模板参数**

### 📌 特性

* 在 C++11 中，`using` 别名模板不能指定默认模板参数。
* C++14 修复了这个限制。

```cpp
template<class T = int>
using Vec = std::vector<T>;

Vec<> v;   // 等价于 std::vector<int>
```

✅ 作用：让别名模板更好用。

---

## 6. **二进制字面量 + 数字分隔符**

### 📌 特性

* 直接写二进制字面量：`0b...`
* 用 `'` 分隔数字，提升可读性。

```cpp
int n = 0b1010'1100;  // 二进制
int big = 1'000'000;  // 数字分隔符
```

✅ 作用：写硬件寄存器值、长数字时更直观。
👉 面试可能考小细节。

---

## 7. **`std::make_unique`**

### 📌 特性

* C++11 有 `std::make_shared`，却没有 `std::make_unique`。
* C++14 补上了这个缺失。

```cpp
auto p = std::make_unique<int>(42);
```

✅ 作用：安全创建 `unique_ptr`，避免裸 `new`。
👉 实际开发里用得非常多。

---

## 8. **泛化的 constexpr**

### 📌 特性

* C++11 的 `constexpr` 函数限制很严格：只能一条 `return`。
* C++14 允许 `constexpr` 函数里有：

  * 局部变量
  * 分支 (`if`)
  * 循环 (`for`, `while`)

```cpp
constexpr int factorial(int n) {
    int res = 1;
    for(int i = 1; i <= n; ++i) res *= i;
    return res;
}

static_assert(factorial(5) == 120, "error");
```

✅ 作用：真正实用的编译期计算。
👉 模板元编程/编译期优化常考。

---

## 9. **`[[deprecated]]` 属性**

### 📌 特性

* C++14 新增属性标记 `[[deprecated]]`，提示某个函数/类已过时。

```cpp
[[deprecated("use new_func instead")]]
void old_func();

void new_func();

old_func(); // 编译时会警告
```

✅ 作用：API 演进时非常有用。
👉 面试可能考属性语法。

---

# 📌 总结（C++14 最值得学的）

1. **泛型 lambda**（auto 参数）
2. **函数返回类型推导 (`auto`)**
3. **decltype(auto)**
4. **变量模板**
5. **别名模板的默认参数**
6. **二进制字面量、数字分隔符**
7. **std::make_unique**
8. **更强大的 constexpr**
9. **[[deprecated]] 属性**

---

✅ C++14 的定位就是：**让 C++11 更好用、更安全、更简洁**。
👉 面试时：泛型 lambda、`decltype(auto)`、`make_unique`、constexpr 的增强，这四个最常考。

---

要不要我帮你做一张 **对比表：C++11 vs C++14 的关键特性差异**，这样更直观地看到 C++14 补了哪些坑？
