
# 17.1 基本的脚本函数

在`bash shell`脚本中有两种创建函数的方法。

```shell
# 方法一：
function name { # name 和 { 之间必须要有空格
	commands
}

# 方法二：
name() {
	commands
}
```

## 17.1.2 使用函数

在使用函数之前必须要定义该函数，如果没有定义函数或者将调用的函数定义在调用函数的位置后，将会出现报错。

```shell
test2.sh: line 16: func2: command not found
```

定义的函数名，必须是唯一的，如果重复定义该函数，新的定义将会覆盖原来函数的定义。再次调用该函数时，执行的内容将是重定义的函数体内的内容。

# 17.2 返回值

## 17.2.1 默认退出状态码

默认情况下函数退出的状态码，是函数中最后一条命令返回的退出状态码。我们可以使用`$?`来查看退出状态码的值。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ cat test4.sh 
#!/bin/bash

func1() {
  echo "try to display a non-existent file"
  ls -l badfile
}

echo "testing the function"
func1
echo "The exit status is: $?"
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ bash test4.sh 
testing the function
try to display a non-existent file
ls: cannot access 'badfile': No such file or directory
The exit status is: 2
```

该函数的退出状态码是2，是因为函数的最后一条命令执行失败。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ cat test5.sh 
#!/bin/bash

func1() {
  ls -l badfile
  echo "try to display a non-existent file"
}

echo "testing the function"
func1
echo "The exit status is: $?"
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ bash test5.sh 
testing the function
ls: cannot access 'badfile': No such file or directory
try to display a non-existent file
The exit status is: 0
```

该函数的退出状态码为0，但是函数中的第一条指令执行失败，最后一条指令执行成功，所以最后返回的状态码为0。

## 17.2.2 使用 return 命令

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ cat test5b.sh
#!/bin/bash

function db1 {
  read -p "Enter a value: " value
  echo "doubling the value"
  return $[ $value * 2 ]
}

db1
echo "The new value is $?"
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ bash test5b.sh
Enter a value: 130
doubling the value
The new value is 4
```

通过`return`指令可以设定函数的状态码。但是需要在函数执行完之后立即立即使用`$?`来输出函数的状态码，如果在函数结束后调用了一条其他指令，函数退出的状态码将会丢失。所以我们应该在函数调用结束后，立即输出函数的状态码。

所以在使用函数时需要注意：
1. return只能返回`0 ~ 255`范围内的数字。
2. 在函数结束后立马取值。
3. 如果返回的值为字符串则无法使用该方法返回。

## 17.2.3 使用函数输出

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ cat test5c.sh 
#!/bin/bash

function db1 {
  read -p "Enter a value:" value
  echo $[ $value * 2]
}

result=$(db1)
echo "The new value is $result"
```

新函数会用echo语句来显示计算的结果。该脚本会获取dbl函数的输出，而不是查看退出状态码。

# 17.3 在函数中使用变量

## 17.3.1 向函数传递参数

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ cat test6.sh 
#!/bin/bash

