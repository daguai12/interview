
这个位于 `benchmark` 目录下的 `CMakeLists.txt` 文件是一个自动化脚本，写得非常巧妙。它的核心作用是**自动发现、编译和创建用于运行所有性能测试程序的便捷指令**。

下面我为您逐行详细讲解这个文件的内容：

### 总体目标

这个 CMake 脚本的主要目的，是让作者不必为每一个新的 benchmark 测试文件都手动修改编译配置。它能自动扫描 `benchmark` 目录下的所有 C++ 源文件，为每一个文件单独创建一个可执行程序，并生成对应的 `make` 命令来方便地编译和运行它们。

-----

### 代码分解

1.  **查找所有 Benchmark 源文件**

    ```cmake
    file(GLOB_RECURSE TINYCORO_BENCH_SOURCES "${PROJECT_SOURCE_DIR}/benchmark/*/*.cpp")
    ```

      * **`file(GLOB_RECURSE ...)`**: 这是一个文件搜索命令。
      * `TINYCORO_BENCH_SOURCES`: 这是一个变量，所有找到的文件的完整路径列表都会被存储在这个变量里。
      * `"${PROJECT_SOURCE_DIR}/benchmark/*/*.cpp"`: 这是搜索规则。它告诉 CMake 去 `benchmark` 目录以及它的所有子目录（由 `*` 代表）下，寻找所有以 `.cpp` 结尾的文件。最终 `TINYCORO_BENCH_SOURCES` 会变成一个类似 `(.../tinycoro_128_bench.cpp; .../epoll_server_bench.cpp; ...)` 的列表。

2.  **创建几个有用的自定义目标 (Custom Target)**

    ```cmake
    add_custom_target(build-bench COMMAND echo "Building benchmark case...")

    add_custom_target(build-benchtools
      COMMAND cargo run --release --manifest-path=${PROJECT_SOURCE_DIR}/third_party/rust_echo_bench/Cargo.toml -- --help
    )
    ```

      * **`add_custom_target(...)`**: 这个命令会创建一个可以用 `make` 来执行的新目标。它本身不编译代码，而是执行一个指定的 `COMMAND`。
      * `build-bench`: 一个简单的目标，执行后只会打印一句话。它主要用作一个“分组目标”。当你执行 `make build-bench` 时，所有依赖于它的 benchmark 可执行文件都会被触发编译。
      * `build-benchtools`: 这是一个非常重要的目标。它执行的命令是去编译基于 Rust 的压测工具 `rust_echo_bench`。命令最后的 `-- --help` 是一个小技巧，目的是让 Cargo 只编译项目而不真正运行它，因为我们只需要编译好的可执行文件。

3.  **遍历每一个 Benchmark 文件（核心逻辑）**

    ```cmake
    foreach (tinycoro_bench_source ${TINYCORO_BENCH_SOURCES})
      ...
    endforeach()
    ```

    这个 `foreach` 循环会遍历之前找到的所有 `.cpp` 文件，并对每一个文件执行循环体内的指令。我们来看看循环内部都做了什么。

4.  **循环内部：处理每个文件**

    ```cmake
    get_filename_component(tinycoro_bench_filename ${tinycoro_bench_source} NAME)
    string(REPLACE ".cpp" "" tinycoro_bench_name ${tinycoro_bench_filename})
    ```

      * **`get_filename_component(...)`**: 从文件的完整路径中提取出文件名（例如 `tinycoro_1k_bench.cpp`）。
      * **`string(REPLACE ...)`**: 将上一步得到的文件名中的 `.cpp` 后缀替换掉，生成一个干净的目标名，例如 `tinycoro_1k_bench`。这个名字将用于后续的可执行文件目标。

5.  **为每个 Benchmark 文件创建可执行程序**

    ```cmake
    add_executable(${tinycoro_bench_name} EXCLUDE_FROM_ALL ${tinycoro_bench_source})
    add_dependencies(build-bench ${tinycoro_bench_name})
    ```

      * **`add_executable(...)`**: 这是定义一个新程序的命令。它为每个 `.cpp` 文件创建了一个对应的编译目标（例如，`tinycoro_1k_bench.cpp` 会被编译成名为 `tinycoro_1k_bench` 的程序）。
      * `EXCLUDE_FROM_ALL`: 这个关键字很重要。它告诉 CMake，如果你只执行 `make` 命令，不要编译这个目标。用户必须明确地请求编译它（例如 `make tinycoro_1k_bench` 或者 `make build-bench`）。
      * **`add_dependencies(...)`**: 这行代码让 `build-bench` 目标依赖于新创建的可执行文件目标。这就是“分组”功能的实现方式：当你执行 `make build-bench` 时，CMake 会看到这个依赖关系，从而去编译 `tinycoro_1k_bench`。

6.  **设置编译选项和链接库**

    ```cmake
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
      target_compile_options(${tinycoro_bench_name} PRIVATE "-g")
    endif()
    if(ENABLE_COMPILE_OPTIMIZE)
      target_compile_options(${tinycoro_bench_name} PUBLIC -O3)
    endif()
    target_link_libraries(${tinycoro_bench_name} ${PROJECT_NAME})
    ```

      * 这些代码为每个 benchmark 程序配置了编译参数。如果是 `Debug` 模式，就加入 `-g` 标志方便调试。如果开启了优化 (`ENABLE_COMPILE_OPTIMIZE` 为 ON)，就加入强大的 `-O3` 优化选项。
      * **`target_link_libraries(...)`**: 这一步至关重要，它将编译好的 benchmark 程序与项目的主库 `tinycoro` (`${PROJECT_NAME}`) 链接起来。这样，benchmark 代码才能调用 `tinycoro` 库中定义的各种函数和类。

7.  **创建自定义的 `make` 命令来运行 Benchmark**

    ```cmake
    string(REPLACE "_bench" "" tinycoro_bench_command ${tinycoro_bench_name})
    add_custom_target(bench_${tinycoro_bench_command}
      COMMAND $<TARGET_FILE:${tinycoro_bench_name}>
      DEPENDS ${tinycoro_bench_name}
      COMMENT "Running ${tinycoro_bench_command} bench..."
    )
    ```

      * 这是最后一步，也是对用户最友好的一步。它创建了一个新的自定义目标，专门用来 *运行* 编译好的程序。
      * `string(REPLACE ...)`: 创建一个更短、更干净的命令名，例如 `tinycoro_1k_bench` 会被处理成 `tinycoro_1k`。
      * `add_custom_target(bench_${tinycoro_bench_command} ...)`: 这样就创建了一个类似 `bench_tinycoro_1k` 的目标。
          * `COMMAND $<TARGET_FILE:${tinycoro_bench_name}>`: 它要执行的命令就是 benchmark 程序本身。
          * `DEPENDS ${tinycoro_bench_name}`: 确保在运行前，程序一定已经被编译好了，并且是最新版本。

### 总结：你可以用 `make` 做什么

正是因为这个 `CMakeLists.txt` 文件，你才可以在 `build` 目录下使用这些简洁的命令：

  * `make build-bench`: 编译所有的 benchmark 服务端程序。
  * `make build-benchtools`: 编译 Rust 写的压测客户端。
  * `make bench_tinycoro_1k`: 编译（如果需要的话）并 **运行** `tinycoro_1k_bench` 这个性能测试服务端。
  * `make bench_epoll_server`: 编译（如果需要的话）并 **运行** `epoll_server_bench` 这个性能测试服务端。

这种高度自动化的配置，使得管理和运行大量的性能测试变得非常高效和方便。