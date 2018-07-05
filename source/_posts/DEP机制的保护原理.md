---
title: DEP机制的保护原理
date: 2017-07-09 17:35:51
categories: 安全技术
tags: [DEP, windows]
---

### 1. DEP简介

溢出攻击的根源是现代计算机对数据和代码没有明确区分。而重新设计计算机体系结构基本上不可能，所以只能向前兼容的修补来减少溢出带来的损害，DEP（数据执行保护， Data Execution Prevention）设计弥补这一缺陷。

DEP基本原理是将数据所在的页面标识设置为不可执行，当程序溢出成功转入shellcode时，程序会尝试在数据基本页面上执行指令，此时CPU会抛出异常，而不是执行恶意指令。

DEP的主要作用是阻止数据页（如默认的堆页、各种堆栈页以及内存池页）执行代码。从Windows XP SP2开始有，分为：软件DEP(Software DEP)和硬件DEP(Hardware-enforeced DEP)

软件DEP就是SafeSEH。

硬件DEP：需要CPU支持，AMD称为No-Execute Page-Protection(NX)、Intel称为Execute Disable Bit(XD)。操作系统通过设置内存页的NX/XD属性标记，来指明是否可以从该内存中执行代码。所以页面表(Page Table)中需要加入特殊标识位(NX/XD)，若其为0表示页面允许执行，为1表示不允许执行。

### 2. 判断机器上是否允许DEP

我的电脑->属性->系统属性->高级->性能->设置->性能选项->数据执行保护。

若CPU不支持硬件DEP，该页面底部会有提示"您的计算机的处理器不支持基于硬件的DEP，但是，Windows可以使用DEP软件帮助保护免受某些类型的攻击"

### 3. DEP的四种工作状态

1. Optin：默认仅将DEP保护用于Windows系统组件和服务，对于其他程序不予保护，但用户可以通过应用程序兼容性工具（ACT，Application Compatibility Toolkit）为选定的程序启用DEP，在Vista下边经过/NXcompat选项编译过的程序将自动应用DEP。这种状态可以被应用程序动态关闭，它多用于普通用户版操作系统：Windows XP、Windows Vista、Windows 7
2. Optout：为排除列表程序外的所有程序和服务启用DEP，用户可以手动在排除列表中指定不启用DEP保护的程序和服务。这种状态可以被动态关闭，多用于服务器版操作系统：windows 2003、windows 2008
3. AlwaysOn：对所有进程启用DEP的保护，不存在排序列表，这种模式下，DEP不可以被关闭，目前只有64位操作系统上才工作在AlwaysOn模式
4. AlwaysOff：对所有进程都禁用DEP，在这种模式下，DEP也不能被动态开启，这种模式一般只有在某种特定场合才使用，如DEP干扰到程序的正常运行

### 4. 设置DEP

<b>机器上设置DEP</b>
在C:\boot.ini中设置：
1. 设置DEP关闭: /execute=optin /fastdetect
2. 设置DEP工作模式： /noexecute=optout /fastdetect

<b>编译器中设置链接选项</b>
1. Visual Studio 2005及其后续版本引入了链接选项/NXCOMPAT，默认为开启
2. Project->project Properties->Configuration Properties->Linker->Advanced->Data Execution Prevention(DEP)中选择是不是使用/NXCOMPAT

采用/NXCOMPAT编译的程序会在PE头中设置IMAGE_DLLCHARACTERISTICS_NX_COMPAT标识，该标识通过结构体IMAGE_OPTIONAL_HEADER中DllCharacteristics变量进行体现，当DllCharacteristics设置为0x100表示程序采用/NXCOMPAT编译。

### 5. DEP的局限性

1. 硬件DEP需要CPU支持
2. 由于兼容性原因Windows不能对所有进程开启DEP保护，否则会出现异常。例如第三方的插件DLL，由于无法确认其是否开启DEP，对这些DLL程序不能贸然开启DEP保护；使用ATL 7.1或者以前版本的程序需要在数据页面上产生可执行代码，这时就不能启用DEP保护，否则会出现异常
3. /NXCOMPAT编译选项，或者IMAGE_DLLCHARACTERISTICS_NX_COMPAT标识的设置，只对Windows Vista以上的系统有效。也就是说，即使采用了这种链接选项，在某些操作系统上也不会自动启用DEP保护。
4. DEP工作在Optin和Optout下时，DEP可以被动态关闭或开启。操作系统中某些API函数可控制DEP状态，而它们在早期的操作系统中对这些API函数的调用没设置线坠。