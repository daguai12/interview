### CMake 中 file(GLOB_RECURSE) 的简单使用示例

在之前的 `file()` 命令教程中，我们提到了 `GLOB_RECURSE` 子命令。它是 `GLOB` 的扩展版本，用于**递归搜索**目录及其所有子目录中的文件列表，而 `GLOB` 只搜索当前目录。这在项目有嵌套子目录时特别有用，比如大型源代码树，能自动收集所有匹配的文件路径，而无需手动列出。

#### 基本语法 

``` cmake
file(GLOB_RECURSE <variable> <glob_pattern> [RELATIVE <path>] [CONFIGURE_DEPENDS])
``` 
- `<variable>`：存储文件路径列表的变量名。
- `<glob_pattern>`：匹配模式，如 `"src/*.cpp"`（支持 `*` 通配符、`?` 单字符匹配等）。
- `RELATIVE <path>`：可选，使路径相对于指定目录（简化输出）。
- `CONFIGURE_DEPENDS`：可选，让 CMake 在文件变化时自动重新配置（CMake 3.12+）。
- 注意：`GLOB_RECURSE` 在配置阶段执行，跨平台，但在大项目中可能稍慢（因为递归扫描）。

#### 一个简单的例子：递归收集源文件
假设你有一个小型 C++ 项目，源代码散布在子目录中。我们用 `GLOB_RECURSE` 自动收集所有 `.cpp` 文件，然后构建一个可执行文件。

**项目目录结构**（自己创建测试）：
```
simple_project/
├── CMakeLists.txt          # 主脚本
└── src/                    # 源代码根目录
    ├── main.cpp            # 根目录文件
    └── utils/              # 子目录
        ├── helper.cpp      # 子目录文件
        └── math/           # 嵌套子目录
            └── calc.cpp    # 更深层文件
```

- `main.cpp` 内容（简单示例）：
  ```cpp
  #include <iostream>
  extern void helper();  // 来自 helper.cpp
  extern int calc(int);  // 来自 calc.cpp

  int main() {
      helper();
      std::cout << "Result: " << calc(5) << std::endl;
      return 0;
  }
  ```

- `src/utils/helper.cpp`：
  ```cpp
  #include <iostream>
  void helper() {
      std::cout << "Helper function called!" << std::endl;
  }
  ```

- `src/utils/math/calc.cpp`：
  ```cpp
  int calc(int x) {
      return x * 2;
  }
  ```

**完整的 CMakeLists.txt**：
```cmake
# CMake 最低版本
cmake_minimum_required(VERSION 3.10)

# 项目设置
project(SimpleProject)

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# =====================================
# 使用 file(GLOB_RECURSE) 递归收集源文件
# =====================================
# 搜索 src/ 及其所有子目录下的 .cpp 文件，存入 SOURCES 变量
file(GLOB_RECURSE SOURCES "src/*.cpp")

# 可选：使用 RELATIVE 使路径相对 src/（简化显示）
# file(GLOB_RECURSE SOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}/src "src/*.cpp")

# 打印列表以调试
message(STATUS "Found source files recursively: ${SOURCES}")

# =====================================
# 构建可执行文件
# =====================================
add_executable(MyApp ${SOURCES})

# 无需额外链接
```

#### 逐步解释
1. **file(GLOB_RECURSE SOURCES "src/*.cpp")**：
   - **作用**：从 `src/` 开始，递归扫描所有子目录（包括 `utils/` 和 `utils/math/`），匹配所有 `.cpp` 文件。
   - **输出到变量**：`SOURCES` 会成为一个分号分隔的路径列表，例如：
     ```
     /path/to/simple_project/src/main.cpp;/path/to/simple_project/src/utils/helper.cpp;/path/to/simple_project/src/utils/math/calc.cpp
     ```
   - **为什么用 RECURSE？** 如果用 `GLOB`（无 RECURSE），只会找到 `main.cpp`，忽略子目录文件。
   - **RELATIVE 示例**：如果加 `RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}/src`，`SOURCES` 变成 `main.cpp;utils/helper.cpp;utils/math/calc.cpp`（更短，便于使用）。

2. **message(STATUS ...)**：在配置时打印 `SOURCES` 的值，便于验证是否正确收集了文件。

3. **add_executable(MyApp ${SOURCES})**：用收集的列表创建可执行文件 `MyApp`，自动包含所有源文件。

#### 如何运行这个例子
1. **准备**：在终端创建上述目录和文件。
2. **配置和构建**（在 `simple_project/` 目录下）：
   ```
   mkdir build
   cd build
   cmake ..     # 配置：会打印 "Found source files recursively: ..."，显示3个文件
   make         # 构建（Linux/macOS）；Windows 用 cmake --build .
   ```
3. **预期输出**：
   - 配置时终端显示：
     ```
     Found source files recursively: /full/path/src/main.cpp;/full/path/src/utils/helper.cpp;/full/path/src/utils/math/calc.cpp
     ```
   - 运行 `./MyApp`：
     ```
     Helper function called!
     Result: 10
     ```

#### 注意事项与小贴士
- **性能**：小项目无问题；大项目（上千文件）可能慢，考虑手动列出文件或用 `CONFIGURE_DEPENDS` 优化。
- **排除文件**：想排除某些目录？用 `LIST(FILTER ... EXCLUDE REGEX ...)` 后处理 `SOURCES`。
- **头文件**：类似地，用 `"src/**/*.h"` 收集头文件（`**` 是递归通配，但 CMake 用 `*` 就行）。
- **常见错误**：路径必须从当前目录相对；如果没找到文件，检查模式（如 `"src/**.cpp"` 不标准，用 `"src/*.cpp"`）。
- **高级**：结合 `file(GLOB_RECURSE)` 和条件：`if(EXISTS ...)` 检查文件存在。

这个例子超级简单，只需几分钟就能跑起来！如果想加排除逻辑、处理头文件，或在你的项目中测试，告诉我更多细节，我可以扩展。