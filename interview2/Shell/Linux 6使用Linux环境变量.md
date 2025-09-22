# 6.1 什么时环境变量

## 6.1.1 全局环境变量

全局环境变量对于shell会话和生成的子shell是可见的。局部变量只对生成他们的shell可见。

查看全局变量的命令：

```shell
$ env HOME
$ printenv HOME
$ echo $HOME
```

## 6.1.2 局部环境变量

```shell
$ set
```

`set`命令会输出，Linux系统的中的全局变量、局部变量、用户定义变量。

>命令env、printenv和set之间的差异很细微。set命令会显示出全局变量、局部变量以 及用户定义变量。它还会按照字母顺序对结果进行排序。env和printenv命令同set命 令的区别在于前两个命令不会对变量排序，也不会输出局部变量和用户定义变量。在这 种情况下，env和printenv的输出是重复的。不过env命令有一个printenv没有的功能， 这使得它要更有用一些。


# 6.2 设置用户自定义变量

## 6.2.1 设置局部用户定义变量

注意: 创建用户自定义变量要用小写避免与环境变量混淆

示例:

```shell
$my_variable="Hello World" #创建局部变量
$echo $my_variable #输出变量值
$Hello World

bash #启动一个子shell
$echo $my_variable #无法输出变量值,因为my_variable 是父shell的局部变量
$

$exit  #退出子shell
$echo $my_variable # 退出子shell之后父shell中的局部变量任然可以使用
$Hello World
$exit #退出父shell之后,局部变量也会随之销毁
```

## 6.2.2 设置全局环境变量

通过export命令可以将局部变量导出为全局变量

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ my_variable="Hello World"
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ export my_variable
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ echo $my_variable 
Hello World

daguai@daguai-VMware-Virtual-Platform:~/shell/16$ bash # 创建子shell
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ echo $my_variable # 子shell仍然可以打印父shell中的变量
Hello World
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ exit
exit
daguai@daguai-VMware-Virtual-Platform:~/shell/16$ echo $my_variable 
Hello World
```

在子shell中修改全局变量的值 , 只会影响子shell中变量的值 , 并不会影响父shell中变量的值.

## 6.3 删除环境变量

可以通过`unset`命令删除环境变量 .

>窍门 在涉及环境变量名时，什么时候该使用$，什么时候不该使用$，实在让人摸不着头脑。 记住一点就行了：如果要用到变量，使用$；如果要操作变量，不使用$。这条规则的一 个例外就是使用printenv显示某个变量的值。

在处理全局环境变量的时候 , 如果在子shell中删除了全局环境变量 , 这个改变只会先子shell中反映 . 而不会在父shell中反映 . 

# 6.4 默认的shell环境变量

# 6.5 设置PATH环境变量

当你在shell命令行界面中输入一个外部命令时，shell必须搜索系统来找到对应 的程序。PATH环境变量定义了用于进行命令和程序查找的目录。

如果命令和程序的路径没有包含在PATH目录中 , 且没有输入命令和程序的绝对路径 , shell将会返回错误 .

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell$ myprog
myprog: command not found
```

如果将该程序所在的目录添加到PATH目录中 , 系统就可以查找到该命令所在的目录位置 , 并且执行该命令 . 

添加步骤:

```shell
daguai@daguai-VMware-Virtual-Platform:~/scripts$ pwd
/home/daguai/scripts
daguai@daguai-VMware-Virtual-Platform:~/scripts$ PATH=$PATH:/home/daguai/scripts 
daguai@daguai-VMware-Virtual-Platform:~/scripts$ echo $PATH
/home/daguai/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:/home/daguai/.local/bin:/home/daguai/scripts
daguai@daguai-VMware-Virtual-Platform:~/scripts$ myprog
myprog: command not found
daguai@daguai-VMware-Virtual-Platform:~/scripts$ myprog.sh 
This is my program.
```

>如果想要子shell也可以查找到程序的位置,一定要记得吧修改之后的PATH环境变量导出 .

但是这种对变量的修改方式只能持续到退出或重启系统 . 下次执行该命令时 , 还需要再次修改PATH变量 . 

# 6.6 定位系统环境变量

在登入Linux系统启动一个bash shell时 , 默认情况下bash会在几个文件中查找命令 . 这些文件叫做启动文件或环境文件 . 

启动bash shell的三种方式 :

- 登录时作为默认登录shell
- 作为非登录shell的交互式shell
- 作为运行脚本的非交互shell

## 6.6.1 登录 shell

当登录Linux系统时 , bash shell会作为登录shell启动 . 登录shell会从5个不同的启动文件里读取命令:

- /etc/profile   该文件是系统上默认的bash shell 主启动文件 . 所有用户登录时 , 都会执行该文件中的命令 . 
- $HOME/.bash_profile  剩下的四个文件是针对用户的 , 可更具个人需求定制 . 
- $HOME/.bashrc
- $HOME/.bash_login
- $HOME/.profile

在 Linux 中，**每个用户都可以在自己的 `$HOME` 目录下放置专属的启动文件，定义自己使用的环境变量和 shell 行为**。

 📌 常见的 4 个启动文件（隐藏文件）：

