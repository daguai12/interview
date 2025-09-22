好的，这两条命令和 **CMake 的依赖关系**相关，我们逐步解析：

```cmake
add_dependencies(build-tests ${tinycoro_test_name})
add_dependencies(check-tests ${tinycoro_test_name})
```

---

### 1️⃣ `add_dependencies`

* **作用**：在 CMake 中设置 **目标之间的依赖关系**。
* 官方语法：

```cmake
add_dependencies(<target> <depend_target1> [<depend_target2> ...])
```

* 参数说明：

  1. `<target>`：依赖的目标，表示 “在构建这个目标之前，需要先构建依赖的目标”。
  2. `<depend_target>`：被依赖的目标，可以是任何 CMake target（可执行文件、库、自定义目标等）。

---

### 2️⃣ `build-tests` 和 `check-tests`

* 这两个是前面创建的 **自定义目标**：

  ```cmake
  add_custom_target(build-tests COMMAND ${CMAKE_CTEST_COMMAND} --show-only)
  add_custom_target(check-tests COMMAND ${CMAKE_CTEST_COMMAND} --verbose)
  ```
* 它们本身不会编译源文件，只执行 ctest 相关命令。

---

### 3️⃣ `${tinycoro_test_name}`

* 这是前面定义的 **可执行文件 target**：

  ```cmake
  add_executable(${tinycoro_test_name} EXCLUDE_FROM_ALL ${tinycoro_test_source})
  ```
* 表示测试程序的实际可执行文件。

---

### 4️⃣ 命令效果

1. `add_dependencies(build-tests ${tinycoro_test_name})`

   * 表示：在执行 `build-tests` 之前，先确保 `${tinycoro_test_name}` 可执行文件已经构建完成。
2. `add_dependencies(check-tests ${tinycoro_test_name})`

   * 同理，在执行 `check-tests` 之前，先构建 `${tinycoro_test_name}`。

> 因为 `build-tests` 和 `check-tests` 是自定义目标，它们默认不会自动编译依赖源文件，使用 `add_dependencies` 就保证了测试可执行文件在执行测试命令前已经存在。

---

### 5️⃣ 流程示意

1. 执行 `make build-tests`：

   * 会先构建 `${tinycoro_test_name}` 可执行文件。
   * 然后执行 `ctest --show-only` 列出测试。
2. 执行 `make check-tests`：

   * 先构建 `${tinycoro_test_name}` 可执行文件（如果已经构建则跳过）。
   * 然后执行 `ctest --verbose` 运行测试并输出详细日志。

---

### ✅ 总结

| 命令                                                    | 作用                             |
| ----------------------------------------------------- | ------------------------------ |
| `add_dependencies(build-tests ${tinycoro_test_name})` | 确保 `build-tests` 执行前先构建测试可执行文件 |
| `add_dependencies(check-tests ${tinycoro_test_name})` | 确保 `check-tests` 执行前先构建测试可执行文件 |

---

我可以帮你画一个 **CMake 流程图**，把 **测试可执行文件 → build-tests/check-tests → ctest 命令执行** 的关系可视化，让依赖流程一眼看懂。

你希望我画吗？
