## 9.1 select 系统调用

```c
int select(int nfds,fd_set* readfds,fd_set* writefds,fd_set* exceptfds,struct timeval* timout)
```

1. nfds参数指定被监听的文件描述符的总数。他被设置为select中所监听的最大的文件描述符加一，因为文件描述符是从0开始计数的。

2. readfds，writefds，exceptfds，分别监听读，写，异常三种事件对应的文件描述符。



```c
fd_set的结构体：

typedef struct {
    unsigned long fds_bits[FD_SETSIZE / (8 * sizeof(unsigned long))];
} fd_set;

```

fd_set的结构体中只有一个数组，所以select可以监听的文件描述符是有限的。

3. timeout参数用来设置select函数的超时事件。

```c
struct timeval{
	long tv_sec;
	long tv_usec;
}
```

select如果调用成功会返回，就绪文件描述符的个数。失败会返回-1，如果时会返回0。

如果在select等待期间，程序接收到信号，则select立即返回-1,并设置errno为EINTR。

## 9.1.2 文件描述符就绪条件

![[Pasted image 20250401160715.png]]

## 9.1.3 处理带外数据

socket上接收普通数据和带外数据都将使select返回，但socket处于不同的就绪状态，前者处于可读状态，后者处于异常状态。

```c
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <stdlib.h>

int main( int argc, char* argv[] )
{
	if( argc <= 2 )
	{
		printf( "usage: %s ip_address port_number\n", basename( argv[0] ) );
		return 1;
	}
	const char* ip = argv[1];
	int port = atoi( argv[2] );
	printf( "ip is %s and port is %d\n", ip, port );

	int ret = 0;
        struct sockaddr_in address;
        bzero( &address, sizeof( address ) );
        address.sin_family = AF_INET;
        inet_pton( AF_INET, ip, &address.sin_addr );
        address.sin_port = htons( port );

	int listenfd = socket( PF_INET, SOCK_STREAM, 0 );
	assert( listenfd >= 0 );

        ret = bind( listenfd, ( struct sockaddr* )&address, sizeof( address ) );
	assert( ret != -1 );

	ret = listen( listenfd, 5 );
	assert( ret != -1 );

	struct sockaddr_in client_address;
        socklen_t client_addrlength = sizeof( client_address );
	int connfd = accept( listenfd, ( struct sockaddr* )&client_address, &client_addrlength );
	if ( connfd < 0 )
	{
		printf( "errno is: %d\n", errno );
		close( listenfd );
	}

	char remote_addr[INET_ADDRSTRLEN];
	printf( "connected with ip: %s and port: %d\n", inet_ntop( AF_INET, &client_address.sin_addr, remote_addr, INET_ADDRSTRLEN ), ntohs( client_address.sin_port ) );

	char buf[1024];
        fd_set read_fds;
        fd_set exception_fds;

        FD_ZERO( &read_fds );
        FD_ZERO( &exception_fds );

        int nReuseAddr = 1;
	setsockopt( connfd, SOL_SOCKET, SO_OOBINLINE, &nReuseAddr, sizeof( nReuseAddr ) );
	while( 1 )
	{
		memset( buf, '\0', sizeof( buf ) );
		FD_SET( connfd, &read_fds );
		FD_SET( connfd, &exception_fds );

        	ret = select( connfd + 1, &read_fds, NULL, &exception_fds, NULL );
		printf( "select one\n" );
        	if ( ret < 0 )
        	{
                	printf( "selection failure\n" );
                	break;
        	}
	
        	if ( FD_ISSET( connfd, &read_fds ) )
		{
        		ret = recv( connfd, buf, sizeof( buf )-1, 0 );
			if( ret <= 0 )
			{
				break;
			}
			printf( "get %d bytes of normal data: %s\n", ret, buf );
		}
		else if( FD_ISSET( connfd, &exception_fds ) )
        	{
        		ret = recv( connfd, buf, sizeof( buf )-1, MSG_OOB );
			if( ret <= 0 )
			{
				break;
			}
			printf( "get %d bytes of oob data: %s\n", ret, buf );
        	}

	}

	close( connfd );
	close( listenfd );
	return 0;
}
```
***

# 9.3epoll系列调用

## 9.3.3 LT 和 ET 模式

epoll对文件描述符的操作有两种，分别是 *LT* 和 *ET* 两种模式。

**1. LT（Level Trigger，电平触发)**

epoll的默认工作方式，当epoll_wait上检测到有事件发生时并将其通知给应用程序的时候，应用程序可以不立即处理该事件。当epoll_wait中的该事件再次触发时，epoll_wait还会再次通知应用程序处理该事件，直到该事件被处理完成。

**2. ET（Edge Trigger，边缘触发)**

当epoll_wait上检测到有事件发生时并将其通知给应用程序的时候，应用程序必须立即处理该事件。后续epoll_wait不会再将该事件通知给应用程序。

