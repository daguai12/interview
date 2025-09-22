## 从指令角度掌握调用堆栈详细过程
```cpp
#include <iostream>

using namespace std;

/*
  问题一：main函数调用完sum，sum执行完之后，怎么知道回到那个函数中
  问题二：sum函数执行完，回到main以后，怎么知道从哪一行指令继续运行
*/
int sum(int a,int b)
{ //push ebp
  //mov ebp, esp
  //sub esp, 4Ch  给sum函数开辟栈帧空间


  int temp = 0; //mov dword ptr[ebp-4], 0
  temp = a + b; //mov eax, dword ptr[ebp+0Ch]
                //add eax,dword ptr[ebp + 8]      a +b
                //move dword ptr[ebp-4], eax
  return temp;  //mov eax,dword ptr[ebp -4]

//此时eax中的值为30

} //mov esp, ebp
  //pop ebp  返回main函数栈 出栈操作
  //ret      把出栈内容，放入CPU的PC寄存器中,此时PC寄存器中的内容为（0x8124458)


int main()
{
  int a = 20; //mov dword ptr[ebp - 4], 0Ah
  int b = 30; //move dword ptr[ebp - 8], 14h
  int ret = sum(a,b);
  // mov eax, dword ptr[ebp - 8]
  // push eax
  // move eax, dword ptr[ebp -4]
  // push eax
  // call sum
  // add  esp, 8     
  // move dword ptr[ebp - 0Ch], eax  跳过a,b形参，将a，b形参所占用的空间还给系统  这行指令的地址0x08124458
  cout << "ret:" << ret << endl;
  getchar();
  return 0;
}
```

在程序启动时main函数会开辟main函数栈帧，将`a`和`b`压入函数栈底。
![[Pasted image 20250525131308.png]]
运行到`sum()`函数的调用点之后，将`sum()`函数的形参，从右往左压入`sum()`函数栈帧之中。再将下一条指令的地址压入栈中，用于函数调用完之后可以找到吓一跳指令运行的位置。接下来继续将栈底的地址压入栈中，用于`ebp`指针在函数调用完之后，回到`main()`函数栈低的位置。并将`esp`移动到栈顶位置。
![[Pasted image 20250525133757.png]]
完成以上操作以后开始运行`sun()`函数，在进入`sum()`函数体之前。先会开辟`sum()`函数栈帧,开辟过程如下：先将`ebp`指针移动到栈顶位置，再将`esp`指针向上移动，开辟`sum()`栈帧。开辟好空间之后，开始运行函数体中的相关指令。
![[Pasted image 20250525134525.png]]
在执行完函数体中的内容之后，开始回收系统资源。将`esp`值指针移动到`sum()`栈帧的栈底，执行`pop ebp`指令之后，`ebp`指针回退到`main`的栈底位置（0x18ff40)。执行`ret`指令，将把出栈的内容放入CPU中的PC寄存器中（PC寄存器保存的是下一条执行的指令的地址）。执行该指令将`eax`寄存器中的值赋值给`ret`变量。最后，`esp`随着`ret`弹出返回地址后，执行 `add esp, 8` 回收参数，回到调用前的栈顶位置。
![[Pasted image 20250525135831.png]]

在vs和gcc环境下栈帧初始化的区别
>在vs平台下，会初始化栈帧为0xCCCCCCCC
>在gcc环境下，并不会初始化栈帧

### 从编译器的角度理解C++

从源代码到可执行程序所经历的四个阶段：
- 预处理
```shell
gcc -E main.cpp -o main.i
```
**这一阶段的处理:**

>删除所有的`#define`,并且展开所有的宏定义。
>处理所有条件预编译指令,比如`#ifndef`,`#if`,`#endif`。
>处理预编译指令`#include`，将指令所包含的文件替换到相应的引用位置。这个过程是递归进行的，也就是说被包含的文件中还包含其他文件。
>删除所有注释`\\``\*\`。
>添加行号和文件名标识，便于编译时产生编译错误或警告时能够显示行号。
>保留`#pragma`指令。这一命令使用在链接阶段。

- 编译
```shell
gcc -S main.i -o main.s
```

把预处理的文件经过词法分析，语法分析，语义分析以及优化后生成相应的汇编文件。

- 汇编
```shell
gcc -c main.s -o main.o
```

将汇编文件转变为可重定位目标文件。

- 链接
```shell
gcc main.o -o mian
```

将可重定位目标文件，静态库链接为可执行目标文件

ELF格式的文件：

| 类型    | 作用           |
| :---- | :----------- |
| 可执行文件 | 程序启动时执行      |
| 目标文件  | 编译后但未链接的中间文件 |
| 动态库   | 动态链接时用       |
| 静态库   | 编译时静态链接进程序   |

**接下来我们可以使用objdump,readelf来窥视目标文件的详细内容**







生成的符号表中 g 为链接可以看到的字段，l则为本地符号连接器无法看到。

readelf -h a.out 查看elf文件头

objdump -S a.out 查看汇编指令

objdump -t a.out 查看你符号表symbol table

readelf -l a.out 查看程序加载到内存的段

## 形参带默认值的函数

给形参默认值只能从右往左给。
使用形参默认值可以提高效率。
在声明函数的时候也可以给新参默认值。
在声明的时候，形参的默认值只能出现一次。

### 掌握inline内联函数

```cpp
inline int sum(int x,int y) // *.o sum_int_int .text
{
  return x + y;
}

int main()
{
  int a = 10;
  int b = 20;
  int ret = sum(a,b);
  //此处有标准的函数调用过程 参数压栈，函数栈帧的开辟和回退的过程，有函数调用的开销
  //x+y mov add mov
  getchar();
  return 0;
}
```

- inline是在程序编译期间展开
- 使用inline关键字可以减少函数调用过程中(形参压栈，栈区开辟和回退)的开销。
- inline所标记的函数不会生成函数符号

**什么情况下inline不会展开?**
- 不是所有的inline都会被展开成为内联函数，如：递归函数
>因为递归函数只有在运行时，才可以知道递归的次数，但是inline函数的展开是在编译时。
- 如果函数体太复杂，编译器也不会展开为内联函数。
>防止变量名发生冲突。
- 跨模块调用
>如果inline函数定在一个cpp文件中，但是在另一个cpp文件中调用，编译器在编译阶段找不到函数体，无法被内联。
- 函数地址被取用
>如果这个inline函数取了地址（比如赋给函数指针），就不能内联，因为它需要实际的地址。

 inline只是一种"建议"并不是强制要求。

**如何查看函数是否内联?**
>g++ -O2 -S test.cpp 在编译时不要加-g指令
>objdump -t main.o


### 详解函数重载

```cpp
#include <iostream>
using namespace std;

bool compare(int a,int b) //compare_int_int
{
  cout << "compare_int_int" << endl;
  return a > b;
}

bool compare(double a,double b) //comprae_double_double
{
  cout << "compare_double_double" << endl;
}

bool compare(const char* a,const char* b) //compare_const char*_const char*
{
  cout << "comapre_char*_char*" << endl;
  return strcmp(a,b) > 0;
}

int main()
{
  bool compare(int a,int b); //函数的声明

  compare(10,20);
  compare(10.0,20.0);
  compare("aaa","bbb");
  return 0;
}
```

#### 为什么C++支持函数重载，C不支持函数重载?

>C++代码产生的符号,是由函数名加函数参数所构成的。
>C代码产生的符号，是由函数名所构成的。

#### 什么是函数重载？

>1. 一组函数，其中函数名相同，参数列表的个数类型不同，呢么这一组函数就称为-函数重载。
>2. 一组函数要称得上重载，必须要在同一作用域中。
>3. const和volatile的时候，是怎样影响形参类型的。
>4. 一组函数，函数名参数相同，参数列表也相同，仅返回类型不同，不算函数重载。因为函数所生成的符号只与函数名和参数列表有关。

#### C++如何调用C函数?

```cpp
main.cpp

//方法一：
int sum(int,int)   // sum_int_int *UND*

//方法二:
extern "C"{
	int sum(int,int) //sum *UND*
}

int main()
{
	int ret = sum(20,10);
	cout << "ret:" << ret << endl;
	return 0;
}


sum.c

int sum(int a,int b) // sum
{
	return a + b;	
}
```

