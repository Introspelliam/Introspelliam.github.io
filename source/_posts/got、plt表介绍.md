---
title: got、plt表介绍
date: 2017-08-03 22:31:33
categories: pwn
tags: 调试
---

### 1. GOT表和PLT表

GOT（Global Offset Table，全局偏移表）是Linux ELF文件中用于定位全局变量和函数的一个表。PLT（Procedure Linkage Table，过程链接表）是Linux ELF文件中用于延迟绑定的表，即函数第一次被调用的时候才进行绑定。

### 2. 延迟绑定

所谓延迟绑定，就是当函数第一次被调用的时候才进行绑定（包括符号查找、重定位等），如果函数从来没有用到过就不进行绑定。基于延迟绑定可以大大加快程序的启动速度，特别有利于一些引用了大量函数的程序

### 3. 延迟绑定的基本原理

假如存在一个bar函数，这个函数在PLT中的条目为bar@plt，在GOT中的条目为bar@got，那么在第一次调用bar函数的时候，首先会跳转到PLT，伪代码如下：

bar@plt:

jmp bar@got

patch bar@got

这里会从PLT跳转到GOT，如果函数从来没有调用过，那么这时候GOT会跳转回PLT并调用patch bar@got，这一行代码的作用是将bar函数真正的地址填充到bar@got，然后跳转到bar函数真正的地址执行代码。当我们下次再调用bar函数的时候，执行路径就是先后跳转到bar@plt、bar@got、bar真正的地址。具体来看个实例：

vulnerable_function函数调用了read函数，由于read函数是动态链接加载进来的只有在链接的时候才知道地址，编译时并不知道地址

![1](/images/2017-08-03/1.png)

执行call _read函数会跳到plt表中寻找中：

![2](/images/2017-08-03/2.png)

plt表中会继续跳入到got表中寻找

![3](/images/2017-08-03/3.png)

got表中的所存的read函数的地址便是在pwn6进程中的实际地址，也就是

![4](/images/2017-08-03/4.png)



