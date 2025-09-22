# 19.1 文本处理

## 19.1.1 sed编辑器

`sed`命令格式： 

```shell
sed option script file
```

sed命令选项：

```shell
-e script #在处理输入时，将script中指定的命令添加到已有的命令中
-f file   #在处理输入时，将file中指定的命令添加到已有的命令中
-n #不产生命令输出，使用print命令来完成输出
```

**1. 在命令行定义编辑器命令**

使用`sed`处理单行输出：

```shell
 ⚡daguai ❯❯ echo "This is a test" | sed 's/test/big test/'
This is a big test
```

使用`sed`处理多行输出：

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed 's/dog/cat/' data1.txt
The quick brown fox jumps over the lazy cat.
The quick brown fox jumps over the lazy cat.
The quick brown fox jumps over the lazy cat.
The quick brown fox jumps over the lazy cat.
The quick brown fox jumps over the lazy cat.
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ cat data1.txt 
The quick brown fox jumps over the lazy dog.
The quick brown fox jumps over the lazy dog.
The quick brown fox jumps over the lazy dog.
The quick brown fox jumps over the lazy dog.
The quick brown fox jumps over the lazy dog.
```

处理单行数据的速度和多行文件的速度相差无几。使用`sed`替换指定的字符串，并不会在源文件中进行修改，而是将数据发送到`STDOUT`。通过`cat`命令查看，源文件的内容并没有发生改变。

**2. 在命令行使用多个编辑器命令**

```shell
# 方式一
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed -e 's/brown/green/; s/dog/cat/' data1.txt
The quick green fox jumps over the lazy cat.
The quick green fox jumps over the lazy cat.
The quick green fox jumps over the lazy cat.
The quick green fox jumps over the lazy cat.
The quick green fox jumps over the lazy cat.

# 方式二
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed -e '
> s/brown/green/
> s/fox/elephant/
> s/dog/cat/' data1.txt
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.

# 错误演示
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed -e '
s/brown/green/
s/fox/elephant/
s/dog/cat/'
data1.txt
data1.txt
```

两个命令都作用到文件中的每行数据上。命令之间必须用分号隔开，并且在命令末尾和分号 之间不能有空格。 如果不想用分号，也可以用bash shell中的次提示符来分隔命令。

只要输入第一个单引号标示 出sed程序脚本的起始（sed编辑器命令列表），bash会继续提示你输入更多命令，直到输入了标示 结束的单引号。

必须记住，要在封尾单引号所在行结束命令。bash shell一旦发现了封尾的单引号，就会执行 命令。开始后，sed命令就会将你指定的每条命令应用到文本文件中的每一行上。

**3. 从文件中读取编辑器命令**

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ cat script1.sed 
s/brown/green/
s/fox/elephant/
s/dog/cat/
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed -f script1.sed data1.txt
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.
The quick green elephant jumps over the lazy cat.
```

最后，如果有大量要处理的sed命令，那么将它们放进一个单独的文件中通常会更方便一些。 可以在sed命令中用-f选项来指定文件。

在这种情况下，不用在每条命令后面放一个分号。sed编辑器知道每行都是一条单独的命令。 跟在命令行输入命令一样，sed编辑器会从指定文件中读取命令，并将它们应用到数据文件中的 每一行上。

## 19.1.2 gawk 程序

**1. gawk命令格式**

```shell
gawk options program file
```

