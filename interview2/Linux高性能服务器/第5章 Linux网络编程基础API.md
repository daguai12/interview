# 5.8 数据读写

## 5.8.1 TCP数据读写

***read*** 和 ***write*** 都可以用于socket数据的读写。但是socket编程接口提供了专门的函数用于读写 ***readv*** 和 ***write***。

```c
ssize_t recv(int sockfd,void* buf,size_t len,int flags);
ssize_t sendv(int sockfd,const void* buf,size_t len,int flags);
```

- flag参数选项：
![[Pasted image 20250401152759.png]]

***MSG_OOB*** 详解

```c
客户端发送的数据:
	const char* oob_data = "abc";
	const char* normal_data = "123";
	send(sockfd,normal_data,strlen(normal_data),0)
	send(sockfd,oob_data,strlen(oob_data),MSG_OOB)
	sned(sockfd,normal_data,strlen(normal_data),0)
服务端接收的数据：
	ret = recv(connfd,buffer,BUF_SIZE -1,0)
	ret = recv(connfd,buffer,BUF_SIZE -1,MSG_OOB)
	ret = recv(connfd,buffer,BUF_SIZE -1,0);

接收到的数据 123ab
接收到的数据 c
接收到的数据 123

外带数据“abc"，只有最后一个字符被当作外带数据
```