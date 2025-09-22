# 1.nslookup

```shell
 ⚡daguai ❯❯ nslookup www.baidu.com
服务器:  public1.114dns.com
Address:  114.114.114.114

非权威应答:
名称:    www.a.shifen.com
Addresses:  2408:871a:2100:1b23:0:ff:b07a:7ebc
          2408:871a:2100:186c:0:ff:b07e:3fbc
          110.242.70.57
          110.242.69.21
Aliases:  www.baidu.com
```

### **1. 服务器信息**
```plaintext
服务器:  public1.114dns.com
Address:  114.114.114.114
```
- **含义**：  
  你当前使用的 DNS 解析服务器是 **114DNS** 的公共服务器（`public1.114dns.com`），其 IPv4 地址为 `114.114.114.114`。  
  - **DNS 服务器作用**：负责将域名（如 `www.baidu.com`）解析为计算机可识别的 IP 地址。


### **2. 非权威应答**
```plaintext
非权威应答:
```
- **含义**：  
  该响应结果并非来自域名的 **权威 DNS 服务器**（如百度自己的 DNS 服务器），而是来自缓存或递归解析过程中的中间服务器。  
  - **非权威应答的特点**：结果可能正确，但不保证是最新的（权威服务器的数据更可信）。


### **3. 域名解析结果**
#### **名称（Name）**
```plaintext
名称:    www.a.shifen.com
```
- **含义**：  
  `www.baidu.com` 的实际解析目标是 `www.a.shifen.com`。  
  - **背景**：  
    百度使用了 **CDN（内容分发网络）** 或负载均衡技术，通过别名（Alias）将主域名映射到不同的节点域名，以实现流量分发和高可用性。


#### **地址（Addresses）**
```plaintext
Addresses:  
  2408:871a:2100:1b23:0:ff:b07a:7ebc  
  2408:871a:2100:186c:0:ff:b07e:3fbc  
  110.242.70.57  
  110.242.69.21
```
- **含义**：  
  - **IPv6 地址**（前两个）：  
    `2408:871a:2100:1b23:0:ff:b07a:7ebc` 和 `2408:871a:2100:186c:0:ff:b07e:3fbc` 是百度服务器的 IPv6 地址，用于支持 IPv6 网络环境。  
  - **IPv4 地址**（后两个）：  
    `110.242.70.57` 和 `110.242.69.21` 是百度服务器的 IPv4 地址，用于 IPv4 网络环境。  
  - **多地址原因**：  
    同一域名对应多个 IP 地址是常见的负载均衡策略，可分摊流量并提高服务可靠性。


#### **别名（Aliases）**
```plaintext
Aliases:  www.baidu.com
```
- **含义**：  
  `www.baidu.com` 是 `www.a.shifen.com` 的 **别名**（Alias），通过 DNS 别名记录（CNAME 记录）实现映射。  
  - **CNAME 记录作用**：便于服务商灵活管理底层服务器，而无需修改用户端的域名配置。


### **4. 总结**
- **解析流程**：  
  当你访问 `www.baidu.com` 时，DNS 服务器会先查找 `www.baidu.com` 的 CNAME 记录，发现其指向 `www.a.shifen.com`，然后再解析 `www.a.shifen.com` 对应的 IP 地址（IPv4 和 IPv6）。  
- **用户影响**：  
  最终你会连接到其中一个可用的 IP 地址，享受百度提供的服务，整个过程由 DNS 自动完成，无需手动干预。


### **扩展知识**
- **DNS 记录类型**：  
  - **A 记录**：域名映射到 IPv4 地址（如 `110.242.70.57`）。  
  - **AAAA 记录**：域名映射到 IPv6 地址（如 `2408:871a:2100:1b23:0:ff:b07a:7ebc`）。  
  - **CNAME 记录**：域名映射到另一个域名（别名）。  
- **如何验证权威应答**：  
  使用 `nslookup` 时添加 `-type=ns` 参数查询百度的权威 DNS 服务器，再直接向其发起查询，即可获得权威应答。


```text
 ⚡daguai ❯❯ nslookup -type=NS baidu.com
服务器:  public1.114dns.com
Address:  114.114.114.114

非权威应答:
baidu.com       nameserver = ns4.baidu.com
baidu.com       nameserver = ns2.baidu.com
baidu.com       nameserver = ns3.baidu.com
baidu.com       nameserver = ns7.baidu.com
baidu.com       nameserver = dns.baidu.com
```

### **1. 命令作用**
- **`-type=NS`**：指定查询 **NS 记录（Name Server Record）**，用于获取域名的**权威 DNS 服务器**信息。  
- **目标**：查询 `baidu.com` 域名的权威 DNS 服务器地址。


