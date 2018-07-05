---
title: Linux内核编译
date: 2017-10-14 01:10:40
categories: 编译原理
tags: [linux, kernel]
---

Linux内核是操作系统的核心，也是操作系统最基本的部分。

Linux内核的体积结构是单内核的、但是他充分采用了微内核的设计思想、使得虽然是单内核、但工作在模块化的方式下、并且这个模块可以动态装载或卸 载；Linux负责管理系统的进程、内存、设备驱动程序、文件和网络系统，决定着系统的性能和稳定性。如是我们在了解Linux内核的基础上根据自己的需 要、量身定制一个更高效，更稳定的内核，就需要我们手动去编译和配置内核里的各项相关的参数和信息了。
**注意：如果两个内核模块的版本不完全相同是不可以跨版本使用的。**

### 1、编译内核

#### 1.1 下载并解压内核文件

 首先我们要去获得Linux内核的压缩文件、获得的路径很多了、最直接的就是去内核官网获得了(http://www.kernel.org)，也可以到各镜像站上去下载。此处使用的是[https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.16.tar.xz](https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.16.tar.xz)

**注意：一般而言，需要编译的linux内核的源码放在/usr/src目录下。**

> wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.16.tar.gz
> sudo tar -zxvf linux-3.16.tar.gz -C /usr/src/

#### 1.2 编译前准备

需要确保系统安装了gcc，ncurses，bc，make，并且系统包需要更新到最新版

> sudo apt-get install gcc
> sudo apt-get install libncurses5-dev
> sudo apt-get update
> sudo apt-get upgrade
> sudo apt-get install make
> sudo apt-get install bc

#### 1.3 配置内核

方法很多，比较常用的是

> make menuconfig
>
> make

```
make config：遍历选择所要编译的内核特性
make allyesconfig：配置所有可编译的内核特性
make allnoconfig：并不是所有的都不编译，而是能选的都回答为NO、只有必须的都选择为yes。
make menuconfig：这种就是打开一个文件窗口选择菜单，这个命令需要打开的窗口大于80字符的宽度，打开后就可以在里面选择要编译的项了

下面两个是可以用鼠标点选择的，比较方便：
make kconfig(KDE桌面环境下，并且安装了qt开发环境)
make gconfig(Gnome桌面环境，并且安装gtk开发环境)

make menuconfig：使用这个命令的话，如果是新安装的系统就要安装gcc和ncurses-devel这两个包才可以打开，然后在里面选择就可以了。此方法使用较多
```

#### 1.4 安装或更新内核

> make modules_install install

如果/boot目录下有下面

```
System.map-3.16.0
vmlinuz-3.16.0
initrd.img-3.16.0
config-3.16.0
```

代表已经成功编译了。

重启系统

>  shutdown -r now

#### 1.5 验证

>  uname -r

查看内核是否发生改变

### 2、 向内核中添加自定义的syscall函数

这部分参考的是文章 [Adding a Hello World System Call to Linux kernel 3.16.0](https://tssurya.wordpress.com/2014/08/19/adding-a-hello-world-system-call-to-linux-kernel-3-16-0/)

#### 2.1 下载并解压内核文件

#### 2.2 定义新的系统函数sys_hello

a) 创建hello.c文件

> cd /usr/src/linux-3.16
>
> mkdir hello
>
> cd hello
>
> vim hello.c

/usr/src/linux-3.16/hello/hello.c

```c
#include <linux/kernel.h>

asmlinkage long sys_hello(void)
{
        printk("Hello world\n");
        return 0;
}
```



b) 创建Makefile

> vim Makefile

/usr/src/linux-3.16/hello/Makefile

```
obj-y := hello.o
```



c) 修改内核的Makefile

修改linux-3.16文件目录下的Makefile，将842行的"*core-y += kernel/ mm/ fs/ ipc/ security/ crypto/ block/* "

修改为"*core-y += kernel/ mm/ fs/ ipc/ security/ crypto/ block/ hello/*"



d) 修改syscall_32.tbl文件（如果是64位系统，就应该修改syscall\_64.tbl）

> *cd arch/x86/syscalls*
>
> vim syscall_32.tbl

在接近末尾处，添加一行

```
354    i386    hello    sys_hello
```

其中354指的是系统调用号，i386指的是系统类型，sys_hello指的是系统函数



e) 修改对应的头文件syscalls.h

> *cd  include/linux/*
>
> vim syscalls.h

在末尾处，添加一行

```
asmlinkage long sys_hello(void);
```

#### 2.3 编译前准备

#### 2.4 配置内核

#### 2.5 安装或更新内核

#### 2.6 检验系统调用函数是否成功编译

随便写一个test.c文件

```c
#include <stdio.h>
#include <linux/kernel.h>
#include <sys/syscall.h>
#include <unistd.h>
int main()
{
         long int amma = syscall(354);
         printf("System call sys_hello returned %ld\n", amma);
         return 0;
}
```

如果内核编译正确的话，程序返回的是"*System call sys_hello returned 0*"

通过dmesg命令可以查看内核信息，发现"Hello world"