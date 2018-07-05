---
title: socket编程
date: 2017-09-04 22:25:45
categories: code
tags: [c++,python]
---

### Linux下的socket编程

#### server.c

```c++
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
 
#define MAX_LINE 1024
#define INET_ADDR_STR 16 
 
 
void my_fun(char *p)
{
    if(p == NULL)
    {
        return;
    }
    for( ; *p != '\0' ; p++)
    {
        if((*p >= 'a') && (*p <= 'z'))
        {
            *p = *p - 32;
        }
    }
    return;
}
int main(int argc,char **argv)
{
    struct sockaddr_in sin;     //服务器通信地址结构
    struct sockaddr_in cin;     //保存客户端通信地址结构
    int l_fd;
    int c_fd;
    socklen_t len;
    char buf[MAX_LINE];     //存储传送内容的缓冲区
    char addr_p[INET_ADDR_STR]; //存储客户端地址的缓冲区
    int port = 8000;
    int n;
    bzero((void *)&sin,sizeof(sin));
    sin.sin_family = AF_INET;   //使用IPV4通信域
    sin.sin_addr.s_addr = INADDR_ANY;   //服务器可以接受任意地址
    sin.sin_port = htons(port); //端口转换为网络字节序
     
    l_fd = socket(AF_INET,SOCK_STREAM,0);   //创建套接子,使用TCP协议
    bind(l_fd,(struct sockaddr *)&sin,sizeof(sin));
     
    listen(l_fd,10);    //开始监听连接
     
    printf("waiting ....\n");
    while(1)
    {
        c_fd = accept(l_fd,(struct sockaddr *)&cin,&len);
         
        n = read(c_fd,buf,MAX_LINE);    //读取客户端发送来的信息
        inet_ntop(AF_INET,&cin.sin_addr,addr_p,INET_ADDR_STR);      //将客户端传来地址转化为字符串
        printf("client IP is %s,port is %d\n",addr_p,ntohs(cin.sin_port));
        printf("content is : %s\n", buf);   //打印客户端发送过来的数据
        my_fun(buf);
        write(c_fd,buf,n);          //转换后发给客户端
 
        close(c_fd);
    }
    printf("buf = %s\n",buf);
    if((close(l_fd)) == -1)
    {
        perror("fail to close\n");
        exit(1);
    }
    return 0;
}
```

#### client.c

```c++
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
 
 
#define MAX_LINE 1024
 
int main(int argc,char **argv)
{
    struct sockaddr_in sin;     //服务器的地址
    char buf[MAX_LINE];
    int sfd;
    int port = 8000;
    char *str = "test string";
    char *serverIP = "127.0.0.1";
    if(argc > 1)
    {
        str = argv[1];  //读取用户输入的字符串
    }
    bzero((void *)&sin,sizeof(sin));
    sin.sin_family = AF_INET;   //使用IPV4地址族
     
    inet_pton(AF_INET,serverIP,(void *)&(sin.sin_addr));
    sin.sin_port = htons(port);
     
    sfd = socket(AF_INET,SOCK_STREAM,0);
     
    connect(sfd,(struct sockaddr *)&(sin),sizeof(sin));
 
    printf("str = %s\n" , str);
    write(sfd , str , strlen(str) + 1);
    read(sfd , buf , MAX_LINE);
    printf("recive from server: %s\n" , buf);
 
    close(sfd);
     
    return 0;
}
```