在c++中调用c中的函数时如果按照方法一会发生报错。
>在sum.c文件中sum函数所生成的符号为sum,而main.cpp中所调用的sum函数生成的符号为sum_int_int。所以在连接阶段无法找到sum_int_int符号，而发生报错。

使用方法二：
>在main.cpp文件中sum函数所生成的符号为sum,所以在链接阶段可以在sum.o文件中找到对应的符号。

#### C如何调用C++函数?
```cpp
main.c

int sum(int,int); //sum *UND*

int main()
{
	int ret = sum(20,10);
	printf("ret: %d",ret);
	return 0;
}


sum.cpp

extern "C"{
	int sum(int a,int b) // sum
	{
		return a + b;	
	}
}
```

在cpp文件中将函数用`extern"C"`包围

#### 在C/C++混合项目中的正确写法

```cpp
//只要是C++编译器都内置了__cplusplus这个宏名
#ifdef __cpluscplus
extern "C" {
#endif

}
#ifdef __cplusplus
}
#endif
```

#### 使用typeinfo头文件查看变量类型

```cpp
#include <typeinfo>
void func(int a ) {} //int 
void func(const int a) {} //int

using namespace std;

int main()
{
  int a = 10;
  const int b = 10;
  cout << typeid(a).name() << endl;
  cout << typeid(b).name() << endl;
  getchar();
  return 0;
}
```

### 全面掌握const

```cpp
main.cpp

int main()
{
  const int a = 20; 
  int array[a] = {}; //不报错
  
  int *p =  (int*)&a;
  *p = 30;

  // 20 30 20
  printf("%d %d %d\n",a,*p,*(&a)); 
  return 0;
}
```

```cpp
输出内容： 20，30，30
```

- 在C++中`const`关键字所修饰的变量为常量，必须进行初始化操作。
- 可以通过指针来修改所指向的内容。

**为什么通过指针修改之后输出的值还是原来的值?**
>在c++中const关键字所修饰的变量都会被替换为初始化的常量，所以即使通过指针修改之后还是会输出原来的值。


**如果通过一个变量来初始化常量，会怎么样？**
```cpp
main.cpp

int main()
{
  int b = 20
  const int a = b; 
  int array[a] = {}; //报错
  
  int *p =  (int*)&a;
  *p = 30;

  // 20 30 20
  printf("%d %d %d\n",a,*p,*(&a)); 
  return 0;
}
```
>如果用一个变量来初始化常量，常量会退化为常变量，将无法在用于设置数组的大小。


```c
main.c

int main()
{
  const int a; 
  // int array[a] = {}; //报错
  
  int *p =  (int*)&a;
  *p = 30;

  // 30 30 30
  printf("%d %d %d\n",a,*p,*(&a)); 
  return 0;
}
```

```c
输出内容：30 30 30
```

- 在C中`const`关键字所修饰的变量并不是常量，而是常变量，可以不进行初始化。
- 在C中，const就是被当作一个变量来生成指令的。

#### 掌握const的一二级指针的集合应用

```cpp
#include <iostream>

using namespace std;
/*
C++的语言规范： const修饰的是离他最近的类型
const int *p; 
int const* p;
int *const p;
const int *const p;
*/


/*
总结const和指针的类型转换公式：
int* <- const int* 是错误的 !
const int* <- int* 是正确的 !

int** <- const int** 是错误的 !
const int** <- int** 是错误的 !

int** <- int*const* 是错误的! const修饰的是一级指针
int*const* <- int** 是可以的!
*/

#if 0
int main()
{
  int a = 10;
  const int *p = &a;
  // int *q = p; // int* <- cosnt int* //错误

  cout << typeid(p).name() << endl;

  // int *q1 = nullptr;
  // int *const q2 = nullptr;
  // cout << typeid(q1).name() << endl;
  // cout << typeid(q2).name() << endl;

  // int a = 10;
  // int *p1 = &a;
  // const int *p2 =&a; // const int * <- int*
  // int *const p3 = &a; // int* <- int*
  // int *p4 = p3; // int* <- int*const 
  getchar();
  return 0;
}
#endif


/*
const和二级指针的结合
*/
int main()
{
  int a = 10;
  int *p = &a;
  const int* *q = &p; // const int ** <- int **

  return 0;
}
```

  - const 如果右边没有指针\*的话，const是不参与类型的

### 掌握C++的左值引用和初识右值引用

```cpp
定义变量所对应的反汇编指令：

int a = 20;
00007FF7A39C185E  mov         dword ptr [a],14h  
int* p = &a;
00007FF7A39C1865  lea         rax,[a]  
00007FF7A39C1869  mov         qword ptr [p],rax  
int& q = a;
00007FF7A39C186D  lea         rax,[a]  
00007FF7A39C1871  mov         qword ptr [q],rax

修改变量所对应的反汇编指令：
*p = 40;
00007FF77D9A1875  mov         rax,qword ptr [p]  
00007FF77D9A1879  mov         dword ptr [rax],28h  
q = 50;
00007FF77D9A187F  mov         rax,qword ptr [q]  
00007FF77D9A1883  mov         dword ptr [rax],32h

```

#### C++引用和指针的区别
>1. 引用必须要初始化，但是指针不用。
>2. 引用只有一级引用，没有多级引用
>3. 定义一个引用变量，和定义一个指针变量，其汇编指令是是一样的：通过引用修改所引用内存的值，和通过指针解引用修改指向内存的值，其底层指令也是一样的。

#### 什么是左值
>左值有内存，有名字，值可以修改。

#### 右值引用
>1. 右值引用本身是左值，只能用左值引用来引用它。
>2. int &&c = 20; 专门用来引用右值类型，指令上可以自动产生临时量然后直接引用临时量。

```cpp
/*
int temp = 20;
temp -> c;
*/
	int&& c = 20; //20是没有内存的（直接存放在cpu的寄存器中），没名字
00007FF63A8D52B9  mov         dword ptr [rbp+84h],14h  
00007FF63A8D52C3  lea         rax,[rbp+84h]  
00007FF63A8D52CA  mov         qword ptr [c],rax  
	const int& d = 20;
00007FF63A8D52CE  mov         dword ptr [rbp+0C4h],14h  
00007FF63A8D52D8  lea         rax,[rbp+0C4h]  
00007FF63A8D52DF  mov         qword ptr [d],rax 
```

### const 指针 引用的结合使用
```cpp
#include <iostream>
#include <typeinfo>
using namespace std;

int main()
{
  // 写一句代码，在内存的0x0018ff44处写一个4字节的10
  // int *const &p = (int*)(0x0018ff44);

  int a = 10;
  int *p = &a;
  int *&q = p; //typeid(q).name()
  // const int*




  //错误转换
  int a = 10;
  int *const p = &a;
  int *&q = p;
  //int **q = &p; //const int** <- int**

  return 0;
}
```

### 深入理解C++的new和delete

#### malloc/free 和 new/delete的区别
1. new和delete为运算符,malloc和free为c的库函数。
2. new不仅可以开辟内存，还可以初始化内存。malloc只能开辟内存且不会初始化内存。
3. 判断malloc是否开辟空间成功需要将返回值与`nullptr`比较。new开辟空间失败会抛出异常`bad_alloc`。

#### new的类型
```cpp
int* p = new int(20);
int* q = new (nothrow) int(20);
const int* p = new const int(40);

//定位new
int data = 0;
int* d = new (&data) int(20);
```


# C++OOP

## this指针

类的成员一经编译，所有方法参数，都会加一个this指针，接收调用该方法的对象的地址。

## 掌握构造函数和析构函数
```cpp
class example{
public:
	example() = default;
	~example() = default;
private:
}

int main()
{
	example* p1 = new example(20);
	delete p1;
	
	exmaple e1;
	e1.~example();
	return 0;
}
```

可以显示的调用析构函数。

**delete和free的区别**
>delete会先调用析构函数销毁对象，再调用free()释放堆内存。

**malloc和new的区别**
>new先调用malloc开辟内存，再调用构造函数创建对象。


## 掌握对象的深拷贝和浅拷贝

在自定义拷贝构造函数的时候不要去使用`memcopy()`这种内存拷贝函数。


## 类和对象代码应用实践