### **2. 服务器信息**
```plaintext
服务器:  public1.114dns.com
Address:  114.114.114.114
```
- 与前一次查询相同，当前使用的 DNS 解析服务器仍是 **114DNS 公共服务器**（IPv4 地址 `114.114.114.114`），但本次查询的是 `baidu.com` 的权威服务器，而非直接解析域名。


### **3. 非权威应答**
```plaintext
非权威应答:
baidu.com       nameserver = ns4.baidu.com
baidu.com       nameserver = ns2.baidu.com
baidu.com       nameserver = ns3.baidu.com
baidu.com       nameserver = ns7.baidu.com
baidu.com       nameserver = dns.baidu.com
```
- **含义**：  
  列出了 `baidu.com` 配置的**权威 DNS 服务器的域名**，共 5 个：  
  - `ns4.baidu.com`  
  - `ns2.baidu.com`  
  - `ns3.baidu.com`  
  - `ns7.baidu.com`  
  - `dns.baidu.com`  
- **关键点**：  
  - **权威服务器的作用**：这些服务器直接负责管理 `baidu.com` 域名的解析记录（如 A/AAAA/CNAME 等），提供**权威应答**。  
  - **非权威应答的原因**：当前查询结果仍来自 **114DNS 服务器的缓存**，而非直接向百度的权威服务器请求。若需获取权威数据，需进一步向这些 NS 服务器发起查询。


### **4. 权威 DNS 服务器的验证**
- **如何获取权威应答**：  
  可以使用 `nslookup` 直接向上述 NS 服务器查询 `baidu.com` 的记录。例如：  
  ```bash
  nslookup www.baidu.com ns4.baidu.com
  ```  
  此时返回的结果会标注为 **权威应答**，因为数据直接来自百度的权威服务器。  
- **NS 记录的一致性**：  
  正常情况下，同一域名的 NS 记录应保持一致（由域名注册商配置），多个 NS 服务器用于冗余和负载均衡，确保解析服务的高可用性。


### **5. 扩展知识：DNS 解析流程中的 NS 记录**
1. **根服务器 → 顶级域服务器**：  
   当用户查询 `www.baidu.com` 时，递归解析流程会先从根服务器获取 `.com` 顶级域的 NS 服务器，再从 `.com` 服务器获取 `baidu.com` 的 NS 服务器（即本次查询结果中的域名）。  
2. **权威服务器解析**：  
   最终通过 `baidu.com` 的 NS 服务器获取 `www.baidu.com` 的 IP 地址（A/AAAA 记录）或别名（CNAME 记录）。  
3. **NS 服务器的 IP 地址**：  
   上述 NS 服务器的域名（如 `ns4.baidu.com`）需进一步解析为 IP 地址（通过 A 记录），才能被网络设备访问。例如，可通过 `nslookup ns4.baidu.com` 查看其 IP 地址。

``` text
nslookup www.baidu.com ns4.baidu.com
```

### **1. 命令意图**

目标：直接向 ns4.baidu.com（百度的权威 DNS 服务器）查询 www.baidu.com 的解析记录，以获取权威应答。

预期结果：正常情况下应返回 www.baidu.com 的 IP 地址，并标注为 权威应答。

# 2.ipconfig

*ipconfig*（对于Windows）和*ifconfig*（对于Linux / Unix）是主机中最实用的程序，尤其是用于调试网络问题时。这里我们只讨论*ipconfig*，尽管Linux / Unix的*ifconfig*与其非常相似。 *ipconfig*可用于显示您当前的TCP/IP信息，包括您的地址，DNS服务器地址，适配器类型等。例如，您只需进入命令提示符，输入

`ipconfig /all`


*ipconfig*对于管理主机中存储的DNS信息也非常有用。在第2.5节中，我们了解到主机可以缓存最近获得的DNS记录。要查看这些缓存记录，在 C:\\> 提示符后输入以下命令：

`ipconfig /displaydns`

每个条目显示剩余的生存时间（TTL）（秒）。要清除缓存，请输入

`ipconfig /flushdns`

清除了所有条目并从hosts文件重新加载条目。

# 3.WireShark
4. 找到DNS询h查询和响应消息。它们是否通过UDP或TCP发送？
	是通过UDP发送的端口号为53。
![[Pasted image 20250604144302.png]]
	
4. DNS查询消息的目标端口是什么？ DNS响应消息的源端口是什么？
	DNS消息的目标端口是53，源端口是60980
