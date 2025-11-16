好的，`objdump` 和 `readelf` 是 Linux/Unix-like 系统下非常强大的二进制文件分析工具，它们都属于 GNU Binutils 工具集。它们是系统程序员、安全研究员和任何需要深入了解可执行文件（ELF 格式）内部结构的人的必备工具。

下面我将详细地教你如何使用它们，包括它们的核心功能、常用选项以及它们之间的区别。

-----

### 什么是 ELF 文件？

在开始之前，我们先明确一下我们的操作对象。在 Linux 上，几乎所有的可执行文件、共享库（`.so`）、目标文件（`.o`）都是 **ELF** (Executable and Linkable Format) 格式。这些文件内部有标准化的结构，比如：

  * **ELF 头 (ELF Header):** 文件的“身份证”，说明这是个 32 位还是 64 位程序、目标架构（如 x86-64, ARM）以及程序入口地址等。
  * **节头表 (Section Headers):** 描述了文件中的各个“节”(Sections)，比如 `.text`（代码）、`.data`（已初始化的数据）、`.bss`（未初始化的数据）、`.rodata`（只读数据）等。这是**链接器**（Linker）关心的视图。
  * **程序头表 (Program Headers):** 描述了文件中的各个“段”(Segments)，告诉**加载器**（Loader）如何将这个文件加载到内存中运行。这是**操作系统**关心的视图。
  * **符号表 (Symbol Table):** 包含了函数名、变量名和它们的地址。

`objdump` 和 `readelf` 就是用来解析和显示这些信息的工具。

-----

### 一、`readelf`：ELF 文件的“结构解剖专家”

`readelf` 专注于**详细解析 ELF 文件的结构**。它对 ELF 格式的每一个部分都能提供详尽的、人类可读的输出。

假设我们有一个程序 `my_program`。

#### 1\. 查看最关键的头部信息：`readelf -h`

这是查看一个文件“摘要”最快的方式。

```bash
readelf -h my_program
```

你会看到：

  * `Magic`: ELF 文件的魔术数字。
  * `Class`: `ELF64` (64位) 或 `ELF32` (32位)。
  * `Machine`: `Advanced Micro Devices X86-64` (说明是 x86-64 架构)。
  * `Entry point address`: 程序执行的第一条指令的地址。
  * `Start of program headers`: 程序头表(Program Headers)在文件中的偏移。
  * `Start of section headers`: 节头表(Section Headers)在文件中的偏移。

#### 2\. 查看节头表 (Sections)：`readelf -S`

这会列出所有的“节”，让你了解文件的“内容分区”，这对链接器很有意义。

```bash
readelf -S my_program
```

你会看到 `.text`, `.data`, `.bss`, `.rodata`, `.symtab` (符号表), `.strtab` (字符串表) 等。

#### 3\. 查看程序头表 (Segments)：`readelf -l`

这是**非常重要**的一个命令，它告诉你操作系统在运行这个程序时，会如何把它加载（`mmap`）到内存。

```bash
readelf -l my_program
```

你会看到 `LOAD` 类型的段，它们有：

  * `Offset`: 段在文件中的偏移。
  * `VirtAddr` (VMA): 段在内存中的虚拟地址。
  * `FileSize`: 段在文件中的大小。
  * `MemSiz`: 段在内存中的大小（`MemSiz` \>= `FileSize`，多出来的部分就是 `.bss`）。
  * `Flags`: 权限，如 `R E` (可读可执行，代码段) 或 ` RW  ` (可读可写，数据段)。

#### 4\. 查看符号表：`readelf -s`

这会列出所有的符号（函数和变量）。

```bash
readelf -s my_program
```

你会看到符号名、它的值（地址）、类型（`FUNC`, `OBJECT`）和绑定（`GLOBAL`, `LOCAL`, `WEAK`）。

#### 5\. 查看动态链接信息：`readelf -d`

如果你的程序是动态链接的（几乎所有程序都是），这个命令至关重要。

```bash
readelf -d my_program
```

你会看到：

  * `(NEEDED)`: 列出所有依赖的共享库，如 `libc.so.6`, `libstdc++.so.6`。
  * `(RPATH)` / `(RUNPATH)`: 额外的库搜索路径。

#### 6\. 查看所有信息：`readelf -a`

这是“全家桶”命令，它会把上面几乎所有的信息全部打印出来。

```bash
readelf -a my_program
```

-----

### 二、`objdump`：强大的“反汇编器”

`objdump` 也能显示很多 ELF 头部信息，但它最强大、最著名的功能是**反汇编 (Disassembly)**。它能将二进制的机器码翻译回人类可读的汇编语言。

#### 1\. 最核心功能：反汇编：`objdump -d` / `-D`

  * `-d` (`--disassemble`): 只反汇编那些“预计包含指令”的节（如 `.text`）。
  * `-D` (`--disassemble-all`): 反汇编所有节（包括数据节，这有时会产生混乱，但很有用）。

<!-- end list -->

```bash
objdump -d my_program
```

默认情况下，`objdump` 使用 AT\&T 汇编语法（如 `mov %rax, %rbx`）。如果你更习惯 Intel 语法（如 `mov rbx, rax`），这在 C/C++ 开发者中很常见，可以使用 `-M intel`：

```bash
objdump -d -M intel my_program
```

你将看到类似这样的输出，这是 C/C++ 开发者调试性能和理解代码执行流程的利器：

```assembly
0000000000401136 <main>:
  401136:   push   rbp
  401137:   mov    rbp,rsp
  ...
  40114e:   call   401030 <puts@plt>  ; 调用 puts 函数
  ...
  401158:   pop    rbp
  401159:   ret
```

