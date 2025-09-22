# 对象使用过程中背后调用了哪些方法

##  一、临时对象（Temporary Object）

### 1. **显式构造的临时对象**

```cpp
Test t4 = Test(20);
```

* 语法上是构造一个临时对象再拷贝给 `t4`，但编译器**优化**后直接调用构造函数构造 `t4`，**不会调用拷贝构造函数**（拷贝消除优化）。

### 2. **临时对象参与赋值**

```cpp
t4 = Test(30);
```

* `Test(30)` 构造临时对象 → 调用赋值运算符。
* 临时对象在语句末尾被析构。

### 4. **隐式类型转换**

```cpp
t4 = 30;
```

* 编译器自动将 `int 30` 转换为 `Test(30)`，再赋值。


### 5. **强制类型转换**

```cpp
t4 = (Test)30;
```

* `(Test)30` 表示调用 `Test(int)` 构造临时对象，再调用赋值运算符。

##  二、对象生命周期与临时对象使用

### 1. **使用地址访问临时对象（危险）**

```cpp
Test* p = &Test(40);
```

* **临时对象生命周期只到语句末尾**，因此 `p` 指向已析构对象 → **悬垂指针**，**不安全行为**。

### 2. **用 const 引用延长临时对象生命周期**

```cpp
const Test& ref = Test(50);
```

* 引用绑定延长了 `Test(50)` 的生命周期，直到 `ref` 作用域结束。
* 这是访问临时对象的**安全做法**。



##  三、编译器优化：返回值优化（RVO）

```cpp
Test t4 = getObject();
```

* 虽然从语义上是：

  1. 构造临时对象 `Test(20)`
  2. 拷贝构造给 `t4`
* 但编译器**优化掉拷贝构造函数调用**，直接构造 `t4`。


# 函数调用过程中对象背后调用的方法

```cpp
class Test
{
	...
};

Test GetObject(Test t)
{
	int val = t.getData();
	Test tmp(val);
	return tmp;
}

int main()
{
	Test t1;
	Test t2;
	t2 = GetObject(t1);
}
```

>函数形参是值传递时，本质上是“拷贝初始化”过程。

因此：
- 不会调用默认构造 + 赋值
- 而是调用拷贝构造（或移动构造）

# 总结三条对象优化的规则

1. 函数传递过程中，对象优先按引用传递，不要按值传递。
2. 函数返回对象的时候，应该优先返回一个临时对象，而不要返回一个定义过的对象。
3. 接收返回值是对象的函数调用的时候，优先按初始化的方式接收，不要按赋值的方式接收。


# 带右值引用参数的拷贝构造和赋值函数

```cpp
#include <iostream>
#include <string.h>
using namespace std;

class CMyString
{
public:
  CMyString(const char* ptr = nullptr)
  { 
    if ( ptr == nullptr )
    {
      mp = new char[1];
      *mp = '\0';
    }
    else
    {
      mp = new char[strlen(ptr) + 1];
      strcpy(mp,ptr);
    }
    cout << "CMyString(char* ptr)" << endl; 
  }
  ~CMyString() { cout << "CMyString()" << endl; delete[] mp; }

  // 带左值引用参数的拷贝构造
  CMyString(const CMyString& rhs)
  {
    mp = new char[strlen(rhs.mp) + 1];
    strcpy(mp,rhs.mp);
    cout << "CMyString(const CMyString&)" << endl;
  }

  // 带右值引用参数的拷贝构造
  CMyString(CMyString&& str)
  {
    cout << "CMyString(MyString&&)" << endl;
    mp = str.mp;
    str.mp = nullptr;
    strcpy(mp,str.mp);
  }

  // 带左值引用参数的赋值预算函数
  CMyString operator=(CMyString& rhs)
  {
    cout << "operator=(CMyString&)" << endl;
    if (&rhs == this)
    {
      return *this;
    }
    delete[] mp;
    mp = new char[strlen(rhs.mp) + 1];
    strcpy(mp,rhs.mp);
    return *this;
  }

  // 带左值引用参数的赋值重载函数
  CMyString operator=(CMyString&& rhs) //临时对象
  {
    cout << "operator=(CMyString&&)" << endl;
    if (&rhs == this)
    {
      return *this;
    }
    delete[] mp;
    mp = rhs.mp;
    rhs.mp = nullptr;
  }

  const char* c_str()
  {
    return mp;
  }
private:
  char* mp;
};

CMyString GetString(CMyString& str)
{
  const char* pstr = str.c_str();
  CMyString tmpStr(pstr);
  return tmpStr;
} 

int main()
{
  CMyString str1("aaaaaaaaaaaaa");
  CMyString str2;
  str2 = GetString(str1);
  cout << str2.c_str() << endl;
  return 0;
}

#if 0
int main()
{
  // 右值引用
  int a = 10;
  int &b = a; //左值：有内存，有名字  

  /*
  int tmp = 20;
  const int&c = 20;
  */
  const int& c = 20;
  /*
  int tmp = 20;
  const int&c = 20;
  */
  int&& d = 20; //可以把一个右值绑定到一个右值引用上

  return 0;
}
#endif
```