```cpp
#include <iostream>
#include <stdlib.h>
#include <string.h>
using namespace std;

class String
{ 
  friend ostream& operator<<(ostream& os,String& str);
public:
  String(const char* str = nullptr)
  {
    if (str != nullptr)
    {
      m_data = new char[strlen(str) + 1];
      strcpy(m_data,str);
    }
    else
    {
      m_data = new char[1];
      m_data[0] = '\0';
    }
  }

  String(const String& other)
  {
    m_data = new char[strlen(other.m_data) + 1];
    strcpy(m_data,other.m_data);
  }

  ~String(void)
  {
    cout << "~String()" << endl;
    delete[] m_data;
    m_data = nullptr;
  }

  //返回*this为了连续赋值
  String &operator=(const String& other)
  {
    //防止自赋值
    if (this == &other)
    {
      return *this;
    }
    delete [] m_data;
    m_data = new char(strlen(other.m_data) + 1);
    strcpy(m_data,other.m_data);
    return *this;
  }

  
private:
  char *m_data;
};

ostream& operator<<(ostream& os,String& str)
{
  os << str.m_data;
  return os;
}

int main()
{
  {
  String str1("nihaoshijie");
  String str2("HelloWorld");
  String str3("woshinibaba");
  str1 = str2 = str3; 
  cout << str1 << endl;
  cout << str2 << endl;
  }
  getchar();
  return 0;
}

```

## 掌握构造函数的初始化列表

## 掌握类的各种成员方法以及区别

普通的成员方法 => 编译器会添加一个this形参变量
1.属于类的作用域
2.调用该方法时，需要依赖一个对象
3.可以任意访问对象的私有成员 

static静态成员方法: 不会生成this形参
1.属于类的作用域。
2.用类名作用域来调用方法。
3.可以任意访问对象的私有成员，仅限于不依赖对象的成员（只能调用其他的static静态成员）

const常成员方法 => const CGoods \*this
1.属于类的作用域
2.调用依赖一个对象，普通对象或者常对象都可以
3.可以任意访问对象的私有成员，但是只能读，不能写


静态成员方法没有this，只能访问静态成员变量。

## 掌握类成员的指针
```cpp
#include <iostream>

using namespace std;

class Test
{
public:
  void func() {cout << "call Test::fun" << "ma:" << ma << endl;}
  int ma;
};

#if 0
int main()
{
  Test t1;
  //指向成员变量的指针
  int Test::*p1 = &Test::ma;
  // int *p1 = &Test::ma; 无法从 "int Test::*"转换为"int*"
  //由于成员变量依赖于对象，所以要通过成员变量来调用指针。
  t1.*p1 = 30;
  t1.func();


  Test* t2 = new Test();
  int Test::*p2 = &Test::ma;
  t2->*p2 = 40;
  t2->func();

  delete t2;
  getchar();
  return 0;
}
#endif

//指向成员方法的指针
int main()
{
  Test t1;
  void (Test::*pfunc)() = &Test::func;
  (t1.*pfunc)();
}
```

因为成员函数要依赖对象（this指针），所以 C++ 专门设计了成员函数指针的语法，和普通函数指针区分开来，防止搞混。

## 理解函数模板

```cpp
#include <iostream>
#include <typeinfo>
#include <string.h>

using namespace std;

//这部分代码在编译阶段是不会进行编译的,因为此时不知道参数的类型jk
template <typename T>
bool compare(T a,T b)
{
  cout << "type: " << typeid(a).name() << endl;
  return a > b;
}


//模板的特例化
template <>
bool compare<const char*>(const char* a, const char* b)
{
  cout << "template<> const char*" << endl;
  return strcmp(a,b);
}
/*
这个是通过模板生成的模板函数，对于const char*类型的比较并不是按照字典中的字母的大小排序。而是按照地址的大小排序。
template <const char*>
bool compare<const char*>(const char* a, const char* b)
{
  return a > b;
}
*/

//如果用户调用名为`compare()`的函数，编译器会优先选择使用函数，而不是模板。
bool compare(const char* a,const char*b )
{
  cout << "normal compare()" << endl;
  return strcmp(a,b);
}


int main()
{
  int a = 20, b = 30;
  bool result;

  //在函数的调用点，函数模板才会实例化
  result = compare<int>(a,b);
  cout << "compare(int, int):" << result << endl;

  //这部分注释代码才是会被编译的代码(这就是实例化的代码)
  /*
    bool compare<int>(int a,int b)
    {
      cout << "type:" << typeid(a).name() << endl;
      return a > b;
    }
  */

  result = compare<double> (a,b);
  cout << "compare(double, double):" << result << endl;

  //这部分注释代码才是会被编译的代码
  /*
    bool compare<double>(double a,double b)
    {
      cout << "type:" << typeid(a).name() << endl;
      return a > b;
    }
  */


  //在遇到像const char* 这样特殊的函数类型时,使用编译器通过模板为我们生成的模板函数，无法达到我们需要的效果。
  //这个时候我们可以使用模板的特例化来实现
  result = compare("aaa","bbb"); //模板的实参推演，不需要用户指定参数类型
  cout << "compare(const char*, char char*):" << result << endl;


  getchar();
  return 0;
}
```

- 模板实参推演  可以根据用户传入的实参的类型，来推导处模板类型参数的具体类型
- 函数模板  是不进行编译的，因为类型还不知道
- 模板的实例化  函数调用点进行实例化
- 模板函数  才是要被编译器所编译的

**编译器优先把compare处理成函数名字，没有，采取找compare模板函数。**

### 将模板放在其他文件中会出现的情况
***main.cpp
```cpp

#include <iostream>
#include <typeinfo>
#include <string.h>

using namespace std;

// 声明模板函数
template <typename T>
bool compare(T a,T b);

int main()
{
  int a = 20, b = 30;
  bool result;

  //当模板定义在其他文件时，在该文件中调用该模板函数，编译无法找到该模板函数的定义。所以，无法实例化该模板。
  result = compare<int>(a,b); // compare *UND*
  cout << "compare(int, int):" << result << endl;


  result = compare<double> (a,b);
  cout << "compare(double, double):" << result << endl;

  result = compare("aaa","bbb"); 
  cout << "compare(const char*, char char*):" << result << endl;


  getchar();
  return 0;
}
```

在编译阶段，在`main.cpp`中调用了`test.cpp`中的模板函数，但是在编译`main.cpp`文件时，由于编译器不知道`compare`的模板函数的定义，无法实例化main函数中`compare`函数模板。

在汇编阶段，由于`compare`模板函数定义在其他文件中。所以main函数中的相关函数调用，都会生成外部符号，可以通过命令`nm main.o`查看生成的符号。

在链接阶段，由于`test.cpp`中的模板函数，不参与代码的编译。无法生成符号（但是特例化的模板可以生成符号）。所以，`main.o`中无法找到想要的外部符号，在生成可执行文件时会发生链接错误。

***test.cpp
```cpp
#include <iostream>

#include <string.h>
using namespace std;

template <typename T>
bool compare(T a,T b)
{
  cout << "type: " << typeid(a).name() << endl;
  return a > b;
}


template <>
bool compare<const char*>(const char* a, const char* b)
{
  cout << "template<> const char*" << endl;
  return strcmp(a,b);
}

bool compare(const char* a,const char*b )
{
  cout << "normal compare()" << endl;
  return strcmp(a,b);
}
```

通过`nm test.o`命令查看生成的符号表

```
00000000 b .bss
00000000 d .data
00000000 r .eh_frame
00000000 r .rdata
00000000 r .rdata$zzz
00000000 t .text
00000000 T __Z7compareIPKcEbT_S2_
00000047 T __Z7comparePKcS0_
         U __ZNSolsEPFRSoS_E
00000028 r __ZNSt8__detail30__integer_to_chars_is_unsignedIjEE
00000029 r __ZNSt8__detail30__integer_to_chars_is_unsignedImEE
0000002a r __ZNSt8__detail30__integer_to_chars_is_unsignedIyEE
         U __ZSt4cout
         U __ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_
         U __ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc
         U _strcmp
```

可以通过`c++filt`命令来查看每一个符号对应的函数名。

**所以在使用模板函数的时候，最好把模板的定义放在头文件中。然后通过`#include`直接包含在源文件中。**


## 理解类模板

### 给模板传递非类型参数

函数模板的非类型参数，必须是整数类型（整数或者地址/引用都可以）都是常量，只能使用，不能修改。

```cpp
template <typename T,int SIZE> //传递一个类型和常量
```


**析构和构造函数不用加\<T\>,其他出现模板的地方都要加上类型参数列表。**

 
## 实现C++ STL向量vector

## 理解容器空间配置器allocator

