---
title: 堆溢出利用（上）——DWORD SHOOT
date: 2017-06-26 10:42:20
categories: 安全技术
tags: [heap, windows]
---

### 1 堆表“拆卸”中的问题

堆管理系统的三类操作：堆块分配、堆块释放和堆块合并归根结底都是对链表的修改。分配是将堆块从空表中“卸下”；释放是把堆块“链入”空表；合并也可以看做将若干个堆块先从空表中卸下，修改块首信息（大小），之后把更新后的新块“链入”空表。

“卸下”和“链入”的过程就有可能获得一次读写内存的机会。

堆溢出利用的精髓就是用精心构造的数据去溢出下一个堆块的块首，改写块首中的前向指针(flink)和后向指针(blink)，然后分配、释放、合并等操作发生时伺机获得一次向内存任意地址写入任意数据的机会。

能向内存任意地址写入任意数据的机会成为"DWORD SHOOT"（"arbitrary DWORD reset"）。其发生时，不但可以控制射击的目标(任意地址)，还可以选用适当的子弹(4字节恶意数据)。

DWORD SHOOT可以劫持进程。

| 点射目标(Target) | 子弹(Payload) | 改写的结果 |
| --- |--- | --- |
|栈帧中的函数返回地址 | shellcode起始地址 | 函数返回时，跳去执行shellcode |
|栈帧中的S.E.H句柄 | shellcode起始地址 | 异常发生时，跳去执行shellcode |
|重要函数调用地址 | shellcode起始地址 | 函数调用时,跳去执行shellcode |

### 2 DWORD SHOOT 举例

这里举的是将一个结点从双向链表中“卸下”时可能发生的问题:

	int remove(ListNode *node)
    {
    	node->blink->flink = node->flink;
        node->flink->blink = node->blink;
        return 0;
    }

通过这个函数逻辑，得到下图缩水的链表变化过程。
![卸载结点的过程图](/images/2017-06-26/remove_node.jpg)

<font color=#f00>当堆溢出发生时，非法数据会淹没下一个堆块块首。即块首中存放的前向指针和后向指针可以被攻击者伪造，当这个堆块从双向链表中卸下时，node->blink->flink=node->flink将把伪造的flink指针值写入伪造的blink所指向的地址中去，从而发生DWORD SHOOT。</font>
![DWORD SHOOT发生的原理](/images/2017-06-26/dword_shoot.jpg)

### 3 调试中体会DWORD SHOOT

代码如下:

	#include <windows.h>

    int main()
    {
        HLOCAL h1,h2,h3,h4,h5,h6;
        HANDLE hp;
        hp = HeapCreate(0, 0x1000, 0x10000);
        h1 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);
        h2 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);
        h3 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);
        h4 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);
        h5 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);

        h6 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);
        __asm int 3		// used to break the process
        //free the odd blocks to prevent coalesing
        HeapFree(hp, 0, h1);
        HeapFree(hp, 0, h3);
        HeapFree(hp, 0, h5);	//now freelist[2] got 3 entries

        //will allocate from freelist[2] which means unlink the last entry(h5)
        h1 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);

        return 0;
    }

(1) 程序首先创建了一个大小为0x1000的堆区，并从其中连续申请了6个大小为8字节的堆块（加上堆首就是16字节），这应该会从大块上切下来。
(2) 释放奇数次申请的堆块为了防止堆块合并的发生。
(3) 三次释放结束后，freelist[2]所标识的空表中应该链入了3个空闲链表，它们一次是h1、h3、h5。
(4) 再次申请8字节的堆块，应该从freelist[2]所标识的空表中分配，这意味着最后一个堆块h5被从空表中拆下。
(5) 如果我们手动修改h5块首中的指针，应该能够观察到DWORD SHOOT的发生。

将代码执行到0x0040112E处，此时三次内存释放操作结束。此时堆块状况如下：
![空表索引](/images/2017-06-26/freelist.jpg)
<b><center>空表索引</center></b>
![空表索引](/images/2017-06-26/freelist2.jpg)
<b><center>堆块状况</center></b>

从0x0040112E处开始，共有7个堆块，如表所示：

<b><center>堆块使用状况</center></b>

| |起始位置|Flag|Size 单位:8bytes|前向指针|后向指针|
|--|--|--|--|--|--|
|h1|0x00360680|空闲态0x00|0x0002|0x003606A8|0x00360188|
|h2|0x00360690|占用态0x01|0x0002|无|无|
|h3|0x003606A0|空闲态0x00|0x0002|0x003606C8|0x00360688|
|h4|0x003606B0|占用态0x01|0x0002|无|无|
|h5|0x003606C0|空闲态0x00|0x0002|0x00360188|0x003606A8|
|h6|0x003606D0|占用态0x01|0x0002|无|无|
|尾块|0x003606E0|最后一项0x10|0x0124|0x00360178<br>(freelist[0])|0x00360178<br>(freelist[0])|

除了freelist[0]和freelist[2]之外，所有的空表索引都为空（指向自身）。结合上面给出的空表索引图，我们可以得到freelist[2]链表的组织情况。如图所示：
![链表组织情况](/images/2017-06-26/freelist3.jpg)

在执行最后一次8字节的内存请求时会把freelist[2]的最后一项（原来的h5）分配出去，这意味着将最后一个结点从双向链表中卸下。

如果直接修改在内存中h5堆块中的空表指针（当然攻击发生时是由于溢出改写的），那么应该能够观察到DWORD SHOOT现象。

如图所示，直接在调试器中手动将0x003606C8处的前向指针改为0x44444444,后向指针改为0x00000000。当最后一个分配函数被调用后，调试器被异常中断，原因是无法将0x44444444写入0x00000000.当然，如果把射击目标定位合法地址，这条指令执行后 0x44444444将会被写入目标。

### 4 说明

事实上，堆块的分配、释放、合并等操作都能引发DWORD SHOOT(因为都涉及链表操作)，甚至快表也可以用来制造DWORD SHOOT。



