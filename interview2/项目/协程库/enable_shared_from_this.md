#  使用背景

假设你有一个类 `MyClass`，并且你用 `std::shared_ptr` 来管理其实例。有时候，你希望在类的成员函数中获取指向自身的 `shared_ptr`，比如：

```cpp
std::shared_ptr<MyClass> ptr = std::make_shared<MyClass>();
ptr->doSomething(); // 在 doSomething 内部想要获得 ptr
```

这时候，如果你在 `doSomething()` 中尝试构造 `shared_ptr<MyClass>(this)`，**会出问题**，因为这样会造成两个 `shared_ptr` 管理同一个原始指针，从而导致 **两次析构**，是未定义行为。

#  正确的做法 —— 使用 `std::enable_shared_from_this`

它的作用是：**允许对象通过 `shared_from_this()` 成员函数获得一个与当前对象共享所有权的 `shared_ptr`。**

##  示例

```cpp
#include <iostream>
#include <memory>

class MyClass : public std::enable_shared_from_this<MyClass> {
public:
    void show() {
        std::shared_ptr<MyClass> self = shared_from_this();
        std::cout << "shared_from_this() use_count = " << self.use_count() << std::endl;
    }
};

int main() {
    std::shared_ptr<MyClass> ptr = std::make_shared<MyClass>();
    ptr->show(); // 输出: shared_from_this() use_count = 2
}
```

#### 输出解释：

* `ptr` 是原始的 `shared_ptr`
* `shared_from_this()` 返回的是另一个 `shared_ptr`，和 `ptr` **共享所有权**
* 所以 use\_count 是 2（两个 shared\_ptr 管理一个对象）

#  使用注意事项

1. **你必须用 `shared_ptr` 创建对象（比如用 `std::make_shared<T>`）**
   否则 `shared_from_this()` 会抛出 `std::bad_weak_ptr` 异常：

   ```cpp
   MyClass obj;                      // 错误：不是通过 shared_ptr 管理的
   obj.show();                       // 调用 shared_from_this() 会崩溃
   ```

2. **`enable_shared_from_this` 应当通过继承使用，并且是公共继承（public）**
   这样才能让 `shared_from_this()` 正常工作。


#  内部机制原理

* `enable_shared_from_this` 内部维护了一个 `std::weak_ptr<T>` 成员 `_weak_this`
* 当你通过 `std::shared_ptr<T>` 创建对象时（如 `make_shared`），构造过程会自动将该 `weak_ptr` 与当前 `shared_ptr` 关联
* `shared_from_this()` 本质上是 `return _weak_this.lock();`，生成新的 `shared_ptr`，不会重复计数


#  典型应用场景

* 异步任务、回调注册时需要获取自身生命周期引用
* 观察者模式中发布者通知时保护自身不被析构
* 将自身作为参数传给需要 `shared_ptr` 的外部接口



# 错误使用情况

```cpp
#include <iostream>
#include <memory>

class MyClass {
public:
    void show() {
        // 错误示范：直接构造 shared_ptr(this)
        std::shared_ptr<MyClass> self(this); // ❌危险！
        std::cout << "use_count: " << self.use_count() << std::endl;
    }
};

int main() {
    std::shared_ptr<MyClass> ptr = std::make_shared<MyClass>();
    ptr->show();  // ❌未定义行为
}
```

- 出错原因
	- 已经使用`std::make_shared<Myclass>()`创建了一个`shared_ptr`来管理`MyClass`的生命周期。
	- `show()`里使用`this`构造了一个新的`shared_ptr<MyClass>`,这会导致**两个**`shared_ptr`分别管理一个原始指针。
	- 析构时会发送双重delete，造成程序崩溃或未定义行为。


----- 


## 🔥 为什么不能用 `shared_ptr<T>(this)`？

因为这会创建一个新的 `shared_ptr`，它会 **单独管理** 这个 `this` 指针，与外部已有的 `shared_ptr` 无关。最终会导致：

* 两个 `shared_ptr` 管理同一个对象（`this`）
* 在引用计数为 0 时，**析构函数会被调用两次**
* 造成 **二次释放（double delete）**
* 引发程序崩溃或更严重的未定义行为

---

## ✅ 正确的做法 —— 使用 `shared_from_this()`

如果你的类继承了 `std::enable_shared_from_this<T>`，你就可以在任何成员函数中安全地调用：

```cpp
std::shared_ptr<T> p = shared_from_this();
```

这会返回一个与当前对象 **共享引用计数** 的 `shared_ptr`，避免了任何重复释放问题。

---

## 🧪 示例对比

### ❌ 错误用法（会双重 delete）：

```cpp
class MyClass {
public:
    std::shared_ptr<MyClass> getPtr() {
        return std::shared_ptr<MyClass>(this); // ❌危险
    }
};

int main() {
    auto p1 = std::make_shared<MyClass>();
    auto p2 = p1->getPtr();  // 会导致两份shared_ptr管理同一个指针
}
```

结果：程序很可能在运行结束时崩溃。

---

### ✅ 正确用法（使用 enable\_shared\_from\_this）：

```cpp
class MyClass : public std::enable_shared_from_this<MyClass> {
public:
    std::shared_ptr<MyClass> getPtr() {
        return shared_from_this(); // ✅安全
    }
};

int main() {
    auto p1 = std::make_shared<MyClass>();
    auto p2 = p1->getPtr();  // p1 和 p2 安全共享所有权
}
```

---

## ❗ 注意：必须由 `shared_ptr` 创建对象

```cpp
MyClass obj;                 // ❌普通对象
obj.getPtr();                // 抛出 std::bad_weak_ptr 异常
```

只有在对象 **最初由 `shared_ptr` 创建时**，`shared_from_this()` 才能正常工作。

---

## ✅ 总结

| 目的                           | 是否用 `shared_from_this()` | 是否安全        |
| ---------------------------- | ------------------------ | ----------- |
| 从对象内部获取自身的 `shared_ptr`      | ✅ 是                      | 安全，共享引用计数   |
| 用 `shared_ptr<T>(this)` 构造自身 | ❌ 否                      | 危险，可能导致二次析构 |

---

如果你希望我给出一个具体例子，比如模拟二次释放崩溃的场景，也可以马上演示。是否继续？
