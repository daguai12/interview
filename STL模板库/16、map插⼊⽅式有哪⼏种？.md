我们将插入方式分为两大类：**“插入或更新”** 的方法 和 **“仅插入”** 的方法。

### 1\. “插入或更新” 的方法：`operator[]`

这正是您提到的第四种方式，也是最直观的一种。

**语法**：

```cpp
std::map<int, std::string> my_map;
my_map[101] = "Alice"; // 插入或更新
```

**工作机制**：

  * **如果 `key` (101) 不存在**：
    1.  `map`会首先为这个 `key` **插入**一个**默认构造**的 `value`（对于 `std::string` 就是一个空字符串）。
    2.  然后，`operator[]` 返回对这个新创建的 `value` 的**引用**。
    3.  最后，通过赋值运算符 `=` 将 `"Alice"` 赋给这个 `value`。
  * **如果 `key` (101) 已经存在**：
    1.  `operator[]` 会直接返回对**已存在 `value` 的引用**。
    2.  然后，通过赋值运算符 `=` **覆盖**掉原来的值。

**优缺点**：

  * ✅ **优点**：语法非常简洁，是实现“如果不存在就插入，如果存在就更新”逻辑的最便捷方式。
  * ❌ **缺点**：
    1.  **效率较低**：对于插入操作，它实际上执行了“默认构造 + 赋值”两步，而非一步到位的构造。
    2.  **有硬性要求**：`map` 的 `value` 类型**必须要有默认构造函数**，否则使用 `operator[]` 会导致编译错误。

-----

### 2\. “仅插入” 的方法：`insert` 与 `emplace`

这类方法的核心特点是：如果 `map` 中已经存在相同的 `key`，它们**不会**执行任何操作，也**不会**覆盖原有的值。

#### a) `insert()` 函数

这是最标准的“仅插入”方法。它有多种重载形式，您提到的前三种都属于 `insert`。

**非常有用的返回值**：
`insert` 函数会返回一个 `std::pair<iterator, bool>`：

  * `iterator`：一个指向**新插入元素**或**已存在元素**的迭代器。
  * `bool`：`true` 表示插入**成功**（key原先不存在）；`false` 表示插入**失败**（key已存在）。

**几种语法形式**：

  * **1. C++11 及以后 (推荐)**：使用**列表初始化 `{}`** 来构造 `pair`。

    ```cpp
    auto result = mapStudent.insert({1, "student_one"});
    ```

    这是最简洁、最现代的写法。

  * **2. 使用 `std::make_pair`** (您的方法3)：

    ```cpp
    auto result = mapStudent.insert(std::make_pair(1, "student_one"));
    ```

    这是 C++11 之前最常见的写法，`make_pair` 可以自动推导类型，比较方便。

  * **3. 显式构造 `std::pair`** (您的方法1和2)：

    ```cpp
    // 方法1
    mapStudent.insert(std::pair<int, std::string>(1, "student_one"));
    // 方法2 (value_type 就是 pair<const int, std::string> 的别名)
    mapStudent.insert(std::map<int, std::string>::value_type(1, "student_one"));
    ```

    这两种写法比较冗长，在现代C++中已不常用。

**`insert` 的工作机制**：
它需要先在外部构造一个 `std::pair` 对象，然后再将这个对象**拷贝**或**移动**到 `map` 的内部节点中。

#### b) `emplace()` 函数 (C++11, 性能更优)

`emplace` 是为了解决 `insert` 需要创建临时对象的问题而引入的，是**最高效的插入方式**。

**语法**：

```cpp
auto result = mapStudent.emplace(1, "student_one");
```

**工作机制**：
`emplace` 不接受一个 `std::pair` 对象，而是接受**构造 `std::pair` 所需的参数**（在这里是 `1` 和 `"student_one"`）。它会将这些参数\*\*完美转发（perfectly forward）\*\*到 `map` 内部，**直接在最终的内存位置上“就地”构造**出 `std::pair` 对象。

**`emplace` vs. `insert`**：

  * `insert`: **构造临时 `pair` -\> 移动/拷贝**到 `map` 内部。 (两步)
  * `emplace`: **直接在 `map` 内部构造 `pair`**。 (一步)

**结论**：`emplace` 避免了临时对象的创建和随后的拷贝/移动开销，性能更好。

-----

### 3\. C++17 的新成员

C++17 提供了更精细的控制，进一步完善了插入操作：

  * **`try_emplace(key, args...)`**：和 `emplace` 类似，但如果 `key` 已存在，它**不会**像 `emplace` 一样先构造一个 `value_type` 再发现插入失败。如果 `value` 的构造很昂贵，这能避免不必要的开销。
  * **`insert_or_assign(key, value)`**：`operator[]` 的完美替代品。它实现了“插入或更新”的逻辑，但**不要求 `value` 类型有默认构造函数**，并且返回与 `insert` 相同的 `pair<iterator, bool>`，让你能判断是插入了还是更新了。

### 总结表格

| 方法 | 语法示例 | 若Key已存在 | 性能特点 | 推荐场景 |
| :--- | :--- | :--- | :--- | :--- |
| **下标 `[]`** | `map[k] = v;` | **更新/覆盖** | 插入时：默认构造+赋值 | 简单的插入或更新 |
| **`insert`** | `map.insert({k, v});`| **不操作** | 构造临时 `pair` + 移动/拷贝 | 需要知道是否插入成功 |
| **`emplace` (C++11)** | `map.emplace(k, v);` | **不操作** | **就地构造**，避免临时对象 | **追求高性能**的插入 |
| **`insert_or_assign` (C++17)**| `map.insert_or_assign(k, v);`| **更新/覆盖**| 高效的“插入或更新”版`emplace`| `[]` 的完美替代品 |

**实践建议**：

  * 如果你的逻辑是“**插入或更新**”，请使用 `operator[]` (如果值类型有默认构造) 或 C++17 的 `insert_or_assign` (更优)。
  * 如果你的逻辑是“**仅当不存在时才插入**”，请使用 **`emplace`**，因为它在性能上总是最优的选择。