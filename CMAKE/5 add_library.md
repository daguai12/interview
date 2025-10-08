好的，我们来详细讲解 `add_library()`。这个命令是 CMake 项目从“小玩具”走向“真实项目”的关键一步。

如果你已经理解了 `add_executable()` 是用来**创建一道菜（可执行程序）**，那么 `add_library()` 就是用来**制作标准化的半成品或调味包（库）**，这样多道不同的菜都可以使用它，而无需每次都从头准备。

### `add_library()` 的核心思想

`add_library()` 的作用是，用指定的源文件创建**库 (Library)**。库是一组编译好的代码（函数、类等）的集合，它本身不能直接运行，而是被设计用来给其他可执行程序或其他库调用的。

**为什么要用库？**

1.  **代码复用**：多个可执行程序（比如你的主程序、测试程序、工具程序）可以共享同一份库代码。
2.  **模块化**：将项目按功能拆分成不同的模块（库），比如 `CoreLibrary`, `PhysicsLibrary`, `RenderingLibrary`。这让项目结构更清晰，更易于维护。
3.  **加速编译**：当你修改主程序的代码时，如果库的代码没有变，那么库就无需重新编译，可以节省大量的编译时间。

-----

### 案例：将我们的计算器升级为“库 + 程序”的模式

我们重构之前的计算器案例。上次，`main.cpp` 和 `math_utils.cpp` 被一起编译成了一个可执行文件。这次，我们要把 `math_utils` 做成一个独立的、可复用的数学库。

**目标：**

1.  创建一个名为 `MathUtils` 的**库**，包含 `add` 函数。
2.  创建一个名为 `my_calculator` 的**可执行程序**。
3.  让 `my_calculator` **使用** `MathUtils` 库。

#### 第1步：创建项目文件（推荐的目录结构）

将库相关的代码放入一个子目录，是一种良好的组织习惯。

```
.
├── CMakeLists.txt      <-- 主 CMake 文件
├── main.cpp            <-- 主程序源文件
└── math_utils/
    ├── CMakeLists.txt  <-- 库的 CMake 文件 (可选，但推荐)
    ├── math_utils.cpp
    └── math_utils.h
```

**1. `math_utils/math_utils.h`** (保持不变)

```cpp
#pragma once
int add(int a, int b);
```

**2. `math_utils/math_utils.cpp`** (保持不变)

```cpp
#include "math_utils.h"
int add(int a, int b) {
    return a + b;
}
```

**3. `main.cpp`** (保持不变)

```cpp
#include <iostream>
#include "math_utils.h" // 它需要找到 math_utils.h

int main() {
    int sum = add(10, 5);
    std::cout << "10 + 5 = " << sum << std::endl;
    return 0;
}
```

**4. `math_utils/CMakeLists.txt` (为库单独创建)**
这个文件只负责一件事：定义 `MathUtils` 库。

```cmake
# add_library(库的名字 类型(可选) 源文件...)
add_library(MathUtils math_utils.cpp)

# 关键一步：让使用这个库的人，能自动找到它的头文件
target_include_directories(MathUtils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
```

**5. 根目录的 `CMakeLists.txt` (总指挥)**
这个文件负责定义项目，并把子目录（库）和主程序（可执行文件）串联起来。

```cmake
cmake_minimum_required(VERSION 3.10)
project(LibraryExample)

# 告诉 CMake 去处理 math_utils 子目录中的 CMakeLists.txt 文件
add_subdirectory(math_utils)

# 定义我们的主程序
add_executable(my_calculator main.cpp)

# 核心：将主程序与库“链接”起来
target_link_libraries(my_calculator PRIVATE MathUtils)
```

#### 第2步：分析 CMake 命令

1.  **`add_library(MathUtils math_utils.cpp)`**

      * `MathUtils` 是我们给库起的名字。
      * `math_utils.cpp` 是构成这个库的源文件。
      * 默认情况下，CMake 会创建一个**静态库 (STATIC)**。

