这个问题问得很好 👍。
答案是：**有时候可以省，但大多数情况下不行**。我来给你详细分开说。

---

## 1. 情况一：库是 **CMake target**

如果你 `target_link_libraries` 的库本身就是一个用 `add_library()` 定义的 CMake target，并且它在自己的 `CMakeLists.txt` 里正确写了 **使用要求 (usage requirements)**，那么你就可以不用手写 `target_include_directories`。

例子：

```cmake
add_library(mylib src/mylib.cpp)
target_include_directories(mylib PUBLIC include)

add_executable(app src/main.cpp)
target_link_libraries(app PRIVATE mylib)
```

这里：

* `mylib` 声明了自己需要 `include/`。
* 因为是 `PUBLIC`，所以 `app` 自动继承到头文件路径。
* 你就不用再写 `target_include_directories(app …)`。

👉 这就是 CMake 推崇的“现代 CMake”写法：
**库自己声明需求，使用者只管 `target_link_libraries`。**

---

## 2. 情况二：库是 **系统库或外部库**

如果你用的是系统库（比如 `/usr/lib/libssl.so`），它本身不是 CMake target，也没有 usage requirements，那么：

```cmake
target_link_libraries(app PRIVATE ssl crypto)
```

只能解决“链接阶段”的问题，**不能解决“编译阶段找不到头文件”的问题**。
这时你还是得写：

```cmake
target_include_directories(app PRIVATE /usr/include/openssl)
```

除非你用了 `find_package(OpenSSL REQUIRED)`，
它返回的 `OpenSSL::SSL` 就是一个 CMake target，里面已经写好了 `INTERFACE_INCLUDE_DIRECTORIES`，
那样就能直接写：

```cmake
target_link_libraries(app PRIVATE OpenSSL::SSL)
```

而不用管 include 路径。

---

## 3. 情况三：Header-only 库

这种库没有 `.cpp` 文件，只靠头文件，比如 `spdlog`。
你可以写成：

```cmake
add_library(spdlog INTERFACE)
target_include_directories(spdlog INTERFACE include)

target_link_libraries(app PRIVATE spdlog)
```

因为 `spdlog` 自己没东西要编译（INTERFACE），但下游需要它的 `include/`，
所以这里完全不用再写 `target_include_directories(app …)`。

---

## 🔑 总结

* `target_link_libraries` **本质是“依赖传递入口”**，它会把库的 **使用要求**（包括 include 路径、宏定义、编译选项、链接库等）传给下游。
* 如果库是“现代 CMake target”，你只要写 `target_link_libraries` 就够了。
* 如果库只是个 `.so/.a` 文件或者没写 usage requirements，那你还得自己写 `target_include_directories`。

---

要不要我给你画一个“编译阶段 vs 链接阶段”的流程图，直观展示 **为什么光 link 不一定能找到头文件**？
