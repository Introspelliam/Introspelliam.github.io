---
title: TEB简介
date: 2017-06-30 21:16:57
categories: 安全技术
tags: [windows, TEB]
---

### TEB特点

1. 一个进程可能同时有多个线程
2. 每个线程都有一个线程环境块TEB
3. 第一个TEB开始于0x7FFDE000
4. 之后新建的线程的TEB将紧随前边的TEB，之间相隔0x100字节，并向内存地址方向
5. 线程退出时，对应的TEB也被销毁，腾出的TEB空间被新建的线程重复使用。

线程环境块的预测图：
![线程环境块的预测图](/images/2017-06-30/TEB_prediction.jpg)

### TEB结构
由于TEB才是初学，对里面的很多结构都不怎么了解，写这一节主要是为了贴一张图，方便以后补充！

![TEB](/images/2017-06-30/TEB.jpg)

当然为了充实被本篇博客，笔者提供几个小程序：

<br>
<font color=#0f0>从FS寄存器获取当前线程</font>

<pre><code>
int GetThreadId()
{
	int ithread = 0;
	_asm{
		xor esi , esi
		mov eax, fs:[esi+18h]     
		mov ecx, [eax+ 20h] 
		mov eax, [eax+ 24h]
		mov dword ptr[ithread], eax
    }
	return ithread;
}

</code></pre>

<br>
<font color=#0f0>从FS寄存器获取当前进程ID</font>

<pre><code>
int GetProcessId()
{
	int iProcess = 0;
	_asm{
    	xor esi , esi
    	mov eax, fs:[esi+18h]
    	mov ecx, [eax+ 20h]
    	mov eax, [eax+ 24h]
		mov dword ptr[iProcess ], ecx
	}
	return iProcess;
}

</code></pre>
