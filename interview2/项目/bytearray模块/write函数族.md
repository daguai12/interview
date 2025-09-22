
# `write(const void* buf, size_t size)`
## 📌 函数原型：

```cpp
void ByteArray::write(const void* buf, size_t size)
```

### ✅ 函数参数：

* `buf`: 指向要写入的数据缓冲区的指针。
* `size`: 要写入的数据大小（以字节为单位）。

---

## 📚 背景知识：

Sylar 的 `ByteArray` 是一种支持分块式动态扩展的二进制缓冲结构，它的内部通过链表的方式管理一系列称为 **`Node`** 的内存块。每个 `Node` 是一个定长的内存区域（大小为 `m_baseSize`），链表中的每个节点通过 `m_cur` 指针顺序访问。

---

## 🔍 源码详解（逐句解释）：

```cpp
if(size == 0) {
    return;
}
```

### ✅ 意图：

如果用户请求写入的数据大小为 0，那么直接返回，不做任何操作。

---

```cpp
addCapacity(size);
```

### ✅ 意图：

确保内部缓冲区有足够的空间来写入 `size` 字节的数据。如果当前链表中剩余空间不够，会自动申请新的节点扩展。

---

```cpp
size_t npos = m_position % m_baseSize;
```

### ✅ 意图：

`npos` 表示当前写指针（`m_position`）在当前节点内的偏移量。

* 举例：若 `m_position = 4099`，`m_baseSize = 4096`，说明当前已经写完了第一个节点（第0个节点），此时 `npos = 3`，表示当前节点内从偏移 3 开始写。

---

```cpp
size_t ncap = m_cur->size - npos;
```

### ✅ 意图：

当前节点剩余可写入空间大小（从 `npos` 开始算起）。

---

```cpp
size_t bpos = 0;
```

### ✅ 意图：

`bpos` 是 `buf` 缓冲区中当前写入数据的偏移量。从 `0` 开始逐步向后写入。

---

### 🔁 核心写入循环：

```cpp
while(size > 0) {
```

只要还有数据没写完，就不断进行写入。

---

#### ✅ 第一种情况：当前节点空间足够写完剩余数据

```cpp
if(ncap >= size) {
    memcpy(m_cur->ptr + npos, (const char*)buf + bpos, size);
```

* 把从 `buf + bpos` 开始的 `size` 字节数据，拷贝到当前节点的 `ptr + npos` 位置。
* `ptr` 是当前节点的数据起始地址。
* `npos` 是当前节点的写入起点偏移。

---

```cpp
    if(m_cur->size == (npos + size)) {
        m_cur = m_cur->next;
    }
```

* 如果本次写完后刚好写满当前节点（即偏移+写入长度等于节点大小），则更新当前节点指针 `m_cur` 指向下一个节点。

---

```cpp
    m_position += size;
    bpos += size;
    size = 0;
```

* 更新全局写入位置 `m_position`
* 更新写入源缓冲的偏移 `bpos`
* 置 0 表示已写完

---

#### ✅ 第二种情况：当前节点空间不够，需要分多次写入多个节点

```cpp
} else {
    memcpy(m_cur->ptr + npos, (const char*)buf + bpos, ncap);
```

* 拷贝当前节点剩余的 `ncap` 字节数据

---

```cpp
    m_position += ncap;
    bpos += ncap;
    size -= ncap;
```

* 更新写入进度

---

```cpp
    m_cur = m_cur->next;
    ncap = m_cur->size;
    npos = 0;
```

* 进入下一个节点，重置写入偏移 `npos = 0`，重新计算新节点的空间 `ncap`

---

### ✅ 更新 ByteArray 总大小：

```cpp
if(m_position > m_size) {
    m_size = m_position;
}
```

* 更新 ByteArray 的总大小 `m_size`（数据的有效长度）。如果当前写入位置 `m_position` 超过原大小 `m_size`，表示扩展了数据范围。

---

## 🧠 总结

这个 `write` 函数的 **核心功能** 是把任意长度的原始数据写入 ByteArray 的链表缓冲中，它：

* 支持自动扩容；
* 分段写入；
* 按需移动到下一个节点；
* 跟踪总写入位置和总有效数据大小。