# CMyString::operator=()优化

```cpp
/*
CMyString operator+(const CMyString& lhs, const CMyString& rhs)
{
  char* ptmp = new char[strlen(lhs.mp) + strlen(rhs.mp) + 1];
  strcpy(ptmp,lhs.mp);
  strcat(ptmp,rhs.mp);
  CMyString tmpStr(ptmp);
  delete[] ptmp;
  return tmpStr;
  // return CMyString(ptmp);
}
*/

// 优化版本的赋值重载运算符
CMyString operator+(const CMyString& lhs, const CMyString& rhs)
{
  CMyString tmpStr;
  tmpStr.mp = new char[strlen(lhs.mp) + strlen(rhs.mp) + 1];
  strcpy(tmpStr.mp,lhs.mp);
  strcat(tmpStr.mp,rhs.mp);
  return tmpStr;
}
```

# move移动语义和forward类型完美转发


## 一、`std::move`

### 1. 定义

`std::move` 是一个**类型转换函数**，用于将一个对象显式地转换为一个 **右值引用**（`T&&`），以便可以触发**移动语义**。

### 2. 用法场景

当你希望**转移资源的所有权**（比如动态内存、文件句柄、指针等）而不是复制它们时使用。

### 3. 示例代码：

```cpp
#include <iostream>
#include <utility>
#include <string>

int main() {
    std::string a = "hello";
    std::string b = std::move(a); // 移动构造，a 的资源被转移到 b

    std::cout << "a: " << a << "\n"; // a 可能为空（但有效）
    std::cout << "b: " << b << "\n"; // b: hello
}
```

### 4. 注意事项

* `std::move` **不会**真的移动任何东西，它只是一个**类型转换**，真正执行移动的是 **移动构造函数或移动赋值运算符**。
* `std::move` 之后不要再使用原对象，除非你明确知道它的状态（比如有效但为空）。


## 二、`std::forward`

### 1. 定义

`std::forward` 是一个用于实现\*\*完美转发（perfect forwarding）\*\*的工具，它根据传入参数的类型（左值或右值）**精确地保持其值类别**（lvalue/rvalue）。

### 2. 用法场景

通常与**模板函数**一起使用，用于将参数“原封不动”地传递给其他函数（比如构造函数或工厂函数），以保留其左值/右值特性。

### 3. 示例代码：

```cpp
#include <iostream>
#include <utility>

void process(int& x) {
    std::cout << "左值引用\n";
}

void process(int&& x) {
    std::cout << "右值引用\n";
}

template <typename T>
void forward_example(T&& arg) {
    process(std::forward<T>(arg)); // 保留值类别
}

int main() {
    int a = 10;
    forward_example(a);        // 输出：左值引用
    forward_example(20);       // 输出：右值引用
}
```

### 4. 注意事项

* `T&&` 在模板中是一个**万能引用（universal reference）**，只有在这种情况下才能使用 `std::forward`。
* 与 `std::move` 不同，`std::forward` 只能在模板中使用，用于保留传入实参的值类别。


# 智能指针基础知识

### 🚫 `auto_ptr`（已废弃）

* **特点**：

  * 拥有指针的唯一所有权。
  * 拷贝构造/赋值操作会**转移所有权**，原指针变为 `nullptr`。
* **问题**：

  * 所有权在拷贝时转移，容易造成误用或悬空指针。
  * 不能安全地用于 STL 容器（如 `vector<auto_ptr<T>>`），因为容器拷贝元素时会让原有指针变空，造成数据丢失。
* **结论**：**已废弃（C++11起）**，不推荐使用。

### ✅ `unique_ptr`（推荐使用）

* **特点**：

  * 独占式所有权，不能拷贝，只能移动。
  * 拷贝构造/赋值操作被禁用：

    ```cpp
    unique_ptr(const unique_ptr<T>&) = delete;
    unique_ptr<T>& operator=(const unique_ptr<T>&) = delete;
    ```
  * 可以通过移动构造/赋值来**安全转移所有权**：

    ```cpp
    unique_ptr(unique_ptr<T>&&);
    unique_ptr<T>& operator=(unique_ptr<T>&&);
    ```

* **推荐用法**：

  ```cpp
  template <typename T>
  unique_ptr<T> getSmartPtr() {
    unique_ptr<T> ptr(new T());
    return ptr; // 移动语义自动生效
  }
  
  unique_ptr<int> ptr1 = getSmartPtr<int>();
  ptr1 = getSmartPtr<int>();  // 移动赋值
  ```

# 实现带引用计数的智能指针

docode....

# share_ptr的交叉引用问题

##  一、智能指针基础（C++11 标准）

### 1. `shared_ptr<T>`

* 强引用智能指针。
* 拥有资源的**共享所有权**，每个 `shared_ptr` 会增加资源的引用计数。
* 引用计数为 0 时资源才会释放。

