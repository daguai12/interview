
这篇文章是一个系列的第一篇，演示如何有效使用 [GNU 调试器 (GDB)](https://www.gnu.org/software/gdb/) 来调试 [C 和 C++](https://developers.redhat.com/topics/c) 应用程序。如果你几乎没有 GDB 使用经验，这个系列会教你如何更高效地调试代码。如果你已经是经验丰富的 GDB 专业用户，或许你也能在这里发现一些以前没见过的内容。

除了提供许多 GDB 命令的开发技巧和窍门之外，后续文章还将涵盖一些主题，例如调试优化过的代码、离线调试（核心转储文件），以及基于服务器的会话（也就是 `gdbserver`，用于容器调试）。

## 为什么要再写一篇 GDB 教程？

目前网上大多数 GDB 教程仅仅介绍 `list`、`break`、`print` 和 `run` 等基础命令。新手用户甚至可能更适合直接阅读（或唱）[官方的 GDB 之歌](https://www.gnu.org/music/gdb-song.html)！

本系列文章的目标不是仅仅演示几个有用的命令，而是每一篇都专注于 GDB 使用的某个方面，并且站在 GDB 开发者的视角来讲解。我每天都在用 GDB，这些技巧和方法是我（以及许多资深 GDB 用户和开发者）用来加快调试过程的经验总结。

因为这是系列的第一篇文章，所以我会按照 GDB 之歌的建议，从最基础的地方讲起：如何运行 GDB。

## 编译器选项

先把一个（看似显而易见但常常被忽略的）建议讲出来：为了获得最佳调试体验，请在**关闭优化**并**开启调试信息**的情况下编译应用程序。这虽然是很简单的建议，但 GDB 的公开 IRC 频道 (#gdb) 上仍然经常有人因为这个问题而遇到麻烦，所以值得特别强调。

**一句话总结**：能避免的话，就不要在开启优化的情况下调试程序。关于优化的专题，请等后续文章。

如果你不了解编译器在“幕后”做了什么，优化可能会导致 GDB 出现一些令人意外的行为。在开发阶段，我总是使用编译器选项 `-O0`（字母 O 后面跟数字 0）来构建可执行文件。

同时，我也总是让工具链生成调试信息，这通过 `-g` 选项实现。现在已经没有必要（也不推荐）去显式指定调试格式了；在 GNU/Linux 上，DWARF 已经作为默认调试信息格式使用多年。所以可以忽略一些建议，例如使用 `-ggdb` 或 `-gdwarf-2`。

有一个选项值得额外提一下，就是 `-g3`。它会让编译器把宏定义（`#define FOO ...`）的调试信息也包含进去。这样，你就可以像使用程序中其他符号一样在 GDB 中使用这些宏。

总之，在编译代码时，推荐使用 `-g3 -O0`。一些环境（例如基于 GNU autotools 的环境）会通过环境变量（`CFLAGS` 和 `CXXFLAGS`）来控制编译器的输出。请检查这些标志，确保编译器的调用中包含了你需要的调试设置。

如果想更深入了解 `-g` 和 `-O` 对调试体验的影响，可以参考 Alexander Oliva 的文章 [GCC gOlogy: Studying the Impact of Optimizations on Debugging](https://www.fsfla.org/~lxoliva/#gOlogy)。

## 启动脚本

在正式使用 GDB 之前，必须先了解一下 GDB 的启动过程以及它会执行哪些脚本文件。启动时，GDB 会依次执行以下系统和用户脚本文件：

1. `/etc/gdbinit`（FSF 版本的 GNU GDB 没有这个）：在许多 GNU/Linux 发行版（包括 Fedora 和 [Red Hat Enterprise Linux](https://developers.redhat.com/products/rhel/overview)）中，GDB 会首先查找系统默认的初始化文件并执行其中的命令。在基于 Red Hat 的系统中，这个文件还会执行 `/etc/gdbinit.d` 下安装的脚本文件（包括 [Python](https://developers.redhat.com/blog/category/python/) 脚本）。
2. `$HOME/.gdbinit`：接着，GDB 会读取用户主目录下的全局初始化脚本（如果存在的话）。
3. `./.gdbinit`：最后，GDB 会在当前目录查找启动脚本。这个文件通常用于应用程序特定的定制，可以添加项目相关的用户自定义命令、pretty-printers 和其他定制内容。

这些启动文件中包含的都是 GDB 命令，但也可以写 Python 脚本，只要用 `python` 命令作为前缀，例如：`python print('Hello from python!')`。

我的 `.gdbinit` 文件其实很简单，主要是启用命令历史功能，让 GDB 能记住之前执行过的命令。它类似于 shell 的历史机制（`.bash_history`）。完整内容如下：

```
set pagination off
set history save on
set history expansion on
```

第一行关闭了 GDB 内置的分页功能。第二行开启了历史记录保存（默认保存到 `~/.gdb_history`）。最后一行启用了感叹号（!）的 shell 风格历史展开。这个选项默认是关闭的，因为感叹号在 C 语言中也是逻辑运算符。

如果你不想让 GDB 读取初始化文件，可以在启动时加上 `--nx` 选项。

## 在 GDB 中获取帮助

GDB 有多种获取帮助的方式，包括非常详尽但略显枯燥的[官方文档](https://sourceware.org/gdb/documentation/)，里面解释了几乎所有开关、功能和细节。

### GDB 社区资源

社区支持的两个主要渠道是：

* 邮件： [GDB 邮件列表](https://sourceware.org/mailman/listinfo/gdb/)
* IRC： [libera.chat](https://libera.chat/) 上的 `#gdb`

不过，既然这篇文章是关于 *使用* GDB 的，那么最简单直接的获取帮助方式还是用 GDB 内置的帮助系统。

### 使用帮助系统

GDB 内置的帮助系统可以通过 `help` 和 `apropos` 命令访问。如果你不知道 `printf` 命令怎么用，可以直接问 GDB：

```
(gdb) help printf
Formatted printing, like the C "printf" function.
Usage: printf "format string", ARG1, ARG2, ARG3, ..., ARGN
This supports most C printf format specifications, like %s, %d, etc.
(gdb)
```

`help` 命令接受任意 GDB 命令或选项的名字，并输出该命令或选项的用法说明。

和所有 GDB 命令一样，`help` 也支持 tab 自动补全。这是了解命令参数类型最有用的方式之一。例如输入 `help show ar` 后按 Tab，会提示可能的补全选项：

```
(gdb) help show ar
architecture   args         arm
(gdb)
```

此时 GDB 会停在命令提示符下，等待你进一步补全输入。如果在后面加上 `g` 再按 Tab，就会补全为 `help show args`：

```
(gdb) help show args
Show argument list to give program being debugged when it is started.
Follow this command with any number of args, to be passed to the program.
(gdb)
```

如果你记不住命令的确切名称，可以使用 `apropos` 来搜索帮助系统里的相关内容，它就像对内置帮助做 grep 一样。

现在你知道了如何找到帮助，我们终于可以进入下一步：启动 GDB。

## 启动 GDB

毫不意外，GDB 支持大量命令行选项来调整行为，但最基本的启动方式就是在命令行中把应用程序的名字传给 GDB：

```
$ gdb myprogram
GNU gdb (GDB) Red Hat Enterprise Linux 9.2-2.el8
...
Reading symbols from /home/blog/myprogram...
(gdb)
```

GDB 启动后会打印版本信息（这里展示的是 GCC Toolset 10），加载程序及其调试信息，显示版权和帮助消息，最后给出命令提示符 `(gdb)`，此时就可以输入命令了。

### 避免冗余信息：`-q` 或 `--quiet`

我已经看过成千上万次 GDB 的启动信息了，所以一般会用 `-q`（quiet）选项来屏蔽它：

```
$ gdb -q myprogram
Reading symbols from /home/blog/myprogram...
(gdb)
```

这样就简洁多了。如果你刚开始接触 GDB，可能会觉得完整的启动信息很有用甚至很“安心”。但用久了之后，你可能会在 shell 里直接把 `gdb` 别名成 `gdb -q`。如果需要查看被隐藏的信息，可以使用 `-v` 选项或在 GDB 内输入 `show version`。

### 传递参数：`--args`

很多程序需要命令行参数。GDB 提供了多种方式来传递参数（在 GDB 术语中，程序叫做 *inferior*）。最常用的两种方式是：

* 在运行时通过 `run` 命令传递
* 在启动时通过 `--args` 选项传递

例如，如果你平时用 `myprogram 1 2 3 4` 启动应用，那么只需改成：

```
$ gdb -q --args myprogram 1 2 3 4
```

这样 GDB 就会记住运行参数。

### 附加到运行中的进程：`--pid`

如果程序已经在运行但“卡住了”，你可能想直接查看它的内部状态。此时可以用 `--pid` 传递进程号，例如：

```
$ gdb -q --pid 1591979
```

这样 GDB 会加载符号信息并挂起该进程，让你可以开始调试。

### 调试崩溃转储文件：`--core`

如果进程异常中止并生成了 core 文件，可以用 `--core` 选项来加载，例如：

```
$ gdb -q abort-me --core core.2127239
```

这样就能直接查看导致崩溃的位置。

（关于 core 文件找不到的问题，可以检查 `ulimit -c`，或者使用 `coredumpctl`。）

### 执行启动命令：`--ex`, `--iex`, `-x`, `--batch`

这些选项可以让你在启动时预先执行一些 GDB 命令，非常适合自动化场景。比如：

* `--ex CMD`：在程序和调试信息加载 **之后** 执行
* `--iex CMD`：在程序加载 **之前** 执行
* `-x FILE`：从脚本文件执行命令
* `--batch`：在命令执行完后直接退出（常用于脚本环境）

示例里展示了如何用这些选项组合来定制启动调试过程。

## 下期预告

在本文中，我介绍了 GDB 的启动过程、脚本执行顺序，以及一些高级用户常用的启动选项。

下一篇文章会稍作绕行，讲解什么是调试信息、如何检查调试信息、GDB 从哪里查找调试信息，以及如何在发行版中安装调试信息包。

你是否有和 GDB 脚本或启动相关的技巧，或者希望未来我们介绍某个具体的 GDB 使用话题？欢迎在文章下方留言分享你的想法。

*最后更新：2024 年 2 月 27 日*

---

要不要我帮你也把里面的命令示例（`gdb -q myprogram`、`help printf` 等）附上中文注释，这样更贴合新手读者？
