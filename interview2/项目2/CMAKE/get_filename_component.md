
```cmake
get_filename_component(tinycoro_test_filename ${tinycoro_test_source} NAME)
```

---

### 1️⃣ `get_filename_component`

* 这是 **CMake 内置命令**，用于**提取文件路径中的某个部分**。
* 官方语法：

```cmake
get_filename_component(<variable> <file> <component> [CACHE])
```

* 参数说明：

  1. `<variable>`：输出变量名，命令会把提取的结果赋给它。
  2. `<file>`：输入的文件路径，可以是绝对路径或相对路径。
  3. `<component>`：想要提取的部分（NAME, DIRECTORY, EXT, ABSOLUTE 等）。
  4. `[CACHE]`：可选，是否存储在 CMake 缓存中。

---

### 2️⃣ `tinycoro_test_filename`

* 这是输出变量名。
* 执行完这条命令后，它会保存提取出来的文件名部分。

---

### 3️⃣ `${tinycoro_test_source}`

* 这是输入的文件路径变量。
* 比如：

```cmake
set(tinycoro_test_source tests/test_main.cpp)
```

---

### 4️⃣ `NAME`

* 这是 `<component>` 参数，表示只提取文件名（不包含路径）。
* 举例：

```cmake
# 假设 tinycoro_test_source = tests/test_main.cpp
get_filename_component(tinycoro_test_filename ${tinycoro_test_source} NAME)
# tinycoro_test_filename 的值 = test_main.cpp
```

* 常用其他 `<component>`：

  * `DIRECTORY` → 提取文件所在目录
  * `EXT` → 提取文件扩展名（如 `.cpp`）
  * `NAME_WE` → 提取文件名不带扩展名
  * `ABSOLUTE` → 转成绝对路径

---

### 5️⃣ 综合解释

这条命令的作用是：

> 从变量 `${tinycoro_test_source}` 所表示的路径中，提取出 **文件名部分**，并赋值给 `tinycoro_test_filename`。

**例子：**

```cmake
set(tinycoro_test_source tests/test_main.cpp)
get_filename_component(tinycoro_test_filename ${tinycoro_test_source} NAME)
message("文件名: ${tinycoro_test_filename}")
```

输出：

```
文件名: test_main.cpp
```

---

如果你愿意，我可以帮你画一个 **文件路径到 NAME/EXT/DIRECTORY 的可视化示意图**，直观理解 `get_filename_component` 的各种选项。

你希望我画吗？