### 2. `weak_ptr<T>`

* 弱引用智能指针。
* **不会增加引用计数**，不能直接使用资源（需要通过 `lock()` 升级为 `shared_ptr` 才能访问）。
* 用于避免 `shared_ptr` 的循环引用问题。


##  二、强引用循环引用问题

### 场景：

两个类 `A` 和 `B` 中，互相持有对方的 `shared_ptr` 成员变量：

```cpp
shared_ptr<A> pa(new A());
shared_ptr<B> pb(new B());

pa->_ptrb = pb;
pb->_ptra = pa;
```

### 问题：

* `pa` 和 `pb` 在作用域结束后，本应释放内存。
* 但由于 `pa` 和 `pb` 互相持有彼此的 `shared_ptr`，引用计数无法为 0。
* **导致内存无法释放 —— 内存泄漏（资源泄漏）**。


##  三、解决方法：使用 `weak_ptr`

### 原则：

* **拥有对象：使用 `shared_ptr`**。
* **引用对象：使用 `weak_ptr`**。

### 示例改法：

* `A` 中持有 `weak_ptr<B>`，`B` 中持有 `weak_ptr<A>`，避免了相互增加引用计数。

```cpp
class A {
  weak_ptr<B> _ptrb; // 引用 B，但不拥有
};

class B {
  weak_ptr<A> _ptra; // 引用 A，但不拥有
};
```

### 使用方式：

* 使用 `weak_ptr` 时需要 `lock()` 获取 `shared_ptr` 才能访问对象：

```cpp
shared_ptr<A> ps = _ptra.lock(); // 升级为 shared_ptr
if (ps != nullptr) {
  ps->testA();
}
```


##  四、运行输出与解释

```cpp
shared_ptr<A> pa(new A());
shared_ptr<B> pb(new B());
pa->_ptrb = pb;
pb->_ptra = pa;
```

* 由于 `_ptrb` 和 `_ptra` 是 `weak_ptr`，所以 `use_count()` 正常为 1。
* 析构时，`~A()` 和 `~B()` 正常调用，没有内存泄漏。


## 📌 五、小结

| 智能指针类型       | 是否影响引用计数  | 用途           |
| ------------ | --------- | ------------ |
| `shared_ptr` | ✅ 增加引用计数  | 拥有对象，管理生命周期  |
| `weak_ptr`   | ❌ 不增加引用计数 | 避免循环引用，仅引用对象 |

> **设计建议：** 对象拥有关系用 `shared_ptr`，引用关系（特别是互相引用）用 `weak_ptr`，避免资源泄漏。


# 多线程访问共享对象的线程安全问题


##  一、`weak_ptr::lock()` 的作用

###  定义：

```cpp
std::shared_ptr<T> lock() const noexcept;
```

###  功能：

* **尝试获取被 `weak_ptr` 引用对象的 `shared_ptr`**。
* 如果所引用的对象还存在（引用计数 `>0`），返回一个指向该对象的 `shared_ptr`。
* 如果对象已经被释放，返回的是一个 **空的 `shared_ptr`（即 `nullptr`）**。


##  二、使用场景：配合 `weak_ptr` 安全访问资源

### 为什么要用 `lock()`？

* `weak_ptr` 本身 **不拥有资源**，也**不能直接访问资源**。
* 如果你想访问资源，必须**先调用 `lock()` 转换为 `shared_ptr`**。
* 这是一种**安全的访问方式**：只有当资源还没被释放时，访问才有效。


##  三、示例与分析

###  正确示例：

```cpp
void B::func()
{
  shared_ptr<A> ps = _ptra.lock(); // 尝试提升
  if (ps != nullptr)
  {
    ps->testA(); // 安全访问资源
  }
  else
  {
    cout << "A 已经被释放，不能访问" << endl;
  }
}
```

###  错误示例（未使用 `lock()`）：

```cpp
_ptra->testA(); // 错误：weak_ptr 不能直接解引用
```


##  四、底层原理：引用计数控制

* `shared_ptr` 内部有两个计数器：

  1. **use\_count（强引用计数）**
  2. **weak\_count（弱引用计数）**
* `weak_ptr::lock()` 会检查 `use_count`：

  * 如果 `use_count > 0`，说明资源还在，返回新的 `shared_ptr`。
  * 如果 `use_count == 0`，资源已释放，返回空指针。


##  五、使用建议和注意事项

| 项目     | 建议/注意事项                                          |
| ------ | ------------------------------------------------ |
| 安全性    | 使用 `lock()` 获取 `shared_ptr` 后一定要检查是否为 `nullptr`  |
| 性能     | `lock()` 的开销较低，不需要担心性能问题                         |
| 生命周期管理 | `weak_ptr` 不会导致循环引用，非常适合做观察者、回调等场景               |
| 替代错误写法 | 永远不要尝试对 `weak_ptr` 解引用或使用 `*`、`->`，只能通过 `lock()` |


