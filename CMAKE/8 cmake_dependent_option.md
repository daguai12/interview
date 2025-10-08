# 注意！！！
在使用的时候必须使用`include`引入`CMakeDependentOption`模块
### 案例场景

假设我们正在开发一个图像处理程序 `ImageProcessor`。这个程序有以下功能模块：

1.  **核心功能**：读取和显示图像（总是启用）。
2.  **可选功能 A**：应用滤镜（比如高斯模糊）。这个功能依赖一个外部库 `LibFilter`。
3.  **可选功能 B**：进行人脸识别。这个功能不仅依赖一个外部库 `LibFaceDetect`，**并且它必须在滤镜功能启用后才能使用**，因为它需要先对图像进行预处理（模糊）。

所以，我们有如下依赖关系：
`人脸识别 (USE_FACE_DETECT)` -\> `滤镜 (USE_FILTERS)`

如果用户想启用人脸识别，那么滤镜功能也必须被启用。如果用户禁用了滤镜功能，那么人脸识别功能应该被自动禁用，并且最好在 CMake GUI 中变灰，不允许用户勾选。

`cmake_dependent_option` 就是为了完美解决这种依赖关系而设计的。

-----

### `cmake_dependent_option` 语法解析

在开始案例前，我们先快速看一下它的语法：

```cmake
cmake_dependent_option(
  <option_name>    # 选项的变量名，例如 USE_FACE_DETECT
  "<description>"    # 选项的描述文字
  <default_value>  # 如果依赖满足，该选项的默认值 (ON/OFF)
  <depends>        # 一个或多个依赖条件，用分号隔开的字符串
  <force>          # (可选) 如果依赖不满足，是否强制清除该选项的值
)
```

  - **`<depends>`**: 这是核心。它是一个表达式，其格式与 `if()` 命令的条件相同。只有当这个表达式为真时，这个选项才“有意义”并且可以被用户设置为 `<default_value>` 或手动更改。
  - **`<force>`**: 通常我们把它设为 `OFF` 或省略。当依赖不满足时，它会将 `<option_name>` 的值从缓存中清除，从而使其“消失”。

-----

### 案例项目结构

我们来搭建一个简单的项目结构来模拟这个场景。

```
cmake-dependent-option-example/
├── CMakeLists.txt
├── main.cpp
├── lib_filter/
│   ├── CMakeLists.txt
│   └── filter.cpp
└── lib_face_detect/
    ├── CMakeLists.txt
    └── face_detect.cpp
```

-----

### 代码实现

#### 1\. 顶层 `CMakeLists.txt`

这是我们配置的核心，`cmake_dependent_option` 将在这里使用。

```cmake
# CMakeLists.txt

cmake_minimum_required(VERSION 3.10)
project(ImageProcessor CXX)

# --- 选项定义 ---

# 1. 定义第一个可选功能：滤镜
# 这是一个常规的、独立的选项。我们假设它默认是开启的。
option(USE_FILTERS "Enable image filtering functionality" ON)

# 2. 定义第二个可选功能：人脸识别
# 这个选项依赖于 USE_FILTERS。
# - 变量名: USE_FACE_DETECT
# - 描述: "Enable face detection (requires filters)"
# - 默认值: ON (如果依赖满足，默认也开启它)
# - 依赖条件: "USE_FILTERS" (一个字符串，内容是依赖的变量名)
# - Force: OFF (如果USE_FILTERS为OFF，就清除USE_FACE_DETECT的值)
cmake_dependent_option(
  USE_FACE_DETECT
  "Enable face detection (requires filters)"
  ON
  "USE_FILTERS"
  OFF
)

# --- 配置和构建 ---

# 根据选项包含子目录
if(USE_FILTERS)
  message(STATUS "Filters enabled.")
  add_subdirectory(lib_filter)
endif()

if(USE_FACE_DETECT)
  # 注意：因为上面的依赖关系，如果这个if为真，那么USE_FILTERS也必然为真
  message(STATUS "Face detection enabled.")
  add_subdirectory(lib_face_detect)
endif()

# 创建主程序
add_executable(ImageProcessor main.cpp)

# 根据选项链接库
if(USE_FILTERS)
  target_link_libraries(ImageProcessor PRIVATE FilterLib)
endif()

if(USE_FACE_DETECT)
  target_link_libraries(ImageProcessor PRIVATE FaceDetectLib)
endif()

# 根据选项添加编译定义，以便在C++代码中判断
if(USE_FILTERS)
  target_compile_definitions(ImageProcessor PRIVATE WITH_FILTERS)
endif()

if(USE_FACE_DETECT)
  target_compile_definitions(ImageProcessor PRIVATE WITH_FACE_DETECT)
endif()
```

#### 2\. 子模块的 `CMakeLists.txt`

这些文件非常简单，只是用来创建对应的库。

**`lib_filter/CMakeLists.txt`**:

```cmake
# lib_filter/CMakeLists.txt
add_library(FilterLib filter.cpp)
```

**`lib_face_detect/CMakeLists.txt`**:

```cmake
# lib_face_detect/CMakeLists.txt
add_library(FaceDetectLib face_detect.cpp)
```

#### 3\. 简单的 C++ 源代码

为了让项目能跑起来，我们创建一些简单的占位代码。

**`main.cpp`**:

```cpp
#include <iostream>

void apply_filters() {
    #ifdef WITH_FILTERS
    std::cout << "Applying filters..." << std::endl;
    #endif
}

void detect_faces() {
    #ifdef WITH_FACE_DETECT
    std::cout << "Detecting faces..." << std::endl;
    #endif
}

int main() {
    std::cout << "ImageProcessor running!" << std::endl;

    #ifndef WITH_FILTERS
    std::cout << "Filter functionality is disabled." << std::endl;
    #endif

    #ifndef WITH_FACE_DETECT
    std::cout << "Face detection functionality is disabled." << std::endl;
    #endif

    apply_filters();
    detect_faces();

    return 0;
}
```

**`lib_filter/filter.cpp`**:

```cpp
// 空文件即可，或者加个函数定义
```

**`lib_face_detect/face_detect.cpp`**:

```cpp
// 空文件即可
```

-----

### 实验与验证

现在，让我们来验证 `cmake_dependent_option` 的效果。

1.  创建一个构建目录：

    ```bash
    mkdir build
    cd build
    ```

2.  **情况一：默认配置**
    运行 CMake，不带任何参数。

    ```bash
    cmake ..
    ```

    输出会包含：

    ```
    -- Filters enabled.
    -- Face detection enabled.
    -- Configuring done
    -- Generating done
    -- Build files have been written to: .../build
    ```

    此时，`USE_FILTERS` 为 `ON` (默认值)，依赖满足，所以 `USE_FACE_DETECT` 也为 `ON` (它的默认值)。

3.  **情况二：手动禁用滤镜功能 `USE_FILTERS`**
    现在，我们通过命令行参数把 `USE_FILTERS` 关掉。

    ```bash
    cmake .. -DUSE_FILTERS=OFF
    ```

    观察 CMake 的输出：

    ```
    -- Configuring done
    -- Generating done
    -- Build files have been written to: .../build
    ```

    你会发现，"Filters enabled." 和 "Face detection enabled." 这两条消息都没有了！
    这是因为：

      - 我们设置了 `USE_FILTERS=OFF`。
      - `cmake_dependent_option` 检测到 `USE_FACE_DETECT` 的依赖条件 `"USE_FILTERS"` 不满足。
      - 因此，CMake 自动将 `USE_FACE_DETECT` 从缓存中移除（因为我们设置了 `FORCE OFF`），它的值变为 "OFF-NOTFOUND"，在 `if(USE_FACE_DETECT)` 判断中为 `false`。

    你可以用 `cmake -L ..` 查看缓存变量来确认：

    ```bash
    cmake -L .. -DUSE_FILTERS=OFF
    # 输出会类似这样:
    # USE_FILTERS:BOOL=OFF
    # USE_FACE_DETECT:BOOL=OFF
    ```

    `USE_FACE_DETECT` 自动变成了 `OFF`。

4.  **情况三：尝试在禁用滤镜的同时强制启用人脸识别（错误操作）**
    让我们看看如果一个不了解依赖关系的用户试图这样做会发生什么。

    ```bash
    cmake .. -DUSE_FILTERS=OFF -DUSE_FACE_DETECT=ON
    ```

    CMake 仍然会正确处理。`cmake_dependent_option` 的优先级更高。它会先评估依赖，发现 `USE_FILTERS` 是 `OFF`，于是它会强制把 `USE_FACE_DETECT` 的值重置为无效/`OFF`，即使用户在命令行中把它设为了 `ON`。最终的结果和情况二完全一样。

5.  **在 `cmake-gui` 或 `ccmake` 中的表现**
    这是 `cmake_dependent_option` 最直观的优点。

      - 运行 `ccmake ..` 或 `cmake-gui ..`。
      - 当 `USE_FILTERS` 的复选框被勾选 (ON) 时，`USE_FACE_DETECT` 是一个正常的选项，可以自由勾选或取消。
      - 当你 **取消勾选 `USE_FILTERS`** 并按 `c` (configure) 之后，你会立刻看到 **`USE_FACE_DETECT` 选项变灰了**，无法再被编辑。它会显示 "depends on USE\_FILTERS" 这样的信息。

    这种交互方式极大地提升了用户体验，从根本上防止了用户创建一个无效的、无法编译的配置组合。

### 对比：如果不使用 `cmake_dependent_option` 会怎样？

如果不使用它，你可能需要这样写：

```cmake
option(USE_FILTERS "Enable image filtering functionality" ON)
option(USE_FACE_DETECT "Enable face detection" ON) # 这是一个独立的选项

if(USE_FACE_DETECT AND NOT USE_FILTERS)
  message(FATAL_ERROR "Face Detection requires the Filter functionality! Please enable USE_FILTERS.")
endif()
```

这种方法的缺点：

1.  **不直观**：用户可以在 GUI 中勾选 `USE_FACE_DETECT` 同时不勾选 `USE_FILTERS`。
2.  **错误后置**：只有在配置（configure）时才会报错，而不是在选择时就给出提示。
3.  **代码繁琐**：如果依赖关系更复杂（比如 A 依赖 B 和 C），你需要写更复杂的 `if` 判断逻辑。

### 总结

`cmake_dependent_option` 是一个非常实用的命令，专门用于创建具有依赖关系的可选功能开关。

**核心优势**：

1.  **逻辑清晰**：将选项的依赖关系直接声明在定义处，代码更易读。
2.  **用户友好**：在 `cmake-gui` 等图形化工具中，当依赖不满足时，选项会自动变灰、不可用，直观地告诉用户配置规则。
3.  **健壮性**：从机制上防止用户创建出矛盾和无法编译的配置，提高了构建系统的稳健性。

在任何一个模块化、功能可配置的 CMake 项目中，只要出现了“启用功能B的前提是必须先启用功能A”这类需求，`cmake_dependent_option` 就是最佳选择。