## 学习复数类CComplex(重载运算符)

编译器做对象运算的时候，会调用对象的运算符重载函数（优先调用成员方法）；如果没有成员方法，就在全局作用域找到合适的运算符重载函数。

```cpp
#include <iostream>

using namespace std;

class Complex
{
  friend ostream& operator<<(ostream& os,const Complex& rhs);
  friend Complex operator+(const Complex& ,const Complex&);
  friend istream& operator>>(istream& is,Complex& rhs);
public:
  Complex(int real = 0,int virt = 0)
    :m_real(real),m_virt(virt)
  {
  }

  Complex operator+(const Complex& rhs)
  {
    cout << "Complex::opertor+()" << endl;
    return (this->m_real+rhs.m_real,this->m_virt,m_virt);
  }

  //前置++
  Complex& operator++()
  {
    ++this->m_real;
    ++this->m_virt;
    return *this;
  }

  //后置++
  Complex operator++(int)
  {
    return Complex(m_real++,m_virt++);
  }

  //重载+=
  void operator+=(const Complex& rhs)
  {
    this->m_real += rhs.m_real;
    this->m_virt += rhs.m_virt;
  }

  ~Complex()
  {}

  void show()
  {
    cout << "real: " << m_real << "virt: "  << m_virt << endl;
  }

private:
  int m_real;
  int m_virt;
};

//全局重载operator+
Complex operator+(const Complex& lhs,const Complex& rhs)
{
  cout << "::operator+()" << endl;
  return Complex(lhs.m_real + lhs.m_real, rhs.m_virt + lhs.m_virt);
}

//重载<<
ostream& operator<<(ostream& os,const Complex& rhs)
{
  os << "m_real:"  << rhs.m_real << "m_virt" << rhs.m_virt;
  return os;
}

istream& operator>>(istream& is,Complex& rhs)
{
  is >> rhs.m_real >> rhs.m_virt;
  return is;
}


int main()
{
  Complex c1(1,2);
  Complex c2(1,3);
  //在调用重载operator+()时，会先调用成员重载函数，如果没有匹配项。则调用全局重载函数
  Complex c3 = c1 + c2;
  Complex c4 = c1 + 20;
  Complex c5 = 20 + c3;
  Complex c9;
  std::cin >> c9;
  cout << c9 << endl;
  getchar(); //会读取残留的换行符
  getchar();
  return 0;
}
```

## 什么是容器的迭代器失效问题

迭代器失效问题：
1.迭代器为什么会失效？
a.当容器调用erase方法后，当前位置到容器末尾元素的所有的迭代器全部失效了。
b.当容器调用insert方法后，当前位置到容器末尾元素的所有的迭代器全部失效了。
c.insert来说，如果引起容器内存扩容,原来容器的所有的迭代器就全部失效了。
d.不同容器的迭代器不能进行比较

2.迭代器失效了以后，问题该如何解决?
对插入/删除点的迭代器进行更新操作

**在MSVC和GUN下vector失效的方式不同**

## 深入理解new和delete的原理

### 1️⃣ `new` 和 `new[]` 区别

| 操作符     | 作用         | 调用过程                         |
| :------ | :--------- | :--------------------------- |
| `new`   | 分配单个对象     | 调用 `operator new` + 构造函数     |
| `new[]` | 分配一组对象（数组） | 调用 `operator new[]` + 多个构造函数 |


### 2️⃣ `delete` 和 `delete[]` 区别

| 操作符        | 作用       | 调用过程                                 |
| :--------- | :------- | :----------------------------------- |
| `delete`   | 释放单个对象内存 | 调用析构函数 → `operator delete`           |
| `delete[]` | 释放对象数组内存 | 调用**每个对象析构函数** → `operator delete[]` |


### 3️⃣ 为什么 **`new/delete` 和 `new[]/delete[]` 不能混用**

* **new 和 delete**

  * `new` 只分配对象内存，没有额外记录
  * `delete` 直接释放对应内存地址

* **new\[] 和 delete\[]**

  * `new[]` 会在内存中**额外开辟一小块区域**（通常在数组前部）记录数组元素个数
  * `delete[]` 需要这块记录，才能正确知道调用多少次析构和释放整块内存

**混用后果**：

* `delete` 删除 `new[]` 分配的内存，无法获取元素个数，可能：

  * 内存泄漏
  * 部分内存未释放
  * 段错误或运行时崩溃

**必须成对使用**：

* `new` ⇔ `delete`
* `new[]` ⇔ `delete[]`

### 4️⃣ `new[]` 的额外内存分配细节

**分配流程**：

1. 调用 `operator new[]`
2. 分配 `sizeof(size_t) + n * sizeof(T)` 的内存
3. 在首部存储 `n`（元素个数）
4. 返回跳过首部偏移后的地址给程序使用

**释放流程**：

1. `delete[]` 接收指针
2. 往前偏移，取出 `n`
3. 调用 `n` 次析构函数
4. 调用 `operator delete[]`，释放整块内存（包括记录块）


### 5️⃣ 总结图

```
new[]  分配内存：
┌──────┬────────────────────────────┐
│ 元素数│ T对象 T对象 T对象 ...        │
└──────┴────────────────────────────┘

delete[] 释放：
1️⃣ 向前偏移取元素数
2️⃣ 调用析构函数
3️⃣ 释放整块内存
```


### ✅ 总结一句

> **new / delete** 是针对单个对象
> **new\[] / delete\[]** 是针对数组，new\[] 额外分配一块记录元素个数，delete\[] 会用这块数据释放内存，二者不能混用，务必成对！


### 代码验证
```cpp
void* operator new(size_t size)
{
  void* p = malloc(size);
  if(p == nullptr)
  {
    throw bad_alloc();
  }
  cout << "operator new addr: " << p << endl;
  return p;
}

void* operator new[](size_t size)
{
  void* p = malloc(size);
  if(p == nullptr)
  {
    throw bad_alloc();
  }
  cout << "operator new[] addr: " << p << endl;
  return p;
}

void operator delete(void* ptr)
{
  cout << "operator delete addr: " << ptr << endl;
  free(ptr);
}

void operator delete[](void* ptr)
{
  cout << "operator delete[] addr: " << ptr << endl;
  free(ptr);
}

class Test
{
public:
  Test(int ma = 10) {cout << "Test()" << endl;}
  ~Test() {cout << "~Test()" << endl;}
private:
  int ma;
};

int main()
{
  //对于普通类型来说，new/delete和new[]/delete[]能混用，因为普通类型只涉及内存的开辟和释放，不涉及构造函数，析构函数。
  #if 0
  int* p = new int(1);
  delete p;

  int* p2 = new int[2]();
  delete[] p2;

  getchar();
  #endif

  /*
  operator new[] addr: 0x62dc58
  Test()
  Test()
  Test()
  Test()
  Test()
  Test[0] addr: 0x62dc5c 
  ~Test()
  ~Test()
  ~Test()
  ~Test()
  ~Test()
  operator delete[] addr: 0x62dc58
  */
  Test* p = new Test[5]();
  cout << "Test[0] addr: " << &p[0]<< endl;
  delete[] p;
  getchar();
  return 0;
}
```

通过代码输出可以发现`0x62dc58`和`0x63dc5c`中间的4字节大小就是用来记录对象数量的。

## new和delete重载实现的对象池应用