---

## 🖼️ 内部数据结构类比图：

```
ByteArray
 ┌───────────────┐      ┌───────────────┐      ┌───────────────┐
 │ Node(4096 B)  │───▶  │ Node(4096 B)  │───▶  │ Node(4096 B)  │──▶ ...
 └───────────────┘      └───────────────┘      └───────────────┘
         ↑                       ↑                      ↑
     m_cur（当前写入点）      写入目标             链式扩展
```

---



# `writeStringF16(std::string& value)`

### 函数原型：

```cpp
void ByteArray::writeStringF16(std::string& value)
```

#### 函数说明：

这是 `sylar::ByteArray` 类中的成员函数，其主要作用是将一个 **字符串（`std::string`）写入 ByteArray 中**，并且使用 **`uint16_t` 类型（即 2 字节无符号整数）表示字符串的长度**，所以称为 `writeStringF16`（F 表示 fixed，16 表示用 16 位定长字段表示长度）。

---

### 逐行解释：

```cpp
writeFuint16(value.size());
```

#### 🔹 `writeFuint16` 是 ByteArray 的另一个成员函数，它的作用是：

* 将一个 `uint16_t`（2 字节无符号整数）写入 ByteArray 中。
* 它的具体实现可能是调用 `write` 函数，把这个整数转为字节序列（通常是小端或大端格式），写入 ByteArray 的内部结构。

这里它将 `value.size()` 写入，即：
📌 **先写入字符串长度（最多 65535 字节）**

---

```cpp
write(value.c_str(), value.size());
```

#### 🔹 `write` 是 ByteArray 的另一个成员函数，其作用是：

* 将一段原始内存缓冲区写入 ByteArray。
* `value.c_str()` 返回的是字符串底层的 `const char*` 指针（以 null 结尾的字符数组），但是注意这里只是写 `value.size()` 字节，不包括结尾的 `'\0'`。
* 所以这里是将字符串的“正文部分”写入 ByteArray，不包含 `\0`。

---

### 🧠 小结：

```cpp
void ByteArray::writeStringF16(std::string& value)
```

的完整逻辑如下：

| 步骤 | 操作                       | 数据                      |
| -- | ------------------------ | ----------------------- |
| 1  | 将字符串长度 `value.size()` 写入 | 用 `uint16_t` 2 字节表示     |
| 2  | 将字符串本体数据写入 ByteArray     | 长度为 `value.size()` 的字节流 |

---

### 🚧 注意事项：

* **字符串长度限制**：由于使用的是 `uint16_t` 表示长度，字符串不能超过 `65535` 个字符。如果超出，会导致截断或异常（视具体实现而定）。
* **与 Protocol Buffers 类似**：这种格式常用于高性能数据序列化，如 RPC 通信、日志写入、磁盘存储等，读取时先解析长度，再读取相应的字节数。

---

### ✅ 举例：

```cpp
std::string str = "hello";
ba.writeStringF16(str);
```

写入后的 ByteArray 内容将是：

```
05 00 68 65 6C 6C 6F
 ↑    ↑ 字符串内容
 |    
 字符串长度（5，用uint16_t 小端序）
```

# `writeStringWithoutlength(std::string& value)`


## ✅ 函数原型：

```cpp
void ByteArray::writeStringWithoutLength(std::string& value)
```

---

### 🔧 所属模块：

这是 `sylar::ByteArray` 类的成员函数，作用是将一个字符串的内容写入到 ByteArray 中，但**不包含任何长度信息或终止符**。

---

## 🔍 函数逐行解释：

---

```cpp
write(value.c_str(), value.size());
```

我们来分别解释参数：

### ▶ `value.c_str()`

* 这是 `std::string` 的成员函数。
* 返回一个 `const char*` 指针，指向字符串数据的**首地址**。
* 注意：这个返回值是以 `\0` 结尾的 C 风格字符串，但你这里 **并没有写入这个 `\0` 结尾符号**，因为只写了 `value.size()` 字节。

---

### ▶ `value.size()`

* 这是 `std::string` 的成员函数。
* 返回字符串内容的字节数（不包括结尾的 `'\0'`）。
* 例如：字符串 `"hello"` 的 `value.size()` 是 `5`。

