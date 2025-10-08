好的，我们来通过一个简单而直观的案例，详细讲解 `set_target_properties` 的使用方法。

### `set_target_properties` 的核心思想

首先，你需要记住，当你在 CMake 中使用 `add_executable()` 或 `add_library()` 时，你不仅仅是在定义一个最终的文件，更是在 CMake 内部创建了一个\*\*“目标对象 (Target Object)”\*\*。

你可以把这个“目标对象”想象成一个角色的**属性面板**或一张个人信息表。它有很多**属性 (Properties)**，比如：

  - 名字 (Name)
  - 类型 (Type: Executable, Static Library, etc.)
  - 源文件列表 (Source Files)
  - **最终输出的文件名 (Output Name)**
  - **最终输出的目录 (Output Directory)**
  - **要求的C++标准 (C++ Standard)**
  - ...等等还有很多

大多数时候，我们使用专用的命令来修改这些属性，比如 `target_include_directories()` 就是专门用来修改“头文件搜索路径”这个属性的。

而 `set_target_properties` 是一个**通用**的、更底层的命令，像一把“瑞士军刀”，可以让你**一次性修改这个“属性面板”上的任意多个属性**。

-----

### 案例：定制我们的可执行程序

**目标：**
我们将创建一个简单的 C++17 程序。默认情况下，CMake 会：

1.  生成一个与目标同名的可执行文件（例如目标叫 `my_app`，文件名就是 `my_app`）。
2.  将这个文件放在构建目录的根路径下。
3.  使用编译器默认的 C++ 标准。

我们将使用 `set_target_properties` 来改变这一切：

1.  **修改输出文件名**：将 `my_app` 改为 `HelloWorld`。
2.  **修改输出目录**：将可执行文件放入构建目录下的 `bin/` 文件夹中。
3.  **指定C++标准**：明确要求使用 C++17 标准来编译。

#### 第1步：创建项目文件

**1. `main.cpp`**
我们将使用 C++17 的 `if constexpr` 特性，这样如果我们成功设置了 C++17 标准，代码就能编译通过；否则，在一些旧的编译器上可能会失败。

```cpp
#include <iostream>
#include <string>

// 一个简单的模板函数，使用 C++17 的 if constexpr
template<typename T>
auto get_value_info(T value) {
    if constexpr (std::is_integral<T>::value) {
        return "It's an integer.";
    } else {
        return "It's not an integer.";
    }
}

int main() {
    std::cout << "Application started!" << std::endl;
    std::cout << "Checking value 123: " << get_value_info(123) << std::endl;
    std::cout << "Checking value 3.14: " << get_value_info(3.14) << std::endl;
    return 0;
}
```

**2. `CMakeLists.txt`**
我们将从一个最基础的版本开始，然后逐步添加属性设置。

```cmake
cmake_minimum_required(VERSION 3.12) # 推荐使用较高版本以获得更好的属性支持
project(PropertiesExample)

# 1. 创建我们的目标，名为 my_app
add_executable(my_app main.cpp)

# 2. 使用 set_target_properties 来定制 my_app 的属性
set_target_properties(
  my_app                  # <-- 要修改的目标
  PROPERTIES              # <-- 这是一个关键字，表示后面是属性列表
  
  # 属性1: 设置 C++ 标准
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
  
  # 属性2: 修改最终输出的文件名
  OUTPUT_NAME "HelloWorld"
  
  # 属性3: 修改可执行文件的输出目录
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)
```

#### 第2步：分析 `set_target_properties` 命令

这个命令的结构非常清晰：
`set_target_properties(目标1 [目标2...] PROPERTIES 属性1 值1 [属性2 值2...])`

  - **`my_app`**: 我们要修改其属性的目标。
  - **`PROPERTIES`**: 固定的关键字。
  - **`CXX_STANDARD 17`**: 将 `CXX_STANDARD` 属性设置为 `17`。
  - **`CXX_STANDARD_REQUIRED ON`**: 这是一个配套属性，表示“必须成功启用C++17，否则就报错”。这是一个好习惯。
  - **`OUTPUT_NAME "HelloWorld"`**: 将 `OUTPUT_NAME` 属性设置为 `"HelloWorld"`。CMake 在内部仍然称呼这个目标为 `my_app`，但它生成的文件名将是 `HelloWorld`。
  - **`RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"`**: 将可执行文件的输出目录设置为 `build/bin/`。`${CMAKE_BINARY_DIR}` 是 CMake 的内置变量，指向构建目录的根（例如 `build/`）。

#### 第3步：构建并验证结果

现在，让我们来构建项目，看看这些属性设置是否生效了。

```bash
# 1. 创建并进入构建目录
mkdir build
cd build

# 2. 配置项目
cmake ..

# 3. 构建项目
cmake --build .
```

构建完成后，**不要急着运行程序**，先来验证一下我们的设置：

1.  **检查输出目录**：在 `build` 目录下，你会发现多了一个 `bin/` 文件夹。

    ```
    build/
    ├── CMakeCache.txt
    ├── CMakeFiles/
    ├── Makefile
    ├── cmake_install.cmake
    └── bin/             <-- 验证成功！
    ```

2.  **检查文件名**：进入 `bin/` 目录，查看里面的文件。

    ```bash
    cd bin
    ls
    ```

    你会看到可执行文件的名字是 `HelloWorld` (在 Windows 上是 `HelloWorld.exe`)，而不是 `my_app`。**验证成功！**

3.  **运行程序**：

    ```bash
    ./HelloWorld
    ```

    **输出结果**：

    ```
    Application started!
    Checking value 123: It's an integer.
    Checking value 3.14: It's not an integer.
    ```

    程序成功运行，并且使用了 `if constexpr`，这证明 `CXX_STANDARD 17` 属性也已生效。**验证成功！**

### 什么时候使用 `set_target_properties`？

虽然 `set_target_properties` 功能强大，但 CMake 社区推荐**优先使用更具体的专用命令**，因为它们意图更清晰。

  - **优先使用**：

      - `target_include_directories()`
      - `target_link_libraries()`
      - `target_compile_definitions()`
      - `target_compile_options()`

    这些命令不仅更易读，而且能更好地处理 `PUBLIC`, `PRIVATE`, `INTERFACE` 关键字带来的属性传递。

  - **何时使用 `set_target_properties`**：

      - 当你需要设置的属性**没有**对应的专用命令时，比如我们案例中的 `OUTPUT_NAME` 和 `RUNTIME_OUTPUT_DIRECTORY`。
      - 当你需要一次性设置大量属性时。

总而言之，`set_target_properties` 是一个非常有用的工具，用于对 CMake 目标进行精细化的配置。