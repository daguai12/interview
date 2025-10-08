好的，这是一个非常棒的问题，它触及了 CMake 项目灵活性和规范性的核心。`BUILD_SHARED_LIBS` 和 `SHARED` 关键字是控制库类型的两种不同哲学方法。

我将用一个简单的案例来详细解释它们。

-----

### 1\. 核心概念对比

| 特性 | `BUILD_SHARED_LIBS` | `add_library(... SHARED ...)` |
| :--- | :--- | :--- |
| **类型** | 全局变量 (开关) | 命令关键字 (指令) |
| **作用范围** | 项目全局 | 单个目标 (target) |
| **行为** | **改变默认行为**。如果`ON`，`add_library`默认创建动态库。 | **显式指定行为**。强制该库为动态库。|
| **优先级** | 低。会被显式 `SHARED` 或 `STATIC` 覆盖。 | 高。无视 `BUILD_SHARED_LIBS` 的值。 |
| **比喻** | **餐厅的“今日例汤”**。如果你不特别点，就给你例汤。 | **直接点单“罗宋汤”**。不管例汤是什么，你就是要罗宋汤。|
| **主要用途**| 为项目的使用者提供一个**编译时选项**，方便地在整个项目中切换动态/静态库构建。| 为项目的开发者**强制规定**某个特定库必须是动态库（例如插件）。|

-----

### 2\. 案例实战

我们将创建一个项目，包含一个主程序和三个功能相同的库，但这三个库的定义方式不同，以便我们观察 `BUILD_SHARED_LIBS` 的效果。

**项目结构:**

```
shared_libs_example/
├── CMakeLists.txt
├── main.cpp
└── mylib/
    ├── CMakeLists.txt
    ├── mylib.cpp
    └── mylib.h
```

#### 第1步：编写代码

**`mylib/mylib.h`**
为了处理 Windows 上动态库符号的导出/导入，我们需要一些宏。这在跨平台库中是标准做法。

```cpp
#pragma once

#if defined(_WIN32) && defined(MYLIB_SHARED)
  #ifdef MYLIB_EXPORTS
    #define MYLIB_API __declspec(dllexport)
  #else
    #define MYLIB_API __declspec(dllimport)
  #endif
#else
  #define MYLIB_API
#endif

// 声明一个函数，我们将在三个不同的库中实现它
MYLIB_API void say_hello_from_default_lib();
MYLIB_API void say_hello_from_explicit_shared_lib();
MYLIB_API void say_hello_from_explicit_static_lib();
```

**`mylib/mylib.cpp`**

```cpp
#include "mylib.h"
#include <iostream>

void say_hello_from_default_lib() {
    std::cout << "Hello from the 'default' library!" << std::endl;
}

void say_hello_from_explicit_shared_lib() {
    std::cout << "Hello from the 'explicitly SHARED' library!" << std::endl;
}

void say_hello_from_explicit_static_lib() {
    std::cout << "Hello from the 'explicitly STATIC' library!" << std::endl;
}
```

**`main.cpp`**

```cpp
#include "mylib.h"

int main() {
    say_hello_from_default_lib();
    say_hello_from_explicit_shared_lib();
    say_hello_from_explicit_static_lib();
    return 0;
}
```

#### 第2步：编写 `CMakeLists.txt`

**`mylib/CMakeLists.txt`**
这是我们实验的核心！我们将创建三个库。

```cmake
# 1. 默认库 (Default Library)
# 注意：这里没有指定 SHARED 或 STATIC。
# 它的类型将完全由 BUILD_SHARED_LIBS 变量决定。
add_library(lib_default mylib.cpp)
target_include_directories(lib_default PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})


# 2. 显式动态库 (Explicitly Shared Library)
# 这里明确使用了 SHARED 关键字。
# 无论 BUILD_SHARED_LIBS 是什么，它永远是动态库。
add_library(lib_explicit_shared SHARED mylib.cpp)
target_include_directories(lib_explicit_shared PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
# 对于Windows动态库，需要定义宏来处理符号导出
# MYLIB_SHARED 会启用 mylib.h 中的 __declspec
# MYLIB_EXPORTS 会让它使用 dllexport
target_compile_definitions(lib_explicit_shared PRIVATE MYLIB_SHARED MYLIB_EXPORTS)


# 3. 显式静态库 (Explicitly Static Library)
# 这里明确使用了 STATIC 关键字。
# 无论 BUILD_SHARED_LIBS 是什么，它永远是静态库。
add_library(lib_explicit_static STATIC mylib.cpp)
target_include_directories(lib_explicit_static PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
```

