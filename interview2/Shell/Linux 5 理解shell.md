# 5.1 shell的类型

在linux系统中有着不同的类型的shell , 如 bash , dash , sh ,fish 等shell . 我们可以通过命令 `cat /etc/passwd` 来查看自己所使用的shell类型 . 

```shell
cat /etc/passwd
daguai:x:1000:1000:daguai:/home/daguai:/usr/bin/fish
```

在用户daguai中使用的shell类型为fish , 该shell该用户的默认shell , 在该用户登录到虚拟终端控制台或者是终端仿真器中 , 默认shell就会自动运行 . 

# 5.2 shell的父子关系

用于登录虚拟终端控制器或者是GUI启动的终端仿真器时所启动的shell是父shell , 该shell会提供CLI提示符 , 然后等待用户的输入 . 

在父shell中输入bash命令可以启动一个子shell , 同样也会提供CLI提示符 , 等待用户的输入 . 在启动一个子shell 系统并不会给我们启动成功的提示 . 我们可以通过使用 `ps -f`的命令来查看子shell是否启动成功 . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ ps -f
UID          PID    PPID  C STIME TTY          TIME CMD
daguai    144414  144406  0 14:50 pts/0    00:00:00 fish
daguai    144762  144414  0 15:13 pts/0    00:00:00 bash
daguai    144811  144762 99 15:25 pts/0    00:00:00 ps -f
```

在示例中bash的ppid为144414 , fish的pid为144414 , 所以bash是子进程而fish为父进程 . 

同时我们也可以使用 `ps --forest` 的命令来更加清晰的看到这种父子之间的关系 . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ ps --forest
    PID TTY          TIME CMD
 144414 pts/0    00:00:00 fish
 144762 pts/0    00:00:00  \_ bash
 144820 pts/0    00:00:00      \_ bash
 144841 pts/0    00:00:00          \_ bash
 144847 pts/0    00:00:00              \_ bash
 144853 pts/0    00:00:00                  \_ bash
 144863 pts/0    00:00:00                      \_ ps
```

bash shell程序可以使用命令行参数修改shell启动方式 . 参数表如下图所示 . 

| 参数       | 描述                                                     |
|:------------|:----------------------------------------------------------|
| `-c string` | 从 `string` 中读取命令并进行处理                          |
| `-i`        | 启动一个能够接收用户输入的交互式 shell                    |
| `-l`        | 以登录 shell 的形式启动                                   |
| `-r`        | 启动一个受限 shell，用户会被限制在默认目录中              |
| `-s`        | 从标准输入中读取命令（通常在脚本或管道中使用）             |

在创建了子shell之后我们可以通过 `exit`命令来 , 有条不紊的退出多个子shell , 如果当前的shell为父shell (启动虚拟终端控制台时默认启动的shell) ,则会退出控制台 . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ exit
exit
daguai@daguai-VMware-Virtual-Platform:~$ exit
exit
daguai@daguai-VMware-Virtual-Platform:~$ exit
exit
daguai@daguai-VMware-Virtual-Platform:~$ exit
exit
daguai@daguai-VMware-Virtual-Platform:~$ ps --forest
    PID TTY          TIME CMD
 144414 pts/0    00:00:00 fish
 144762 pts/0    00:00:00  \_ bash
 144900 pts/0    00:00:00      \_ ps
```

##  5.2.1 进程列表

如果想要在一行中执行多个不同的命令 , 可以通过命令列表的方式 . 

``` shell
daguai@daguai-VMware-Virtual-Platform:~$ pwd ; ls ; cd /etc ; pwd ; cd ; pwd ;ls
/home/daguai
CloudDrive      Desktop    Linux_network_code       myfile.txt  shell
CloudDrive.1.0  Documents  Linux_reviews            neovide     snap
CloudDrive.zip  Downloads  Linux_system_code        Pictures    temp
CMake           go         Linux_work               project     Templates
cppbase         home       log4cpp                  Public      Videos
cppbost         learn-git  log4cpp-1.1.4rc3.tar.gz  SEM
csapp           Linux      Music                    server
/etc
/home/daguai
CloudDrive      Desktop    Linux_network_code       myfile.txt  shell
CloudDrive.1.0  Documents  Linux_reviews            neovide     snap
CloudDrive.zip  Downloads  Linux_system_code        Pictures    temp
CMake           go         Linux_work               project     Templates
cppbase         home       log4cpp                  Public      Videos
cppbost         learn-git  log4cpp-1.1.4rc3.tar.gz  SEM
csapp           Linux      Music                    server