##  六、总结一句话

> **`weak_ptr::lock()` 是在需要访问但不拥有资源的场合，通过“临时拥有”的方式，安全访问对象的一种机制。**


**example:**

```cpp
class A
{
public:
  A() {cout << "A()" << endl;}
  ~A() {cout << "~A()" << endl;}
  void testA() {cout << "非常好的方法" << endl;}

};


// 子线程
void handler01(weak_ptr<A> q)
{
  std::this_thread::sleep_for(std::chrono::seconds(2));
  // q访问A对象的时候，需要侦测一下A对象是否存活,
  shared_ptr<A> sp = q.lock();
  if (sp != nullptr)
  {
    sp->testA();
  }
  else
  {
    cout << "A object is destroy,use is no!" << endl;

  }
}

// main线程
int main()
{
  // A* p = new A();
  {
    shared_ptr<A> p(new A());
    thread t1(handler01,weak_ptr<A>(p));
    t1.detach();
  }
  // t1.join();
  std::this_thread::sleep_for(std::chrono::seconds(20));
  getchar();
  return 0;

}

```

# 自定义删除器


##  一、什么是智能指针的删除器（Deleter）

###  默认行为：

* `unique_ptr` 在对象生命周期结束时，**会调用默认的删除器**（`default_delete<T>`）来自动释放资源。

```cpp
~unique_ptr() { deletor(ptr); }  // 实际上就是调用一个函数对象
```

###  删除器的用途：

* 当资源的释放方式不标准（例如：

  * `new[]` 需要用 `delete[]`，
  * `fopen` 打开的文件需要用 `fclose` 关闭），
  * 就需要提供 **自定义的删除器** 来正确释放资源。

##  二、自定义删除器的使用方式

### 示例 1：数组删除器（`delete[]`）

```cpp
template <typename T>
class MyDeletor {
public:
  void operator()(T* ptr) const {
    cout << "call MyDeletor.operator()" << endl;
    delete[] ptr;
  }
};
```

使用方式：

```cpp
unique_ptr<int, MyDeletor<int>> ptr1(new int[100]);  // 使用 delete[]
```

---

### 示例 2：文件删除器（`fclose`）

```cpp
template <typename T>
class MyFileDeletor {
public:
  void operator()(T* ptr) const {
    cout << "call MyDeletor.operator()" << endl;
    fclose(ptr);
  }
};
```

使用方式：

```cpp
unique_ptr<FILE, MyFileDeletor<int>> ptr2(fopen("data.txt", "w"));
```

---

##  三、使用 Lambda 表达式作为删除器

###  函数式写法：

使用 `lambda` 作为删除器，可以避免专门写类，代码更简洁。

```cpp
unique_ptr<int, function<void(int*)>> ptr1(new int[100], [](int* p) {
  cout << "call lambda release new int[100]";
  delete[] p;
});
```

###  文件资源释放：

```cpp
unique_ptr<FILE, function<void(FILE*)>> ptr2(fopen("data.txt", "w"), [](FILE* p) {
  cout << "call lambda release FILE";
  fclose(p);
});
```

> 🔍 `function<void(FILE*)>` 表示这个 lambda 匿名函数是一个**可调用对象**，签名是 `void(FILE*)`。

##  注意事项

1. `unique_ptr<T>` 默认使用 `delete`，处理数组时要改用 `delete[]`。
2. 若自定义删除器类型不同，需要指定第二个模板参数。
3. `function<void(T*)>` 类型消耗资源较大，但通用性强。
4. 删除器必须满足 **可拷贝/可移动并可调用** 要求。

# bind1st和bind2nd什么时候会用到

##  一、函数对象（Function Object）

###  定义：

函数对象就是**重载了 `operator()` 的类对象**，行为类似函数。

###  标准库中的例子：

* `greater<int>`：返回 `a > b`
* `less<int>`：返回 `a < b`（默认排序函数）
* `plus<int>`、`minus<int>`、`multiplies<int>` 等


##  二、绑定器（Binder）机制

###  目的：

**将二元函数对象变成一元函数对象**，以配合 `find_if`、`for_each` 等只接受一元谓词的算法。

###  bind1st/bind2nd：

绑定一个参数为固定值，产生一元函数对象。

| 绑定器             | 效果                        | 示例说明                  |
| --------------- | ------------------------- | --------------------- |
| `bind1st(f, x)` | 把 `f(x, y)` 的第一个参数绑定为 `x` | `greater<int>(70, y)` |
| `bind2nd(f, y)` | 把 `f(x, y)` 的第二个参数绑定为 `y` | `less<int>(x, 70)`    |

###  示例：

```cpp
auto it = find_if(vec.begin(), vec.end(), bind1st(greater<int>(), 70));
```

相当于：

```cpp
[](int val) { return 70 > val; }
```

即找出 **第一个小于 70 的元素**。


##  三、函数对象 vs 函数指针 vs `std::function`