| 选项               | 功能说明                                           |
|:------------------|:--------------------------------------------------|
| `-F fs`            | 指定行中划分数据字段的字段分隔符                   |
| `-f file`          | 从指定的文件中读取程序                             |
| `-v var=value`     | 定义 gawk 程序中的一个变量及其默认值               |
| `-mf N`            | 指定要处理的数据文件中的最大字段数                 |
| `-mr N`            | 指定数据文件中的最大数据行数                       |
| `-W keyword`       | 指定 gawk 的兼容模式或警告等级                     |
**2. 从命令行读取程序脚本**

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ gawk '{print "Hello World!"}'
hello
Hello World!
nihaos
Hello World!
shijie1
Hello World!
```

gawk程序脚本用一对花括号来定义。你必须将脚本命令放到两个花括号（{}）中。如果你 错误地使用了圆括号来包含gawk脚本，就会得到一条类似于下面的错误提示。

```shell
$ gawk '(print "Hello World!"}' gawk: (print "Hello World!"} gawk: ^ syntax error
```

运行该命令之后，命令会等待`STDIN`中的输入。如果想要结束命令，可以使用组合键`CTRL+D`来结束命令，因为`CTRL+D`会生成`EOF`字符，表明数据流已经结束了。

**3. 使用数据字段变量**

gawk的主要特性之一是其处理文本文件中数据的能力。它会自动给一行中的每个数据元素分 配一个变量。默认情况下，gawk会将如下变量分配给它在文本行中发现的数据字段：

 $0代表整个文本行； 
 $1代表文本行中的第1个数据字段； 
 $2代表文本行中的第2个数据字段； 
 $n代表文本行中的第n个数据字段。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ gawk -F: '{print $1}' data2.txt
One line
Two line
Three line
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ cat data2.txt 
One line:of test text.
Two line:of test text.
Three line:of test text.
```

如果你要读取采用了其他字段分隔符的文件，可以用-F选项指定。

**4.在程序脚本中使用多个命令**

要在命令行上的程序脚本中使用多条命令，只要在命令之间放个分 号即可。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ echo "My name is Rich" | gawk '{$4="Christine"; print $0}'
My name is Christine

daguai@daguai-VMware-Virtual-Platform:~/shell/19$ gawk '{
> $4="Christine"
> print $0}'
My name is Rich
My name is Christine
```

在你用了表示起始的单引号后，bash shell会使用次提示符来提示你输入更多数据。你可以每 次在每行加一条命令，直到输入了结尾的单引号。因为没有在命令行中指定文件名，gawk程序会 从STDIN中获得数据。当运行这个程序的时候，它会等着读取来自STDIN的文本。要退出程序， 只需按下Ctrl+D组合键来表明数据结束。

**5.从文件中读取程序**

跟sed编辑器一样，gawk编辑器允许将程序存储到文件中，然后再在命令行中引用。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ cat script2.gawk 
{print $1 "'s home directory is " $6}
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ gawk -F: -f script2.gawk  /etc/passwd
root's home directory is /root
daemon's home directory is /usr/sbin
bin's home directory is /bin
sys's home directory is /dev
sync's home directory is /bin
games's home directory is /usr/games
man's home directory is /var/cache/man
lp's home directory is /var/spool/lpd
```

可以在程序文件中指定多条命令。要这么做的话，只要一条命令放一行即可，不需要用分号。

```shell
{
text = "'s home directory is "
print $1 text $ 6
}
```

**6.在处理数据前运行脚本**

gawk还允许指定程序脚本何时运行。默认情况下，gawk会从输入中读取一行文本，然后针 对该行的数据执行程序脚本。有时可能需要在处理数据前运行脚本，比如为报告创建标题。BEGIN 关键字就是用来做这个的。它会强制gawk在读取数据前执行BEGIN关键字后指定的程序脚本。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ gawk 'BEGIN {print "Hello WOrld!"}'
Hello WOrld!

```

这次print命令会在读取数据前显示文本。但在它显示了文本后，它会快速退出，不等待任 何数据。如果想使用正常的程序脚本中处理数据，必须用另一个脚本区域来定义程序。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ gawk 'BEGIN {print "The data3 File Contents:"}
> {print $0}' data3.txt
The data3 File Contents:
Line 1
Line 2
Line 3

```

在gawk执行了BEGIN脚本后，它会用第二段脚本来处理文件数据。这么做时要小心，两段 脚本仍然被认为是gawk命令行中的一个文本字符串。你需要相应地加上单引号。

**7. 在处理数据后运行脚本**

