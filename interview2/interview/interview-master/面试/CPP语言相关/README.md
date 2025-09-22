## 语言特性

#### 关键字

* static 
  * [static全局变量和普通全局变量](static全局变量和普通全局变量.md)
  * [static修饰函数](static修饰函数.md)
  * ?[static什么时候初始化](static什么时候初始化.md)
  * [static在类中使用](static在类中使用.md)
* volatile
  * [volatile作用](volatile作用.md)
  * [const和volatile](const和volatile.md)
* extern
  * [extern](extern.md)
* const
  * [const作用](const作用.md)
  * [const与define](const与define.md)
* [mutable](mutable.md)
* inline
  * [inline](inline.md)
  * [inline优缺点](inline优缺点.md)
  * [虚函数可以内联吗](虚函数可以内联吗.md)
  * [inline与typedef与define](inline与typedef与define.md)



#### 宏

* [宏的应用](宏的应用.md)



* [i++与++i](i++与++i.md)
* [范围解析运算符](范围解析运算符.md)
* [性能瓶颈](性能瓶颈.md)



#### 模板

[模板函数和模板特化](模板函数和模板特化.md)

## STL

[traits](traits.md)

[两级空间配置器](两级空间配置器.md)

### 容器（containers）

#### **序列容器：**

* [string](interview/interview-master/面试/CPP语言相关/STL/容器containers/string/string.md)

* [vector](vector.md)

* [deque](deque.md)

* [list](interview/interview-master/面试/CPP语言相关/STL/容器containers/list/list.md)

* [forward_list](forward_list.md)



**函数对象**：[less & hash](STL/容器containers/less & hash.md)



* [priority_queue](priority_queue.md)

#### [关联容器](interview/interview-master/面试/CPP语言相关/STL/容器containers/关联式容器/README.md)

[hashtable的实现](hashtable的实现.md)

**C 数组的替代品**:[array](array.md)

### 容器适配器（adapter）

* [queue](queue.md)

* [stack](stack.md)



##### 为什么大部分容器都提供了 begin、end 等方法？

答：容器提供了 begin 和 end 方法，就意味着是可以迭代（遍历）的。大部分容器都可以从头到尾遍历，因而也就需要提供这两个方法。

##### 为什么容器没有继承一个公用的基类？

答：C++ 不是面向对象的语言，尤其在标准容器的设计上主要使用值语义，使用公共基类完全没有用处。



* [pair]()

* [tuple]()



#### STL源码剖析

[vector实现](vector实现.md)

[slist的实现](slist的实现.md)

[list的实现](list的实现.md)

[deque的实现](deque的实现.md)

[stack和queue实现](stack和queue实现.md)

[heap实现](heap实现.md)

[priority_queue的实现](priority_queue的实现.md)

[set的实现](set的实现.md)

[map的实现](map的实现.md)





### 迭代器

[iterator](iterator.md)



## C++11、14、17（某个点可能串起来）

#### 关键字：

1. [auto](auto.md)
2. [decltype](decltype.md)
3. [auto和decltype对比](auto和decltype对比.md)
4. [override & final](final.md):都**不是**关键字，放这里仅仅是方便
5. [default & delete](C++11/关键字/default & delete.md)
6. [explicit](explicit.md)
7. [using](using.md)



#### 常用技巧：

1. [委托构造](委托构造.md)
2. [成员初始化列表](成员初始化列表.md)
3. [类型别名](类型别名.md)
4. [for each循环](C++11/常用技巧/for each循环.md)
5. [可调用对象](可调用对象.md)
6. [lambda](lambda.md)
7. [类模板的模板参数推导](类模板的模板参数推导.md)
8. [结构化绑定](结构化绑定.md)
9. [列表初始化](列表初始化.md)
10. [统一初始化](统一初始化.md)
11. [类数据成员的默认初始化](类数据成员的默认初始化.md)
12. [静态断言](静态断言.md)
13. [类型转换](类型转换.md)
14. [可变参数模板](可变参数模板.md)
15. [智能指针](智能指针.md)





## 语言对比

#### [C与C++](C和C++.md)：

