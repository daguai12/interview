# 注意!!!!

必须包含头文件`GUNINSTALLDIR"

----

好的，我们通过一个完整的、贴近实际项目的案例，来详细教学如何使用 `CMAKE_INSTALL_LIBDIR` 和 `CMAKE_INSTALL_BINDIR`。
### 场景介绍：为什么要用它们？
想象一下，你开发了一个项目，它包含一个库（library）和一个使用该库的可执行文件（executable）。当你想要“安装”这个项目时（比如打包给其他人用，或者安装到系统中），你需要把编译好的文件放到正确的目录下。
问题来了，“正确”的目录是什么？
- 在某些 Linux 系统（如 Debian, Ubuntu）上，64位的库通常放在 `/usr/lib` 或者 `/usr/lib/x86_64-linux-gnu`。
- 在另一些 Linux 系统（如 Fedora, CentOS）上，64位的库则放在 `/usr/lib64`。
- 在 Windows 上，库（`.dll`）和可执行文件（`.exe`）通常都在 `bin` 目录下。
- 在 macOS 上，库通常在 `lib` 目录下。
如果你在 `CMakeLists.txt` 里硬编码 `install(... DESTINATION lib)`，那么在 CentOS 上你的软件就会被安装到错误的地方，这不符合系统规范，可能会导致链接问题。
**`CMAKE_INSTALL_LIBDIR` 和 `CMAKE_INSTALL_BINDIR` 就是为了解决这个跨平台目录差异的问题而生的。**
它们是 CMake 提供的标准变量，由一个叫 `GNUInstallDirs` 的模块根据当前操作系统和架构自动计算得出。你只需要使用这些变量，CMake 就会帮你把文件放到最符合当前平台规范的位置。

-----
### 核心模块: `GNUInstallDirs`
要使用这些变量，你必须在你的 `CMakeLists.txt` 文件的开头包含这个模块：
```cmake
include(GNUInstallDirs)
```
一旦包含了它，底下这些变量就自动可用了：
- `CMAKE_INSTALL_BINDIR`: 可执行文件的安装目录 (通常是 `bin`)
- `CMAKE_INSTALL_LIBDIR`: 库文件的安装目录 (可能是 `lib`, `lib64`, `lib/x86_64-linux-gnu` 等)
- `CMAKE_INSTALL_INCLUDEDIR`: 头文件的安装目录 (通常是 `include`)
- `CMAKE_INSTALL_SYSCONFDIR`: 配置文件的安装目录 (通常是 `etc`)
- ... 等等
-----
### 案例项目结构
我们将创建一个项目，它包含一个 "greeter" 库和一个使用该库的 "hello\_app" 程序。
```
install-dirs-example/
├── CMakeLists.txt         # 顶层 CMake 文件
├── greeter/
│   ├── CMakeLists.txt
│   ├── greeter.h
│   └── greeter.cpp
└── src/
	├── CMakeLists.txt
	└── main.cpp
