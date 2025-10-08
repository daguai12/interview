好的，我们通过一个非常简单和常见的案例，来详细讲解 CMake 中的 `configure_file()` 命令。这个命令是连接 CMake 构建配置和源代码最主要的桥梁之一。

### 场景介绍：它解决了什么问题？

想象一下，你的 C++ 程序需要知道它自身的版本号。你可以在代码里硬编码：
`const char* VERSION = "1.0.0";`

但这样做有几个问题：

1.  **重复劳动**：你的 `CMakeLists.txt` 里已经用 `project(MyApp VERSION 1.0.0)` 定义了版本号。现在 C++ 代码里又写了一遍。
2.  **容易出错**：当你发布新版本时，你可能会记得修改 `CMakeLists.txt`，但忘了修改 C++ 代码里的版本号，导致版本信息不一致。
3.  **不够灵活**：如果某些信息只有在构建时才能确定（比如构建日期，或者是否启用某个功能），硬编码就无法处理了。

`configure_file()` 的核心作用就是：**读取一个文件的模板（template），用 CMake 变量替换其中的占位符，然后生成一个新文件。**

这样，你就可以在 CMake 中管理唯一的真实信息源（single source of truth），然后让它自动“注入”到你的源代码中。

-----

### `configure_file()` 语法解析

```cmake
configure_file(
  <input>           # 输入的模板文件路径 (例如 "config.h.in")
  <output>          # 输出的目标文件路径 (例如 "config.h")
  [@ONLY]           # (可选) 只替换 @VAR@ 格式的变量，忽略 ${VAR}
  [COPYONLY]        # (可选) 只复制文件，不替换任何变量
)
```

  - **占位符格式**: 在输入模板文件中，CMake 主要识别两种占位符：
    1.  `@VAR@`: 变量 `VAR` 的值会被直接替换到这里。
    2.  `${VAR}`: 同样会被替换。（但在使用 `@ONLY` 选项时会被忽略）。
  - **`#cmakedefine` 指令**: 这是一个 `configure_file` 专用的强大指令，特别适合用来生成宏定义的头文件。

-----

### 案例：生成一个配置头文件 (`config.h`)

这是 `configure_file()` 最经典的应用场景。我们的目标是：

1.  将 `project()` 命令中定义的项目名称和版本号传递给 C++ 代码。
2.  创建一个 CMake `option()` 开关，用于控制是否启用一个“高级功能”。这个开关的状态也要传递给 C++ 代码。

#### 项目结构

```
configure-file-example/
├── CMakeLists.txt
├── main.cpp
└── config.h.in      # <-- 这是我们的模板文件
```

-----

### 代码实现

#### 1\. 创建模板文件 `config.h.in`

这是一个带有特殊占位符的普通头文件。`.in` 后缀是 CMake 的一个常用约定，表示这是一个待处理的输入文件。

```cpp
// config.h.in

#pragma once

// 将项目名称和版本号定义为宏
// @VAR@ 占位符将被 CMake 变量的真实值替换
#define PROJECT_NAME      "@PROJECT_NAME@"
#define PROJECT_VERSION   "@PROJECT_VERSION@"

// #cmakedefine 是一个特殊的指令，专门用于处理宏定义
// 如果 CMake 变量 ENABLE_ADVANCED_FEATURES 为 ON (或任何非0值),
// 这一行在输出文件中会变成: #define USE_ADVANCED_FEATURES
// 如果为 OFF, 则会变成: /* #undef USE_ADVANCED_FEATURES */ (注释掉的)
#cmakedefine USE_ADVANCED_FEATURES
```

#### 2\. 编写 `CMakeLists.txt`

```cmake
# CMakeLists.txt

cmake_minimum_required(VERSION 3.10)

# 定义项目名称和版本号，这些会自动设置 PROJECT_NAME 和 PROJECT_VERSION 变量
project(MyAwesomeApp VERSION 1.2.3)

# 创建一个用户可配置的选项，默认开启
option(ENABLE_ADVANCED_FEATURES "Enable the advanced features of the app" ON)

# --- 核心命令在这里 ---
# configure_file() 会读取 config.h.in 文件，替换占位符，
# 然后在构建目录 (CMAKE_CURRENT_BINARY_DIR) 中生成 config.h 文件。
# 将生成的文件放在构建目录而不是源码目录，是为了保持源码目录的干净。
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/config.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/config.h"
)

# 创建可执行文件
add_executable(my_app main.cpp)

# --- 非常关键的一步 ---
# 因为 config.h 是在构建目录中生成的，
# 编译器默认是找不到它的。我们必须把构建目录添加到
# my_app 目标的头文件搜索路径中。
target_include_directories(my_app PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}
)
```