1. [结构体、联合体(以及匿名)](结构体、联合体(以及匿名).md)
2. [bool类型](bool类型.md)
3. [memcpy](memcpy.md)
4. [strcpy](strcpy.md)
5. [strlen](strlen.md)
6. [类型安全](类型安全.md)

#### Java和C++

1. [Java和C++](Java和C++.md)

#### Python和C++

1. [Python和C++](Python和C++.md)



## 指针和引用

#### 指针

1. [指针和数组](指针和数组.md)
   * [数组名当做指针用](数组名当做指针用.md)
2. [野指针和悬空指针](interview/interview/interview-master/面试/CPP语言相关/指针和引用/野指针和悬空指针.md)
3. [函数指针](函数指针.md)
4. [nullptr](nullptr.md)
5. [对象指针](对象指针.md)
6. [this指针](this指针.md)
7. [指针和引用](指针和引用.md)



## 右值

0. [右值和移动究竟解决了什么问题](右值和移动究竟解决了什么问题.md)
1. [右值和左值](右值和左值.md)
2. [右值引用](右值引用.md)
3. [转移语意](转移语意.md)
4. [完美转发](完美转发.md)
5. [move实现原理](move实现原理.md)

## [异常](异常.md)

1. [异常：用还是不用，这是个问题](异常：用还是不用，这是个问题.md)



## 内存管理

#### 编译链接

0. [程序编译过程](程序编译过程.md)
1. [#include](内存管理/编译链接/#include.md)
2. [动态链接与静态链接](动态链接与静态链接.md)
3. [main前](main前.md)
4. [模板的编译与链接](模板的编译与链接.md)
5. [各个平台相关](各个平台相关.md)

#### 内存对齐

1. [结构体大小](结构体大小.md)
2. [类的大小](类的大小.md)
3. [内存对齐原因](内存对齐.md)

#### 运行时内存

1. [内存泄露](内存泄露.md)
2. [内存溢出OOM](内存溢出.md)
3. [防止内存泄露](防止内存泄漏.md)
4. [检测内存泄漏](检测内存泄漏.md)
5. new和delete和malloc和free
   * [malloc](malloc.md)
   * [new和operator new()](内存管理/new和delete和malloc和free/new和operator new().md)
   * [new和malloc](new和malloc.md)
   * [三种new](三种new.md)
   * [delete](delete.md)
   
6. 虚拟地址空间
   * [虚拟地址空间](虚拟地址空间.md)
7. [变量区别](变量.md)



## 类与对象

#### 面向对象

1. [什么是面向对象编程](什么是面向对象编程.md)
   * [public和protected和private](public和protected和private.md)
2. [重载、重写、隐藏](重载、重写、隐藏的区别.md)
3. [多态](多态.md)
   * [RTTI](RTTI.md)

   * 虚函数
     * [虚函数机制](虚函数机制.md)
     * [多继承虚函数机制](多继承虚函数机制.md)
     * [纯虚函数](纯虚函数.md)
     * [构造、析构要虚不](构造析构和虚.md)
     * [虚函数效率分析](虚函数效率分析.md)
     * [虚函数与内联](虚函数与内联.md)
     * [哪些函数不能是虚函数](哪些函数不能是虚函数.md)
4. [多重继承](多重继承.md)

   * [多继承](多继承.md)
   * [虚基类](虚基类.md)
   * [自适应偏移](自适应偏移.md)
5. [如何让类不能被继承](如何让类不能被继承.md)
6. [友元](友元.md)
7. [返回类型协变](返回类型协变.md)

#### 构造

1. [对象构造过程](对象构造过程.md)
2. [生成默认构造函数](生成默认构造函数.md)
3. [拷贝构造函数](拷贝构造函数.md)
4. [禁止类被实例化](禁止类被实例化.md)
5. [禁止拷贝](禁止拷贝.md)

#### 析构

1. [对象析构过程](对象析构过程.md)

#### 内存管理

1. [深拷贝和浅拷贝](深拷贝和浅拷贝.md)
2. [只能在栈上或堆上生成对象](只能在栈上或堆上生成对象.md)
3. [空类](空类.md)
4. [简单对象](简单对象.md)