***
注意 每个使用ET的文件描述符，必须是非阻塞的。如果文件描述符时阻塞的，那么读或写操作会因为没有后续事件一直处于阻塞状态。
***

- 设置方法

```cpp
events.events = EPOLLIN |= EPOLLET
```

测试代码：

```cpp
#include <cerrno>
#include <list>
#include <assert.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_EVENT_NUMBER 1024
#define BUFFER_SIZE 10

int setnoblocking(int fd)
{
  int old_option = fcntl(fd,F_GETFL);
  int new_option = old_option | O_NONBLOCK;
  fcntl(fd,F_SETFL,new_option);
  return old_option;
}

void addfd(int epollfd,int fd,bool enable_et)
{
  epoll_event event;
  event.data.fd = fd;
  event.events = EPOLLIN;
  if(enable_et)
  {
    event.events |= EPOLLET;
  }
  epoll_ctl(epollfd,EPOLL_CTL_ADD,fd,&event);
  setnoblocking(fd);
}

//lt模式工作流程
void lt(epoll_event* events,int number,int epollfd,int listenfd)
{
  char buf[BUFFER_SIZE];
  for(int i = 0;i < number;i++)
  {
    int sockfd = events[i].data.fd;
    if(sockfd == listenfd)
    {
      struct sockaddr_in client_address;
      socklen_t client_addrlength = sizeof(client_address);
      int connfd = accept(listenfd,(struct sockaddr*)&client_address,&client_addrlength);
      addfd(epollfd,connfd,false);
    }
    else if(events[i].events & EPOLLIN)
    {
      //只要socket中还有未读出的数据，这段代码就被触发
      printf("event trigger once\n");
      memset(buf,'\0',BUFFER_SIZE);
      int ret = recv(sockfd,buf,BUFFER_SIZE - 1,0);
      if(ret <= 0)
      {
        close(sockfd);
        continue;
      }
      printf("get %d bytest of content:%s\n",ret,buf);
    }
    else
    {
      printf("something else happened\n");
      
    }
  }
}

//ET模式的工作流程
void et(epoll_event* events,int number,int epollfd,int listenfd)
{
  char buf[BUFFER_SIZE];
  for(int i = 0;i < number;i++)
  {
    int sockfd = events[i].data.fd;
    if(sockfd == listenfd)
    {
      struct sockaddr_in client_address;
      socklen_t client_addrlength = sizeof(client_address);
      int connfd = accept(listenfd,(struct sockaddr*)&client_address,&client_addrlength);
      addfd(epollfd,connfd,true); //开启ET模式
    }
    else if(events[i].events & EPOLLIN)
    {
      //这段代码不会被重复触发,所以我们循环读取数据，以确保把socket读缓存中的所有数据读出
      printf("event trigger once\n");
      while(1)
      {
        memset(buf,'\0',BUFFER_SIZE);
        int ret = recv(sockfd,buf,BUFFER_SIZE - 1,0);
        if(ret < 0)
        {
          //对于非阻塞IO,下面的条件成立表示数据已经读取完毕，此后，epoll就能再次触发sockfd上的EPOLLIN事件，以驱动下一次读操作
          if((errno == EAGAIN) || (errno == EWOULDBLOCK))
          {
            printf("read later\n");
            break;
          }
          close(sockfd);
          break;
        }
        else if(ret == 0)
        {
          close(sockfd);
        }
        else 
        {
          printf("get %d bytes os content: %s\n",ret,buf);
        }

      }

    }
    else
    {
      printf("something else happened\n");

    }

  }

}

int main(int argc,char* argv[])
{
  if(argc <= 2)
  {
    printf("usage");
    return 1;
  }
  const char* ip = argv[1];
  int port = atoi(argv[2]);

  int ret = 0;
  struct sockaddr_in address;
  bzero(&address,sizeof(address));
  address.sin_family = AF_INET;
  inet_pton(AF_INET,ip,&address.sin_addr);
  address.sin_port = htons(port);

  int listenfd = socket(PF_INET,SOCK_STREAM,0);
  assert(listenfd >= 0);

  ret = bind(listenfd,(struct sockaddr*)&address,sizeof(address));
  assert(ret != -1);

  ret = listen(listenfd,5);
  assert(listenfd >= 0);

  epoll_event events[MAX_EVENT_NUMBER];
  int epollfd = epoll_create(5);
  assert(epollfd != -1);
  addfd(epollfd,listenfd,true);

  while(1)
  {
    int ret = epoll_wait(epollfd,events,MAX_EVENT_NUMBER,-1);
    if(ret < 0)
    {
      printf("epoll failture\n");
      break;
    }
    lt(events,ret,epollfd,listenfd);
    // et(events,ret,epollfd,listenfd);
  }
  close(listenfd);
  return 0;
}
```


# 9.3.4 EPOLLONESHOT事件

