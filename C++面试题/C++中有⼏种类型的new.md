-----

### `new` 的本质：两步操作

首先，我们需要理解一个普通的 `new` 表达式在概念上分为两个步骤：

1.  **内存分配**：调用一个名为 `operator new` 的函数，在堆上申请一块原始的、未初始化的内存。
2.  **对象构造**：在这块分配好的内存上，调用对象的构造函数，将其初始化为一个合法的对象。

C++提供的三种 `new` 的使用方式，主要是围绕着**如何处理第一步（内存分配）及其可能发生的失败**来展开的，而 `placement new` 则是一个完全跳过第一步的特例。

-----

### 1\. 普通 `new` (Plain `new`)

**口号：“要么成功，要么抛异常！”**

这是我们在C++代码中最常用、也是最标准的 `new` 表达式。

  * **行为**：它执行上述的内存分配和对象构造两个步骤。
  * **错误处理**：如果在第一步内存分配时失败（例如，L统内存耗尽），它会**抛出一个 `std::bad_alloc` 类型的异常**。程序流程会立即中断，并跳转到相应的 `catch` 块。
  * **比喻**：就像在一家严格的餐厅点餐。如果你点的菜（申请的内存）有，厨师就会做好端给你。如果菜卖完了（内存不足），餐厅经理会直接大声告诉你“订单失败，我们无法服务！”（抛出异常），而不是给你一个空盘子。

**使用方法**：
你必须使用 `try...catch` 块来捕获这个异常，否则程序会因未捕获的异常而终止。

```cpp
#include <iostream>
#include <new> // for std::bad_alloc

void use_plain_new() {
    try {
        // 尝试分配一个极大的、几乎不可能成功的内存块
        char* buffer = new char[1000000000000ULL]; 
        std::cout << "Plain new succeeded (unlikely)." << std::endl;
        delete[] buffer;
    }
    catch (const std::bad_alloc& e) {
        std::cerr << "Plain new failed: " << e.what() << std.endl;
    }
}
```

-----

### 2\. `nothrow new`

**口号：“不抛异常，只返空值。”**

这是 `new` 的一个变体，它遵循了C语言 `malloc` 的错误处理风格。

  * **行为**：同样执行内存分配和对象构造。
  * **错误处理**：如果在内存分配时失败，它**不会抛出异常**，而是会**返回一个 `nullptr`**。
  * **比喻**：就像去图书馆借书。如果图书管理员（内存管理器）找到了你要的书，就把它给你。如果没找到，他会递给你一张“未找到”的纸条（返回 `nullptr`），然后继续做别的事情。检查纸条并决定下一步做什么，是你自己的责任。

**使用方法**：
需要包含 `<new>` 头文件，并在 `new` 关键字后加上 `(std::nothrow)`。每次分配后，你必须**手动检查**返回的指针是否为 `nullptr`。

```cpp
#include <iostream>
#include <new> // for std::nothrow

void use_nothrow_new() {
    char* buffer = new(std::nothrow) char[1000000000000ULL];

    if (buffer == nullptr) {
        std::cerr << "Nothrow new failed: returned nullptr." << std::endl;
    } else {
        std::cout << "Nothrow new succeeded (unlikely)." << std::endl;
        delete[] buffer;
    }
}
```

**适用场景**：主要用于那些**禁用异常**的代码环境（例如某些嵌入式系统、游戏引擎的部分模块），或者是需要与大量C风格代码交互的项目。

-----

### 3\. 定位 `new` (Placement `new`)

**口号：“别管内存，只管构造！”**

这是一种非常特殊和高级的 `new` 用法。它**完全跳过了内存分配的步骤**。

  * **行为**：它不申请任何新内存。相反，它接收一个**已经分配好的内存地址**（一个指针），并在这块指定的内存上调用对象的构造函数。
  * **错误处理**：因为它不分配内存，所以它本身**永远不会失败**（除非提供的指针是无效的，但这属于调用者的错误）。
  * **比喻**：就像你已经买好了一块地皮（预先分配的内存 `buffer`），然后你请来一个建筑队（`placement new`），指着这块地皮说：“**就在这里 (`new(buffer)`)**，帮我盖一座房子 (`MyClass()`)”。建筑队只负责盖房子（构造对象），不负责买地（分配内存）。

#### **使用 `placement new` 的生命周期三部曲**

使用 `placement new` 必须严格遵循以下步骤，否则将导致严重错误：

1.  **准备内存**：首先，你需要自己准备一块足够大的、对齐正确的原始内存缓冲区。
2.  **构造对象**：使用 `placement new` 在这块内存上构造对象。
3.  **销毁与释放**：
    a. **手动调用析构函数**：由于 `delete` 会同时“析构对象”和“释放内存”，而这里的内存是我们自己管理的，所以**绝对不能**对 `placement new` 返回的指针使用 `delete`。我们必须**显式地、手动地调用对象的析构函数** (`ptr->~ClassName();`) 来清理对象资源。
    b. **释放原始内存**：最后，再通过与第一步对应的方式，释放原始的内存缓冲区（例如，如果缓冲区是用 `new char[]` 创建的，就用 `delete[]` 释放）。

**代码示例** (您的示例非常完美，这里稍作整理):

```cpp
#include <iostream>
#include <new>

class ADT {
public:
    ADT() { std::cout << "ADT object constructed." << std::endl; }
    ~ADT() { std::cout << "ADT object destructed." << std::endl; }
};

void use_placement_new() {
    // 1. 准备内存
    char* buffer = new char[sizeof(ADT)];
    std::cout << "Memory buffer allocated at: " << (void*)buffer << std::endl;

    // 2. 在 buffer 上构造 ADT 对象
    ADT* obj_ptr = new(buffer) ADT();

    // 3a. 手动调用析构函数
    std::cout << "Explicitly calling destructor..." << std::endl;
    obj_ptr->~ADT();

    // 3b. 释放原始内存缓冲区
    std::cout << "Deleting the original buffer..." << std::endl;
    delete[] buffer;
}
```

**适用场景**：主要用于对性能要求极高的场景，如**内存池（Memory Pool）**、自定义内存分配器、在特定硬件地址上创建对象等。

### 总结

| `new` 的类型           | 内存分配？ | 失败时行为               | 如何释放/销毁               | 主要用途         |
| :------------------ | :---- | :------------------ | :-------------------- | :----------- |
| **Plain `new`**     | ✅ 是   | 抛出 `std::bad_alloc` | `delete` / `delete[]` | C++通用动态内存分配  |
| **`nothrow new`**   | ✅ 是   | 返回 `nullptr`        | `delete` / `delete[]` | 禁用异常的环境      |
| **Placement `new`** | ❌ 否   | (不失败)               | 手动调用析构 + 释放原始内存       | 高性能内存管理，如内存池 |