```cpp
#include <iostream>

using namespace std;

template <typename T>
class Queue
{
public:
  Queue()
  {
    _front = _rear = new QueueItem();
  }

  ~Queue()
  {
    QueueItem *cur = _front;
    while(cur != nullptr)
    {
      _front = _front->_next;
      delete cur;
      cur = _front;
    }
  }

  void push(const T& val)
  {
    QueueItem* item = new QueueItem(val); //malloc
    _rear->_next = item;
    _rear = item;
  }

  void pop()
  {
    if (empty())
      return;
    QueueItem *first = _front->_next;
    _front->_next = first->_next;
    if (_front->_next == nullptr)
    {
      _rear = _front;
    }
    delete first; //free
  }

  T front() const
  {
      return _front->_next->_data;
  }

  bool empty() const { return _front == _rear;}

private:
  struct QueueItem //产生一个QueueItem的对象池 (10000个节点)
  {
    QueueItem(T data = T()) : _data(data), _next(nullptr) {}

    //给QueueItem提供自定义内存管理
    //这两个本身就是静态方法
    void* operator new (size_t size)
    {
      if (_itemPool == nullptr)
      {
        _itemPool = (QueueItem*)new char[POOL_ITEM_SIZE*sizeof(QueueItem)];
        QueueItem* p = _itemPool;
        for(; p < _itemPool+POOL_ITEM_SIZE - 1; ++p)
        {
          p->_next = p + 1;
        }
        p->_next = nullptr;
      }

      QueueItem* p = _itemPool;
      _itemPool = _itemPool->_next;
      return p;
    }

    void operator delete(void *ptr)
    {
      QueueItem *p = (QueueItem*)ptr;
      p->_next = _itemPool;
      _itemPool = p;
    }

    T _data;
    QueueItem *_next;
    static QueueItem *_itemPool;
    static const int POOL_ITEM_SIZE = 100000;
  };

  QueueItem *_front;
  QueueItem *_rear;
};

//typename 可以告诉编译器后面的嵌套类是一个类型
template <typename T>
typename Queue<T>::QueueItem* Queue<T>::QueueItem::_itemPool = nullptr;


int main()
{
  Queue<int> que;
  for (int i = 0;i < 100000;++i)
  {
    que.push(i);
    que.pop(); 
  }

  cout << que.empty() << endl;
  getchar();
  return 0;
}
```

###  背景：

在 C++ 模板类里，**某个类型是否是类型名**，编译器有时候无法判断。
比如这句：

```cpp
template <typename T>
Queue<T>::QueueItem* ptr;
```

编译器看到 `Queue<T>::QueueItem`，它不知道 `QueueItem` 是：

* **类型（class/struct）**
  还是
* **静态成员变量、成员函数、或其他东西**

C++ 规定：

> 👉 **如果一个名字依赖于模板参数（比如 `T`），且它是个类型，需要用 `typename` 显式标明**。

### 你的代码里：

```cpp
template <typename T>
typename Queue<T>::QueueItem* Queue<T>::QueueItem::_itemPool = nullptr;
```

这里：

* `Queue<T>::QueueItem` 依赖于模板参数 `T`
* 又是一个 **类型名**

所以需要加 `typename`。


### 如果不加会怎么样？

不加 `typename`，编译器会以为 `Queue<T>::QueueItem` 是一个静态成员变量或函数，然后发现用 `*` 解引用，语法就崩了，编译器报错：

> `error: need 'typename' before dependent type name 'Queue<T>::QueueItem'`

### 总结

| 写法                     | 含义                             | 是否依赖T | 是否要加typename |
| :--------------------- | :----------------------------- | :---- | :----------- |
| `Queue<T>::QueueItem*` | `Queue<T>` 中的 `QueueItem` 类型指针 | 是     | ✅            |
| `Queue<T>::itemCount`  | `Queue<T>` 中的静态成员变量            | 是     | ❌            |
### 通俗一句话：

> 👉 **凡是模板依赖名（dependent name）里是类型，就得写 `typename`，不然编译器迷惑。**



## 继承的基本意义

1. 外部只能访问对象public的成员，protected和private的成员无法直接访问。
2. 再继承结构中，派生类从基类可以继承过来private成员，但是派生类却无法直接访问。
3. protected和private的区别？再基类中定义的成员，想被派生类访问，但是不想被外部访问，那么再基类中，把相关成员定义成protected保护的；如果派生类和外部都不打算访问，那么在基类中，就把相关成员定义成private私有的。


## 派生类的构造过程

1. 派生类调用基类的构造函数，初始化从基类继承来的成员。
2. 调用派生类自己的构造函数，初始化派生类自己特有的成员。
3. 调用派生类的析构函数，释放派生类成员可能占用的外部资源（堆内存，文件）
4. 调用基类的析构函数，释放派生类内存中，从基类继承来的成员可能占用的外部资源（堆内存）

## 重载、隐藏、覆盖


###  1️⃣ 重载（Overload）

### ✔ 定义：

* **同一个作用域内**
* **函数名相同**
* **参数列表不同**

👉 编译器根据**参数个数、类型、顺序**来区分调用哪个。

###  示例：

```cpp
void show();
void show(int);
```


### 2️⃣ 隐藏（Name Hiding）

### ✔ 定义：

* **派生类中有和基类同名的成员（函数或变量）**
* 会把基类的同名成员“隐藏”掉
* **不管参数列表是否相同，名字相同就隐藏**

### 📌 注意：

* 如果要访问被隐藏的基类成员，需要用**作用域限定符**。

### 📌 示例：

```cpp
class Base {
  public:
    void show();
    void show(int);
};

class Derive : public Base {
  public:
    void show();
};
```

✔ 此时 `Derive` 作用域里：

* `show()` 覆盖（隐藏）了 `Base` 中所有 `show` 名字相关的函数（无论参数如何）

✔ 要访问基类的：

```cpp
Derive d;
d.Base::show(10);
```


###  3️⃣覆盖（Override）

### ✔ 定义：

* **基类中的虚函数（virtual）**
* **派生类中有相同签名（函数名+参数+返回值）函数**

✔ 此时，**基类指针/引用 指向派生类对象，调用的是派生类的版本（动态绑定）**

### 📌 示例：

```cpp
class Base {
  public:
    virtual void show();
};

class Derive : public Base {
  public:
    void show() override;
};
```

✔ 动态绑定：

```cpp
Base* pb = new Derive();
pb->show(); // 调用 Derive::show()
```

### 4️⃣ 类型转换规则（is-a）

| 转换方向               | 是否允许 | 说明                         |
| :----------------- | :--- | :------------------------- |
| 派生类对象 → 基类对象       | ✅    | 向上类型转换，**安全**              |
| 基类对象 → 派生类对象       | ❌    | 向下类型转换，**不安全**，除非强制转换      |
| 派生类指针/引用 → 基类指针/引用 | ✅    | 向上类型转换                     |
| 基类指针/引用 → 派生类指针/引用 | ❌    | 向下类型转换，除非使用 `dynamic_cast` |

## 📌 5️⃣ 示例解析 📖

```cpp
Base b(10);
Derive d(20);

b = d; // ✅ 派生类对象 → 基类对象，安全，切片现象发生
```

✔ 切片（Object Slicing）：

* 基类对象只保留基类那部分，派生类独有成员丢失。


```cpp
Base* pb = &d;
pb->show();      // 调用 Base::show()，因为没有 virtual
pb->show(20);    // 调用 Base::show(int)
```

✔ 没有 `virtual`，所以是**静态绑定**，根据**指针类型**调用。


```cpp
Derive* p = &b;  // ❌ 不允许，基类对象地址不能赋值给派生类指针
```


###  6️⃣ 小结

| 特性   | 关键点                      |
| :--- | :----------------------- |
| 重载   | 同作用域、同名、不同参数             |
| 隐藏   | 派生类同名成员屏蔽基类成员            |
| 覆盖   | 基类 `virtual` 函数，派生类同签名覆盖 |
| 类型转换 | 默认只允许**从派生到基类**          |

## 虚函数、静态绑定和动态绑定

1. 一个类里面定义了虚函数，那么编译阶段，编译器给这个类类型产生一个唯一的vftable虚函数表，虚函数表中主要存储的内容就是**RTTI指针**(类型字符串）和虚函数的地址。当程序运行时，每一张虚函数表都会加载到内存的.rodata区。

2. 一个类里面定义了虚函数，那么这个类定义的对象，其运行时，内存中开始部分，多存储一个vfptr虚函数指针，指向相应类型的虚函数表vftable。一个类型定义的n个对象，他们的vfptr指向的都是同一张虚函数表。

3. 一个类里面虚函数的个数，不影响对象内存大小（vfptr)，影响的是虚函数表的大小。

4. 如果派生类中的方法，和基类继承来的某个方法，返回值、函数名、参数列表都相同，而且基类的方法是virtual虚函数，那么派生类的这个方法，自动处理成虚函数。

>覆盖：虚函数表中虚函数地址的覆盖。

