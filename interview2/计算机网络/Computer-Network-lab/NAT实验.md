在本次实验中，我们将探究NAT路由器的工作行为。本次实验与我们之前的Wireshark实验有所不同，以往的实验仅在单一Wireshark测量点捕获跟踪文件。由于我们需要在NAT设备的输入和输出两侧同时捕获数据包，因此需要在两个位置进行数据包捕获。此外，许多学生难以轻松获取NAT设备，或难以使用两台计算机进行Wireshark测量，因此学生很难“实时”完成该实验。因此，在本次实验中，你将使用我们为你捕获的Wireshark跟踪文件。由于NAT背后的概念并不复杂，因此本次实验应相对简短且简单，但观察NAT的实际工作过程仍然是有益的。在开始本实验之前，你可能需要复习课本第4.3.3节中关于NAT的内容。  


### NAT测量场景  
在本次实验中，我们将捕获包含从家庭网络内的客户端向远程服务器发送的简单HTTP GET请求消息，以及来自该服务器的相应HTTP响应的数据包。如第4章所述，家庭网络中的家庭网络路由器提供NAT服务。图1展示了我们的Wireshark跟踪收集场景。我们将在两个位置捕获数据包，因此本实验包含两个跟踪文件：  
- 我们将在NAT路由器的局域网（LAN）侧捕获接收到的数据包。该LAN中的所有设备的地址均属于192.168.10/24网段。此文件名为**nat-inside-wireshark-trace1-1.pcapng**。  
- 由于我们还需要分析NAT路由器在其面向互联网一侧转发（和接收）的数据包，因此我们将在路由器的互联网侧收集第二个跟踪文件，如图1所示。在第二个测量点处，Wireshark捕获的从右侧主机发送至左侧服务器的数据包，在到达该测量点时已完成NAT转换。此文件名为**nat-outside-wireshark-trace1-1.pcapng**。

在图1所示的场景中，局域网内的某台主机将向IP地址为138.76.29.8的Web服务器发送HTTP GET请求，服务器将向请求主机返回响应。当然，我们真正关注的并非HTTP GET请求本身，而是NAT路由器如何将局域网侧（内侧）包含GET请求的数据报的IP地址和端口号，转换为转发至互联网侧（外侧）的数据报的地址和端口号。  


### 首先分析NAT路由器局域网侧的情况  
打开跟踪文件**nat-inside-wireshark-trace1-1.pcapng**。在此文件中，你应能看到一个发往外部Web服务器（IP地址138.76.29.8）的HTTP GET请求，以及后续的HTTP响应消息（“200 OK”）。跟踪文件中的这两条消息均在路由器的局域网侧捕获。  

### 回答以下问题：  
1. **在nat-inside-wireshark-trace1-1.pcapng跟踪文件中，发送HTTP GET请求的客户端IP地址是什么？** 此数据报中包含HTTP GET请求的TCP段的源端口号是什么？此HTTP GET请求的目标IP地址是什么？该数据报中TCP段的目标端口号是什么？  
2. **Web服务器通过NAT路由器转发至路由器局域网侧客户端的对应HTTP 200 OK消息的时间是什么？**  
3. **携带此HTTP 200 OK消息的IP数据报的源IP地址和目标IP地址是什么？TCP源端口和目标端口是什么？**  


### 接下来聚焦于这两条HTTP消息（GET和200 OK）  
我们的目标是在跟踪文件**nat-outside-wireshark-trace1-1.pcapng**（捕获于路由器与ISP之间的互联网侧链路）中定位这两条HTTP消息。由于捕获的发往服务器的数据包已通过NAT路由器转发，部分IP地址和端口号会因NAT转换而改变。  

打开跟踪文件**nat-outside-wireshark-trace1-1.pcapng**。请注意，此文件与**nat-inside-wireshark-trace1-1.pcapng**文件中的时间戳不一定同步。  

在**nat-outside-wireshark-trace1-1.pcapng**跟踪文件中，找到与**nat-inside-wireshark-trace1-1.pcapng**跟踪文件中记录的“客户端在时间t=0.27362245发送至138.76.29.8服务器的HTTP GET消息”对应的HTTP GET消息。  
4. **此HTTP GET消息在nat-outside-wireshark-trace1-1.pcapng跟踪文件中出现的时间是什么？**  
5. **携带此HTTP GET的IP数据报的源IP地址和目标IP地址是什么？TCP源端口和目标端口是什么？（根据nat-outside-wireshark-trace1-1.pcapng跟踪文件记录）**  
6. **这四个字段中，哪些与上述问题1的答案不同？**  
7. **HTTP GET消息中的字段是否有任何变更？**  
8. **从局域网（内侧）接收的数据报至NAT路由器转发至互联网侧（外侧）的对应数据报，携带HTTP GET的IP数据报中以下哪些字段会发生变更：版本（Version）、首部长度（Header Length）、标志（Flags）、校验和（Checksum）？**  


### 继续分析nat-outside-wireshark-trace1-1.pcapng跟踪文件  
找到与上述问题4-8中分析的HTTP GET请求对应的、包含“200 OK”消息的HTTP响应。  
9. **此消息在nat-outside-wireshark-trace1-1.pcapng跟踪文件中出现的时间是什么？**  
10. **携带此HTTP响应（“200 OK”）消息的IP数据报的源IP地址和目标IP地址是什么？TCP源端口和目标端口是什么？（根据nat-outside-wireshark-trace1-1.pcapng跟踪文件记录）**  


### 最后，考虑NAT路由器的转换过程  
当NAT路由器接收问题9和10中分析的数据报后，会执行NAT转换并将数据报转发至局域网侧的目标主机。基于问题1至10的答案及你对NAT工作原理的理解，无需查看**nat-inside-wireshark-trace1-1.pcapng**跟踪文件即可回答以下问题：  
11. **从路由器转发至图1右侧目标主机的、携带HTTP响应（“200 OK”）的IP数据报的源IP地址和目标IP地址是什么？TCP源端口和目标端口是什么？**  


### 验证NAT原理理解  
现在请使用Wireshark查看**nat-inside-wireshark-trace1-1.pcapng**跟踪文件中的HTTP响应（“200 OK”）。  
**问题11的答案是否与你在nat-inside-wireshark-trace1-1.pcapng跟踪文件中看到的内容一致？** （希望你的答案是“一致” ）  


### 实验结束  
如我们所说，这个Wireshark NAT实验并不难！