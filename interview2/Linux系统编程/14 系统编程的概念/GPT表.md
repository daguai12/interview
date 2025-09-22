好问题 👍，我们来详细聊聊 **GPT（GUID Partition Table）** 的表里存的内容，并且我会画一份 **ASCII 结构图**，让你直观理解。

---

## 1. GPT 表的作用

GPT（GUID Partition Table）是 UEFI 下的分区表格式，用来描述磁盘上的分区情况。
它解决了 MBR 的限制（只能有 2TB 磁盘 + 最多 4 个主分区）。

在 GPT 中，除了分区的数据本身，磁盘开头和结尾会有一些 **元数据结构** 来描述分区布局。

---

## 2. GPT 的基本结构

磁盘布局大致是这样的（以逻辑顺序排列）：

```
+----------------------+  LBA 0
| Protective MBR       |  保护性 MBR（兼容旧系统）
+----------------------+  LBA 1
| Primary GPT Header   |  主 GPT 头
+----------------------+  LBA 2 - LBA n
| Partition Entries    |  分区表项数组
+----------------------+  ...
| User Data            |  分区数据区
+----------------------+  LBA = Last - 33
| Backup Partition     |  备份分区表项数组
| Entries              |
+----------------------+  LBA = Last - 1
| Backup GPT Header    |  备份 GPT 头
+----------------------+
```

---

## 3. 每个部分的内容

### (1) Protective MBR （保护性 MBR）

* 占用第一个扇区（LBA 0）。
* 作用：让不支持 GPT 的老系统看到一个“假的”MBR 分区（通常是一个类型为 0xEE 的分区），防止误以为磁盘是空的。

---

### (2) GPT Header （GPT 头）

* 存在于磁盘开头（LBA 1）和结尾（最后一个扇区）。
* 主要内容：

  * GPT 版本号
  * 磁盘 GUID（全局唯一 ID）
  * 分区表起始位置 & 数量
  * CRC 校验值（保证 GPT 数据没损坏）

---

### (3) Partition Entry Array（分区表项数组）

* 紧跟在 GPT 头后面，一般从 LBA 2 开始。
* 每个分区表项固定 128 字节。
* 默认最多 128 个分区（可以扩展）。
* 每个分区表项包括：

  * 分区类型 GUID
  * 分区唯一 GUID
  * 起始 LBA、结束 LBA
  * 分区属性标志（如只读、隐藏）
  * 分区名称（UTF-16 编码）

---

### (4) Backup GPT（备份 GPT）

* 位于磁盘最后 33 个扇区（默认）。
* 包含：

  * 备份 GPT Header
  * 备份 Partition Entries
* 作用：保证 GPT 数据安全，如果前面的 GPT 损坏，可以从备份恢复。

---

## 4. ASCII 图（直观展示）

```
Disk (example: 1TB)

LBA 0         [ Protective MBR ]   <- 兼容旧 BIOS/MBR 系统
LBA 1         [ Primary GPT Header ]
LBA 2-33      [ Partition Entries (128 个分区表项) ]
LBA 34-...    [ User Data (分区内容) ]
...
LBA Last-33   [ Backup Partition Entries ]
LBA Last-1    [ Backup GPT Header ]
```

---

👉 总结：
GPT 表里存的就是 **磁盘的分区元数据**：

* 头（Header）描述整体信息（版本、GUID、分区表位置、校验）
* 分区项（Entries）描述每个分区（起止地址、类型、名称）
* 有主有备份，避免数据丢失

---

要不要我帮你画一个 **具体分区表项的 ASCII 结构**（128 字节展开），让你看到每个字段？