| 类型              | 描述                | 特点                    |
| --------------- | ----------------- | --------------------- |
| 函数对象            | 类中重载 `operator()` | 可携带状态，效率高，内联优化        |
| 函数指针            | 普通函数地址            | 功能单一，不支持捕获上下文         |
| `std::function` | 泛化的可调用包装器         | 灵活通用，可持有 lambda、函数对象等 |


##  四、重要 STL 算法函数回顾

| 函数                          | 作用                    |
| --------------------------- | --------------------- |
| `sort(begin, end)`          | 升序排序，默认使用 `less<T>()` |
| `sort(begin, end, comp)`    | 使用自定义比较器              |
| `find_if(begin, end, pred)` | 找第一个满足条件的元素           |
| `insert(pos, val)`          | 在迭代器 `pos` 位置插入元素     |


##  五、其他语言特性

### 1. `typename` 用法（模板细节）

```cpp
typename Container::iterator it;
```

原因：

* 在模板中，`Container::iterator` 是**依赖类型**，编译器不能确定它是类型，必须用 `typename` 显示说明。

example:

```cpp
template <typename Container>
void showContainer(Container &conn){
  typename Container::iterator it = conn.begin();
  for(;it != conn.end();++it){
    cout << *it << " ";
  }
  cout << endl;
}
```
如果不加typename，编译器就不知道iterator是类型还是变量。

##  六、C++11 引入新方式替代 bind1st/bind2nd

###  `std::bind` 示例（C++11）：

```cpp
find_if(vec.begin(), vec.end(), bind(greater<int>(), 70, placeholders::_1));
```

等价于：

```cpp
[](int val) { return 70 > val; }
```



# function函数对象类型的应用示例

```cpp
#include <iostream>
#include <map>
#include <functional>
#include <string>
using namespace std;

/*

*/

void hello1()
{
  cout << "hello world!" << endl;
}

void hello2(string str) //void (*pfunc) (string)
{
  cout << str << endl;
}

int sum(int a,int b)
{
  return a + b;
}

class Test
{
  public: //必须依赖一个对象 (Test::*pfunc)(string)
    void hello(string str) {cout << str << endl;}
};

void doShowAllBooks() {cout << "show all books" << endl;}
void doBorrow() {cout << "borrow books" << endl;}
void doBack() {cout << "还书" << endl;}
void doQueryBooks() {cout << "serach books" << endl;}
void doLoginOut() {cout << "logout" << endl;}

int main()
{
  int choice = 0;
  map<int,function<void()>> actionMap;
  actionMap.insert({1,doShowAllBooks});
  actionMap.insert({2,doBorrow});
  actionMap.insert({3,doBack});
  actionMap.insert({4,doQueryBooks});
  actionMap.insert({5,doLoginOut});
  for(;;)
  {
    cout << "------------" << endl;
    cout << "1.all books" << endl;
    cout << "2.books" << endl;
    cout << "3.back books" << endl;
    cout << "4.search books" << endl;
    cout << "5.logout" << endl;
    cout << "------------" << endl;
    cout << "choice";
    cin >> choice;
  }

  auto it = actionMap.find(choice); //map pair first second
  if (it == actionMap.end())
  {
    cout << "error choice" << endl;
  }
  else
  {
    it->second();
  }

#if 0
  switch (choice)
  {
    case 1:
    break;
    case 2:
    break;
    case 3:
    break;
    case 4:
    break;
    case 5:
    break;
    default:
    break;
  }
#endif
}
#if 0
int main()
{
  /*
  1.用函数类型实例化function
  2.通过function调用operator（）函数的时候，需要根据函数类型传入相应的参数
  */
  //从function的类模板定义处，看到希望用一个函数类型实例化function
  function<void()> func1(hello1);
  func1(); //func1.operator() => hello1()
  function<void(string)> func2(hello2);
  func2(string("hello world2"));

  function<int(int,int)> func3 = sum;
  cout << func3(20,30) << endl;

  function<int(int,int)> func4 = [](int a,int b)->int {return a + b;};
  cout << func4(100,200) << endl;

  Test test;
  function<void(Test*,string)> func5 = &Test::hello;
  func5(&test,"call Test::hello");
  getchar();
  return 0;
}
#endif
```