function addem {
  if [ $# -eq 0 ] || [ $# -gt 2 ]
  then
    echo -1
  elif [ $# -eq 1 ]
  then
    echo $[ $1 + $1 ]
  else
    echo $[ $1 + $2 ]
  fi
}

echo -n "Adding 10 and 15: "
value=$(addem 10 15)
echo $value
echo -n "let's try adding just one number:"
value=$(addem 10)
echo $value
echo -n "Now Try adding no numbers: "
value=$(addem)
echo $value
echo -n "Finally, try adding three numbers: "
value=$(addem 10 15 20)
echo $value
```

错误的使用方式，函数中的`$1`和`$2`，和命令行参数的不同。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ cat badtest1.sh 
#!/bin/bash

function badfunc1 {
  echo $[ $1 * $2 ]
}

if [ $# -eq 2 ]
then
  value=$(badfunc1)
  echo "The result is $value"
else
  echo "Usage:badtest1 a b"
fi
```

在使用命令行传递参数的时候，需要手动将参数传递给函数。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ cat test7.sh 
#!/bin/bash

function badfunc1 {
  echo $[ $1 * $2 ]
}

if [ $# -eq 2 ]
then
  value=$(badfunc1 $1 $2)
  echo "The result is $value"
else
  echo "Usage:badtest1 a b"
fi
```

## 17.3.2 在函数中处理变量

1. 全局变量
	默认情况下，你在脚本中定义的任何变量都是全局变量。在函数外定义的变量可在函数内正常访问。
2. 局部变量
	无需在函数中使用全局变量，函数内部使用的任何变量都可以被声明成局部变量。要实现这 一点，只要在变量声明的前面加上local关键字就可以了。

# 17.4 数组变量和函数

## 17.4.1 向函数传数组参数

## 17.4.2 从函数返回数组

# 17.5 函数递归

# 17.6 创建库

当我们需要在不同的脚本中使用相同的函数，这个时候我们可以创建一个库文件。在需要使用库函数的脚本中引入该库文件。

错误的引入方式：

```shell
#!/bin/bash

./myfuncs.sh

value1=10
value2=5
result1=$(addem $value1 $value2)
result2=$(multem $value1 $value2)
result3=$(divem $value1 $value2)
echo "The result of adding them is: $result1"
echo "The result of adding them is: $result2"
echo "The result of adding them is: $result3"

daguai@daguai-VMware-Virtual-Platform:~/shell/17$ bash test14.sh 
test14.sh: line 7: addem: command not found
test14.sh: line 8: multem: command not found
test14.sh: line 9: divem: command not found
The result of adding them is: 
The result of adding them is: 
The result of adding them is: 

```

如果像执行普通的shell脚本一样引入该库文件，在运行脚本时将会报错。因为，使用`./myfuncs.sh`命令时，会创建一个新的`shell`并运行该脚本。但是，当运行另外一个要用到该函数的脚本时，该脚本是无法使用这些函数的。（因为两个脚本所处的shell会话不同）

正确的引入方式：

```shell
#!/bin/bash

. ./myfuncs.sh

value1=10
value2=5
result1=$(addem $value1 $value2)
result2=$(multem $value1 $value2)
result3=$(divem $value1 $value2)
echo "The result of adding them is: $result1"
echo "The result of adding them is: $result2"
echo "The result of adding them is: $result3"

daguai@daguai-VMware-Virtual-Platform:~/shell/17$ bash test14.sh 
test14.sh: line 7: addem: command not found
test14.sh: line 8: multem: command not found
test14.sh: line 9: divem: command not found
The result of adding them is: 
The result of adding them is: 
The result of adding them is: 
```

使用`. ./myfuncs.sh`的方式引入库文件就避免了上述的情况，因为该命令是在当前shell上下文中执行命令，而不是创建一个新shell。这样脚本就可以使用库中的函数了。

# 17.7 在命令行上使用函数

在命令行中定义函数，这样就可以在系统的任何地方使用该函数。而不用像`shell`脚本一样关系，脚本是否在`PATH`环境变量之中。
# 17.7.1 在命令行上创建函数

创建函数的两种方式：

```shell
方式一：
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ function multem {
> echo $[ $1 * $2 ]
> }
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ multem 10 20
200

方式二：
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ function divem { read -p "Enter value: " value; echo $[ $value * 2 ]; }
daguai@daguai-VMware-Virtual-Platform:~/shell/17$ divem 20 10
Enter value: 20 
40

```

## 17.7.2 在 .bashrc文件中定义函数

使用在命令行上创建函数的方式，在退出`shell`之后就失效，无法做到持久化。所以，我们可以在`.bashrc`中定义函数，这样当我们每次登录`shell`之后，系统都会在主目录上查找这个文件，并且导入文件中的命令。

**1. 直接定义函数**

我们可以直接在`.bashrc`文件的末尾定义自己的函数。

**2.读取函数文件**

我们可以直接使用`source`命令库文件的函数添加到`.bashrc`文件中。

```shell
. /home/daguai/libraries/myfuncs
```

