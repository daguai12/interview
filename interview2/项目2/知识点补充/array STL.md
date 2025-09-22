在 C++ 标准库中，`std::array` 是一个封装固定大小数组的容器，定义在 `<array>` 头文件中。它结合了 C 风格数组的高效性和 STL 容器的便捷接口，是处理固定长度序列的理想选择。

### 基本用法

#### 1. 包含头文件
使用 `std::array` 必须包含头文件：
```cpp
#include <array>
```

#### 2. 定义和初始化
```cpp
#include <array>
#include <iostream>

int main() {
    // 定义一个包含3个int元素的array
    std::array<int, 3> arr1;  // 未初始化
    
    // 初始化方式1：列表初始化
    std::array<int, 3> arr2 = {1, 2, 3};
    
    // 初始化方式2：聚合初始化（C++11及以上）
    std::array<int, 3> arr3{4, 5, 6};
    
    // 初始化方式3：全部元素设为相同值
    std::array<int, 3> arr4;
    arr4.fill(0);  // 所有元素设为0
}
```

#### 3. 元素访问
```cpp
std::array<int, 3> arr = {10, 20, 30};

// 方式1：下标访问（无越界检查）
std::cout << arr[0] << std::endl;  // 输出：10

// 方式2：at()方法（有越界检查，抛出out_of_range异常）
std::cout << arr.at(1) << std::endl;  // 输出：20

// 方式3：访问第一个和最后一个元素
std::cout << arr.front() << std::endl;  // 输出：10
std::cout << arr.back() << std::endl;   // 输出：30

// 方式4：通过数据指针访问
int* ptr = arr.data();  // 获取指向底层数组的指针
std::cout << ptr[2] << std::endl;  // 输出：30
```

#### 4. 容量相关
```cpp
std::array<int, 5> arr;

// 固定大小，size()和max_size()返回值相同
std::cout << "大小: " << arr.size() << std::endl;       // 输出：5
std::cout << "最大容量: " << arr.max_size() << std::endl;  // 输出：5

// 判断是否为空（对于非0大小的array，始终返回false）
std::cout << std::boolalpha << "是否为空: " << arr.empty() << std::endl;  // 输出：false
```

#### 5. 迭代器操作
```cpp
#include <array>
#include <iostream>
#include <algorithm>  // 用于sort等算法

int main() {
    std::array<int, 4> arr = {3, 1, 4, 2};
    
    // 正向迭代
    std::cout << "正向遍历: ";
    for (auto it = arr.begin(); it != arr.end(); ++it) {
        std::cout << *it << " ";
    }
    // 输出：3 1 4 2
    
    // 反向迭代
    std::cout << "\n反向遍历: ";
    for (auto it = arr.rbegin(); it != arr.rend(); ++it) {
        std::cout << *it << " ";
    }
    // 输出：2 4 1 3
    
    // 使用范围for循环
    std::cout << "\n范围for循环: ";
    for (int num : arr) {
        std::cout << num << " ";
    }
    // 输出：3 1 4 2
    
    // 排序（使用STL算法）
    std::sort(arr.begin(), arr.end());
    std::cout << "\n排序后: ";
    for (int num : arr) {
        std::cout << num << " ";
    }
    // 输出：1 2 3 4
}
```

#### 6. 赋值与交换
```cpp
std::array<int, 3> arr1 = {1, 2, 3};
std::array<int, 3> arr2 = {4, 5, 6};

// 赋值
arr1 = arr2;  // arr1 变为 {4, 5, 6}

// 交换
arr1.swap(arr2);  // arr1 变为 {1, 2, 3}，arr2 变为 {4, 5, 6}
```

### 注意事项

1. **固定大小**：`std::array` 的大小在编译时确定，定义后不能动态改变。

2. **与C风格数组的兼容性**：可以通过 `data()` 方法获取底层C风格数组的指针，方便与C接口交互：
   ```cpp
   std::array<int, 3> arr = {1, 2, 3};
   int* c_array = arr.data();  // 等同于 int c_array[] = {1,2,3};
   ```

3. **性能**：`std::array` 在性能上与C风格数组几乎一致，因为它不涉及动态内存分配，所有元素都存储在栈上（或包含它的对象所在的内存区域）。

4. **与其他容器的区别**：
   - 与 `std::vector` 相比：`std::array` 大小固定，不支持动态扩容；`std::vector` 大小可变，元素存储在堆上。
   - 与 `std::vector` 相同点：都支持STL容器的通用接口（迭代器、`size()`、`front()` 等）。

### 适用场景

- 需要固定大小的数组，且希望使用STL容器的便捷接口（如迭代器、算法兼容）。
- 对性能要求高，不希望动态内存分配的开销。
- 需要与C代码交互（通过 `data()` 转换为C风格数组）。

通过合理使用 `std::array`，可以在保证性能的同时，写出更安全、更易维护的代码。