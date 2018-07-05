---
title: 内存随机化保护(ASLR)简介
date: 2017-07-14 16:39:22
categories: 安全技术
tags: [windows, ASLR]
---

ASLR(Address Space Layout Randomization)技术就是通过加载程序的时候不再使用固定的基址加载，从而干扰shellcode定位的一种保护机制。

支持ASLR的程序在其PE头中会设置IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识来说明其支持ASLR。从VS 2005 SP1开始加入/dynamicbase链接选项来帮我们完成这个任务。本书使用VS 2008(VS 9.0)中，通过Project->project Properties->Configuration Properties->Linker->Advanced->Randomized Base Address选项对/dynamicbase链接选项进行设置。

ASLR一般分为映像随机化、堆栈随机化、PEB与TEB随机化

### 1. 映像随机化

映像随机化是在PE文件映射到内存时，对其加载的虚拟地址进行随机化处理，这个地址在系统启动时确定，系统重启后该地址会变化。

以IE为例
![对比](/images/2017-07-14/aslr_image.jpg)

系统中设置了映像随机化的开关，用户可以通过设置注册表中的HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\MoveImages的键值来设定映像随机化的工作模式
* 0： 映像随机化被禁用
* -1： 强制对可随机化的映像进行处理，无论是否设置IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识
* 其他值：正常工作模式，只对具有随机化处理标识的映像进行处理

### 2. 堆栈随机化

在运行时随机的选择堆栈的基址，与映像基址随机化不同的是堆栈的基址不是在系统启动的时候确定的，而是在打开程序的时候确定的

<pre><code>
int _tmain(int argc, _TCHAR* argv[])
{
    char * heap = (char *)malloc(100);
    char stack[100];
    printf("Address of heap:%#0.4x\nAddress of stack %#0.4x", heap, stack);
    getchar();
    return 0;
}
</code></pre>

使用win xp和win vista进行对比，如下：
win xp两次运行的结果：
![win_xp两次运行的结果](/images/2017-07-14/win_xp_heap_stack.jpg)
win vista两次运行的结果：
![win_vista两次运行的结果](/images/2017-07-14/win_vista_heap_stack.jpg)


### 3. PEB与TEB

PEB与TEB随机化在win xp sp2就引入了，不再使用固定的PEB基址0x7FFDF00和TEB基址0x7FFDE00

<font color=#f00>获取当前进程的TEB和PEB很简单，TEB存放在FS:0和FS:[0x18]处，PEB存放在TEB偏移0x30处的位置。获取TEB、PEB的方法如下：</font>

<pre><code>
int _tmain(int argc, _TCHAR* argv[])
{
    unsigned int teb;
    unsigned int peb;
    __asm{
        mov eax, FS:[0x18]
        mov teb, eax
        mov eax, dword ptr [eax + 0x30]
        mov peb, eax
    }
    printf("PEB:%#x\nTEB:%#x", peb, teb);
    getchar();
    return 0;
}
</code></pre>

PEB、TEB随机化测试:
![PEB、TEB随机化](/images/2017-07-14/aslr_teb_peb.jpg)

### 4. ASLR存在的缺陷

1. 映像随机化测试时各模块的入口点（Entry那列）地址的低位2个字节时不变的，也就是说映像随机化只是对加载基址的前2字节做了随机处理
2. 堆栈随机化可以防止精准攻击，但是使用JMP ESP跳板、浏览器攻击中的heap spray等技术是不需要精准跳转
3. PEB与TEB的随机化的程度较差，而且即使做到完全随机，依然可以使用其他方法获取当前进程的PEB与TEB