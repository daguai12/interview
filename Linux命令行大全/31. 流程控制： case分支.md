### 31.1 case 命令

  - **核心思想**：`case` 命令是 Shell 中用于处理**多重选择**的复合命令。当你需要根据**同一个变量**的不同取值来执行不同操作时，`case` 语句通常比一长串的 `if/elif/else` 结构**更清晰、更易读**。

  - **基本语法**：

    ```bash
    case "$variable" in
      pattern1)
        # 匹配 pattern1 时执行的命令
        ;;
      pattern2)
        # 匹配 pattern2 时执行的命令
        ;;
      *)
        # 没有任何模式匹配时，执行这里的命令 (默认情况)
        ;;
    esac
    ```

**关键示例：用 `case` 简化菜单脚本**
对比一下用 `if` 和用 `case` 实现的同一个菜单，可以明显看出 `case` 的结构更整洁。

  - **`if` 版本 (回顾)**：

    ```bash
    # (前面显示菜单和 read 的代码省略)
    if [[ "$REPLY" == 0 ]]; then
      # ...
    elif [[ "$REPLY" == 1 ]]; then
      # ...
    elif [[ "$REPLY" == 2 ]]; then
      # ...
    # ...
    fi
    ```

  - **`case` 版本 (推荐)**：

    ```bash
    #!/bin/bash
    # case-menu: 使用 case 的菜单驱动程序
    # (前面显示菜单和 read 的代码省略)
    read -p "Enter selection [0-3] > "

    case "$REPLY" in
      0)
        echo "Program terminated."
        exit
        ;;
      1)
        echo "Hostname: $HOSTNAME"
        uptime
        ;;
      2)
        df -h
        ;;
      3)
        du -sh "$HOME"
        ;;
      *) # 匹配所有其他情况
        echo "Invalid entry" >&2
        exit 1
        ;;
    esac
    ```

-----

#### 31.1.1 模式

  - **核心思想**：`case` 使用的模式 (Pattern) 与**文件名通配符 (globbing)** 相同，**不是正则表达式**。
  - **常用模式**：
      - `a)`：精确匹配字符串 "a"。
      - `a|b)`：逻辑 **OR**，匹配 "a" **或者** "b"。
      - `[abc])`：匹配 "a"、"b"、"c" 中的任意一个字符。
      - `???)`：匹配任意三个字符。
      - `*.txt)`：匹配以 ".txt" 结尾的任意字符串。
      - `*)`：**捕获所有**，匹配任何内容。通常用作最后一个模式，处理所有未匹配到的情况（相当于 `if` 中的 `else`）。

**关键示例：使用 `|` 匹配大小写**
通过 `|` 操作符，可以轻松地让一个模式同时接受大写和小写输入。

```bash
# (菜单显示和 read 代码省略)
read -p "Enter selection [A, B, C or Q] > "

case "$REPLY" in
  q|Q) # 匹配小写 q 或 大写 Q
    echo "Program terminated."
    exit
    ;;
  a|A)
    echo "Hostname: $HOSTNAME"
    uptime
    ;;
  # ... 其他选项 ...
  *)
    echo "Invalid entry" >&2
    exit 1
    ;;
esac
```

-----

#### 31.1.2 执行多次操作

  - **默认行为**：`case` 在找到**第一个**匹配的模式并执行完其代码后，就会立即终止。
  - **新特性 (Bash 4.0+)**：如果你希望 `case` 在匹配成功后**继续向下检查**其他模式，可以使用 `;&&` 代替 `;;`。这在某个输入可能同时属于多种分类时非常有用。

**关键示例：使用 `;&&` 实现“穿透”匹配**
下面的脚本用来判断一个字符的多种属性。字符 'a' 同时是小写字母、字母、可见字符和十六进制数。

```bash
#!/bin/bash
# case4-2: 测试一个字符的多重属性
read -n 1 -p "Type a character > "
echo

case "$REPLY" in
  [[:upper:]]) echo "'$REPLY' is upper case." ;;&
  [[:lower:]]) echo "'$REPLY' is lower case." ;;&
  [[:alpha:]]) echo "'$REPLY' is alphabetic." ;;&
  [[:digit:]]) echo "'$REPLY' is a digit." ;;&
  [[:xdigit:]]) echo "'$REPLY' is a hexadecimal digit." ;;&
esac
```

**执行结果：**

```shell
[me@linuxbox ~]$ case4-2
Type a character > a
'a' is lower case.
'a' is alphabetic.
'a' is a hexadecimal digit.
```