与BEGIN关键字类似，END关键字允许你指定一个程序脚本，gawk会在读完数据后执行它。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ gawk 'BEGIN {print "The data3 File3 content:"}
> {print $0}
> END {print "End of File"}' data3.txt
The data3 File3 content:
Line 1
Line 2
Line 3
End of File
```

当gawk程序打印完文件内容后，它会执行END脚本中的命令。这是在处理完所有正常数据 后给报告添加页脚的最佳方法。 

可以将所有这些内容放到一起组成一个漂亮的小程序脚本文件，用它从一个简单的数据文件 中创建一份完整的报告。

# 19.2 sed编辑器基础

## 19.2.1 更多的替换选项

**1.替换标记**

替换命令`s`，在默认情况下只能替换每行中第一个出现的字符串。要替换一行中不同地方出现的文本必须使用替换标记（subsitution flag)。

命令格式：
```shell
s/pattern/replacement/flags
```

有四种可替换标记：
 数字，表明新文本将替换第几处模式匹配的地方； 
 g，表明新文本将会替换所有匹配的文本；
 p，表明原先行的内容要打印出来；
 w file，将替换的结果写到文件中。

>在第一类替换中，可以指定sed编辑器用新文本替换第几处模式匹配的地方。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed 's/test/trial/2
> ' data4.txt
This is a test of the trial script.
This is the second test of the trial script.

```

>g替换标 记使你能替换文本中匹配模式所匹配的每处地方。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed 's/test/trial/g' data4.txt
This is a trial of the trial script.
This is the second trial of the trial script.
```

>p替换标记会打印与替换命令中指定的模式匹配的行。这通常会和sed的-n选项一起使用。
>-n选项将禁止sed编辑器输出。但p替换标记会输出修改过的行。将二者配合使用的效果就是 只输出被替换命令修改过的行。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed -n 's/test/trial/p' data5.txt 
This is a trial line.
```

>w替换标记会产生同样的输出，不过会将输出保存到指定文件中。

```shell
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ sed 's/test/trial/w test.txt' data5.txt 
This is a trial line.
This is a different line.
daguai@daguai-VMware-Virtual-Platform:~/shell/19$ cat test.txt
This is a trial line.
```

**2.替换字符**

有时你会在文本字符串中遇到一些不太方便在替换模式中使用的字符。Linux中一个常见的 例子就是正斜线（/）。 
替换文件中的路径名会比较麻烦。比如，如果想用C shell替换/etc/passwd文件中的bash shell， 必须这么做：

```shell
$ sed 's/\/bin\/bash/\/bin\/csh/' /etc/passwd 
```

由于正斜线通常用作字符串分隔符，因而如果它出现在了模式文本中的话，必须用反斜线来 转义。这通常会带来一些困惑和错误。 

要解决这个问题，sed编辑器允许选择其他字符来作为替换命令中的字符串分隔符： 
```shell
$ sed 's!/bin/bash!/bin/csh!' /etc/passwd 
```

在这个例子中，感叹号被用作字符串分隔符，这样路径名就更容易阅读和理解了。

## 19.2.2 使用地址


**行寻址的两种形式：**

1. **数字形式**
    
    - 直接指定行号或行号区间
        
    - 格式：
        
        ```bash
        [行号]command
        [起始行号,结束行号]command
        ```
        
    - 示例：
        
        ```bash
        sed '2s/dog/cat/' data.txt   # 只修改第 2 行
        sed '2,3s/dog/cat/' data.txt # 修改第 2 行和第 3 行
        sed '2,$s/dog/cat/' data.txt # 从第 2 行到最后一行
        ```
        
    - 特殊符号：
        
        - `$` 表示最后一行
            

2. **文本模式形式**
    
    - 使用**正则表达式**或固定文本匹配筛选行
        
    - 格式：
        
        ```bash
        /pattern/command
        ```
        
    - 示例：
        
        ```bash
        sed '/Samantha/s/bash/csh/' /etc/passwd
        ```
        
    - 匹配包含 `Samantha` 的行，将 `bash` 替换成 `csh`
        

 **命令组合（多命令对某行或区间生效）**

- 用花括号 `{}` 将多条命令组合在一起，作用于同一地址行或地址区间
    
- 格式：
    
    ```bash
    address {
        command1
        command2
    }
    ```
    
- 示例：
    
    ```bash
    sed '2{
    s/fox/elephant/
    s/dog/cat/
    }' data.txt
    ```
    
    或者作用于区间：
    
    ```bash
    sed '3,${
    s/brown/green/
    s/lazy/active/
    }' data.txt
    ```
    