5. DNS查询消息发送到哪个IP地址？使用ipconfig来确定本地DNS服务器的IP地址。这两个IP地址是否相同？
	DNS查询消息发送到的是 114.114.114.114。
	本地的dns服务器地址是 114.114.114.114。(通过ipconfig /all查询本地dns服务器)
	两个ip地址相同。
6. 检查DNS查询消息。DNS查询是什么"Type"的？查询消息是否包含任何"answers"？
	DNS查询的Type类型是A，不包含answers。
7. 检查DNS响应消息。提供了多少个"answers"？这些答案具体包含什么？
	提供了两个answers。
	这些主机名里包括：
	1. 主机名"NAME"
	2. 资源记录类型“type"
	3. 主机的IP地址
	![[Pasted image 20250604145212.png]]
8. 考虑从您主机发送的后续TCP SYN数据包。 SYN数据包的目的IP地址是否与DNS响应消息中提供的任何IP地址相对应？
	IP地址相同。
9. 这个网页包含一些图片。在获取每个图片前，您的主机是否都发出了新的DNS查询？
	没有发出新的dns查询，此时请求主机的ip已经被缓存到浏览器中。
10. DNS查询消息的目标端口是什么？ DNS响应消息的源端口是什么？
	DNS查询的目标端口是53，DNS响应的源端口是53
11. DNS查询消息的目标IP地址是什么？这是你的默认本地DNS服务器的IP地址吗？
	目标IP地址是144.144.144.144，是本地的DNS服务器的ip地址
12. 检查DNS查询消息。DNS查询是什么"Type"的？查询消息是否包含任何"answers"？
	Type类型是A，没有answears
13. 检查DNS响应消息。提供了多少个"answers"？这些答案包含什么？
	提供了三个answers
	1. CNAME规范主机名
	2. CNAME规范主机名
	3. 规范主机名对应的IP地址
14. 提供屏幕截图。

15. DNS查询消息发送到的IP地址是什么？这是您的默认本地DNS服务器的IP地址吗？
	发送到的地址还是144.144.144.144，是本地DNS服务器
16. 检查DNS查询消息。DNS查询是什么"Type"的？查询消息是否包含任何"answers"？
	TYPE类型为NS，不包含任何answers
17. 检查DNS响应消息。响应消息提供的MIT域名服务器是什么？此响应消息还提供了MIT域名服务器的IP地址吗？ ![[Pasted image 20250604151616.png]]
	提供了域名服务器的IP地址
18. 提供屏幕截图。



一下问题答案在：其他答案中
19. DNS查询消息发送到的IP地址是什么？这是您的默认本地DNS服务器的IP地址吗？如果不是，这个IP地址是什么？
20. 检查DNS查询消息。DNS查询是什么"Type"的？查询消息是否包含任何"answers"？
21. 检查DNS响应消息。提供了多少个"answers"？这些答案包含什么？
22. 提供屏幕截图。




在 DNS（域名系统）中，**`PTR`记录（Pointer Record，指针记录）**是一种特殊的资源记录类型，主要用于**反向域名解析**，即通过**IP地址查询对应的域名**。它是 DNS 反向解析的核心记录类型，与正向解析（通过域名查 IP）的 `A`/`AAAA` 记录功能相反。


### **`PTR`记录的作用**
1. **反向解析**  
   将 **IP地址** 映射到 **域名**，例如：  
   - IP 地址 `192.168.1.100` 对应 `server.example.com` 的 `PTR` 记录。  
   - 当用户或程序查询该 IP 的域名时，DNS 服务器会返回 `server.example.com`。

2. **验证与安全**  
   - 常用于邮件服务器（如 SMTP）的**发件人验证**（SPF、DKIM 等机制可能依赖反向解析）。  
   - 辅助判断 IP 是否属于合法域名，减少垃圾邮件或网络攻击的可能性。

3. **网络管理与监控**  
   - 方便管理员通过 IP 快速定位对应的设备或服务域名，简化故障排查。

o





----
![[Pasted image 20250627155806.png]]
以下是对该 **DNS 响应（Domain Name System - response）** 数据包各字段及内容的详细解析，帮你理解 DNS 解析 `www.baidu.com` 的完整过程：  


### 一、DNS 基础框架字段  
#### 1. **事务标识（Transaction ID: 0x0002）**  
- 作用：匹配 DNS 请求与响应，确保响应对应正确的查询。  
- 说明：与发起查询的 DNS 请求包的 `Transaction ID` 一致（本题中请求包编号 `93`，可通过 `[Request In: 93]` 关联）。  