即使使用ET模式，文件描述符还是可能会被多次触发。尤其是在多线程（进程）环境之下，当一个进程（线程）读取完socket中的数据之后，开始处理这些数据，这是socket中又有新的数据到来，此时另一个线程（进程），可能会读取该socket中的数据（EPOLLIN再次被触发)。但是我们期望的是socket连接在任意时刻只被一个线程处理。这是我们可以使用EPOLLONESHOT事件实现。

当使用了 **EPOLLONESHOT** 事件之后，操作系统只会触发一个可读或可写事件，且只触发一次。除非重置了文件描述符的 EPOLLONESHOT 事件，否则其他线程没有机会处理该事件。当注册了 EPOLLONESHOT 的socket被一个线程处理完之后，该线程会重置该socket，使得其他线程有机会继续处理该socket。

```cpp
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/epoll.h>
#include <pthread.h>

#define MAX_EVENT_NUMBER 1024
#define BUFFER_SIZE 1024
struct fds
{
   int epollfd;
   int sockfd;
};

int setnonblocking( int fd )
{
    int old_option = fcntl( fd, F_GETFL );
    int new_option = old_option | O_NONBLOCK;
    fcntl( fd, F_SETFL, new_option );
    return old_option;
}

void addfd( int epollfd, int fd, bool oneshot )
{
    epoll_event event;
    event.data.fd = fd;
    event.events = EPOLLIN | EPOLLET;
    if( oneshot )
    {
        event.events |= EPOLLONESHOT;
    }
    epoll_ctl( epollfd, EPOLL_CTL_ADD, fd, &event );
    setnonblocking( fd );
}

void reset_oneshot( int epollfd, int fd )
{
    epoll_event event;
    event.data.fd = fd;
    event.events = EPOLLIN | EPOLLET | EPOLLONESHOT;
    epoll_ctl( epollfd, EPOLL_CTL_MOD, fd, &event );
}

void* worker( void* arg )
{
    int sockfd = ( (fds*)arg )->sockfd;
    int epollfd = ( (fds*)arg )->epollfd;
    printf( "start new thread to receive data on fd: %d\n", sockfd );
    char buf[ BUFFER_SIZE ];
    memset( buf, '\0', BUFFER_SIZE );
    while( 1 )
    {
        int ret = recv( sockfd, buf, BUFFER_SIZE-1, 0 );
        if( ret == 0 )
        {
            close( sockfd );
            printf( "foreiner closed the connection\n" );
            break;
        }
        else if( ret < 0 )
        {
            if( errno == EAGAIN )
            {
                reset_oneshot( epollfd, sockfd );
                printf( "read later\n" );
                break;
            }
        }
        else
        {
            printf( "get content: %s\n", buf );
            sleep( 5 );
        }
    }
    printf( "end thread receiving data on fd: %d\n", sockfd );
}

int main( int argc, char* argv[] )
{
    if( argc <= 2 )
    {
        printf( "usage: %s ip_address port_number\n", basename( argv[0] ) );
        return 1;
    }
    const char* ip = argv[1];
    int port = atoi( argv[2] );

    int ret = 0;
    struct sockaddr_in address;
    bzero( &address, sizeof( address ) );
    address.sin_family = AF_INET;
    inet_pton( AF_INET, ip, &address.sin_addr );
    address.sin_port = htons( port );

    int listenfd = socket( PF_INET, SOCK_STREAM, 0 );
    assert( listenfd >= 0 );

    ret = bind( listenfd, ( struct sockaddr* )&address, sizeof( address ) );
    assert( ret != -1 );

    ret = listen( listenfd, 5 );
    assert( ret != -1 );

    epoll_event events[ MAX_EVENT_NUMBER ];
    int epollfd = epoll_create( 5 );
    assert( epollfd != -1 );
    addfd( epollfd, listenfd, false );

    while( 1 )
    {
        int ret = epoll_wait( epollfd, events, MAX_EVENT_NUMBER, -1 );
        if ( ret < 0 )
        {
            printf( "epoll failure\n" );
            break;
        }
    
        for ( int i = 0; i < ret; i++ )
        {
            int sockfd = events[i].data.fd;
            if ( sockfd == listenfd )
            {
                struct sockaddr_in client_address;
                socklen_t client_addrlength = sizeof( client_address );
                int connfd = accept( listenfd, ( struct sockaddr* )&client_address, &client_addrlength );
                addfd( epollfd, connfd, true );
            }
            else if ( events[i].events & EPOLLIN )
            {
                pthread_t thread;
                fds fds_for_new_worker;
                fds_for_new_worker.epollfd = epollfd;
                fds_for_new_worker.sockfd = sockfd;
                pthread_create( &thread, NULL, worker, ( void* )&fds_for_new_worker );
            }
            else
            {
                printf( "something else happened \n" );
            }
        }
    }

    close( listenfd );
    return 0;
}
```