#### 2\. 查看节头表：`objdump -h`

这类似于 `readelf -S`，但输出格式不同，通常更简洁。

```bash
objdump -h my_program
```

#### 3\. 查看符号表：`objdump -t`

这类似于 `readelf -s`。

```bash
objdump -t my_program
```

#### 4\. 查看文件头：`objdump -f`

这类似于 `readelf -h`，提供了文件的架构和类型等摘要信息。

```bash
objdump -f my_program
```

#### 5\. 混合源码和汇编：`objdump -S`

如果你在编译时加了 `-g` 选项（包含了调试信息），`objdump` 可以将 C/C++ 源码和汇编代码交织在一起显示，这对于理解编译器优化非常有帮助！

```bash
# 1. 编译时加入 -g
gcc -g -o my_program my_program.c

# 2. 使用 -S (大写)
objdump -S -M intel my_program
```

你会看到：

```c
int main() {
  401136:   push   rbp
  401137:   mov    rbp,rsp
    puts("Hello");
  40114e:   call   401030 <puts@plt>
}
  401158:   pop    rbp
  401159:   ret
```

-----

### 三、`objdump` vs `readelf`：总结与选择

虽然它们有很多重叠的功能（都能看符号表、节头表），但它们的侧重点完全不同：

| 核心功能             | `readelf` (ELF 结构专家)        | `objdump` (反汇编器)                   |
| :--------------- | :-------------------------- | :--------------------------------- |
| **主要用途**         | 深入分析 ELF 文件的**结构**和**元数据**。 | **反汇编**代码，查看机器指令。                  |
| **ELF 文件头 (-h)** | `readelf -h` (非常详细)         | `objdump -f` (比较简略)                |
| **程序头表 (-l)**    | `readelf -l` (**唯一且最好**的选择) | *不支持*                              |
| **动态链接 (-d)**    | `readelf -d` (**唯一且最好**的选择) | *不支持*                              |
| **反汇编**          | *不支持*                       | `objdump -d` / `-D` (**唯一且最好**的选择) |
| **节头表**          | `readelf -S` (详细)           | `objdump -h` (简洁)                  |
| **符号表**          | `readelf -s` (详细)           | `objdump -t` (简洁)                  |

#### 如何选择？

  * **我想看代码是怎么执行的 (汇编)：**

      * **用 `objdump -d -M intel`**。

  * **我想看我的程序依赖哪些 `.so` 库：**

      * **用 `readelf -d`**。

  * **我想看操作系统是如何把程序加载到内存的 (段分布)：**

      * **用 `readelf -l`**。

  * **我想看 C++ 源码和汇编的对应关系：**

      * 编译时加 `-g`，然后**用 `objdump -S -M intel`**。

  * **我想看一个 `.o` 目标文件里有哪些符号 (函数/变量)：**

      * `readelf -s my_file.o` 或 `objdump -t my_file.o` 都可以。

  * **我想全面深入地了解这个 ELF 文件的所有结构化信息：**

      * **用 `readelf -a`**。

### 四、实战演练

我们来创建一个简单的 C 程序并分析它。

`test.c`:

```c
#include <stdio.h>

int global_data = 42; // .data
int global_bss;       // .bss

int main() {
    printf("Hello: %d\n", global_data);
    return 0;
}
```

#### 1\. 编译

```bash
gcc -g -o test test.c
```

#### 2\. 它依赖什么库？(动态链接)

```bash
readelf -d test | grep NEEDED
```

输出:

```
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
```

> **分析：** 它依赖于 `libc.so.6` (C 标准库)。

#### 3\. 它的代码和数据是怎么加载的？(程序头表)

```bash
readelf -l test
```

输出 (节选):

```
  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
  LOAD           0x000000 0x0000000000400000 0x0000000000400000 0x00067c 0x00067c R E 0x200000  <-- 代码段 (Read + Execute)
  LOAD           0x000e10 0x0000000000600e10 0x0000000000600e10 0x000218 0x000220 RW  0x200000  <-- 数据段 (Read + Write)
```

> **分析：** 第一个 `LOAD` 段是代码，权限 `R E`。第二个 `LOAD` 段是数据，权限 `RW`。注意数据段的 `MemSiz` (0x220) 大于 `FileSiz` (0x218)，多出来的 8 字节（在 64 位系统上）就是留给 `.bss` 段（`global_bss` 变量）的空间。

#### 4\. `main` 函数长什么样？(反汇编)

```bash
objdump -S -M intel test
```

输出 (节选):

```c
000000000040052d <main>:
# int main() {
  40052d:   push   rbp
  40052e:   mov    rbp,rsp
#     printf("Hello: %d\n", global_data);
  400531:   mov    eax,DWORD PTR [rip+0x200ae5] # 60101c <global_data>
  400537:   mov    esi,eax
  400539:   mov    edi,0x4005f0               # "Hello: %d\n" 字符串的地址
  40053e:   mov    eax,0x0
  400543:   call   400410 <printf@plt>
#     return 0;
  400548:   mov    eax,0x0
#}
  40054d:   pop    rbp
  40054e:   ret
```

> **分析：** 我们可以清晰地看到：
>
> 1.  `global_data` (地址 `0x60101c`) 的值被加载到 `eax`。
> 2.  "Hello: %d\\n" 字符串的地址 (`0x4005f0`) 被加载到 `edi`（`printf` 的第一个参数）。
> 3.  `eax` 的值被移动到 `esi`（`printf` 的第二个参数）。
> 4.  调用了 `printf@plt`。

希望这个详细的教程对你有帮助！