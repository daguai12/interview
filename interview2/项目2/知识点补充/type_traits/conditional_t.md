# `std::conditional_t`

`std::conditional_t` 是 C++11 引入的一个模板元编程工具，定义在 `<type_traits>` 头文件中，用于在编译时根据条件选择两种类型中的一种。

它的核心作用是：**在编译期根据一个布尔常量（条件），从两个备选类型中选择其一**，生成最终的类型。


### 基本语法
```cpp
#include <type_traits>

// 模板参数：
// 1. 条件（bool 类型的常量表达式）
// 2. 条件为 true 时选择的类型
// 3. 条件为 false 时选择的类型
std::conditional_t<Condition, TypeIfTrue, TypeIfFalse>
```

- 如果 `Condition` 为 `true`，则 `std::conditional_t<...>` 等价于 `TypeIfTrue`
- 如果 `Condition` 为 `false`，则等价于 `TypeIfFalse`


### 示例说明
```cpp
#include <type_traits>
#include <iostream>

// 编译时根据条件选择类型
using Type1 = std::conditional_t<true, int, double>;   // Type1 是 int
using Type2 = std::conditional_t<false, int, double>;  // Type2 是 double

// 结合类型 traits 使用（判断类型是否为指针）
template <typename T>
struct MyType {
    // 如果 T 是指针类型，使用 const T，否则使用 T&
    using type = std::conditional_t<
        std::is_pointer_v<T>,  // 条件：T 是否为指针
        const T,               // 是指针：选 const T
        T&                     // 非指针：选 T&
    >;
};

int main() {
    MyType<int*>::type a;  // int* 是指针 → 类型为 const int*
    MyType<int>::type b;   // int 非指针 → 类型为 int&
    return 0;
}
```


### 注意点
1. **编译期决策**：条件必须是编译期可确定的常量表达式（如 `true`、`false` 或 `constexpr` 变量）。
2. **与 `std::conditional` 的关系**：`std::conditional_t` 是 `std::conditional` 的简化版本。  
   `std::conditional<Condition, T, U>::type` 等价于 `std::conditional_t<Condition, T, U>`（C++14 起支持 `_t` 后缀的便捷别名）。
3. **不执行分支代码**：它只是选择类型，不会执行任何代码分支，与运行时的 `if-else` 完全不同。


### 典型用途
- 模板中根据类型特性选择不同的实现类型
- 简化条件性的类型定义，避免冗长的特化代码
- 结合其他类型 traits（如 `std::is_integral`、`std::is_pointer` 等）做更复杂的类型判断

例如，在泛型编程中为整数类型和浮点类型提供不同的处理类型：
```cpp
template <typename T>
using NumericType = std::conditional_t<
    std::is_integral_v<T>,
    long long,  // 整数类型 → 用 long long
    long double // 浮点类型 → 用 long double
>;
```

通过 `std::conditional_t`，可以在编译期灵活地进行类型选择，是模板元编程中的基础工具之一。