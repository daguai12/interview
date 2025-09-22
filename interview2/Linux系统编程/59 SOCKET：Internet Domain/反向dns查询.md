你在示例代码中看到 `host` 变量得到 `dns.google` 这个结果，是因为 `getnameinfo` 函数执行了一项关键操作：**反向DNS查询 (Reverse DNS Lookup)**。

我们一步步来解释这个过程：

### 1\. 你的代码做了什么？

在之前的示例代码中，有类似这样的设置：

```c
struct sockaddr_in sa;
// ...
// 将 IP 地址 "8.8.8.8" 填入地址结构 sa 中
inet_pton(AF_INET, "8.8.8.8", &sa.sin_addr); 
// ...

// 然后调用 getnameinfo
getnameinfo((struct sockaddr*)&sa, sizeof(sa), host, NI_MAXHOST, ...);
```

你传给 `getnameinfo` 的是一个包含了**IP地址 `8.8.8.8`** 的二进制结构体。

### 2\. `getnameinfo` 的默认行为

当你调用 `getnameinfo` 时，如果**没有**使用 `NI_NUMERICHOST` 这个标志，它的默认行为之一就是：

  * **尝试将这个 IP 地址解析回它在互联网上注册的主机名。**

这个过程就叫做**反向DNS查询**。

### 3\. 什么是反向DNS查询？

我们通常接触的是“正向DNS查询”：

  * **正向查询**：你问 DNS 系统：“`www.google.com` 的 IP 地址是什么？” -\> DNS 系统回答：“`142.250.74.196`”。

**反向DNS查询**则完全相反：

  * **反向查询**：你问 DNS 系统：“拥有 IP 地址 `8.8.8.8` 的是哪台主机？” -\> DNS 系统回答：“这台主机的名字是 `dns.google`”。

### 4\. `8.8.8.8` 和 `dns.google` 的关系

  * **`8.8.8.8`** 是谷歌提供的一个非常著名的公共 DNS 服务器的 IP 地址。
  * 为了便于管理和识别，谷歌为这个 IP 地址在 DNS 系统中设置了一个“指针记录”（PTR Record）。这个记录就声明了 `8.8.8.8` 这个 IP 地址对应的主机名是 `dns.google`。

所以，当你的 `getnameinfo` 函数向 DNS 系统查询 `8.8.8.8` 的主机名时，DNS 系统找到了这条 PTR 记录，并把 `dns.google` 这个字符串返回给了你的程序。你的程序再把它存入 `host` 这个字符数组里。

### 总结

`getnameinfo` 函数之所以能得到 `dns.google` 这个主机名，并不是因为它知道你正在查询谷歌的服务器，而是因为它忠实地执行了**反向DNS查询**的任务。

**IP 地址 (`8.8.8.8`) -\> `getnameinfo()` -\> 反向DNS查询 -\> 查到PTR记录 -\> 返回主机名 (`dns.google`)**

如果你换一个 IP 地址，比如 `208.67.222.222` (OpenDNS)，`getnameinfo` 就会返回 `resolver1.opendns.com`。

**如何阻止这个行为？**

如果你不希望进行反向DNS查询，只想得到 IP 地址的字符串形式，你可以在 `getnameinfo` 的最后一个参数中加入 `NI_NUMERICHOST` 标志。这样，它就会直接返回 `"8.8.8.8"` 这个字符串，而不会去麻烦 DNS 系统了。