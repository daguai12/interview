下面这行是 CMake 里非常常见的“用模板生成头文件”的写法：

```cmake
configure_file(
  ${PROJECT_SOURCE_DIR}/config/config.h.in
  ${PROJECT_SOURCE_DIR}/config/config.h
  @ONLY
)
```

# 它在做什么

`configure_file(<in> <out> [@ONLY|COPYONLY] [NEWLINE_STYLE <style>])`
在“配置阶段”读取模板文件 `<in>`，把里面的占位符替换成当前 CMake 变量的值，然后写出成 `<out>` 文件。典型用途就是把 `config.h.in` 生成 `config.h` 并在代码里 `#include "config.h"`。

# 三个关键点逐条解释

1. 路径变量

* `PROJECT_SOURCE_DIR`：工程顶层**源码目录**的绝对路径。
  你现在把输入和输出都指向源码树：`config.h.in -> config.h` 都在 `config/` 里。

2. 模板替换规则

* 默认情况下，`configure_file` 会替换两种写法的变量：`@VAR@` 和 `${VAR}`。
* 加上 `@ONLY` 之后，只会替换 `@VAR@`，而**不会**替换 `${VAR}`。
  这在模板里需要保留 `${...}`（例如示例代码、shell 片段）时很有用。

3. 何时执行

* 发生在 **cmake 配置阶段**（不是编译时）。变量值取自当前的 CMake 变量空间（`set()`、`option()`、检测结果等）。

# 模板文件怎么写（示例）

`config.h.in` 里可以这样写：

```c
/* 项目信息 */
#define PROJECT_NAME "@PROJECT_NAME@"
#define PROJECT_VERSION "@PROJECT_VERSION@"

/* 可选特性：用 #cmakedefine / #cmakedefine01 */
#cmakedefine HAVE_OPENSSL
#cmakedefine01 ENABLE_METRICS

/* 保留花括号变量示例（因为用了 @ONLY） */
#define SAMPLE_LITERAL "${do_not_expand}"
```

* `@PROJECT_NAME@`、`@PROJECT_VERSION@` 会被替换成 CMake 变量的值。
* `#cmakedefine VAR`：若 `VAR` 被设置（非空/非 0），则生成 `#define VAR`，否则生成 `/* #undef VAR */`。
* `#cmakedefine01 VAR`：若设置则 `#define VAR 1`，否则 `#define VAR 0`。
* 若模板里需要字面量 `@`，写成 `@@`。

# 强烈建议的改法（不要把生成物写回源码树）

把输出放到**构建目录**，避免污染源码、支持多构建目录并行：

```cmake
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/config/config.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/config.h
  @ONLY
)

# 让目标能找到生成的头文件
target_include_directories(your_target PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
```

为何不写回源码树？

* 污染仓库，容易被误提交；
* 你无法为 Debug/Release 建两个并行构建目录，因为它们会同时争抢同一个源树文件；
* 一些生成内容依赖配置，切换构建选项会不断改动源树文件。

# 常见坑与对策

* **变量未定义**：`@FOO@` 会被替换为空串；用 `#cmakedefine` 包住更安全。
* **需要在编译配置（如 Debug/Release）不同值**：`configure_file` 在配置阶段执行，不能使用生成期的生成表达式 `$<...>`；那就用 `file(GENERATE ...)`（生成期）或在目标上用 `target_compile_definitions()`。
* **需要保留 `${...}`**：务必带 `@ONLY`，否则 `${...}` 也会被替换。
* **只想复制不替换**：用 `COPYONLY` 选项（与 `@ONLY` 互斥）。
* **行尾风格**：跨平台需要一致时可加 `NEWLINE_STYLE UNIX|DOS|LF|CRLF`。

# 一个完整、可用的小例子

```cmake
# CMakeLists.txt
project(Demo VERSION 1.2.3)
option(ENABLE_METRICS "Enable metrics" ON)

set(HAVE_OPENSSL 1)        # 或者来自 find_package(OpenSSL) 的结果

configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/config/config.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/config.h
  @ONLY
)

add_executable(demo main.cpp)
target_include_directories(demo PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
```

```c
/* config.h.in */
#define DEMO_VERSION "@PROJECT_VERSION@"
#cmakedefine HAVE_OPENSSL
#cmakedefine01 ENABLE_METRICS
```

生成后的 `config.h`（当 HAVE\_OPENSSL=1, ENABLE\_METRICS=ON）大致是：

```c
#define DEMO_VERSION "1.2.3"
#define HAVE_OPENSSL
#define ENABLE_METRICS 1
```

# 小结

* 你的那行命令=“用 `@VAR@` 规则把 `config.h.in` 变成 `config.h`”。
* 最好把输出改到 `CMAKE_CURRENT_BINARY_DIR`，并把该目录加入 include 路径。
* 模板里优先用 `@VAR@`，条件宏用 `#cmakedefine` / `#cmakedefine01`，需要保留 `${...}` 就用 `@ONLY`。