**根目录 `CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.15)
project(SharedLibsExample CXX)

# 将 mylib/CMakeLists.txt 文件包含进来处理
add_subdirectory(mylib)

# 创建可执行文件
add_executable(my_app main.cpp)

# 链接这三个库到主程序
target_link_libraries(my_app PRIVATE
    lib_default
    lib_explicit_shared
    lib_explicit_static
)

# 当 lib_default 变成动态库时，也需要为它添加编译定义
# 我们使用生成器表达式，仅当其类型为 SHARED 时才添加定义
target_compile_definitions(lib_default
    PRIVATE $<IF:$<TARGET_PROPERTY:lib_default,TYPE>,==,SHARED_LIBRARY>,MYLIB_SHARED;MYLIB_EXPORTS,>
)
# main.cpp 在使用动态库时，也需要定义 MYLIB_SHARED 以便正确导入符号
target_compile_definitions(my_app
    PRIVATE $<IF:$<TARGET_PROPERTY:lib_default,TYPE>,==,SHARED_LIBRARY>,MYLIB_SHARED,>
            $<IF:$<TARGET_PROPERTY:lib_explicit_shared,TYPE>,==,SHARED_LIBRARY>,MYLIB_SHARED,>
)
```

#### 第3步：实验与观察

现在，让我们来编译并观察结果。

```bash
# 在项目根目录 shared_libs_example/ 下
mkdir build
cd build
```

**场景一：默认行为 (`BUILD_SHARED_LIBS` 未设置，默认为 `OFF`)**

```bash
# 只运行 cmake，不传递任何特殊参数
cmake ..
cmake --build .
```

编译完成后，查看 `build/mylib` 目录下的文件：

  * **Linux/macOS:**
      * `liblib_default.a` (静态库, 因为默认是 `OFF`)
      * `liblib_explicit_shared.so` / `.dylib` (动态库, 因为显式指定)
      * `liblib_explicit_static.a` (静态库, 因为显式指定)
  * **Windows:**
      * `lib_default.lib` (静态库)
      * `lib_explicit_shared.dll`, `lib_explicit_shared.lib` (动态库)
      * `lib_explicit_static.lib` (静态库)

**结论**：`lib_default` 变成了**静态库**，而另外两个库的行为符合其显式定义，不受全局变量影响。

**场景二：开启 `BUILD_SHARED_LIBS`**

```bash
# 清理旧的配置缓存或在一个新的 build 目录中操作
# 然后运行 cmake 并将 BUILD_SHARED_LIBS 设置为 ON
cmake .. -DBUILD_SHARED_LIBS=ON
cmake --build .
```

再次查看 `build/mylib` 目录下的文件：

  * **Linux/macOS:**
      * `liblib_default.so` / `.dylib` (**动态库**, 因为全局开关是 `ON`)
      * `liblib_explicit_shared.so` / `.dylib` (动态库, 不变)
      * `liblib_explicit_static.a` (静态库, 不变)
  * **Windows:**
      * `lib_default.dll`, `lib_default.lib` (**动态库**)
      * `lib_explicit_shared.dll`, `lib_explicit_shared.lib` (动态库, 不变)
      * `lib_explicit_static.lib` (静态库, 不变)

**结论**：`lib_default` 的类型被全局开关改变，变成了**动态库**。而显式指定的库完全不受影响。

-----

### 4\. 总结与最佳实践

  * **作为库的开发者，我应该用哪个？**

      * **优先尊重 `BUILD_SHARED_LIBS`**。
      * 在你的 `add_library()` 命令中**省略** `SHARED` 或 `STATIC` 关键字。
      * 这为你的库的使用者提供了最大的灵活性。他们可以通过一个简单的 CMake 命令行参数 (`-DBUILD_SHARED_LIBS=ON`) 来决定你的库是以静态还是动态方式集成到他们的项目中，而无需修改你的 `CMakeLists.txt`。这是大型开源项目（如 Boost, gRPC, Protobuf）的标准做法。

  * **什么时候我应该显式使用 `SHARED` 或 `STATIC`？**

      * **当库的类型是强制性的时候。**
      * **使用 `SHARED`**：如果你正在开发一个**插件系统**，插件**必须**是动态库才能在运行时被加载。在这种情况下，你必须写 `add_library(my_plugin SHARED ...)` 来确保它永远是动态库。
      * **使用 `STATIC`**：如果你正在开发一个小型工具库，并且你希望它总是被静态链接到最终程序中以避免分发额外的 `.dll`/`.so` 文件，你可以写 `add_library(my_util_lib STATIC ...)`。

简而言之，`BUILD_SHARED_LIBS` 是一个**约定**，它为项目构建提供了**灵活性**；而 `SHARED`/`STATIC` 关键字是一个**命令**，它为特定目标提供了**确定性**。