---

### ▶ `write(...)`

* 这是 `ByteArray` 中另一个重要的成员函数，用于写入原始内存数据到 ByteArray 的内部结构中。
* 接收一个 `void*` 指针和一个 `size_t` 大小，表示写入多少字节。
* 它将从 `value.c_str()` 起始的内存地址中，拷贝 `value.size()` 字节的数据到 ByteArray 的当前位置。

---

## 📌 函数行为总结：

```cpp
void ByteArray::writeStringWithoutLength(std::string& value)
```

这段代码的作用是：

> **将字符串内容（以二进制字节形式）原封不动地写入 ByteArray 中，不包含任何长度字段或结束符。**

---

## ❗ 注意事项：

1. ❌ **不会写入字符串长度**：

   * 与 `writeStringF16()`、`writeStringF32()` 等函数不同，这里不写长度。
   * 这意味着读取方要知道该字符串有多少字节，才能正确读回。

2. ❌ **不会写入 `'\0'` 结尾符**：

   * `c_str()` 返回的是带 `\0` 结尾的字符数组，但这里只写 `value.size()` 字节，所以不会写入结尾。
   * 如果你想写一个 `C风格字符串`，请手动写 `value.size() + 1` 字节。

3. ✅ **适合固定结构协议**：

   * 这种方式一般适合结构固定、或者字符串后紧跟其他字段的二进制格式通信，如二进制协议或日志结构。

---

## 🧪 示例：

假设你有：

```cpp
std::string str = "world";
ba.writeStringWithoutLength(str);
```

那么 `ByteArray` 中写入的内容是：

```
77 6F 72 6C 64
 w  o  r  l  d
```

没有长度前缀，也没有结尾的 `\0`。


# `writeUint32(uint32_t)`


## 🔧 函数定义

```cpp
void ByteArray::writeUint32(uint32_t value)
```

这是 `ByteArray` 类的一个成员函数，用于将一个 `uint32_t` 整数使用 **Varint 编码格式** 写入 `ByteArray` 中。

---

## 💡 背景知识：Varint 编码原理

Varint 将整数按 **每 7 位一组** 编码，每个字节的第 8 位（最高位）是 continuation bit：

* **高位为 1**：后面还有字节
* **高位为 0**：这是最后一个字节

例如：

* `1` → `0x01`（1 字节）
* `300` → `0xAC 0x02`（2 字节）

---

## 🔍 逐行详解代码

```cpp
uint8_t tmp[5];
```

* 定义一个最多 5 字节的临时数组，用于保存编码后的字节。
* 为什么最多 5 个？因为 `uint32_t` 是 32 位，而 Varint 每次编码 7 位 → 最多 5 字节能覆盖 35 位。

```cpp
uint8_t i = 0;
```

* 用于记录当前写了几个字节。

```cpp
while(value >= 0x80) {
    tmp[i++] = (value & 0x7F) | 0x80;
    value >>= 7;
}
```

### 🔄 分析这个循环逻辑：

* **条件 `value >= 0x80` (即 ≥ 128)**：

  * 表示当前值还不止 7 位，要继续分组。
* **`(value & 0x7F)`**：

  * 取最低 7 位有效数据。
* **`| 0x80`**：

  * 设置最高位为 `1`（告诉解码器“后面还有”）。
* **`value >>= 7`**：

  * 舍弃已经编码的 7 位，继续处理高位。

这个循环会不断把整数拆成 7 位一组，直到只剩下最后的那一组。

```cpp
tmp[i++] = value;
```

* 最后一个字节，`value` 的剩余部分一定小于 128（即最高位为 0）
* 所以直接保存，无需设置 continuation bit（高位为 0）

---

### 📤 写入数据

```cpp
write(tmp, i);
```

调用 `ByteArray::write(const void* buf, size_t size)`，把这 `i` 个字节写入 ByteArray 的底层缓冲区。

---

## ✅ 举个例子

假设 `value = 300`

```text
300 = 0b 00000001 00101100
     = 0b 100101100

按 7 位分组：
- 第1组：00101100 (0x2C) → 加高位1 → 0xAC
- 第2组：00000010 (0x02) → 高位为0 → 0x02

写入结果：0xAC 0x02
```

