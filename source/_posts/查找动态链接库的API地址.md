---
title: 查找动态链接库的API地址
date: 2017-06-22 13:10:12
categories: 安全技术
tags: windows
---

### 1、开始之前
为什么要获取动态链接库的API函数地址，这是为了方便测试时得到需要的函数，并通过该函数进行一系列的操作。
而为了能够写出shellcode，需要的是这个动态链接库的API函数的地址，因而需要掌握获取API地址的方法。

### 2、使用OllyDbg获取动态链接库的API函数地址
<font color=#0f0>本文以获取动态链接库user32.dll中的MessageBoxA函数地址为例。</font>

（1）首先使用OllyDbg打开一个使用了该动态链接库的PE程序
其实包含user32.dll的程序有很多，大致上只要含有图形界面，就需要user32.dll这个动态链接库。
我们以windows系统中最为常见的calc.exe为例(calc是计算器程序，很明显有界面；其存放在c:\windows\system32\calc.exe)

（2）使用OllyDbg的查看可执行模块的功能
点击查看->可执行模块
可以看到下面的界面

![OllyDbg查看可执行模块](/images/2017-06-22/executable.jpg)

（3）点击user32.dll，右键点击查看名称

![查看动态链接库的API函数](/images/2017-06-22/find_name.png)

（4）找到MessageBoxA，并得到其对应的地址

![找到API函数地址](/images/2017-06-22/find_address.jpg)

### 3、使用C32asm获取动态链接库的API函数地址
<font color=#0f0>【该工具属于吾爱破解工具包=>反编译工具】</font>
点击 工具->API地址查询

![使用C32asm查询dll的API函数地址](/images/2017-06-22/C32asm_API_address.jpg)

<font color=#f00>毫无疑问，从简易程度来看，使用C32asm查询的速度更快，而且更为适合用户！！！</font>

