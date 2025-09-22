

## 📖 `include_directories` 和 `target_include_directories` 的用法对比

---

## ① `include_directories`

### 📌 作用：

- 设置**全局性的头文件搜索路径**
    
- 所有后续定义的 target（add_executable、add_library）都会受到影响。
    

### 📌 基本用法：

```cmake
include_directories(${CMAKE_SOURCE_DIR}/include)
```

### 📌 特点：

- **作用范围广**，对当前 CMakeLists.txt 中定义的所有 target 都有效（包括子目录中的 CMakeLists.txt，除非你手动限制作用域）。
    
- 适合**小型项目**或者**临时调试**
    

---

## ② `target_include_directories`

### 📌 作用：

- 给**指定的 target** 添加头文件搜索路径。
    

### 📌 基本用法：

```cmake
target_include_directories(MyApp PRIVATE ${CMAKE_SOURCE_DIR}/include)
```

### 📌 特点：

- **作用范围只限于指定 target**
    
- 配置更加清晰、可控，适合现代 CMake 推荐写法。
    
- 可以指定路径的作用域（PUBLIC、PRIVATE、INTERFACE）
    

#### 📌 作用域说明：

- `PRIVATE`：仅本 target 使用
    
- `PUBLIC`：本 target 和依赖它的 target 都使用
    
- `INTERFACE`：只有依赖它的 target 使用，本 target 本身不使用
    

```cmake
target_include_directories(MyLib
  PUBLIC ${CMAKE_SOURCE_DIR}/lib/include
)
```

---

## 📊 总结对比表：

|特性|include_directories|target_include_directories|
|:--|:--|:--|
|设置方式|全局性设置|只针对某个 target|
|影响范围|当前 CMakeLists 及其子目录中的所有 target|仅限指定 target|
|是否支持作用域（PRIVATE等）|❌|✅|
|推荐程度|不推荐（老式写法）|推荐（现代 CMake标准）|

---

## 📌 举例场景

- 小项目/快速调试：`include_directories`
    
- 中大型项目/多人协作/库开发：`target_include_directories`
    


set(CMAKE_EXPORT_COMPILE_COMMANDS ON)