---
title: pwn的新姿势
date: 2018-03-16 22:47:52
categories: pwn
tags: heap
---

### 1. 调用malloc的其它常见函数

- 没有setbuf(stdin,0)的时候，scanf也会malloc个堆作为缓冲区。
- 没有setbuf(stdout,0)的时候，printf才会调用malloc用来在堆上分配缓冲区。

[https://paper.seebug.org/450/](https://paper.seebug.org/450/)

### 2. read函数读入指定长度的数据

当做pwn题时，经常会遇到read一个长度，但是此时输入长度不够，导致其读入了后续操作的字符串，于是给程序调试带来大量的麻烦！

解决办法：在每个read函数处后面都加入time.sleep(1~2)，这相当于时间中断！

另外需要知道的是，scanf其实会产生输入中断。如果前面是read函数，那么此处的scanf函数将会对读入进行中断！

### 3. free_hook和malloc_hook

其实从名字就可以看出，free_hook是free函数调用时的钩子函数，malloc_hook是malloc函数调用时的钩子函数。如果能够改变free_hook或者malloc_hook为system地址，并布置好其参数“/bin/sh\0”，那么在调用free或者malloc函数，将会执行system("/bin/sh")

那么使用其的场景是什么呢？

一般是用户有fastbin attack任意地址写，但是找不到对应大小的可用bin块，这时候会选择使用stderr或者stdout或者stdin其地址高位的0x7f，从而在libc中不断使用任意地址写，直到可以改写free_hook或者malloc_hook。

比较经典的是2018_qwb的那道raisepig题！