# function的实现原理
```cpp
void hello(string str) { cout << str << endl;}
int sum(int a,int b) { return a + b;}
int sum2(int a,int b,int c) { return a + b + c;}

template <typename FTY>
class myfunction
{};

#if 0
//模板的偏特化
template <typename R,typename A>
class myfunction<R(A)>
{
public:
  using FUNCTION = R(*)(A);
  myfunction(FUNCTION func): _func(func) {}
  R operator() (A arg){
    return _func(arg);
  }
private:
  FUNCTION _func;
};

template <typename R,typename A1,typename A2>
class myfunction<R(A1,A2)>
{
public:
  using FUNCTION = R(*)(A1,A2);
  myfunction(FUNCTION func): _func(func) {}
  R operator() (A1 arg1,A2 arg2){
    return _func(arg1,arg2);
  }
private:
  FUNCTION _func;
};
#endif

template <typename R,typename ...Arg>
class myfunction<R(Arg...)>
{
public:
  using FUNCTION = R(*)(Arg...);
  myfunction(FUNCTION func): _func(func) {}
  R operator() (Arg... arg)
  {
    return _func(arg...);
  }
private:
  FUNCTION _func;
};


int main()
{
  // function<void(string)> func1 = hello;
  // func1("hello world!"); //func1.operator() {"hello world!"}
  #if 0
  myfunction<void(string)> func1 = hello;
  myfunction<int(int,int)> func2 = sum;
  func1("helloWorld!");
  cout << func2(1,2) << endl;
  #endif
  myfunction<int(int,int,int)> func3 = sum2;
  cout << sum2(1,2,34) << endl;
  getchar();
  return 0;
}
```

# bind和function实现线程池

```cpp
class Thread
{
public:
  Thread(function<void()> func): _func(func) {}
  ~Thread() {}
  thread start(){
    thread t(_func);
    return t;
  }
private:
  function<void()> _func;
};

class ThreadPool
{
public:
  ThreadPool(int size): _size(size) {}
  ~ThreadPool() {
    for(int i = 0;i < _size;++i){
      delete _pool[i];
    }
  }
  void startLoop(){
    for(int i = 0;i < _size;++i){
      _pool.push_back(new Thread(bind(runInThread,this,i)));
    }
    for(int i = 0;i < _size;++i){
      _handler.push_back(_pool[i]->start());
    }
    for(auto& t : _handler)
    {
      t.join();
    }
  }
private:
  void runInThread(int id){
    cout << "call thread nums id:" << id << endl;
  }
  int _size;
  vector<Thread*> _pool;
  vector<thread> _handler;
};

int main()
{
  ThreadPool pool(4);
  pool.startLoop();
  getchar();
  return 0;
}
```

# lambda表达式的实现原理

C++ 中的 **lambda 表达式（Lambda Expression）** 本质上是 **编译器自动为你生成一个匿名的函数对象（类）**，其行为类似于你手写一个带 `operator()` 的类。


##  示例

```cpp
auto f = [](int a, int b) { return a + b; };
cout << f(3, 4); // 输出 7
```

上面的 lambda：

```cpp
[](int a, int b) { return a + b; }
```

大致等价于编译器生成这样的类：

```cpp
struct LambdaGenerated {
    int operator()(int a, int b) const {
        return a + b;
    }
};

// 使用
LambdaGenerated f;
cout << f(3, 4);
```


##  捕获变量的原理

当 lambda **捕获外部变量** 时（如 `[=]` 或 `[&]`），编译器会把这些变量变成类的成员变量。

### 示例：

```cpp
int x = 10;
auto f = [x](int a) { return a + x; };
```

大致等价于：

```cpp
struct LambdaCaptured {
    int x; // 捕获变量变成成员变量

    LambdaCaptured(int x_) : x(x_) {}

    int operator()(int a) const {
        return a + x;
    }
};

// 使用
int x = 10;
LambdaCaptured f(x);
f(5); // 等价于 f.operator()(5)，结果是 15
```


##  编译器生成 lambda 的原理总结

| Lambda 表达式   | 编译器做的事情（本质）               |
| ------------ | ------------------------- |
| `[](){}`     | 生成一个无捕获的函数对象类             |
| `[x](){}`    | 生成一个含成员变量 `x` 的类          |
| `[&x](){}`   | 生成一个含引用 `x` 的成员变量类        |
| `[](...) {}` | 重载 `operator()` 方法，实现调用行为 |


## 🚀 关键点（简记）

* Lambda 是一个**语法糖**，编译器自动为你创建一个 **匿名类**。
* 捕获列表决定了类成员变量和构造函数。
* `operator()` 实现了函数调用行为。
* `auto f = [](...) { ... };` 本质上是：创建一个“带 `()` 操作符的类对象”。




## 1. Lambda 与 `std::function` 结合使用

### 🎯 作用：

`std::function` 是一个**通用函数包装器**，可以用来存储 lambda 表达式、函数指针、函数对象。

### 示例：

```cpp
#include <iostream>
#include <functional>
using namespace std;

int main() {
    std::function<int(int, int)> func;

    func = [](int a, int b) {
        return a + b;
    };

    cout << func(2, 3) << endl; // 输出 5
    return 0;
}
```

### ✅ 优点：

* 支持多态函数对象。
* 可作为类成员、回调参数等传递。


## ✅ 2. Lambda 与 `std::bind` 结合使用

有时我们可以用 `std::bind` 简化 lambda 表达式，或者反之。

### 示例：

```cpp
#include <iostream>
#include <functional>
using namespace std;

void greet(string name, int age) {
    cout << "Hello, " << name << ". You are " << age << " years old." << endl;
}

int main() {
    auto f = std::bind(greet, "Alice", std::placeholders::_1);
    f(22); // 输出 Hello, Alice. You are 22 years old.
}
```