好！我来帮你把这段关于 `sed` 删除行的用法整理成清晰总结笔记👇：


##  19.2.3 sed 删除行命令总结

###  删除命令基本格式

```bash
[address]d
```

 `d` 是 **delete** 命令，删除匹配行，不影响原文件，只作用于输出结果。


### 📌 删除行的几种常见方式

#### ① 删除**所有行**

```bash
sed 'd' file.txt
```

> ⚠️ **危险操作**，会清空所有行的输出。

---

#### ② 按**行号**删除

```bash
sed '3d' file.txt       # 删除第 3 行
sed '2,3d' file.txt     # 删除第 2 到 3 行
sed '3,$d' file.txt     # 删除第 3 行到最后一行
```

---

#### ③ 按**文本模式**删除

```bash
sed '/pattern/d' file.txt
```

示例：

```bash
sed '/number 1/d' file.txt
```

> 删除所有包含 "number 1" 的行。

---

#### ④ 删除**区间行（模式到模式）**

```bash
sed '/起始模式/,/结束模式/d' file.txt
```

示例：

```bash
sed '/1/,/3/d' file.txt
```

- 删除从**匹配“1”**的行到**匹配“3”**的行（包括这两行）。
    
- ⚠️ 注意：
    
    - **开始模式匹配就开启删除**
        
    - **直到匹配到结束模式才关闭**
        
    - 如果结束模式**不存在**，删除功能会持续到文件结尾
        

示例：

```bash
sed '/1/,/5/d' file.txt
```

> 因为找不到“5”，所以删除从匹配到“1”之后的**所有行**


### 📖 小结表格：

|类型|示例|说明|
|:--|:--|:--|
|删除所有行|`sed 'd' file.txt`|删除全部行，输出为空|
|删除指定行|`sed '3d' file.txt`|删除第 3 行|
|删除行区间|`sed '2,4d' file.txt`|删除第 2~4 行|
|删除最后到某行|`sed '3,$d' file.txt`|删除第 3 行到最后一行|
|删除匹配模式的行|`sed '/pattern/d' file.txt`|删除包含“pattern”的所有行|
|删除模式区间内的行|`sed '/start/,/end/d' file.txt`|删除从匹配“start”到“end”的行（含这两行）|

### 📌 注意事项

- `sed` 删除的是**输出流中的行**，**原文件不变**
    
- 使用模式区间删除时：
    
    - 一旦匹配到起始模式，删除功能开启
        
    - 遇到结束模式才关闭
        
    - 结束模式若不存在 → 删除到结尾
        

##  19.2.4 sed 插入（insert）与附加（append）命令

### 📌 功能区别：

|操作|命令|说明|
|:--|:--|:--|
|插入|`i`|在**指定行前**插入新行|
|附加|`a`|在**指定行后**附加新行|


### 📌 基本格式

```bash
sed '[地址]命令\
新行内容'
```

👉 插入和附加命令不能写在单行，需要换行输入新行内容  
👉 新行内容会显示在 sed 输出流中，不会改动原文件


### 📌 示例讲解

#### ✅ 在**行前插入**

```bash
echo "Test Line 2" | sed 'i\
Test Line 1'
```

**输出**

```
Test Line 1
Test Line 2
```


#### ✅ 在**行后附加**

```bash
echo "Test Line 2" | sed 'a\
Test Line 1'
```

**输出**

```
Test Line 2
Test Line 1
```


### 📌 使用**行号定位**

- 只能针对单行（数字行号或文本模式），不能是区间
    

#### 插入到第 3 行前

```bash
sed '3i\
This is an inserted line.' file.txt
```

#### 附加到第 3 行后

```bash
sed '3a\
This is an appended line.' file.txt
```


### 📌 特殊行定位

|地址|作用|
|:--|:--|
|`1`|第一行|
|`$`|最后一行|

#### 附加到最后一行后

```bash
sed '$a\
This is a new line.' file.txt
```


### 📌 插入或附加**多行文本**