| 文件名                   | 说明                                                        |
| --------------------- | --------------------------------------------------------- |
| `$HOME/.bash_profile` | **bash 登录交互式 shell 启动时执行**，优先运行。                          |
| `$HOME/.bash_login`   | 如果 `.bash_profile` 不存在，就执行这个。                             |
| `$HOME/.profile`      | 如果上面两个都不存在，就执行这个。                                         |
| `$HOME/.bashrc`       | **非登录交互式 shell（比如开一个新终端窗口）时执行**，通常被 `.bash_profile` 间接调用。 |

> 📌 注意：**shell 只会执行上面优先顺序中第一个存在的文件，后面的就忽略了。**

## 6.6.2 交互式shell进程

如果bash shell不是登录系统时启动的(比如在命令行输入bash时启动) , 呢么启动的shell叫做交互式shell . 

如果bash是作为交互式shell启动的 , 它就不会访问 /etc/profile 文件 , 只会检查用户 HOME 目录中 `.bashrc`文件.

.bashrc文件有两个作用：一是查看/etc目录下通用的bashrc文件，二是为用户提供一个定制自 己的命令别名和私有脚本函数的地方。

## 6.6.3 非交互式shell


 什么是非交互式 shell？

- 没有命令行提示符。
    
- 执行 shell 脚本或其他批处理命令时自动启动。
    
- 不读取 `.bash_profile`、`.bashrc` 这类交互式启动文件。
    


 非交互式 shell 如何执行启动命令？

**bash 提供了 `BASH_ENV` 环境变量**

- 当启动一个非交互式 shell 时，bash 会检查 `BASH_ENV` 是否设置了路径。
    
- 如果设置了，会执行 `BASH_ENV` 指定的文件，通常用于设置变量或执行初始化命令。
    

默认情况：

- 在 CentOS 和 Ubuntu 中，默认 **没有设置 `BASH_ENV`**。
    
- 查看方法：
    
```bash
printenv BASH_ENV # 或 echo $BASH_ENV`
```
如果没设置，会返回空行或直接提示符。


 那如果 `BASH_ENV` 没设置，脚本怎么获取环境变量？

**通过子 shell 继承父 shell 的“导出变量”**

- 父 shell 中如果是**导出（export）过的全局变量**，子 shell 能继承。
    
- 父 shell 中的**局部变量（未 export）**，子 shell 无法继承。
    

举例：

如果父 shell 是登录 shell：

- `/etc/profile`
    
- `/etc/profile.d/*.sh`
    
- `$HOME/.bashrc`
    

这些文件里导出的变量，子 shell 执行脚本时都能继承。


 特别注意：

- 脚本是否启动子 shell，取决于执行方式（第 5 章会讲）：
    
    - **启动子 shell** → 能继承父 shell 的导出变量。
        
    - **不启动子 shell**（比如 `. ./script.sh` 或 `source script.sh`）→ 变量直接在当前 shell 中生效。

## 6.6.4 环境变量持久化

对于全局环境变量 , 可以将新的或者是修改过的变量设置放在/etc/profile文件中 . 但是通过这种方法 , 如果你升级了所用的发行版 , 这个文件也会跟着更新 , 所有定制过的变量设置就没有了.

最好是在/etc/profile.d目录中创建一个以`.sh`结尾的文件 . 把所新的修改过的全局环境变量设置放在这个文件中 . 

存储永久性bash shell变量的位置是$HOME/.bashrc文件 . 这一种方式适于所有类型的shell进程 .

# 6.7 数组变量

1. **数组变量的定义：**
    
    - 使用括号将多个值放在一起，用空格分隔。例如：
        
        ```bash
        $ mytest=(one two three four five)
        ```
        
2. **引用数组元素：**
    
    - 直接引用整个数组变量时，只会显示第一个值：
        
        ```bash
        $ echo $mytest
        one
        ```
        
    - 若要引用特定索引的元素，需要使用方括号和索引值：
        
        ```bash
        $ echo ${mytest[2]}
        three
        ```
        
3. **引用整个数组：**
    
    - 使用 `*` 通配符来显示整个数组：
        
        ```bash
        $ echo ${mytest[*]}
        one two three four five
        ```
        
4. **修改数组元素：**
    
    - 可以通过指定索引来修改某个数组元素的值：
        
        ```bash
        $ mytest[2]=seven
        $ echo ${mytest[*]}
        one two seven four five
        ```
        
5. **删除数组元素：**
    
    - 使用 `unset` 命令可以删除指定索引的数组元素：
        
        ```bash
        $ unset mytest[2]
        $ echo ${mytest[*]}
        one two four five
        $ echo ${mytest[2]}
        (空)
        $ echo ${mytest[3]}
        four
        ```
        
6. **删除整个数组：**
    
    - 使用 `unset` 命令删除整个数组：
        
        ```bash
        $ unset mytest
        $ echo ${mytest[*]}
        (空)
        ```
        
7. **注意事项：**
    
    - 数组索引从 **0** 开始，这可能引起一些混淆。
        
    - 数组变量的可移植性差，尤其是在不同的 Shell 环境中，因此在脚本编程时不常使用。
        
    - 由于可移植性问题，数组变量在跨平台或不同 Shell 环境下使用时需要小心。
        
