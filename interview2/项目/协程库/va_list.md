## ✅ 使用场景

当你想写一个函数，参数个数不固定时，比如 `printf`、`log(...)`，就可以用 `va_list`。

---

## ✅ 基本步骤（记住这四步）

```c
#include <stdarg.h>

// 声明一个可变参数函数
void myPrint(const char* format, ...) {
    va_list args;                // 1. 定义变量 args
    va_start(args, format);      // 2. 初始化 args，第二个参数是最后一个固定参数

    // 3. 提取参数（根据你的设计）
    int i = va_arg(args, int);   // 取一个 int 类型的参数
    char* str = va_arg(args, char*); // 取一个 char* 类型的参数

    // 使用参数
    printf("int = %d, str = %s\n", i, str);

    va_end(args);                // 4. 清理资源
}
```

---

## 🔁 循环读取多个参数（比如自定义 printf）

```c
void printInts(int count, ...) {
    va_list args;
    va_start(args, count);

    for (int i = 0; i < count; ++i) {
        int value = va_arg(args, int); // 必须明确类型
        printf("arg %d: %d\n", i + 1, value);
    }

    va_end(args);
}
```

```c
int main() {
    printInts(3, 10, 20, 30);
    return 0;
}
```

输出：

```
arg 1: 10
arg 2: 20
arg 3: 30
```

---

## 🔥 实际应用：日志函数

```c
void myLog(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);

    vprintf(fmt, args);  // 使用 vprintf/vfprintf/vsnprintf 等格式化函数

    va_end(args);
}
```

用法：

```c
myLog("Error code %d: %s\n", 404, "Not Found");
```

---

## ⚠️ 注意事项

1. **参数类型必须匹配**：你在 `va_arg` 中指定的类型必须和传入的一致。
2. **不能直接传递结构体、类对象**：建议只传基础类型（int、double、char\*等）。
3. `va_list` 不能复制，除非使用 `va_copy`。
4. 必须用 `va_end` 清理。

---

## ✅ 小结口诀

```
va_list 声明，
va_start 开始，
va_arg 取值，
va_end 收尾。
```

---

如果你需要写一个自定义的 `printf`、日志系统、或参数打包函数，我也可以帮你写模板。需要的话告诉我用途即可。