```

而进程列表的方式是在该行的命令外添加一个括号 . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ (pwd ; ls ; cd /etc ; pwd ; cd ; pwd ;ls)
/home/daguai
CloudDrive      Desktop    Linux_network_code       myfile.txt  shell
CloudDrive.1.0  Documents  Linux_reviews            neovide     snap
CloudDrive.zip  Downloads  Linux_system_code        Pictures    temp
CMake           go         Linux_work               project     Templates
cppbase         home       log4cpp                  Public      Videos
cppbost         learn-git  log4cpp-1.1.4rc3.tar.gz  SEM
csapp           Linux      Music                    server
/etc
/home/daguai
CloudDrive      Desktop    Linux_network_code       myfile.txt  shell
CloudDrive.1.0  Documents  Linux_reviews            neovide     snap
CloudDrive.zip  Downloads  Linux_system_code        Pictures    temp
CMake           go         Linux_work               project     Templates
cppbase         home       log4cpp                  Public      Videos
cppbost         learn-git  log4cpp-1.1.4rc3.tar.gz  SEM
csapp           Linux      Music                    server
```

这两种方式的命令看似作用相同 , 但是使用进程列表的方式是创建了一个子shell来执行相应的命令 . 我们可以通过使用 `echo $BASH_SUBSEHLL` 的值来查看是否用到了子shell , 如果 `BASH_SUBSHELL`的值为0则是没有使用 , 如果值为 1 或者 更大则是使用了子shell . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ (pwd ; ls ; cd /etc ; pwd ; cd ; pwd ;ls ; echo $BASH_SUBSHELL)
/home/daguai
CloudDrive      Desktop    Linux_network_code       myfile.txt  shell
CloudDrive.1.0  Documents  Linux_reviews            neovide     snap
CloudDrive.zip  Downloads  Linux_system_code        Pictures    temp
CMake           go         Linux_work               project     Templates
cppbase         home       log4cpp                  Public      Videos
cppbost         learn-git  log4cpp-1.1.4rc3.tar.gz  SEM
csapp           Linux      Music                    server
/etc
/home/daguai
CloudDrive      Desktop    Linux_network_code       myfile.txt  shell
CloudDrive.1.0  Documents  Linux_reviews            neovide     snap
CloudDrive.zip  Downloads  Linux_system_code        Pictures    temp
CMake           go         Linux_work               project     Templates
cppbase         home       log4cpp                  Public      Videos
cppbost         learn-git  log4cpp-1.1.4rc3.tar.gz  SEM
csapp           Linux      Music                    server
1
```

我们也可以嵌套的使用进程列表 . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ (pwd ; (echo $BASH_SUBSHELL))
/home/daguai
2
```

在shell脚本中，经常使用子shell进行多进程处理。但是采用子shell的成本不菲，会明显拖慢 处理速度。在交互式的CLI shell会话中，子shell同样存在问题。它并非真正的多进程处理，因为 终端控制着子shell的I/O。

## 5.2.2 别出心裁的子shell用法

1. 将进程列表置入后台

示例：

```bash
(sleep 2 ; echo $BASH_SUBSHELL ; sleep 2)
```

- 先 `sleep 2`
    
- 然后输出 `$BASH_SUBSHELL`（应该是1，表示第一级子shell）
    
- 再 `sleep 2`
    
- 再返回到提示符
    

这个命令**阻塞式执行**，你得等它跑完，才有下一个命令行提示符。

示例: 将进程列表放到后台执行

如果你在命令末尾加上 `&`，Bash 就把这组命令放到后台去执行，马上返回提示符，让你继续干别的。

 示例：

```bash
(sleep 2 ; echo $BASH_SUBSHELL ; sleep 2) &
```

执行效果：

- 立刻返回提示符
    
- Bash 显示一个**作业号**（比如`[2]`）和**进程ID**（比如`2401`）
    
- 然后子shell里的命令继续跑
    
- 中间 echo 打印的 `1` 可能会插到当前命令行位置上（不碍事，按个回车就行）
    

 实用场景举例 :

前面用 `sleep` 和 `echo` 只是演示。实际可以在子shell里做一些**耗时但不想阻塞终端的操作**，比如：

```bash
(tar -cf Rich.tar /home/rich ; tar -cf My.tar /home/christine) &
```

- 在后台压缩 `/home/rich` 和 `/home/christine` 目录
    
- 你能立刻继续在命令行里干别的事
    

2. 协程

协程可以做两件事 . 它在后台生成一个子shell , 并在这个子shell中执行命令 .

要使用协程处理 , 得使用coproc命令.