```cpp
#include <iostream>
#include <typeinfo>

using namespace std;

class Base
{
public:
  Base(int data = 20):ma(data) {}

  /*
  //静态绑定
  void show() { cout << "Base::show()" << endl;}
  void show(int) { cout << "Base::show(int)" << endl;}
  */

  //将成员函数定义为虚函数，会发生动态绑定
  virtual void show() { cout << "Base::show()" << endl;}
  void show(int) { cout << "Base::show(int)" << endl;}
private:
  int ma;
};

class Derive : public Base
{
public:
  Derive(int data = 20):Base(data),mb(data) { }
  virtual void show() {cout << "Derive::show()" << endl;}
private:
  int mb;
};

int main()
{
  Derive d(50);
  Base* p = &d;
  /*
  p->Base Base::show 如果发现show是普通函数，就进行静态绑定 call Base::show
  p->Base Base::show 如果发现show是虚函数，就进行动态绑定
  00007FF6B29E2695  mov         rax,qword ptr [p]  
  00007FF6B29E2699  mov         rax,qword ptr [rax]  
  00007FF6B29E269C  mov         rcx,qword ptr [p]  
  00007FF6B29E26A0  call        qword ptr [rax] 
  */
  p->show();
  p->show(20); //静态绑定 call Base::show(地址)

  cout << typeid(p).name() << endl;
  /*
  p的类型：Base -> 有没有虚函数
  如果Base没有虚函数，*p识别的就是编译时期的类型，*p == Base类型
  如果Base有虚函数，*p识别的就是运行时期的类型RTTI类型
  */
  cout << typeid(*p).name() << endl;

  getchar();
  return 0;
}
```


### 📦 汇编代码：

```
00007FF6B29E2695  mov         rax,qword ptr [p]  
00007FF6B29E2699  mov         rax,qword ptr [rax]  
00007FF6B29E269C  mov         rcx,qword ptr [p]  
00007FF6B29E26A0  call        qword ptr [rax] 
```


### 📌 场景：

C++ 中当你调用**虚函数**时，实际是：

* 对象里有个**虚函数表指针 (vptr)**
* 这个 vptr 指向虚函数表 (vtable)
* 表里按顺序存着虚函数的地址

调用时：

1. 取对象的 vptr
2. 再从表里取函数地址
3. 然后 call

---

### 📌 汇编逐行讲解：

---

### 📍 `00007FF6B29E2695  mov rax, qword ptr [p]`

👉 `p` 是指向对象的指针
👉 把 `p` 指向的**对象地址**取出来，放到 `rax` 寄存器里

例：

```cpp
Base* p = new Derive();
```

这里就是取 `p` 保存的那个地址（指向对象的内存）

---

### 📍 `00007FF6B29E2699  mov rax, qword ptr [rax]`

👉 `rax` 现在是对象地址
👉 对象的前8个字节（64位下）是**vptr**
👉 取出对象内存开头那 8 字节（虚函数表地址），放到 `rax`

**🚨 说明：**
C++ 对象内存布局：

```
0x0000 | vptr -> 虚函数表地址
0x0008 | 成员变量1
0x000C | 成员变量2
...
```

---

### 📍 `00007FF6B29E269C  mov rcx, qword ptr [p]`

👉 再次取 `p` 保存的对象地址，放到 `rcx`
👉 因为 Windows x64 下，调用成员函数，第一个参数是 `this`，通过 `rcx` 传递

---

### 📍 `00007FF6B29E26A0  call qword ptr [rax]`

👉 调用 `rax` 指向的虚函数表里的某个函数地址
👉 执行虚函数调用（多态！）

---

### 📊 汇总一下执行流程：

1. 取对象地址 → `p`
2. 从对象内存取 vptr（虚函数表地址）
3. vptr\[0]（第一个虚函数地址）放到 `rax`
4. 把 `this` 传到 `rcx`
5. call `[rax]` 执行多态调用


### 📌 举个虚函数调用 C++ 源码 🌰

```cpp
class Base {
public:
    virtual void func() { cout << "Base::func" << endl; }
};

Base* p = new Base();
p->func();
```

👉 调用 `p->func()` 就会生成类似你这段汇编。

## 📖 小结

| 汇编指令             | 功能             |
| :--------------- | :------------- |
| `mov rax, [p]`   | 取对象地址          |
| `mov rax, [rax]` | 取 vptr（虚函数表地址） |
| `mov rcx, [p]`   | 把 this 传到 rcx  |
| `call [rax]`     | 调用虚函数表里的函数地址   |

## 虚析构函数

### 哪些函数不能定义为虚函数？
1. 构造函数不能定义为虚函数。
	虚函数的调用依赖于对象（通过对象的前四个字节vfptr,指向vftable中保存的函数地址，间接调用vftable中的虚函数）。在调用构造函数之前，对象还不存在，所以无法将构造函数定义为虚函数。同时在构造函数中，所调用的任何函数都是静态绑定。
2. 静态成员方法不能定义为虚函数
	静态成员方法不能是虚函数，因为它们不与对象实例关联，不依赖 this 指针，也没有虚函数表来支持动态绑定，而虚函数机制正是基于对象的 this 指针和虚函数表来实现的动态多态。

### 什么时候将析构函数定义为虚函数？
当基类的指针指向在堆上分配的派生类对象时，需要将析构函数定义为虚函数。如果，不定义为虚函数，在释放堆上的空间时，只会调用基类的析构函数，导致内存泄漏

### 1. **析构函数和多态**

在 C++ 中，析构函数是用来清理对象资源（如内存、文件句柄等）的特殊成员函数。通常，析构函数会在对象销毁时自动调用。对于一个类层次结构，**如果没有将基类的析构函数定义为虚函数**，那么当通过基类指针删除派生类对象时，**只会调用基类的析构函数**，这可能导致一些资源没有被正确释放，最终造成 **内存泄漏**。

### 2. **问题的根源**

假设你有如下的代码：

```cpp
class Base {
public:
    virtual ~Base() {}  // 如果基类析构函数没有定义为虚函数，这个析构函数不会被调用
};

class Derived : public Base {
public:
    ~Derived() {
        std::cout << "Derived destructor called!" << std::endl;
    }
};

int main() {
    Base* basePtr = new Derived();
    delete basePtr;  // 销毁 Derived 对象时，析构函数会出问题
}
```

### **非虚析构函数的情况**

如果 `Base` 的析构函数没有定义为虚函数，调用 `delete basePtr` 时只会调用 **基类的析构函数**。但是 **派生类** 的析构函数不会被调用，因此派生类中分配的资源（如内存）不会被释放，从而造成 **内存泄漏**。

### **虚析构函数的情况**

如果将 `Base` 的析构函数定义为 **虚函数**，当调用 `delete basePtr` 时，C++ 会根据 `basePtr` 实际指向的对象类型（即 `Derived` 类型）来正确地调用 **派生类的析构函数**，然后再回溯到 **基类的析构函数**。这样，就能确保派生类和基类的资源都被正确释放，避免了内存泄漏。

### 3. **内存泄漏的详细原因**

考虑如下的对象销毁过程：

* 如果 **基类的析构函数不是虚函数**，则当使用基类指针删除派生类对象时，编译器会直接调用基类的析构函数。这时候，由于派生类的析构函数没有被调用，派生类中使用 `new` 或其他资源分配方式分配的内存不会被释放，导致 **内存泄漏**。

* 如果 **基类的析构函数是虚函数**，当调用 `delete` 时，C++ 会查找对象的实际类型（即派生类），然后 **先调用派生类的析构函数**，释放派生类的资源，再调用基类的析构函数，释放基类的资源。这样就能够确保无论是基类还是派生类中分配的资源都能被正确释放。

### 4. **原理：虚函数表（vtable）**

C++ 实现多态性的方式之一是通过 **虚函数表（vtable）**。每个含有虚函数的类都会有一个 **虚函数表**，虚函数表存储了该类的虚函数的地址。

* 当你使用基类指针指向派生类对象时，虚函数表会指向 **派生类版本** 的虚函数。
* 当你调用虚函数（如析构函数）时，C++ 会查找对象的虚函数表，确定应该调用哪个版本的虚函数。
* 如果基类的析构函数是虚函数，调用 `delete basePtr` 时，虚函数表会确保 **先调用派生类的析构函数**，然后才是基类的析构函数。

### 5. **总结**

* **基类析构函数必须是虚函数**，否则在使用基类指针删除派生类对象时，**只会调用基类的析构函数**，导致派生类的析构函数不被调用，可能会引发内存泄漏等资源未释放的问题。
* **虚析构函数** 通过虚函数表（vtable）实现多态，保证正确的析构函数调用顺序，确保对象销毁时，派生类和基类的资源都能正确释放。


## 再谈动态绑定

只有通过指针和引用才会发生动态绑定。

## 理解多态到底是什么