### 对等的 lambda：

```cpp
auto f = [](int age) { greet("Alice", age); };
```

> ✅ 用法互补：`std::bind` 可以用在需要函数指针的地方（如线程库），而 lambda 表达式在结构上更灵活。

---

## ✅ 3. Lambda 高级用法

---

### （1）捕获方式 `[=]`, `[&]`, `[this]`

```cpp
int x = 10, y = 20;

auto f1 = [=]() { return x + y; };  // 值捕获
auto f2 = [&]() { x += 5; return x + y; };  // 引用捕获

class MyClass {
public:
    int val = 42;
    void show() {
        auto f = [this]() { cout << val << endl; }; // 捕获 this 指针
        f();
    }
};
```

---

### （2）mutable 使捕获变量变“可变”

```cpp
int x = 10;
auto f = [x]() mutable {
    x += 5;       // 允许修改捕获的副本
    return x;
};

cout << f() << endl; // 15
cout << x << endl;   // 原始 x 仍是 10
```

---

### （3）递归 lambda（需要 `std::function`）

```cpp
function<int(int)> factorial = [&](int n) {
    return n <= 1 ? 1 : n * factorial(n - 1);
};

cout << factorial(5) << endl; // 输出 120
```

---

### （4）泛型 lambda（C++14 起）

```cpp
auto add = [](auto a, auto b) {
    return a + b;
};

cout << add(3, 4) << endl;       // 7
cout << add(1.5, 2.3) << endl;   // 3.8
```


## 📌 总结：什么时候用 lambda？

| 场景         | 建议用法                      |
| ---------- | ------------------------- |
| 需要临时函数或回调  | 用 lambda                  |
| 要绑定部分参数    | `std::bind` 或 lambda      |
| 要存储、传递函数对象 | `std::function` 配合 lambda |
| 有递归需求      | `std::function` + lambda  |

# lambda表达式的应用实践

## 使用lambda为自定义类型，定义比较运算符
```cpp
class Data
{
public:
  Data(int val1 = 10,int val2 = 10):ma(val1),mb(val2) {}
  // bool operator>(const Data& data) const {return ma > data.ma;}
  // bool operator<(const Data& data) const {return ma < data.ma;}
  int ma;
  int mb;
};
int main()
{
  using FUNC = function<bool(Data&,Data&)>;
  priority_queue<Data,vector<Data>,FUNC> maxHeap([](Data& d1,Data& d2)->bool{
      return d1.ma > d2.ma;
  });
  maxHeap.push(Data(10,20));
  maxHeap.push(Data(15,20));
  maxHeap.push(Data(20,10));

}
```

## 使用lambda定义删除器
```cpp
int main()
{
  //智能指针自定义删除器
  unique_ptr<FILE,function<void(FILE*)>> ptr1(fopen("data.txt","w"),[](FILE* fp)->void {fclose(fp);});
}
```

## 使用lambda定义函数对象
``` cpp
int main()
{
  map<int,function<int(int,int)>> caGculateMap;
  caculateMap[1] = [](int a,int b)->int {return a + b;};
  caculateMap[2] = [](int a,int b)->int {return a - b;};
  caculateMap[3] = [](int a,int b)->int {return a * b;};
  caculateMap[4] = [](int a,int b)->int {return a / b;};

  cout << "选择:" << endl;
  int choice;
  cin >> choice;
  cout << "10 + 15:" << caculateMap[choice](10,15) << endl;

  getchar();
  return 0;
}
```


# 通过thread类编写C++多线程程序


## 代码知识点总结：

### 一、`std::thread` 的使用

* `std::thread` 是 C++11 引入的线程库，创建线程的基本方法：

  ```cpp
  std::thread t1(threadHandle1);
  ```

  启动线程时，传入函数名和可选的参数，线程会**立即执行**。

### 二、线程函数的定义

* 线程函数可以是任意可调用对象（普通函数、lambda、成员函数等），这里使用的是普通函数：

  ```cpp
  void threadHandle1() { ... }
  ```

* 每个线程函数中使用：

  ```cpp
  std::this_thread::sleep_for(std::chrono::seconds(N));
  ```

  让线程“休眠”一段时间，模拟耗时任务或延迟执行。


### 三、主线程与子线程的关系

#### 1. **`join()`**

* 阻塞主线程，直到对应的子线程结束：

  ```cpp
  t1.join();
  ```
* 适用于：**主线程需要等待子线程完成后再继续工作**。

#### 2. **`detach()`**

* 将线程**分离（detach）**，独立运行，主线程不再关心它的状态：

  ```cpp
  t1.detach();
  ```
* 使用 detach 后，**不能再对该线程对象调用 join 或其他操作**。
* detach 后子线程可能在主线程结束前或后运行结束，需注意程序中资源共享的问题。


### 四、`getchar()` 的作用

