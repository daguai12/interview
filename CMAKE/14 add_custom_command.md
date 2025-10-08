好的，我们来用一个非常常见且实用的案例，详细讲解 `add_custom_command`。这个命令是 CMake 中实现自动化构建和代码生成的“瑞士军刀”。

### `add_custom_command` 的核心思想

如果你已经理解 `add_custom_target` 是用来创建一个**可以执行的“动作”**（比如 `make docs`），那么 `add_custom_command` 则完全不同。它的核心思想是：

**定义一条“规则”或“菜谱”，用于说明如何从一些输入（原料）生成一个或多个输出文件（菜品）。**

最关键的一点是：`add_custom_command` 本身是\*\*“懒惰”的\*\*。你仅仅定义了这条规则，它**不会**被自动执行。它只有在构建系统中的**另一个目标（比如一个可执行程序）需要它所生成的那个文件时**，才会被“触发”执行。

这就像你在菜谱上写下了一道菜的做法，但你只有在真正准备做这道菜时，才会去照着菜谱操作。

-----

### 案例：使用 Protocol Buffers (Protobuf) 生成 C++ 代码

这是一个工业级的标准用法。Protobuf 是一个由 Google 开发的数据交换格式。开发者会编写一个 `.proto` 文件来定义数据结构，然后使用 `protoc` 编译器来自动生成对应语言（如 C++、Python）的序列化和反序列化代码。

**我们的目标：**

1.  编写一个 `user.proto` 文件，定义一个 `User` 消息。
2.  使用 `add_custom_command` 来定义一条规则，该规则调用 `protoc` 编译器，根据 `user.proto` 生成 `user.pb.h` 和 `user.pb.cpp`。
3.  创建一个可执行程序 `my_app`，它会使用这些生成的代码。

#### 第1步：准备工作 (安装 Protobuf)

你需要先安装 Protocol Buffers 编译器。在大多数系统中，可以通过包管理器安装。

```bash
# Ubuntu/Debian
sudo apt-get install protobuf-compiler libprotobuf-dev

# macOS (using Homebrew)
brew install protobuf

# Windows (using Chocolatey or from GitHub releases)
choco install protoc
```

确保 `protoc` 命令在你的 `PATH` 中可用。

#### 第2步：创建项目文件

```
.
├── CMakeLists.txt
├── main.cpp
└── user.proto      <-- 我们的 Protobuf 定义文件
```

**1. `user.proto`**
定义一个简单的 `User` 结构，包含ID、用户名和邮箱。

```protobuf
syntax = "proto3";

message User {
  int32 id = 1;
  string username = 2;
  string email = 3;
}
```

**2. `main.cpp`**
这个程序会 `#include` 即将由 `protoc` 生成的头文件，并使用其中的 `User` 类。

```cpp
#include <iostream>
#include "user.pb.h" // 关键：这个文件还不存在，将由 add_custom_command 生成

int main() {
    User user;
    user.set_id(101);
    user.set_username("CMakeUser");
    user.set_email("user@example.com");

    std::cout << "User created successfully!" << std::endl;
    std.cout << "ID: " << user.id() << std::endl;
    std::cout << "Username: " << user.username() << std::endl;

    // 清理 Protobuf 库分配的资源 (良好实践)
    google::protobuf::ShutdownProtobufLibrary();
    return 0;
}
```

**3. `CMakeLists.txt`**
这是所有魔法发生的地方。

