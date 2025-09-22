你这三行 CMake 代码的作用是 **设置不同类型的目标文件输出目录**，便于统一管理生成的静态库、动态库和可执行文件。我们逐行详细解析。

---

### 原始代码

```cmake
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY
    ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY
    ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY
    ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})
```

---

### 逐行解析

#### 1️⃣ `CMAKE_ARCHIVE_OUTPUT_DIRECTORY`

* **作用**：指定 **静态库**（`.a` 或 `.lib`）生成的目录。
* 例如：

  ```bash
  build/libmylib.a
  ```
* `${CMAKE_BINARY_DIR}`：

  * CMake 的构建根目录（build 目录）。
* `${CMAKE_INSTALL_LIBDIR}`：

  * 来自 `include(GNUInstallDirs)`，通常为：

    * Linux/macOS: `lib`
    * Windows: `lib` 或 `Lib`
* **效果**：

  * 所有静态库会生成在：

    ```
    ${CMAKE_BINARY_DIR}/lib/
    ```

---

#### 2️⃣ `CMAKE_LIBRARY_OUTPUT_DIRECTORY`

* **作用**：指定 **动态库/共享库**（`.so`, `.dll`, `.dylib`）生成目录。
* 设置方式和静态库类似：

  ```
  ${CMAKE_BINARY_DIR}/lib/
  ```

---

#### 3️⃣ `CMAKE_RUNTIME_OUTPUT_DIRECTORY`

* **作用**：指定 **可执行文件**（exe 或 bin）生成目录。
* 使用 `${CMAKE_INSTALL_BINDIR}`：

  * 通常是 `bin` 目录。
* **效果**：

  ```
  ${CMAKE_BINARY_DIR}/bin/
  ```
* 方便统一管理可执行文件和库文件。

---

### 举例

假设项目结构：

```
project/
├── CMakeLists.txt
└── src/
    ├── main.cpp
    └── lib.cpp
```

#### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.16)
project(MyProject)

set(CMAKE_CXX_STANDARD 20)

include(GNUInstallDirs)

# 设置输出目录
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})

# 添加库和可执行文件
add_library(mylib STATIC src/lib.cpp)
add_executable(myapp src/main.cpp)
target_link_libraries(myapp PRIVATE mylib)
```

#### 构建后生成文件位置

```
build/
├── bin/
│   └── myapp       # 可执行文件
└── lib/
    └── libmylib.a  # 静态库
```

---

### ✅ 总结

* `CMAKE_ARCHIVE_OUTPUT_DIRECTORY` → 静态库输出目录
* `CMAKE_LIBRARY_OUTPUT_DIRECTORY` → 动态库输出目录
* `CMAKE_RUNTIME_OUTPUT_DIRECTORY` → 可执行文件输出目录
* 使用 `GNUInstallDirs` 提供的 `${CMAKE_INSTALL_LIBDIR}` 和 `${CMAKE_INSTALL_BINDIR}` 可以保证跨平台一致性。
* 这种方式让生成的文件按类型统一放在 `bin/` 和 `lib/` 下，便于管理和安装。

---

如果你愿意，我可以帮你写一个 **完整 CMake 输出目录 + Debug/Release 编译选项 + 测试 target 模板**，让你项目结构非常干净且易管理。

你希望我直接写吗？