```c++
class Animal
{
public:
  Animal(string name): _name(name) {}
  virtual void bark() {}
protected:
  string _name;
};

class Cat : public Animal
{
public:
  Cat (string name):Animal(name) {}
  void bark() {cout << _name << "Bark: miao miao" << endl;}
};

class Dog : public Animal
{
public:
  Dog(string name) :Animal(name) {}
  void bark() {cout << _name << "Bark: wang wang!" << endl;}
};

class Pig : public Animal
{
public:
  Pig(string name): Animal(name) {}
  void bark() {cout << _name << "Bark: heng heng!" << endl;}
};

/*
void bark(Cat &cat)
{
  cat.bark();
}
void bark(Dog &cat)
{
  cat.bark();
}
void bark(Pig &cat)
{
  cat.bark();
}
*/

void bark(Animal& animal)
{
  animal.bark();
}

int main()
{
  Cat cat("猫咪");
  Dog dog("二哈");
  Pig pig("佩奇");

  bark(cat);
  bark(dog);
  bark(pig);
  getchar();
  return 0;
}
```

## 理解抽象类

```cpp
class Car //抽象类
{
public:
  Car(string name):_name(name) {}
  // 获取汽车剩余油量还能跑的公里数
  double getLeftMiles(double oil) 
  {
    // 1L 10 * oil
    return oil * this->getMilesPerGallon(); //发生动态绑定
  }
protected:
  string _name;
  virtual double getMilesPerGallon() = 0; //纯虚函数
};
```
o

## 理解虚基类和虚继承

**什么是虚基类？**

不同于抽象类，虚基类中没有纯虚函数，而是在派生类继承基类时在基类前添加`virtual`关键字。此时可以称作派生类虚继承基类。

虚继承会在编译期间生成`vbtable`,在运行时放入`.rodata`段。

```cpp
class A
{
public:
  virtual void func() {cout << "call A::func" << endl;}
  void operator delete(void *ptr)
  {
    cout << "operator deltete p:" << ptr << endl;
    free(ptr);
  }
private:
  int ma;
};

class B : virtual public A
{
public:
void func() {cout << "call B::func" << endl;}
void* operator new(size_t size)
{
  void*p = malloc(size);
  cout << "operator new p:" << p << endl;
  return p;
}
private:
  int mb;
};

/*
A a; 4个字节
B b; ma,mb 8个字节 + 4 = 12个字节  vbptr
*/

int main()
{
  //基类指针指向派生类对象，永远指向的是派生类基类部分数据的起始地址
  A *p = new B();
  cout << "main p:" << p << endl;
  p->func();
  delete p;
  getchar();
  return 0;
}
```

派生类`B`虚继承基类`A`。在`main`函数中，B类型的对象包含从A对象继承而来的`vfptr`和成员变量`ma`，同时在B类型对象的头部还会添加一个指针`vbptr`指向`vbtable`。此时，对象b的大小为`ma + mb + vbptr + vfptr`为16个字节(32位平台下)。

类B对象的内存布局：
![[Pasted image 20250601144815.png]]

如上图所示，`vbptr`始终是在内存布局最顶部位置。`vfptr`是从基类A继承而来的(因为派生类b没有虚函数),但是`vfptr`所指向的是派生类B的`vftable`。

**运行以上代码会发生内存释放错误，这是什么原因？**

基类指针指向派生类对象，永远指向的都是派生类基类部分的起始地址(vfptr)。所以，在释放内存的时候，只会释放基类部分的地址。导致内存释放错误。
>在Linux/g++编译器下不会发生报错，因为g++会自动偏移到new的地址,进行内存的释放。

![[Pasted image 20250601151232.png]]

## 菱形继承


C++ 中的 **多重继承**（Multiple Inheritance）在涉及“**菱形继承**”（Diamond Inheritance）结构时，会引发一个非常经典的问题：**间接基类的成员会在派生类中被复制多份**，从而带来数据冗余、二义性等问题。

下面我将从原理、问题、解决方法三个方面**详细解释**：

---

### 一、什么是菱形继承？

### 🔹 继承结构图示：

```cpp
       A
      / \
     B   C
      \ /
       D
```

- `B` 和 `C` 都继承自 `A`（间接基类）
    
- `D` 同时继承自 `B` 和 `C`
    
- 这就构成了一个 **菱形结构**
    

### 📌 示例代码（未使用虚继承）：

```cpp
#include <iostream>
using namespace std;

class A {
public:
    int a;
};

class B : public A {};
class C : public A {};
class D : public B, public C {};

int main() {
    D d;
    d.B::a = 1;  // 访问B继承来的A::a
    d.C::a = 2;  // 访问C继承来的A::a
    cout << d.B::a << " " << d.C::a << endl;
}
```

---

### 二、问题出现在哪？

### 🟥 问题 1：**派生类 D 中存在两份 A 的成员变量 `a`**

- `B` 中有一份 A 的子对象
    
- `C` 中又有一份 A 的子对象
    
- 所以 `D` 中有两份 A 的数据（a 重复了两次）
    

### 🟥 问题 2：**访问 A 的成员时存在二义性**

如果你尝试直接访问 `d.a`：

```cpp
d.a = 10;  // ❌ 错误，编译器报“二义性”
```

编译器不知道你是想访问从 `B` 继承来的 `A::a` 还是从 `C` 继承来的 `A::a`

---

### ✅ 三、如何解决？——使用**虚继承（virtual inheritance）**

### 🌐 虚继承的核心思想：

> 多个派生类共享一个公共的基类子对象，避免重复。

### ✅ 修改示例代码：

```cpp
class A {
public:
    int a;
};

class B : virtual public A {};
class C : virtual public A {};
class D : public B, public C {};
```

现在：

- `B` 和 `C` 不再各自持有一份 `A`
    
- 它们共享 `A`，`D` 中只存在 **一份 A 的子对象**
    
- `d.a` 不再二义性，访问的是唯一的一份 `A::a`
    

---

### 🧪 虚继承后的访问演示：

```cpp
int main() {
    D d;
    d.a = 10;  // ✅ 不再二义性
    cout << d.a << endl;
}
```

###  总结

| 特性       | 普通继承           | 虚继承         |
| -------- | -------------- | ----------- |
| A 的子对象个数 | 多份（重复）         | 一份（共享）      |
| 是否二义性    | 是（如 `d.a` 不明确） | 否（只有一份 `a`） |
| 用途       | 普通多继承          | 解决菱形继承二义性   |



### 一、**普通（非虚）继承下的内存结构**

### ✅ 代码结构

```cpp
class A { int a; };
class B : public A {};
class C : public A {};
class D : public B, public C {};
```

### 🧠 内存布局图（D 的对象）

```
+--------------------+ ← D对象起始地址
| B::A::a            | ← 来自 B 的 A 子对象
+--------------------+
| B 部分其他成员     |
+--------------------+
| C::A::a            | ← 来自 C 的 A 子对象（重复）
+--------------------+
| C 部分其他成员     |
+--------------------+
| D 自己的成员       |
+--------------------+
```

🟥 **问题**：有两份 `A::a`，访问 `d.a` 会产生二义性，必须使用 `d.B::a` 或 `d.C::a` 指定路径。

---

### ✅ 二、**虚继承后的内存结构**

### ✅ 代码结构

```cpp
class A { int a; };
class B : virtual public A {};
class C : virtual public A {};
class D : public B, public C {};
```

### 🧠 内存布局图（D 的对象）

```
+--------------------+ ← D对象起始地址
| B 虚基表指针       | ↘
+--------------------+   \
| B 部分其他成员     |    \
+--------------------+     ↘
| C 虚基表指针       |      ↘
+--------------------+       ↘
| C 部分其他成员     |        ↘
+--------------------+         ↘
| 虚基类 A::a        | ← 只有一份 A 的数据
+--------------------+
| D 自己的成员       |
+--------------------+
```

🟩 **优势**：只有一份 `A::a`，不再二义性，`d.a` 就能直接访问。

---

## 🧩 补充说明：为什么虚继承要加“虚基表指针”

* C++ 实现虚继承时，需要让派生类动态找到共享的虚基类子对象地址
* 因此，编译器会添加“虚基指针”（类似虚表）来管理这个偏移和映射关系


## C++的四种类型转换

