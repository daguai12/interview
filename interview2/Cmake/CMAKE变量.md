### **1. 变量定义**
- **含义**：`CMAKE_PROJECT_DIR` 指向**最顶层 `CMakeLists.txt` 文件所在的目录**。
- **对比**：
  - `CMAKE_CURRENT_SOURCE_DIR`：当前正在处理的 `CMakeLists.txt` 所在目录（可能是子目录）。
  - `CMAKE_SOURCE_DIR`：与 `CMAKE_PROJECT_DIR` 等价，二者完全相同。


### **2. 典型场景**
#### **（1）跨目录引用文件**
若项目结构为：
```
MyProject/
├── CMakeLists.txt      # 顶层 CMake 文件
├── src/
└── resources/
    └── config.ini
```
在子目录的 CMake 脚本中引用顶层资源：
```cmake
# src/CMakeLists.txt
SET(CONFIG_PATH ${CMAKE_PROJECT_DIR}/resources/config.ini)
```

#### **（2）生成相对路径**
```cmake
# 获取项目根目录到当前目录的相对路径
STRING(REPLACE "${CMAKE_PROJECT_DIR}/" "" REL_PATH "${CMAKE_CURRENT_SOURCE_DIR}")
MESSAGE(STATUS "当前目录相对于项目根的路径: ${REL_PATH}")
```

#### **（3）统一输出路径**
确保所有编译产物（如可执行文件、库）输出到顶层项目的 `bin/` 目录：
```cmake
SET(EXECUTABLE_OUTPUT_PATH ${CMAKE_PROJECT_DIR}/bin)
SET(LIBRARY_OUTPUT_PATH ${CMAKE_PROJECT_DIR}/lib)
```


### **3. 与其他变量的对比**
| 变量名                        | 含义                                   |
| -------------------------- | ------------------------------------ |
| `CMAKE_PROJECT_DIR`        | 顶层 CMakeLists.txt 所在目录（整个项目的根目录）。    |
| `CMAKE_CURRENT_SOURCE_DIR` | 当前正在处理的 CMakeLists.txt 所在目录（可能是子目录）。 |
| `CMAKE_SOURCE_DIR`         | 同 `CMAKE_PROJECT_DIR`（顶层目录）。         |
| `PROJECT_SOURCE_DIR`       | 当前项目（可能是子项目）的源代码目录。                  |


### **4. 注意事项**
- **单项目 vs 多项目**：  
  在单项目中，`CMAKE_PROJECT_DIR`、`CMAKE_SOURCE_DIR` 和 `PROJECT_SOURCE_DIR` 通常相同。  
  在多项目（子项目使用 `ADD_SUBDIRECTORY()`）中：
  - `CMAKE_PROJECT_DIR` 始终指向顶层目录，
  - `PROJECT_SOURCE_DIR` 指向当前子项目的目录。

- **嵌套层级**：  
  无论 CMakeLists.txt 嵌套多深，`CMAKE_PROJECT_DIR` 保持不变。


### **5. 示例**
假设项目结构：
```
MyApp/
├── CMakeLists.txt      # 顶层：PROJECT(MyApp)
├── src/
│   └── CMakeLists.txt  # 子目录
└── lib/
    └── CMakeLists.txt  # 子目录
```

在 `src/CMakeLists.txt` 中：
```cmake
MESSAGE(STATUS "顶层目录: ${CMAKE_PROJECT_DIR}")  # 输出 "/path/to/MyApp"
MESSAGE(STATUS "当前目录: ${CMAKE_CURRENT_SOURCE_DIR}")  # 输出 "/path/to/MyApp/src"
```


### **总结**
`CMAKE_PROJECT_DIR` 是 CMake 中用于定位顶层项目目录的关键变量，特别适合在子项目中引用顶层资源、统一输出路径或构建相对路径。理解它与 `CMAKE_CURRENT_SOURCE_DIR`、`PROJECT_SOURCE_DIR` 的区别，能避免路径相关的配置错误。