```shell
daguai@daguai-VMware-Virtual-Platform:~$ coproc sleep 3
[1] 145039
daguai@daguai-VMware-Virtual-Platform:~$ 
[1]+  Done                    coproc COPROC sleep 3
```

COPROC 是coproc命令给进程起的名字 . 我们也可以使用扩展语法自己设置这个名字 .

```shell
daguai@daguai-VMware-Virtual-Platform:~$ coproc MY_Job { sleep 10; }
[1] 145054
daguai@daguai-VMware-Virtual-Platform:~$ jobs
[1]+  Done                    coproc MY_Job { sleep 10; }
```

我们还可以将协程与进程列表结合起来产生嵌套的子shell .

```shell
daguai@daguai-VMware-Virtual-Platform:~$ coproc ( sleep 10; sleep 2)
[1] 145067
daguai@daguai-VMware-Virtual-Platform:~$ jobs
[1]+  Running                 coproc COPROC ( sleep 10; sleep 2 ) &
daguai@daguai-VMware-Virtual-Platform:~$ ps --forest
    PID TTY          TIME CMD
 144414 pts/0    00:00:00 fish
 144762 pts/0    00:00:00  \_ bash
 145067 pts/0    00:00:00      \_ bash
 145068 pts/0    00:00:00      |   \_ sleep
```

# 5.3 理解shell的内建命令

## 5.3.1 外部命令

外部命令 , 有时会被称为文件系统命令 , 是存在于bash shell之外的程序 . 他们并不是shell程序的一部分 . 外部命令程序通常位于/bin , /usr/bin , /sbin或/usr/sbin中 . 

ps就是一个外部命令 , 我们可以通过which和type命令找到它 . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ which ps
/usr/bin/ps
daguai@daguai-VMware-Virtual-Platform:~$ type ps
ps is hashed (/usr/bin/ps)
daguai@daguai-VMware-Virtual-Platform:~$ type -a ps
ps is /usr/bin/ps
ps is /bin/ps
```

作为外部命令 , ps命令执行的时候会创建一个子进程 . 外部命令的执行过程称为衍生(forking) . 

## 5.3.2 内建命令

内建命令和外部命令的区别在于 , 前者不需要使用子进程执行 . 他们已经和shell编译成了一体 , 作为shell的工具组成部分存在 . 不需要借助外部程序文件来运行 .

我们可以利用type命令来查看该命令是否是内建的 .如`cd`和`exit`就是内建命令 . 

```shell
daguai@daguai-VMware-Virtual-Platform:~$ type cd
cd is a shell builtin
daguai@daguai-VMware-Virtual-Platform:~$ type exit
exit is a shell builtin
```

有些命令既是外部命令也是内部命令 , 如`pwd`和`echo`就有两种实现 .

我们可以使用`type -a`和`which`命令 , 来查看命令的不同实现 . 

>which命令只能显示外部命令

```
daguai@daguai-VMware-Virtual-Platform:~$ which pwd
/usr/bin/pwd
daguai@daguai-VMware-Virtual-Platform:~$ type -a pwd
pwd is a shell builtin
pwd is /usr/bin/pwd
pwd is /bin/pwd
daguai@daguai-VMware-Virtual-Platform:~$ which echo
/usr/bin/echo
daguai@daguai-VMware-Virtual-Platform:~$ type -a echo
echo is a shell builtin
echo is /usr/bin/echo
echo is /bin/echo
```

1. 使用`history`命令

bash会记录过用户当前使用过的命令(默认值为1000 , 可以在.bashrc中修改HISTSIZE环境变量来修改默认大小) , 

```shell
$history

$!! #执行上一条命令

$!20 #执行指定编号的命令
```

历史命令是先保存在内存中 , 在退出shell时 , 才会写入到用户主目录下的`~/.bash_history`文件下 .可以使用 `history -a`强制把当前会话内存中的历史追加写入 `~/.bash_history` 中 . 

 > 如果打开了多个终端,执行`history -a`命令只会保存当前终端的历史 , 别的终端不会自动同步 . 
 
 >如果你打开了多个终端会话，仍然可以使用history -a命令在打开的会话中 向.bash_history文件中添加记录。但是对于其他打开的终端会话，历史记录并不会自动更 新。这是因为.bash_history文件只有在打开首个终端会话时才会被读取。要想强制重新读 取.bash_history文件，更新终端会话的历史记录，可以使用history -n命令。
 
2. 命令别名

使用`alias`别名可以将复杂的命令简单化 . Linux系统中设置了一些常用的命令别名 , 我们可以通过 `alias -p`命令查看 . 