```
-----
### 代码实现
#### 1\. 库和程序源代码
**`greeter/greeter.h`**
```cpp
#pragma once
#include <string>
class Greeter {
public:
	void say_hello(const std::string& name);
};
```
**`greeter/greeter.cpp`**
```cpp
#include "greeter.h"
#include <iostream>
void Greeter::say_hello(const std::string& name) {
	std::cout << "Hello, " << name << " from the Greeter library!" << std::endl;
}
```
**`src/main.cpp`**
```cpp
#include <greeter.h>
int main() {
	Greeter greeter;
	greeter.say_hello("World");
	return 0;
}
```
#### 2\. 子目录的 `CMakeLists.txt`
**`greeter/CMakeLists.txt`**
```cmake
# greeter/CMakeLists.txt
add_library(greeter SHARED greeter.cpp)
# 设置 greeter.h 为 public 头文件，以便其他目标可以找到它
target_include_directories(greeter PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
```
**`src/CMakeLists.txt`**
```cmake
# src/CMakeLists.txt
add_executable(hello_app main.cpp)
# 链接 greeter 库
target_link_libraries(hello_app PRIVATE greeter)
```
#### 3\. 顶层 `CMakeLists.txt`（核心部分）
这是我们将使用 `GNUInstallDirs` 和 `install()` 命令的地方。
```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.14)
project(InstallExample CXX)
# 1. 包含 GNUInstallDirs 模块
#    这是最关键的一步！必须在 install() 命令之前。
include(GNUInstallDirs)
# 打印出 CMake 为我们计算出的路径，方便学习和调试
message(STATUS "Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "Binary install dir: ${CMAKE_INSTALL_BINDIR}")
message(STATUS "Library install dir: ${CMAKE_INSTALL_LIBDIR}")
message(STATUS "Include install dir: ${CMAKE_INSTALL_INCLUDEDIR}")
# 添加子目录
add_subdirectory(greeter)
add_subdirectory(src)
# --- 安装规则 ---
# 2. 安装可执行文件 hello_app
#    使用 install(TARGETS ...) 命令
#    RUNTIME DESTINATION 用于安装可执行文件 (.exe, ELF binaries)
install(TARGETS hello_app
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
# 3. 安装库文件 greeter
#    对于一个库目标，有三种类型的产物需要考虑：
#    - LIBRARY: 共享库 (.so, .dll) 和 macOS 框架
#    - ARCHIVE: 静态库 (.a, .lib)
#    - RUNTIME: 在Windows上，共享库 (.dll) 也是一种 RUNTIME 产物
#    我们把它们都安装到 CMAKE_INSTALL_LIBDIR
install(TARGETS greeter
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} # 主要针对 Windows 的 .dll
)
# 4. 安装头文件
#    对于库来说，只安装 .so/.a 文件是不够的，还必须安装头文件
install(FILES greeter/greeter.h
		DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/greeter
)
# message("Installation directories configured.")
```
-----
### 实验与验证
现在，让我们来编译并“安装”这个项目，看看 `CMAKE_INSTALL_LIBDIR` 的魔力。
1.  **创建构建目录**
	```bash
	mkdir build
	cd build
	```
2.  **配置项目**
	我们将使用 `CMAKE_INSTALL_PREFIX` 来指定一个本地的安装目录 `_install`，而不是安装到系统目录（这需要 root 权限且会污染系统）。
	```bash
	cmake .. -DCMAKE_INSTALL_PREFIX=../_install
	```
	在配置阶段，你会看到我们之前设置的 `message` 命令打印出的路径。
	- **在 Ubuntu/Debian 上，你可能会看到:**
		```
		-- Binary install dir: bin
		-- Library install dir: lib
		```
	- **在 64 位的 CentOS/Fedora 上，你可能会看到:**
		```
		-- Binary install dir: bin
		-- Library install dir: lib64
		```
	这就是 `GNUInstallDirs` 的作用！它自动检测了系统类型并设置了正确的路径。
3.  **构建项目**
	```bash
	cmake --build .
	```
4.  **安装项目**
	这个命令会执行我们在 `CMakeLists.txt` 中定义的所有 `install()` 规则。
	```bash
	cmake --install .
	```
5.  **验证安装结果**
	现在，查看我们项目根目录下的 `_install` 文件夹的结构：
	```bash
	# 回到项目根目录
	cd ..
	# 使用 tree 命令查看（如果没有 tree，可以用 ls -R）
	tree _install
	```
	- **在 Ubuntu/Debian 上，结果如下：**
		```
		_install/
		├── bin/
		│   └── hello_app
		├── include/
		│   └── greeter/
		│       └── greeter.h
		└── lib/
			└── libgreeter.so
		```
	- **在 CentOS/Fedora 上，结果会是这样：**
		```
		_install/
		├── bin/
		│   └── hello_app
		├── include/
		│   └── greeter/
		│       └── greeter.h
		└── lib64/
			└── libgreeter.so
		```
我们成功了！**我们没有写任何一行 `if(UNIX AND ...)` 之类的平台判断代码**，就实现了在不同 Linux 发行版上符合规范的安装布局。
6.  **(可选) 运行已安装的程序**
	因为库被安装到了一个非标准的路径，你需要告诉操作系统去哪里找它。
	```bash
	# 在 Linux/macOS 上
	LD_LIBRARY_PATH=$PWD/_install/lib ./_install/bin/hello_app
	# 或者，如果在 lib64 目录下
	# LD_LIBRARY_PATH=$PWD/_install/lib64 ./_install/bin/hello_app
	```
	输出:
	```
	Hello, World from the Greeter library!
	```
### 总结与最佳实践
1.  **始终包含 `GNUInstallDirs`**：在任何需要 `install()` 命令的项目中，都应该在 `CMakeLists.txt` 顶部包含 `include(GNUInstallDirs)`。
2.  **使用标准变量**：在 `install()` 命令的 `DESTINATION` 参数中，始终使用 `CMAKE_INSTALL_BINDIR`, `CMAKE_INSTALL_LIBDIR`, `CMAKE_INSTALL_INCLUDEDIR` 等变量，不要硬编码 `bin`, `lib` 等路径。
3.  **使用 `CMAKE_INSTALL_PREFIX`**：在配置时通过 `-DCMAKE_INSTALL_PREFIX=<path>` 可以灵活控制安装的根目录，这对于测试、打包和部署都至关重要。
通过遵循这个模式，你的 CMake 项目将变得非常专业、可移植，并且能够轻松地被其他人打包成 `.deb`, `.rpm` 等格式，因为它完全符合 GNU/Linux 生态系统的标准。