2.  **`target_include_directories(MathUtils PUBLIC ...)`**

      * 这行非常重要！它是在给 `MathUtils` 这个**目标**设置一个属性。
      * `PUBLIC` 关键字意味着：“任何链接到 `MathUtils` 库的目标，都将**自动地**把这个目录 (`math_utils/`) 添加到自己的头文件搜索路径中。”
      * 这样，当 `my_calculator` 链接到 `MathUtils` 时，CMake会自动帮它找到 `math_utils.h`，我们就不需要在主 `CMakeLists.txt` 中为 `my_calculator` 再单独指定头文件路径了。这就是现代 CMake 的强大之处。

3.  **`add_subdirectory(math_utils)`**

      * 这个命令告诉 CMake：“嘿，进入 `math_utils` 文件夹，那里还有一个 `CMakeLists.txt` 文件，请执行它。” 这样，`add_library` 命令就会被执行。

4.  **`target_link_libraries(my_calculator PRIVATE MathUtils)`**

      * 这是把所有东西连接起来的“胶水”。
      * 它告诉 CMake：“`my_calculator` 这个程序需要使用 `MathUtils` 库中的功能。在最后链接生成可执行文件时，请把 `MathUtils` 库的代码也包含进来。”
      * `PRIVATE` 表示这个依赖关系是 `my_calculator` 内部的，不会向外传递。对于初学者，可以先将其理解为标准用法。

#### 第3步：库的类型：`STATIC` vs `SHARED`

`add_library` 可以创建不同类型的库，最常用的是 `STATIC` 和 `SHARED`。

  * **`STATIC` (静态库)**：

      * **命令**: `add_library(MyLib STATIC src1.cpp src2.cpp)`
      * **工作方式**: 库的代码在链接时，被**完整地复制**到每一个使用它的可执行文件中。
      * **优点**: 程序不依赖外部库文件，单个文件即可运行。
      * **缺点**: 如果多个程序都使用这个库，那么每个程序体积都会变大，造成空间浪费。
      * **产物**: 在 Linux/macOS 是 `.a` 文件，Windows 是 `.lib` 文件。

  * **`SHARED` (共享库/动态库)**：

      * **命令**: `add_library(MyLib SHARED src1.cpp src2.cpp)`
      * **工作方式**: 库的代码生成一个独立的文件。程序在运行时，由操作系统动态加载这个库。
      * **优点**: 程序体积小，多个程序可以共享内存中同一份库代码，节省资源。可以单独更新库文件而无需重新编译主程序。
      * **缺点**: 发布程序时，需要同时带上这个库文件（比如 Windows 上的 `.dll` 文件）。
      * **产物**: 在 Linux 是 `.so` 文件，macOS 是 `.dylib` 文件，Windows 是 `.dll` 文件。

你可以很容易地在 `math_utils/CMakeLists.txt` 中切换类型来观察效果：

```cmake
# 尝试改成 SHARED 看看 build 目录产物的变化
add_library(MathUtils SHARED math_utils.cpp) 
```

#### 第4步：构建并运行

构建步骤和之前完全一样。

```bash
mkdir build && cd build
cmake ..
cmake --build .
```

在 `build` 目录中，你会看到 `math_utils` 目录下生成了库文件（比如 `libMathUtils.a`），而在顶层生成了 `my_calculator` 可执行文件。

运行程序：

```bash
./my_calculator
```

输出结果依然是 `10 + 5 = 15`，但这次，`add` 函数的功能是从一个独立的库中提供的！

### 关键 takeaway

> `add_library()` 用于创建可复用的代码模块。通过 `target_link_libraries()` 将库链接到可执行程序，再通过 `target_include_directories()` 的 `PUBLIC` 属性，可以非常优雅地管理头文件的可见性，这是现代 CMake 项目组织的核心模式。