#### 3\. 编写 C++ 源代码 `main.cpp`

这个文件将包含我们**生成**的 `config.h` 文件，而不是模板 `config.h.in`。

```cpp
// main.cpp

#include <iostream>

// 包含由 CMake 生成的配置文件
#include "config.h"

void run_advanced_feature() {
    // 这段代码只有在 USE_ADVANCED_FEATURES 宏被定义时才会被编译
    #ifdef USE_ADVANCED_FEATURES
        std::cout << "--> Advanced feature is ENABLED and running." << std::endl;
    #else
        std::cout << "--> Advanced feature is DISABLED." << std::endl;
    #endif
}

int main() {
    // 使用从 CMake 传递过来的宏
    std::cout << "Welcome to " << PROJECT_NAME << std::endl;
    std.cout << "Version: " << PROJECT_VERSION << std::endl;
    
    run_advanced_feature();

    return 0;
}
```

-----

### 实验与验证

现在，让我们来构建和运行项目，看看 `configure_file()` 的效果。

1.  **创建构建目录并配置**

    ```bash
    mkdir build
    cd build
    cmake ..
    ```

2.  **检查生成的 `config.h`**
    在 `build` 目录下，你会发现一个新文件 `config.h`。让我们看看它的内容：

    ```bash
    cat config.h
    ```

    输出将会是：

    ```cpp
    // config.h.in

    #pragma once

    // 将项目名称和版本号定义为宏
    // @VAR@ 占位符将被 CMake 变量的真实值替换
    #define PROJECT_NAME      "MyAwesomeApp"
    #define PROJECT_VERSION   "1.2.3"

    // #cmakedefine 是一个特殊的指令，专门用于处理宏定义
    // 如果 CMake 变量 ENABLE_ADVANCED_FEATURES 为 ON (或任何非0值),
    // 这一行在输出文件中会变成: #define USE_ADVANCED_FEATURES
    // 如果为 OFF, 则会变成: /* #undef USE_ADVANCED_FEATURES */ (注释掉的)
    #define USE_ADVANCED_FEATURES
    ```

    看！所有的占位符都被完美替换了。因为我们默认 `ENABLE_ADVANCED_FEATURES` 是 `ON`，所以 `#cmakedefine` 变成了一个有效的 `#define`。

3.  **编译和运行**

    ```bash
    cmake --build .
    ./my_app
    ```

    程序输出：

    ```
    Welcome to MyAwesomeApp
    Version: 1.2.3
    --> Advanced feature is ENABLED and running.
    ```

4.  **改变配置再试一次**
    现在，让我们禁用高级功能。

    ```bash
    # 使用 -D 命令行参数来关闭 option
    cmake .. -DENABLE_ADVANCED_FEATURES=OFF
    ```

    再次查看 `build/config.h` 的内容：

    ```bash
    cat config.h
    ```

    这次，最后一行会变成：

    ```cpp
    /* #undef USE_ADVANCED_FEATURES */
    ```

    `#cmakedefine` 聪明地将宏定义注释掉了！
    重新编译和运行：

    ```bash
    cmake --build .
    ./my_app
    ```

    程序输出变为：

    ```
    Welcome to MyAwesomeApp
    Version: 1.2.3
    --> Advanced feature is DISABLED.
    ```

### 总结

`configure_file()` 是一个简单但极其强大的工具，用于自动化代码生成和配置管理。

**最佳实践**:

1.  **使用 `.in` 后缀**：为所有模板文件使用这个约定。
2.  **生成到构建目录**：始终将输出文件生成到 `${CMAKE_BINARY_DIR}` 或 `${CMAKE_CURRENT_BINARY_DIR}`，以保持源码树的整洁。
3.  **添加 `include` 路径**：不要忘记使用 `target_include_directories()` 将生成文件所在的目录添加到目标的搜索路径中。
4.  **使用 `#cmakedefine`**：对于布尔开关（ON/OFF），`#cmakedefine` 是生成可靠且清晰的 `#define`/`#undef` 逻辑的最佳方式。