```cmake
cmake_minimum_required(VERSION 3.10)
project(ProtobufExample)

# 步骤1: 找到 Protobuf 编译器 (protoc) 和库
# find_package 会帮我们找到头文件路径、库路径和 protoc 可执行文件
find_package(Protobuf REQUIRED)

# 步骤2: 定义由 protoc 生成的源文件和头文件的变量
# 我们希望生成的文件放在构建目录 (build/) 中，以保持源码目录整洁
set(PROTO_HEADER ${CMAKE_CURRENT_BINARY_DIR}/user.pb.h)
set(PROTO_SOURCE ${CMAKE_CURRENT_BINARY_DIR}/user.pb.cpp)

# 步骤3: 使用 add_custom_command 定义文件生成规则 (!!本案例的核心!!)
add_custom_command(
  # A. 声明此命令的输出文件
  OUTPUT  ${PROTO_HEADER} ${PROTO_SOURCE}
  
  # B. 声明执行的命令
  #    - ${PROTOBUF_PROTOC_EXECUTABLE} 是 find_package 找到的 protoc 路径
  #    - --cpp_out 指定 C++ 代码的输出目录
  #    - --proto_path 指定在哪里寻找 .proto 源文件
  #    - 最后是要处理的 .proto 文件
  COMMAND ${PROTOBUF_PROTOC_EXECUTABLE}
          --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
          --proto_path=${CMAKE_CURRENT_SOURCE_DIR}
          ${CMAKE_CURRENT_SOURCE_DIR}/user.proto
          
  # C. 声明此命令的依赖项
  #    如果 user.proto 文件被修改了，这条命令就需要重新运行
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/user.proto
  
  # D. 在构建时打印的提示信息
  COMMENT "Generating C++ sources from user.proto..."
)

# 步骤4: 定义可执行程序 (这是“触发器”!)
add_executable(my_app
  main.cpp
  ${PROTO_HEADER}   # <-- 将生成的头文件也列为源文件
  ${PROTO_SOURCE}   # <-- 将生成的源文件作为编译的一部分
)

# 步骤5: 为我们的程序配置依赖
# A. 告诉编译器去哪里找生成的头文件 (user.pb.h)
target_include_directories(my_app PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

# B. 链接 Protobuf 库，因为生成的代码和主程序都用到了它
target_link_libraries(my_app PRIVATE ${PROTOBUF_LIBRARIES})
```

#### 第3步：分析 `add_custom_command` 的关键部分

  - **`OUTPUT`**: 这是最重要的参数！你必须明确列出这个命令将会生成的**所有**文件。CMake 通过 `OUTPUT` 来识别这条规则。
  - **`COMMAND`**: 要执行的命令行。这里我们调用了 `protoc`。
  - **`DEPENDS`**: 命令的输入。CMake 会检查这些依赖项的时间戳。如果 `user.proto`比 `user.pb.h` 更新，CMake 就知道需要重新运行 `COMMAND` 来生成新文件。
  - **触发机制**: `add_custom_command` 本身是惰性的。那么它是如何被执行的呢？是在 `add_executable` 这一步：
    `add_executable(my_app main.cpp ${PROTO_HEADER} ${PROTO_SOURCE})`
    当 CMake 准备构建 `my_app` 时，它看到了源文件列表中的 `${PROTO_HEADER}` (`user.pb.h`) 和 `${PROTO_SOURCE}` (`user.pb.cpp`)。它会问：“这两个文件从哪里来？” 然后它会在自己的规则库里查找，并发现我们用 `add_custom_command` 定义的、`OUTPUT` 是这两个文件的规则。于是，它就会先执行这个自定义命令来生成文件，然后再继续编译 `my_app`。

#### 第4p步：构建与运行

```bash
mkdir build && cd build
cmake ..
cmake --build .
./my_app
```

**输出结果**:

```
User created successfully!
ID: 101
Username: CMakeUser
```

### `add_custom_command` vs `add_custom_target`

| 特性 | `add_custom_command` (菜谱) | `add_custom_target` (烹饪步骤) |
| :--- | :--- | :--- |
| **核心目的** | 定义**如何生成文件**的规则。 | 定义一个可被执行的**动作**。 |
| **是否有产物**| **必须有**，通过 `OUTPUT` 指定。 | **没有**，它本身不与任何文件产出绑定。 |
| **如何执行** | **被动触发**：当某个目标需要它的 `OUTPUT` 文件时。| **主动执行**：通过 `make <target_name>` 或因 `ALL` 关键字被包含在默认构建中。|
| **独立性**| 不是一个独立目标，不能被 `make` 直接调用。| 是一个独立的目标。|

**总结**: 当你的构建过程需要**从输入文件生成输出文件**时（如代码生成、资源编译），请使用 `add_custom_command`。当你需要定义一个可随时调用的**独立操作**时（如运行测试、生成文档、部署），请使用 `add_custom_target`。