* 程序末尾的：

  ```cpp
  getchar();
  ```

  用于**阻止主线程立刻退出**，给子线程足够时间执行（因为用了 `detach`）。

  否则主线程如果先退出，整个进程结束，**子线程来不及执行完就被强制终止**。


### 五、命名空间说明

* `std::this_thread` 是一个命名空间，提供与当前线程相关的工具：

  * `sleep_for`：当前线程休眠一定时间
  * `sleep_until`：休眠到某个时间点
  * `get_id`：获取当前线程 ID


## ✳️ 总结建议：

| 功能     | 方法                    | 说明              |
| ------ | --------------------- | --------------- |
| 创建线程   | `std::thread t(func)` | 启动新线程           |
| 阻塞等待   | `join()`              | 主线程等子线程结束       |
| 分离运行   | `detach()`            | 子线程独立运行         |
| 当前线程工具 | `std::this_thread`    | 如 `sleep_for` 等 |
| 延缓退出   | `getchar()`           | 阻止主线程立即结束       |

# make_shared

`std::make_shared<T>()` 是 C++11 引入的标准库函数，它用于更高效、可靠地创建 `std::shared_ptr<T>`。相比直接使用构造函数 `std::shared_ptr<T>(new T(...))`，它有几个非常实用的**优势**。


## ✅ 一句话总结：

> `make_shared<T>()` 提高了性能、减少了内存碎片，并增强了异常安全性，是创建 `shared_ptr` 的首选方式。


## 📌 常见两种写法对比：

```cpp
// 方法 1：传统写法
std::shared_ptr<MyClass> sp1(new MyClass(args));

// 方法 2：推荐写法
auto sp2 = std::make_shared<MyClass>(args);
```


## 🧠 为什么推荐使用 `make_shared`？

### ✅ 1. 性能更优：**只分配一次内存**

```cpp
std::shared_ptr<T>(new T(...))  
// 👆 分配两次内存：一次用于 T 对象，一次用于引用计数控制块

std::make_shared<T>(...)         
// 👆 分配一次内存：T 对象和控制块一起分配在一块内存中（结构体）

```

**带来的好处：**

* 更少的 `malloc`/`new`，提高性能
* 减少内存碎片，特别适合频繁创建和销毁对象


### ✅ 2. 异常更安全：**避免资源泄漏**

```cpp
std::shared_ptr<T>(new T(args)) // new 之后可能抛异常，造成内存泄漏
std::make_shared<T>(args)       // 内部构造保证异常安全
```

在 `new` 后对象构造可能抛异常，但 `shared_ptr` 还没拿到 → 内存泄漏。

而 `make_shared` 是原子操作，**要么成功创建对象并封装进智能指针，要么不会泄露内存**。


### ✅ 3. 简洁：代码更短、避免重复类型名

```cpp
std::shared_ptr<MyLongTemplate<Type1, Type2>> p1(new MyLongTemplate<Type1, Type2>());
auto p2 = std::make_shared<MyLongTemplate<Type1, Type2>>();
```

* 更简洁易读
* 避免重复写复杂模板类型


### ✅ 4. 更适合用于 `std::weak_ptr`

```cpp
auto sp = std::make_shared<T>();
std::weak_ptr<T> wp = sp;
```

由于 `make_shared` 创建的对象和控制块共享同一块内存，**可以确保 `weak_ptr` 生命周期管理更加高效**，比手动分配的更紧凑。


## ⚠️ 何时不适合使用 `make_shared`？

虽然 `make_shared` 几乎是默认推荐，但在以下极少数情况你可能不适用：

### ❌ 1. 自定义 `new`/`delete` 行为

```cpp
// 你可能要使用内存池、自定义分配器等
```

### ❌ 2. 要从多个构造路径管理同一个裸指针

```cpp
// 比如：shared_ptr从已存在裸指针构建
```

### ❌ 3. 配合自定义 deleter 时（`shared_ptr<T>(new T, deleter)`）


## ✅ 总结对比表

| 特性       | `new + shared_ptr` | `make_shared` ✅    |
| -------- | ------------------ | ------------------ |
| 内存分配次数   | 两次（对象 + 控制块）       | 一次                 |
| 内存碎片     | 多                  | 少                  |
| 异常安全     | ❌ 有可能泄漏            | ✅ 更安全              |
| 简洁性      | 代码冗长               | ✅ 更清晰              |
| 性能       | 较低                 | ✅ 更快               |
| 自定义删除器支持 | ✅ 支持               | 限制（不支持自定义 deleter） |


## 📌 示例：为什么 `make_shared` 更安全

```cpp
// ❌ 这种写法可能泄漏内存
std::shared_ptr<MyClass> ptr(new MyClass(get_may_throw())); // 如果 get_may_throw() 抛异常，内存泄漏！

// ✅ 安全写法
auto ptr = std::make_shared<MyClass>(get_may_throw()); // 不会泄漏
```


如你需要，我可以演示 `make_shared` 和 `shared_ptr<T>(new T)` 的底层分配结构差异（内存结构对比图），是否需要？