👉 每行结尾需用反斜线 `\` 续行

#### 示例：第一行前插入两行

```bash
sed '1i\
This is one line of new text.\
This is another line of new text.' file.txt
```

**效果**

```
This is one line of new text.
This is another line of new text.
原数据内容……
```

---

### 📖 小结表格：

|类型|示例|说明|
|:--|:--|:--|
|行前插入|`3i\新行内容`|在第 3 行前插入|
|行后附加|`3a\新行内容`|在第 3 行后附加|
|文件开头插入|`1i\新行内容`|文件开头前插入|
|文件结尾附加|`$a\新行内容`|文件最后一行后附加|
|多行插入/附加|每行后加 `\` 续行|每行都需 `\`，最后一行不用|


---

##  19.2.5 sed `c` 修改命令总结

### 📌 功能：

- **将匹配行的整行文本替换为新内容**
    
- 和 `i`（插入）、`a`（附加）类似，都需要换行单独写新行内容
    


### 📌 基本格式

```bash
sed '[地址]c\
新行内容' 文件名
```

- `[地址]`：可以是行号、文本模式或地址区间
    


### 📌 示例讲解

#### ✅ 按行号修改

将第 3 行改成新内容：

```bash
sed '3c\
This is a changed line of text.' data6.txt
```


#### ✅ 按文本模式匹配行修改

匹配包含 `number 3` 的行，改成新内容：

```bash
sed '/number 3/c\
This is a changed line of text.' data6.txt
```


#### ✅ 多行匹配修改（地址区间）

把第 2 行到第 3 行，一起用新的一行替换：

```bash
sed '2,3c\
This is a new line of text.' data6.txt
```

**效果**

- `2,3` 行都会被替换成**同一行新内容**，而不是逐行修改
    


### 📖 小结表格：

|类型|示例|说明|
|:--|:--|:--|
|行号修改|`3c\新内容`|将第 3 行替换为新内容|
|模式匹配修改|`/模式/c\新内容`|将匹配该模式的所有行替换为新内容|
|行区间修改|`2,3c\新内容`|将第 2 行到第 3 行**整体替换成一行新内容**|


### 📌 注意事项：

- `c` 命令是**替换整行**，不能只替换行内部分内容
    
- 地址区间会**整体用一行新文本替代所有匹配行**，而不是逐行改
    

##  19.2.6 sed `y` 转换命令总结

### 📌 功能：

- **逐字符替换**
    
- 将某些字符一对一映射成其他字符
    
- 是 sed 中**唯一处理单个字符**的命令
    

---

### 📌 基本格式

```bash
[address]y/inchars/outchars/
```

- `inchars`：要转换的字符集合
    
- `outchars`：对应转换后的字符集合
    
- **长度必须相同**，否则报错
    
- `address` 可以省略，表示作用于所有行
    

---

### 📌 示例讲解

#### ✅ 简单字符转换

把 `1`→`7`，`2`→`8`，`3`→`9`

```bash
sed 'y/123/789/' data8.txt
```

**效果**：

- `This is line number 1.` → `This is line number 7.`
    
- 所有匹配字符都会被替换
    

---

#### ✅ 全局逐字符替换

```bash
echo "This 1 is a test of 1 try." | sed 'y/123/456/'
```

**效果**

- 所有 `1` → `4`
    
- 全行内所有目标字符都会替换，**无法指定位置**
    

---

### 📖 小结表格：

|特性|说明|
|:--|:--|
|作用对象|单个字符|
|inchars 与 outchars 长度|必须相等|
|替换方式|一对一映射，`inchars` 中第 N 个 → `outchars` 中第 N 个|
|区域范围|默认全行，不能定位某个位置|

---

### 📌 注意事项：

- 这是**逐字符映射替换**，不是字符串替换
    
- 无法限定某个特定位置，只能全行内**遇到就替换**
    
- 必须保证 inchars 和 outchars 数量相同
    


##  19.2.7 回顾打印命令总结

sed 除了用 `p` 标记外，还有 3 个**常用打印相关命令**：


### 📌 1️⃣ `p` 命令：打印文本行

- **作用**：打印符合条件的行
    
- **常搭配 `-n` 选项**，避免默认打印所有行
    

#### ✅ 示例：

```bash
sed -n '/number 3/p' data6.txt
```

👉 只打印包含 `number 3` 的行

#### ✅ 打印多行：

```bash
sed -n '2,3p' data6.txt
```

👉 打印第 2 和第 3 行

#### ✅ 和替换命令一起用：

```bash
sed -n '/3/{
p
s/line/test/p
}' data6.txt
```

👉 打印原行 → 替换 → 再打印替换后的行

---

### 📌 2️⃣ `=` 命令：打印行号

- **作用**：在行文本前打印行号
    
- **每个换行符作为行的分界**
    

#### ✅ 示例：

```bash
sed '=' data1.txt
```

👉 每行前显示行号

#### ✅ 配合 `-n` 和模式匹配：

```bash
sed -n '/number 4/{
= 
p
}' data6.txt
```

👉 打印匹配行的行号和行文本


### 📌 3️⃣ `l` 命令（小写L）：列出行内容（含不可打印字符）

- **作用**：显示行内容和不可见字符
    
- 制表符（tab） → `\t`
    
- 行尾 → `$`
    
- 特殊字符 → 八进制或 C 风格转义
    

#### ✅ 示例：

```bash
sed -n 'l' data9.txt
```

👉 把制表符显示成 `\t`，行尾有 `$`

```bash
sed -n 'l' data10.txt
```

👉 可见行内的控制字符（如 `\a`）

---

## 📖 小结表格：

|命令|功能|常见用法|
|:--|:--|:--|
|`p`|打印文本行|`-n '/pattern/p'`|
|`=`|打印行号|`-n '/pattern/{=;p}'`|
|`l`|列出行内容（含不可打印字符）|`-n 'l'`|

---

### 📌 一句话总结：

> **`p` 打内容，`=` 打行号，`l` 查看不可见字符，配合 `-n` 精准控制输出**


##  19.2.8 使用 sed 处理文件总结

sed 除了能在输出里替换、打印，还能**读写文件**。主要涉及两个命令：

---

### 📌 1️⃣ `w` 命令：将数据写入文件

- **作用**：把匹配到或指定行的内容写入文件
    
- **格式**：
    
    ```bash
    [address]w filename
    ```
    
- **说明**：
    
    - `filename`：可以是相对或绝对路径
        
    - 必须有写权限
        
    - `address`：可用行号、文本模式、行区间
        

#### ✅ 示例：

👉 将前两行写入 `test.txt`：

```bash
sed '1,2w test.txt' data6.txt
```

👉 只把包含 `Browncoat` 的行写入新文件：

```bash
sed -n '/Browncoat/w Browncoats.txt' data11.txt
```

---

### 📌 2️⃣ `r` 命令：从文件读取并插入数据

- **作用**：将另一个文件的内容插入到数据流中
    
- **格式**：
    
    ```bash
    [address]r filename
    ```
    
- **说明**：
    
    - `filename`：指定插入用的文件
        
    - `address`：行号或文本模式地址，表示插入到该行之后
        

#### ✅ 示例：

👉 将 `data12.txt` 中内容插入到第 3 行后：

```bash
sed '3r data12.txt' data6.txt
```

👉 将 `data12.txt` 中内容插入到匹配 `number 2` 的行后：

```bash
sed '/number 2/r data12.txt' data6.txt
```

👉 将内容插入到文件末尾：

```bash
sed '$r data12.txt' data6.txt
```

---

### 📌 `r` + `d` 组合：替换占位文本

- **场景**：把某行的占位符替换成另一个文件的内容
    
- **做法**：
    
    - `r`：读取插入内容
        
    - `d`：删除占位行
        

#### ✅ 示例：

👉 将 `LIST` 替换成 `data11.txt` 内容：

```bash
sed '/LIST/{
r data11.txt
d
}' notice.std
```

---

## 📖 小结表格：

|命令|功能|常见用法|
|:--|:--|:--|
|`w`|将匹配行写入文件|`sed '1,2w out.txt' in.txt`|
|`r`|将文件内容插入数据流|`sed '3r insert.txt' in.txt`|
|`r+d`|读取文件内容替换占位符行|`sed '/PLACEHOLDER/{r file;d}' template.txt`|

---

### 📌 一句话总结：

> **`w` 写文件，`r` 读文件，`r+d` 替换占位行**，灵活操作多文件数据流！
