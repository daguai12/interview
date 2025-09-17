### 核心思想

首先，我们要明确这两个关键字解决的是完全不同的问题：

  * **`static`**：主要用于控制变量的 **“生命周期（Lifetime）”** 和 **“链接性（Linkage）”**。它回答的是“这个变量能活多久？”和“在哪些地方可以看到它？”这两个问题。
  * **`const`**：主要用于施加 **“不可变性（Immutability）”** 的约束。它回答的是“这个变量的值或对象的状态可以被修改吗？”这个问题。

-----

### `static` 的作用

`static` 的含义会根据其使用的上下文而改变。

#### 1\. 不考虑类的情况

##### a) `static` 修饰全局变量/函数：改变链接性（隐藏）

默认情况下，全局变量和函数具有**外部链接（External Linkage）**，意味着它们在整个程序的所有文件中都是可见的。使用 `static` 修饰后，其链接性会变为**内部链接（Internal Linkage）**，意味着它们只在自己所在的源文件（.cpp）中可见。

```cpp
// ---- utils.cpp ----
static int s_secret_counter = 0; // 内部链接，只能在 utils.cpp 内部使用

void public_function() {
    s_secret_counter++; // OK
}

// ---- main.cpp ----
// extern int s_secret_counter; // 尝试链接到 s_secret_counter

int main() {
    // s_secret_counter++; // 链接错误！无法找到 s_secret_counter 的定义
                       // "unresolved external symbol"
    return 0;
}
```

##### b) `static` 修饰局部变量：改变生命周期

当 `static` 用于函数内部的局部变量时，它会将该变量的存储位置从**栈（Stack）移动到静态存储区**。

  * **生命周期**：变量的生命周期延长至整个程序的运行期间，而不是函数调用期间。
  * **初始化**：只会在程序第一次执行到该定义时**初始化一次**。
  * **记忆性**：函数退出后，该变量的值会**得以保留**，下次再进入该函数时，它会延续上次的值。

<!-- end list -->

```cpp
#include <iostream>

void counter_function() {
    static int call_count = 0; // 只在第一次调用时初始化为 0
    std::cout << "This function has been called " << ++call_count << " times." << std::endl;
}

int main() {
    counter_function(); // 输出: ... called 1 times.
    counter_function(); // 输出: ... called 2 times.
    counter_function(); // 输出: ... called 3 times.
    return 0;
}
```

#### 2\. 考虑类的情况

##### a) `static` 成员变量

它是一个与**类本身关联**，而不是与类的某个特定对象关联的变量。所有该类的对象共享这一个 `static` 成员变量。

  * **存储**：它不存储在任何对象内部，而是单独存放在静态存储区。
  * **初始化**：必须在类的外部进行定义和初始化。
  * **访问**：可以通过类名直接访问（`ClassName::var`），也可以通过对象访问。

<!-- end list -->

```cpp
class Player {
public:
    static int active_players; // 声明 static 成员变量
    Player() { active_players++; }
    ~Player() { active_players--; }
};

int Player::active_players = 0; // 定义并初始化 static 成员变量

int main() {
    std::cout << "Active players: " << Player::active_players << std::endl; // 输出 0
    Player p1;
    Player p2;
    std::cout << "Active players: " << Player::active_players << std::endl; // 输出 2
    {
        Player p3;
        std::cout << "Active players: " << p1.active_players << std::endl; // 输出 3
    }
    std::cout << "Active players: " << Player::active_players << std::endl; // 输出 2
}
```

##### b) `static` 成员函数

它是一个与**类本身关联**的函数，不与任何特定对象绑定。

  * **`this` 指针**：它**没有 `this` 指针**，因为它不作用于任何具体对象。
  * **访问限制**：因此，它不能直接访问非 `static` 成员变量或调用非 `static` 成员函数（因为这些都需要 `this` 指针来确定是哪个对象的数据）。
  * **调用**：主要通过类名来调用（`ClassName::func()`）。

<!-- end list -->

```cpp
class MathHelper {
public:
    static int add(int a, int b) { // static 成员函数
        // secret_factor++; // 错误！不能访问非 static 成员
        return a + b;
    }
private:
    int secret_factor;
};

int main() {
    int sum = MathHelper::add(5, 3); // 直接通过类名调用
    std::cout << "Sum: " << sum << std::endl; // 输出 8
}
```

-----

### `const` 的作用

#### 1\. 不考虑类的情况

##### a) `const` 修饰变量：定义常量

`const` 变量在定义时必须初始化，之后其值不能被修改。

> **补充重要知识点**：您提到的 `const` 全局变量也具有**内部链接**，这一点完全正确！这是 C++ 为了方便在头文件中定义常量而设定的规则。
>
> ```cpp
> // ---- my_constants.h ----
> const int MAX_BUFFER_SIZE = 1024; // 默认是内部链接，每个包含它的.cpp文件会有一份独立的拷贝
> ```

##### b) `const` 修饰函数参数

主要用于指针和引用，表示函数内部不会修改该参数所指向或引用的原始数据，这是一种重要的接口承诺。

```cpp
void print_message(const std::string& message) {
    // message = "new message"; // 错误！不能修改 const 引用
    std::cout << message << std::endl;
}

int main() {
    std::string my_msg = "Hello";
    const std::string const_msg = "World";
    print_message(my_msg);    // OK
    print_message(const_msg); // OK
}
```

#### 2\. 考虑类的情况

##### a) `const` 成员变量

表示该成员变量是对象的一部分，但一旦在对象构造时被初始化，就不能再被修改。

  * **初始化**：它**不能**在声明时初始化，也**不能**在构造函数体内赋值，必须通过**构造函数的初始化列表**进行初始化。

<!-- end list -->

```cpp
class User {
public:
    const int USER_ID;
    User(int id) : USER_ID(id) { // 必须在初始化列表中初始化
        // USER_ID = id; // 错误！
    }
};
```

##### b) `const` 成员函数

在函数声明的末尾加上 `const` 关键字，例如 `void print() const;`。

  * **承诺**：它向编译器和调用者承诺，**该函数不会修改对象的任何（非 `mutable`）成员变量**。
  * **`this` 指针**：在 `const` 成员函数内部，`this` 指针的类型是 `const ClassName*`，即一个指向常对象的指针。
  * **调用规则**：
      * `const` 对象**只能**调用 `const` 成员函数。
      * 非 `const` 对象**既可以**调用 `const` 成员函数，也可以调用非 `const` 成员函数。

<!-- end list -->

```cpp
class Point {
public:
    int x, y;
    mutable int get_count = 0; // mutable 变量可以在 const 函数中被修改

    Point(int x_val, int y_val) : x(x_val), y(y_val) {}

    void set(int new_x, int new_y) {
        x = new_x;
        y = new_y;
    }

    void print() const { // const 成员函数
        // x = 10; // 错误！不能修改非 mutable 成员
        get_count++; // OK，因为 get_count 是 mutable
        std::cout << "(" << x << ", " << y << ")" << std::endl;
    }
};

int main() {
    const Point p1(10, 20);
    // p1.set(5, 5); // 错误！const 对象不能调用非 const 成员函数
    p1.print();      // OK

    Point p2(30, 40);
    p2.set(6, 6);    // OK
    p2.print();      // OK
}
```
