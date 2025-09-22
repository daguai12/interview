你这行 CMake 代码定义了一个 **布尔型选项（option）**，用于控制构建开关。我们详细解析一下：

---

### 原始代码

```cmake
option(ENABLE_UNIT_TESTS "Enable unit tests" ON)
```

---

### 逐项解析

1. **`option()`**

* CMake 的命令，用于定义布尔选项（ON/OFF）。
* 语法：

  ```cmake
  option(<option_variable> "Description" <initial_value>)
  ```

  * `<option_variable>`：选项变量名（CMake 变量名）。
  * `"Description"`：选项描述，显示在 CMake GUI 或 `ccmake` 中。
  * `<initial_value>`：默认值，通常为 `ON` 或 `OFF`。

---

2. **`ENABLE_UNIT_TESTS`**

* 变量名，用来控制是否启用单元测试。
* 定义后，你可以在 CMake 里使用：

  ```cmake
  if(ENABLE_UNIT_TESTS)
      # 添加测试
  endif()
  ```

---

3. **`"Enable unit tests"`**

* 描述信息，用于提示作用。
* 在 CMake GUI 或 `ccmake` 中会显示：

  ```
  ENABLE_UNIT_TESTS: Enable unit tests
  ```

---

4. **`ON`**

* 默认值。
* 表示默认启用单元测试。
* 如果想默认关闭，可以写成：

  ```cmake
  option(ENABLE_UNIT_TESTS "Enable unit tests" OFF)
  ```

---

### 使用示例

#### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.16)
project(MyProject)

# 定义是否启用单元测试
option(ENABLE_UNIT_TESTS "Enable unit tests" ON)

if(ENABLE_UNIT_TESTS)
    message(STATUS "Unit tests enabled")
    enable_testing()
    add_executable(my_test test.cpp)
    add_test(NAME my_test COMMAND my_test)
else()
    message(STATUS "Unit tests disabled")
endif()
```

#### 配置和构建

1. **默认启用**

```bash
cmake -S . -B build
cmake --build build
```

输出：

```
-- Unit tests enabled
```

2. **关闭单元测试**

```bash
cmake -S . -B build -DENABLE_UNIT_TESTS=OFF
cmake --build build
```

输出：

```
-- Unit tests disabled
```

---

### ✅ 总结

* `option()` 用于创建布尔开关，便于用户在 CMake 配置时选择功能。
* `ENABLE_UNIT_TESTS` 是常见模式，用于控制是否添加测试目标。
* 默认值为 `ON`，可以通过 `-D` 命令行参数修改。

---

如果你愿意，我可以帮你写一个 **带完整测试开关的 LazyVim CMake 模板**，把 `ENABLE_UNIT_TESTS` 与 `build-test` / `run-test` 自定义 target 自动集成。

你希望我写吗？