#### 2. **标志位（Flags: 0x8180 Standard query response, No error）**  
- 解析：  
  - `0x8180` 是十六进制标志，拆解后含义：  
    - `Standard query response`：表示这是标准查询的**响应包**（区别于请求包）。  
    - `No error`：DNS 服务器处理正常，无错误（如域名不存在会显示 `NXDOMAIN` 等错误）。  


#### 3. **资源记录计数**  
- `Questions: 1`：表示本次响应对应的**查询问题数量**（与请求包一致，查询 `www.baidu.com` 的 A 记录）。  
- `Answer RRs: 3`：DNS 服务器返回的**回答资源记录数量**（共 3 条，解释 `www.baidu.com` 的解析结果）。  
- `Authority RRs: 0`、`Additional RRs: 0`：权威记录和附加记录数量（本题中无相关内容，故为 0 ）。  


### 二、查询内容（Queries）  
```plaintext
Queries
    www.baidu.com: type A, class IN
        Name: www.baidu.com
        [Name Length: 13]
        [Label Count: 3]
        Type: A (1) (Host Address)
        Class: IN (0x0001)
```  
- **含义**：  
  - 这是 DNS 请求包中携带的**查询内容**（响应包原样带回，方便客户端匹配）。  
  - 查询 `www.baidu.com` 的 **A 记录**（`Type: A`，将域名解析为 IPv4 地址 ），网络类别为 `IN`（互联网，默认类别 ）。  


### 三、回答资源记录（Answers）  
DNS 服务器返回 3 条记录，分两步解析 `www.baidu.com`：  


#### 1. 第一条：CNAME 记录  
```plaintext
Answers
    www.baidu.com: type CNAME, class IN, cname www.a.shifen.com
        Name: www.baidu.com
        Type: CNAME (5) (Canonical NAME for an alias)
        Class: IN (0x0001)
        Time to live: 400 (6 minutes, 40 seconds)
        Data length: 15
        CNAME: www.a.shifen.com
```  
- **作用**：`CNAME`（规范名称）记录表示 `www.baidu.com` 是 `www.a.shifen.com` 的**别名**。  
- **说明**：  
  - `Time to live (TTL): 400`：记录缓存时间（6 分 40 秒后，本地 DNS 缓存会过期，需重新查询 ）。  
  - 实际要解析的目标变为 `www.a.shifen.com`（继续查其 A 记录 ）。  


#### 2. 第二条：`www.a.shifen.com` 的 A 记录  
```plaintext
www.a.shifen.com: type A, class IN, addr 110.242.69.21
        Name: www.a.shifen.com
        Type: A (1) (Host Address)
        Class: IN (0x0001)
        Time to live: 80 (1 minute, 20 seconds)
        Data length: 4
        Address: 110.242.69.21
```  
- **作用**：将 `www.a.shifen.com` 解析为 **IPv4 地址 `110.242.69.21`**（A 记录的核心功能 ）。  


#### 3. 第三条：`www.a.shifen.com` 的另一条 A 记录  
```plaintext
www.a.shifen.com: type A, class IN, addr 110.242.70.57
        Name: www.a.shifen.com
        Type: A (1) (Host Address)
        Class: IN (0x0001)
        Time to live: 80 (1 minute, 20 seconds)
        Data length: 4
        Address: 110.242.70.57
```  
- **作用**：`www.a.shifen.com` 可能对应**多个 IP 地址**（CDN 负载均衡常用策略 ），这里返回另一个 IPv4 地址 `110.242.70.57`，客户端可任选其一访问。  


### 四、其他辅助信息  
- `[Request In: 93]`：关联到请求包的编号（本题中请求包是编号 `93` 的 UDP 包 ）。  
- `[Time: 0.009048000 seconds]`：DNS 服务器处理查询的**耗时**（约 9 毫秒，反映解析速度 ）。  


### 五、完整解析流程总结  
1. 客户端发起查询：请求解析 `www.baidu.com` 的 A 记录（请求包编号 `93` ）。  
2. DNS 服务器响应：  
   - 第一步：返回 `CNAME` 记录，告知 `www.baidu.com` 是 `www.a.shifen.com` 的别名。  
   - 第二步：返回 `www.a.shifen.com` 的两个 A 记录（`110.242.69.21` 和 `110.242.70.57` ）。  
3. 客户端行为：拿到 IP 后，即可向对应服务器发起 HTTP 请求（访问百度网站 ）。  


这就是一个典型的 **DNS 解析过程**（通过 CNAME 跳转 + 多 A 记录负载均衡 ），你可以结合请求包（编号 `93` ）一起看，理解 DNS “请求-响应” 的完整交互逻辑~