这一行是 **CMake 定义库目标** 的指令，我们拆开分析：

---

### 代码

```cmake
add_library(${PROJECT_NAME} ${TINYCORO_SOURCE_FILES})
```

---

### 1️⃣ `add_library`

* 作用：创建一个 **库目标**（可以是静态库 `.a` 或动态库 `.so`，也可以是模块 `.dll/.dylib`）。
* 语法：

  ```cmake
  add_library(<name> [STATIC | SHARED | MODULE] [EXCLUDE_FROM_ALL] source1 source2 ...)
  ```

  * `<name>`：库的名字。
  * `[STATIC | SHARED]`：可选，指定生成静态库还是动态库。

    * 不写的话，由 `BUILD_SHARED_LIBS` 变量控制：

      * `ON` → 默认生成 **共享库**（动态库）
      * `OFF` → 默认生成 **静态库**
  * `[EXCLUDE_FROM_ALL]`：不让这个 target 默认参与 `make all`。
  * `source1 source2 ...`：源文件列表。

---

### 2️⃣ `${PROJECT_NAME}`

* `PROJECT_NAME` 是在 `project()` 里定义的工程名字变量。

  ```cmake
  project(tinycoro CXX)
  ```

  那么 `${PROJECT_NAME}` → `"tinycoro"`
* 所以这行的效果就是：

  ```cmake
  add_library(tinycoro ${TINYCORO_SOURCE_FILES})
  ```

---

### 3️⃣ `${TINYCORO_SOURCE_FILES}`

* 这是一个变量，存放 **库的源码文件路径列表**。
* 例如可能是：

  ```cmake
  set(TINYCORO_SOURCE_FILES
      src/scheduler.cpp
      src/task.cpp
      src/fiber.cpp
  )
  ```

---

### 4️⃣ 执行效果

如果 `BUILD_SHARED_LIBS` 是默认的 `OFF`，这行会生成：

```
libtinycoro.a    # 静态库
```

如果 `BUILD_SHARED_LIBS` 是 `ON`，会生成：

```
libtinycoro.so   # 动态库
```

生成路径会受到你前面 `set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ...)` 的影响。

---

### 5️⃣ 使用方法

* 生成的库可以被其他 target 链接：

  ```cmake
  add_executable(app main.cpp)
  target_link_libraries(app PRIVATE tinycoro)
  ```

---

📌 **总结**
这行指令是告诉 CMake：

> 用 `${TINYCORO_SOURCE_FILES}` 里的源文件构建一个库，库名就是 `${PROJECT_NAME}`（比如 tinycoro），类型由 `BUILD_SHARED_LIBS` 决定。

---

如果你愿意，我可以帮你画一张 **CMake 构建流程图**，把 `add_library` 之后文件怎么编译、怎么打包成 `.a/.so` 的过程可视化，这样你一眼就能看懂整个构建链路。
你需要我画吗？