``` cpp
#include <iostream>
#include <stdio.h>

using namespace std;

class Base
{
public:
  virtual void func() {cout << "Base::func()" << endl;} 
protected:
  int ma;
};

class Derive1 : public Base
{
public:
  virtual void func() {cout << "Derive::func()" << endl;}
};

class Derive2 : public Base
{
public:
  virtual void func() {cout << "Derive2::func()" << endl;}
  void dynamic_func2() {cout << "Derived2:dynmaic_func2()" << endl;}
};

void showFunc(Base* p)
{
  // dynamic_cast会检查p指针是否指向的是一个Derive2类型的对象？
  // p->vfptr->vftable RTTI信息，如果是，dynamic_cast转换类型成功
  // 返回Derive2对象的地址，给pd；否则返回nullptr
  Derive2* pd = dynamic_cast<Derive2*>(p);
  if( pd != nullptr)
  {
    pd->dynamic_func2();
  }
  else
  {
    p->func();
  }
}

int main()
{
  // const int a = 10;
  // char* p1 = (char*)&a;

  // //const_cast<这里面必须是指针或者引用类型 int* int&>
  // int *p2 = const_cast<int*>(&a);
  Derive1 p;
  Derive2 p2;
  showFunc(&p);
  showFunc(&p2);
  getchar();
  return 0;
}
```

# 实现智能指针

待实现。。。。

# shared_ptr的交叉引用问题

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


> **设计建议：** 对象拥有关系用 `shared_ptr`，引用关系（特别是互相引用）用 `weak_ptr`，避免资源泄漏。


关于 `weak_ptr::lock()` 的使用，下面是对其涉及的**核心知识点总结**，帮助你全面理解其作用和使用方式：

---

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

### 🔁 正确示例：

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

---
##  五、使用建议和注意事项

| 项目     | 建议/注意事项                                          |
| ------ | ------------------------------------------------ |
| 安全性    | 使用 `lock()` 获取 `shared_ptr` 后一定要检查是否为 `nullptr`  |
| 性能     | `lock()` 的开销较低，不需要担心性能问题                         |
| 生命周期管理 | `weak_ptr` 不会导致循环引用，非常适合做观察者、回调等场景               |
| 替代错误写法 | 永远不要尝试对 `weak_ptr` 解引用或使用 `*`、`->`，只能通过 `lock()` |

# 多线程访问共享对象的线程安全问题

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

deletor里默认调用delete ptr
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

### ✅ 函数式写法：

使用 `lambda` 作为删除器，可以避免专门写类，代码更简洁。

```cpp
unique_ptr<int, function<void(int*)>> ptr1(new int[100], [](int* p) {
  cout << "call lambda release new int[100]";
  delete[] p;
});
```

### ✅ 文件资源释放：

```cpp
unique_ptr<FILE, function<void(FILE*)>> ptr2(fopen("data.txt", "w"), [](FILE* p) {
  cout << "call lambda release FILE";
  fclose(p);
});
```

> 🔍 `function<void(FILE*)>` 表示这个 lambda 匿名函数是一个**可调用对象**，签名是 `void(FILE*)`。


## ✅ 四、总结知识点清单

| 知识点              | 说明                                |
| ---------------- | --------------------------------- |
| `unique_ptr`     | 独占所有权的智能指针，自动释放资源                 |
| 默认删除器            | `delete`（单对象），不适合 `new[]` 或特殊资源   |
| 自定义删除器           | 通过自定义类 `operator()` 函数，指定释放行为     |
| `delete[]` 删除器   | 用于数组资源，必须用 `delete[]` 而非 `delete` |
| 文件关闭器            | 用 `fclose` 关闭 `fopen` 打开的文件       |
| `lambda` 删除器     | 简洁灵活，不需要额外定义类                     |
| `function` 类型删除器 | 用于支持 lambda 作为可调用对象               |


## ❗ 注意事项

1. `unique_ptr<T>` 默认使用 `delete`，处理数组时要改用 `delete[]`。
2. 若自定义删除器类型不同，需要指定第二个模板参数。
3. `function<void(T*)>` 类型消耗资源较大，但通用性强。
4. 删除器必须满足 **可拷贝/可移动并可调用** 要求。


# bind1st和bind2nd什么时候会用到

##  一、函数对象（Function Object）

### ✅ 定义：

函数对象就是**重载了 `operator()` 的类对象**，行为类似函数。

### ✅ 标准库中的例子：

* `greater<int>`：返回 `a > b`
* `less<int>`：返回 `a < b`（默认排序函数）
* `plus<int>`、`minus<int>`、`multiplies<int>` 等


## 🔁 二、绑定器（Binder）机制

### ✅ 目的：

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


## 🔧 四、重要 STL 算法函数回顾

| 函数                          | 作用                    |
| --------------------------- | --------------------- |
| `sort(begin, end)`          | 升序排序，默认使用 `less<T>()` |
| `sort(begin, end, comp)`    | 使用自定义比较器              |
| `find_if(begin, end, pred)` | 找第一个满足条件的元素           |
| `insert(pos, val)`          | 在迭代器 `pos` 位置插入元素     |


## 💡 五、其他语言特性

### 1. `typename` 用法（模板细节）

```cpp
typename Container::iterator it;
```

原因：

* 在模板中，`Container::iterator` 是**依赖类型**，编译器不能确定它是类型，必须用 `typename` 显示说明。

# 模板的完全特例化和部分特例化

```cpp
#include <iostream>
#include <string.h>
#include <typeinfo>
using namespace std;

/*
模板的完全特例化和非完全（部分）特例化
模板的实参推演
*/

template<typename T> //T包含了所有的大类型 返回值，所有形参的类型都取出来
void func(T a)
{
  cout << typeid(T).name() << endl;
}

class Test
{
public:
  int sum(int a,int b) {return a + b;}
private:
  int ma;
  int mb;
};

template<typename R,typename A1,typename A2> //T包含了所有的大类型 返回值，所有形参的类型都取出来
void func2(R (*a)(A1,A2))
{
  cout << typeid(R).name() << endl;
  cout << typeid(A1).name() << endl;
  cout << typeid(A2).name() << endl;
}

template <typename R,typename T,typename A1,typename A2>
void func3(R (T::*a)(A1,A2))
{ 
  cout << typeid(R).name() << endl;
  cout << typeid(T).name() << endl;
  cout << typeid(A1).name() << endl;
  cout << typeid(A2).name() << endl;
}

int sum(int a,int b) { return a + b;}

int main()
{
  func(sum);
  func2(sum);
  func3(Test::sum);
  getchar();
  return 0;
}

//模板的完全特例化和非完全（部分）特例化
#if 0
template <typename T>
class Vector
{
public:
  Vector() {cout << "call Vector template init" << endl;}
};

//下面这个是对char*类型提供的完全特例化版本 #1
template <>
class Vector<char*>
{
public:
  Vector() {cout << "call Vector<char*> template init" << endl;}
};

// 下面这个是对指针类型提供的部分特例化版本 #2
template<typename Ty>
class Vector<Ty*>
{
public:
  Vector() {cout << "call Vector<Ty*> template init" << endl;}
};

// 针对函数指针(有返回值，有两个形参变量）提供的部分特例化
template <typename R, typename A1, typename A2>
class Vector<R(*)(A1,A2)>
{
public:
  Vector() {cout << "call Vector<R(*)(A1,A2)> template init" << endl;}
};

// 针对函数(有一个返回值，有两个形参变量）类型提供的部分特例化
template <typename R, typename A1, typename A2>
class Vector<R(A1,A2)>
{
public:
  Vector() {cout << "call Vector<R(A1,A2)> template init" << endl;}
};

int sum(int a,int b) {return a + b;}

int main()
{
  Vector<int> vec1;
  Vector<char*> vec2;
  Vector<int*> vec3;
  Vector<int(*)(int,int)> vec4;
  Vector<int(int,int)> vec5;

  typedef int (*PFUNC1)(int,int);
  PFUNC1 pfunc1 = sum;
  cout << pfunc1(10,20) << endl;

  typedef int PFUNC2(int,int);
  PFUNC2* pfunc2 = sum;
  cout << (*pfunc2)(10,20) << endl;
  return 0;
}
#endif

#if 0
template <typename T1, typename T2>
bool compare(T1 a, T2 b)
{
  return a > b;
}

template <>
bool compare<const char*, const char*>(const char* a, const char* b)
{
  return strcmp(a, b) > 0;
}

int main()
{
  return 0;
}
#endif
```