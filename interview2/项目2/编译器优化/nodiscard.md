👌 你问的 **`nodiscard`**，它和 `alignas` 一样，也是 **标准 C++ 里的 attribute**，不是 GCC 专属扩展。

---

## 🔹 `[[nodiscard]]` 的作用

`[[nodiscard]]` 用来告诉编译器：**函数的返回值不应该被忽略**。
如果调用者丢弃了返回值，编译器会给出警告。

这是 C++17 引入的标准 attribute（在 GCC、Clang、MSVC 都支持），C++20 增强了它，可以带上一个提示信息。

---

## 🔹 基本用法

```cpp
[[nodiscard]] int compute() {
    return 42;
}

int main() {
    compute();  // ⚠️ 编译器警告：返回值被忽略
}
```

---

## 🔹 带原因提示 (C++20)

```cpp
[[nodiscard("use the result to check success or failure")]]
bool doSomething() {
    return false;
}

int main() {
    doSomething();  
    // ⚠️ 警告：返回值被忽略 (use the result to check success or failure)
}
```

---

## 🔹 适用范围

1. **函数返回值**

   * 通常用于返回错误码、资源句柄、计算结果的函数。
2. **类 / 枚举类型**

   * 给类型加 `[[nodiscard]]`，表示该类型的对象不能被随意丢弃。

   ```cpp
   struct [[nodiscard]] ErrorCode {
       int value;
   };

   ErrorCode foo() { return {1}; }

   int main() {
       foo();  // ⚠️ 警告：ErrorCode 被忽略
   }
   ```

---

## 🔹 GCC 对应扩展

在 GCC 早期（C++17 之前），可以用：

```cpp
__attribute__((warn_unused_result))
```

作用相同，甚至更早就能用。

```cpp
__attribute__((warn_unused_result))
int legacyCompute();

int main() {
    legacyCompute();  // ⚠️ 警告：返回值被忽略
}
```

---

## 🔹 总结

* **现代 C++ (C++17+)** → 用 `[[nodiscard]]`（推荐）。
* **旧 GCC / C 代码** → 用 `__attribute__((warn_unused_result))`。
* 典型应用场景：

  * 返回错误码的函数 (`bool` / `int`)
  * 返回资源句柄的函数 (比如 `FILE*`, socket fd)
  * 计算结果函数 (比如数学运算库)

---

要不要我帮你整理一个 **对比表**，把 `[[nodiscard]]` 和 GCC 的 `warn_unused_result`，还有 MSVC 的对应写法统一封装成一个宏？这样你在跨平台项目里就能写成一个 `ATTR_NODISCARD` 来用。