---

## 🧠 总结

该函数的作用是将一个 `uint32_t` 类型的整数 **以 Varint 格式编码并写入 ByteArray**，实现要点：

| 步骤  | 说明                  |
| --- | ------------------- |
| 1   | 循环处理，每 7 位打包        |
| 2   | 中间字节设置高位为 1         |
| 3   | 最后一个字节高位为 0         |
| 4   | 写入所有编码字节到 ByteArray |

---

如果你还需要 `readUint32()`（解码函数）的详细分析，我也可以帮你拆解那部分。是否需要？

# `writeToFile()`

## 📌 函数签名

```cpp
bool ByteArray::writeToFile(const std::string& name) const
```

### ✅ 作用

将当前 `ByteArray` 中未读取的内容（从当前读取位置 `m_position` 开始）写入到一个文件中。

---

## 📘 函数内部详解

### 打开文件流

```cpp
std::ofstream ofs;
ofs.open(name, std::ios::trunc | std::ios::binary);
```

* 定义一个输出文件流 `ofs`。
* `name` 是目标文件名。
* `std::ios::trunc` 表示如果文件已存在则清空它。
* `std::ios::binary` 表示以**二进制模式写入**，避免文本模式带来的换行符转换（Windows 下）。

---

### 文件打开失败处理

```cpp
if(!ofs) {
    SYLAR_LOG_ERROR(g_logger) << "writeToFile name=" << name
        << " error , errno=" << errno << " errstr=" << strerror(errno);
    return false;
}
```

* 如果文件打开失败（`ofs` 状态为 false）：

  * 通过日志系统记录错误：包括文件名、`errno` 值和错误描述字符串。
  * 返回 `false` 表示写入失败。

---

### 初始化写入所需变量

```cpp
int64_t read_size = getReadSize(); // 获取当前还未读取的字节数
int64_t pos = m_position;          // 从当前读取位置开始
Node* cur = m_cur;                 // 当前节点（注意：从当前位置开始）
```

* `read_size` 表示剩余可读的字节数，即 `m_size - m_position`。
* `pos` 表示当前读指针位置。
* `cur` 是当前节点指针，也就是当前数据读取所在的位置。

---

### 写入循环逻辑

```cpp
while(read_size > 0) {
    int diff = pos % m_baseSize;
    int64_t len = (read_size > (int64_t)m_baseSize ? m_baseSize : read_size) - diff;
    ofs.write(cur->ptr + diff, len);
    cur = cur->next;
    pos += len;
    read_size -= len;
}
```

#### 分步骤解释：

##### ① 计算偏移量：

```cpp
int diff = pos % m_baseSize;
```

* `diff` 是当前节点中应跳过的偏移量。
* 因为每个节点容量是 `m_baseSize`，读指针可能处于节点的中间某个位置。

##### ② 计算本次可写长度：

```cpp
int64_t len = (read_size > (int64_t)m_baseSize ? m_baseSize : read_size) - diff;
```

* 当前节点中最多能写多少字节：

  * 如果剩余读数据大于单节点容量，写满一个节点。
  * 否则只写剩余的 `read_size`。
* 减去 `diff` 是因为当前节点可能从中间开始写（不是从0开始）。

##### ③ 写入数据：

```cpp
ofs.write(cur->ptr + diff, len);
```

* 写 `cur` 节点中，从 `diff` 位置开始的 `len` 个字节到文件中。

##### ④ 准备下一轮：

```cpp
cur = cur->next;
pos += len;
read_size -= len;
```

* 将指针移向下一个节点。
* 更新写入位置 `pos`，以及剩余未写入字节 `read_size`。

---

### 成功写入

```cpp
return true;
```

* 所有内容写入完成，返回 `true`。

---

## 🔚 总结作用

这个函数实现的是：

> 将 `ByteArray` 中从当前位置开始的未读取数据（即 `getReadSize()`）以二进制形式完整写入到指定文件中。

它的特性包括：

* 跨多个节点写入：支持链式节点结构。
* 支持从任意偏移位置开始写。
* 高效：按块顺序写，不用一次性拷贝所有数据到中间缓冲。

