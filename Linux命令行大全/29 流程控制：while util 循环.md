
### 29.1 循环

  - **核心思想**：循环 (loop) 是一种编程结构，它允许一段代码**重复执行**，直到某个特定条件不再满足为止。`while` 循环是 Shell 中最基础的循环类型之一。

#### while

  - **`while` 的工作原理**：`while` 循环和 `if` 语句非常相似，它也是通过检查一个命令的**退出状态**来做决策。只要该命令的退出状态为 `0` (成功)，`do...done` 之间的代码块就会一直重复执行。
  - **基本语法**：
    ```shell
    while commands; do
      # 当 commands 成功时 (退出状态为0)，
      # 这里的代码会一直重复执行
    done
    ```

**关键示例 1：使用 `while` 循环计数**
这个脚本展示了 `while` 循环最基本的用法：重复执行代码块，并在每次循环时更新一个计数器，直到计数器达到指定的值。

```bash
#!/bin/bash
# while-count: 显示从 1 到 5 的一系列数字
count=1

# 当条件 [[ "$count" -le 5 ]] 为真时，就一直循环
while [[ "$count" -le 5 ]]; do
  echo "$count"
  count=$((count + 1)) # 每次循环将 count 的值加 1
done

echo "Finished."
```

**执行流程**：

1.  `count` 初始值为 1，`1 <= 5` 为真，打印 1，`count` 变为 2。
2.  `count` 值为 2，`2 <= 5` 为真，打印 2，`count` 变为 3。
3.  ...
4.  `count` 值为 5，`5 <= 5` 为真，打印 5，`count` 变为 6。
5.  `count` 值为 6，`6 <= 5` 为假，循环结束。

**关键示例 2：用 `while` 改进菜单脚本**
通过将整个菜单逻辑放入一个 `while` 循环，我们可以让菜单在用户做出选择并看到结果后，**自动重新显示**，而不是像之前的版本那样直接退出。只有当用户明确选择“退出”（例如输入0）时，循环条件才为假，程序才会终止。

```bash
#!/bin/bash
# while-menu: 循环显示的菜单驱动程序
DELAY=3 # 每次显示结果后暂停的秒数

while [[ "$REPLY" != 0 ]]; do
  clear
  # 1. 显示菜单 (cat 和 here document)
  cat <<- _EOF_
    Please Select:
      1. Display System Information
      2. Display Disk Space
      3. Display Home Space Utilization
      4. Quit
_EOF_

  # 2. 获取用户输入
  read -p "Enter selection [0-3] > "

  # 3. 判断并执行
  if [[ "$REPLY" =~ ^[0-3]$ ]]; then
    if [[ "$REPLY" == 1 ]]; then
      echo "Hostname: $HOSTNAME"
      uptime
      sleep "$DELAY"
    fi
    if [[ "$REPLY" == 2 ]]; then
      df -h
      sleep "$DELAY"
    fi
    # ... 其他选项 ...
  else
    echo "Invalid entry."
    sleep "$DELAY"
  fi
done

echo "Program terminated."
```

-----

### 29.2 跳出循环

  - **核心思想**：在循环执行过程中，有时需要提前改变循环的正常流程。Bash 提供了两个命令来实现这一点：
      - `break`：**立即彻底终止**当前循环，程序将跳转到 `done` 之后的代码继续执行。
      - `continue`：**立即跳过本次循环中余下的代码**，直接开始下一次循环的判断和执行。

**关键示例：在无限循环菜单中使用 `break` 和 `continue`**
这个版本的菜单使用了 `while true;` 创建了一个“无限循环”，它自身永远不会停止。我们必须在内部通过 `break` 来提供一个出口。

```bash
#!/bin/bash
# while-menu2: 使用 break 和 continue 的菜单
DELAY=3

while true; do # true 命令永远成功 (返回0), 形成无限循环
  clear
  cat <<- _EOF_
    Please Select:
      1. Display System Information
      2. Display Disk Space
      3. Display Home Space Utilization
      4. Quit
_EOF_
  read -p "Enter selection [0-3] > "

  if [[ "$REPLY" == 0 ]]; then
    break # 用户输入0, 调用 break 退出无限循环
  fi

  # ... (处理 1, 2, 3 的代码) ...
  # 在每个选项处理完后，可以加 continue (可选)，
  # 立即跳回循环开头显示菜单，不再执行后面的判断
  if [[ "$REPLY" == 1 ]]; then
    uptime; sleep "$DELAY"; continue
  fi
  # ...

done

echo "Program terminated."
```

#### until

  - **核心思想**：`until` 循环是 `while` 循环的**反义词**。
      - `while` 循环：当条件为**真** (退出状态为0) 时，**继续**循环。
      - `until` 循环：当条件为**真** (退出状态为0) 时，**停止**循环。（换句话说，当条件为**假**时，**继续**循环）。

**关键示例：使用 `until` 循环计数**
要实现和 `while [[ "$count" -le 5 ]]` 同样的效果，`until` 的条件必须反过来。

```bash
#!/bin/bash
# until-count: 使用 until 显示一系列数字
count=1

# 循环直到 count 大于 5 (即当 count<=5 时，一直循环)
until [[ "$count" -gt 5 ]]; do
  echo "$count"
  count=$((count + 1))
done

echo "Finished."
```

-----

### 29.3 使用循环读取文件

  - **核心思想**：`while` 循环结合 `read` 命令，是 Shell 脚本中逐行读取和处理文件的标准、高效方法。

  - **两种主要方式**：

    1.  **输入重定向 (推荐)**：使用 `<` 将文件内容重定向给整个循环。
    2.  **管道 (有副作用)**：将其他命令的输出通过 `|` 管道连接给循环。

**关键示例 1：使用输入重定向读取文件**
这是最常用、最推荐的逐行读取文件的方式。注意重定向符 `< distros.txt` 是加在 `done` 关键字后面的。

```bash
#!/bin/bash
# while-read: 从文件读取行

# 假设 distros.txt 文件内容是 "Ubuntu 24.04 LTS" 这样的格式
while read distro version release; do
  printf "发行版: %s\t版本: %s\n" "$distro" "$version"
done < distros.txt
```

**关键示例 2：通过管道读取命令输出**
可以方便地处理其他命令（如 `sort`, `grep`）的输出结果。

```bash
#!/bin/bash
# while-read2: 读取 sort 命令的输出

sort distros.txt | while read distro version release; do
  printf "发行版: %s\t版本: %s\n" "$distro" "$version"
done
```

> **重点提醒：警惕管道中的子 Shell**
>
> 和 `echo "data" | read var` 一样， `command | while ...` 这种管道用法会创建一个**子 Shell**来运行 `while` 循环。
>
> **副作用**：在循环内部创建或修改的任何变量，在循环结束、子 Shell 销毁后，都会**全部丢失**，无法在脚本的后续部分使用。
>
> **结论**：如果你需要在循环结束后继续使用在循环内计算出的变量，**必须使用输入重定向的方式 (`done < file`)**。