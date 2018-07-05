---
title: 攻击SEHOP的方法
date: 2017-07-18 13:40:19
categories: 安全技术
tags: [SEH, windows]
---

### 1. 攻击返回地址

如果程序启用了SEHOP但是未启用GS，或者启用了GS但是刚好被攻击的函数没有GS保护，那么就可以供给函数的返回地址！

### 2. 攻击虚函数

SEHOP保护的只是SEH，对于SEH以外的不提供保护。所以我们可以通过攻击虚函数来劫持程序流程，这个过程不涉及任何异常处理。

### 3. 利用未启用SEHOP的模块

出于兼容性的考虑，对一些程序禁用了SEHOP，如经过Armadilo加壳的软件。

操作系统会根据PE头MajorLinkerVersion和MinorLinkerVersion两个选项来判断是否为程序禁用SEHOP。可以将这两个选项设置为0x53和0x52来模拟经过Armadilo加壳的程序，从而达到禁用SEHOP的目的！

此处是通过CFF Explorer来进行这种处理
![CFF Explorer修改PE头来禁用SEHOP](/images/2017-07-18/set_version.jpg)

#### 3.1 实验代码

#### 3.2 实验内容

<b>实验环境</b>

||推荐使用的环境|备注|
|--|--|--|
|操作系统|windows 7||
|EXE编译器|Visual Studio 2008||
|DLL编译器|VC++ 6.0| 将dll基址设置为0x11120000|
|系统SEHOP|启用||
|秩序DEP|关闭||
|程序ASLR|EXE随意，DLL禁用||
|编译选项|禁用优化选项||
|build版本|release版本||

<b>windows 7 下的弹出对话框的shellcode</b>
<pre><code>
char shellcode[] = 
    "\xFC\x68\x6A\x0A\x38\x1E\x68\x63\x89\xD1\x4F\x68\x32\x74\x91\x0C"
    "\x8B\xF4\x8D\x7E\xF4\x33\xDB\xB7\x04\x2B\xE3\x66\xBB\x33\x32\x53"
    "\x68\x75\x73\x65\x72\x54\x33\xD2\x64\x8B\x5A\x30\x8B\x4B\x0C\x8B"
    "\x49\x1C\x8B\x09<font color=#f00>\x8B\x09</font>\x8B\x69\x08\xAD\x3D\x6A\x0A\x38\x1E\x75\x05\x95"
    "\xFF\x57\xF8\x95\x60\x8B\x45\x3C\x8B\x4C\x05\x78\x03\xCD\x8B\x59"
    "\x20\x03\xDD\x33\xFF\x47\x8B\x34\xBB\x03\xF5\x99\x0F\xBE\x06\x3A"
    "\xC4\x74\x08\xC1\xCA\x07\x03\xD0\x46\xEB\xF1\x3B\x54\x24\x1C\x75"
    "\xE4\x8B\x59\x24\x03\xDD\x66\x8B\x3C\x7B\x8B\x59\x1C\x03\xDD\x03"
    "\x2C\xBB\x95\x5F\xAB\x57\x61\x3D\x6A\x0A\x38\x1E\x75\xA9\x33\xDB"
    "\x53\x68\x77\x65\x73\x74\x68\x66\x61\x69\x6C\x8B\xC4\x53\x50\x50"
    "\x53\xFF\x57\xFC\x53\xFF\x57\xF8";
</code></pre>

上面代码中的红字是与xp和window 2000中不同的shellcode之处，其指代的意思是mov ecx, [ecx]
之所以在此处多加这一句，是因为ntdll.dll链的下一个为KERNELBASE.dll，而它下一个才是kernel32.dll，这也是win7与之前的系统的不同之处！

本次实验是在"利用未启用SafeSEH模块"实验的基础上进行的

win7中关闭DEP的方法：cmd窗口中
bcdedit.exe/set {current} nx AlwaysOff pause

首先为SEH_NOSafeSEH_JUMP.dll禁用SEHOP，使用CFF Explorer打开SEH_NOSafeSEH_JUMP.dll后在Optional header选项页中来进行设置，分别将MajorLinkerVersion和MinorLinkerVersion设置为0x53和0x52。这个如上图

然后对演示的主程序进行一定的修改：
1. 修改弹出对话框的shellcode，让其可以在windows 7下正常弹出
2. 取消程序的/NXCOMPAT链接选项来禁用程序的DEP


<font color=#f00>不知道什么原因，到目前为止，我还没有实现弹出对话框的效果</font>

### 4. 伪造SEH链表

伪造SEH是非常困难的，首先需要系统的ASLR不能启用，因为伪造SEH链时需要用到FinalExceptionHandler指向的地址，如果每次系统重启后这个地址都变化的话，溢出的成功率将大大降低。

#### 4.1 实验代码

#### 4.2 实验内容

伪造SEH链绕过SEHOP所需的条件：
1. 下图中的0xXXXXXXXX地址必须指向当前栈中，而且必须能够被4整除
2. 0xXXXXXXXX处存放的异常处理记录作为SEH链的最后一项，其异常处理函数指针必须指向终极异常处理函数
3. 突破SEHOP检查后，溢出程序还需搞定SafeSEH

![伪造SEH链示意图](/iamges/2017-07-18/seh.jpg)

为了方便，本实验在"利用未启用SafeSEH模块绕过SafeSEH"的基础上进行，不用考虑SafeSEH问题，只需确定0xXXXXXXXX的值和FinalExceptionHandler指向的地址即可。

<b>实验思路</b>
1. 通过未启用SafeSEH的SEH_NOSafeSEH_JUMP.dll来绕过SafeSEH
2. 通过伪造SEH链，造成SEH链未被破坏的假象来绕过SEHOP
3. SEH_NOSafeSEH中的test函数存在典型的溢出
4. 使用SEH_NOSafeSEH_JUMP.dll中的“pop pop retn”指令地址覆盖异常处理函数地址，然后通过制造除0异常，将程序转入异常处理，通过劫持异常处理流程，程序转入SEH_NOSafeSEH_JUMP.DLL中执行"pop pop retn"指令，在执行retn后程序转入shellcode执行

<b>实验环境</b>

||推荐使用的环境|备注|
|--|--|--|
|操作系统|windows 7||
|EXE编译器|Visual Studio 2008||
|DLL编译器|VC++ 6.0| 将dll基址设置为0x11120000|
|系统SEHOP|启用||
|秩序DEP|关闭||
|程序ASLR|关闭||
|编译选项|禁用优化选项||
|build版本|release版本||
