---
title: SafeSEH的保护原理以及攻击方法
date: 2017-07-07 20:05:58
categories: 安全技术
tags: [SEH,windows]
---

### 1. 启用SafeSEH

通过启用/SafeSEH链接选项可以让编译好的程序具备SafeSEH功能

VS命令提示行，通过执行"dumpbin /loadconfig 文件名"就可以查看程序安全SEH表的情况。

可以通过"程序->Microsoft Visual Studio 2008->Visual Studio Tools->Visual Studio 2008 Command Prompt"启用

具有SafeSEH编译能力的VS 2008在编译程序时将程序中的异常处理函数的地址提取出来放到安全SEH表中

### 2. SafeSEH的保护措施

1. 检查异常处理链是否位于当前程序的栈中，如果不在当前栈中，程序将终止异常处理函数的调用
2. 检查异常处理函数指针是否指向当前程序的栈中。如果指向当前栈中，程序将终止异常处理函数的调用
3. 在前面两项检查之后，程序调用全新的函数RtlIsValidHandler()，来对异常处理函数的有效性进行检验。
* 首先该函数判断异常处理函数地址是不是在加载模块的内存空间，如果属于加载模块的内存空间，检校函数将依次进行如下判断：
	1. 判断程序设置IMAGE_DLLCHARACTERISTICS_NO_SEH标识。设置了，异常就忽略，函数返回校验失败。
	2. 检测程序是否包含SEH表。如果包含，则将当前异常处理函数地址与该表进行匹配，匹配成功返回校验成功，否则失败。
	3. 判断 程序是否设置ILonly标识。设置了，标识程序只包含.NET编译人中间语言，函数直接返回校验失败
	4. 判断异常处理函数是否位于不可执行页（non-executable page）上。若位于，校验函数将检测DEP是否开启，如若系统未开启DEP则返回校验成功；否则程序抛出访问违例的异常
* 如果异常处理函数的地址没有包含在加载模块的内存空间。校验函数将直接执行DEP相关检测，函数将依次进行如下检验：
	1. 判断异常处理函数是否位于不可执行页（non-executable page）上。若位于，校验函数将检测DEP是否开启，如若系统未开启DEP则返回校验成功；否则程序抛出访问违例的异常
	2. 判断系统是否允许跳转到加载模块的内存空间外执行，如允许则返回校验成功；否则返回校验失败

![RtlIsValidHandler校验流程](/images/2017-07-07/RtlIsValidHandler.jpg)

RtlIsValidHandler()函数的伪代码如下：

<pre><code>
BOOL RtlIsValidHandler(handler)
{
	if (handler is in image){	//在加载模块内存空间内
    	if (image has the IMAGE_DLLCHARACTERISTICS_NO_SEH flag ser)
        	return FALSE;
        if (image has a SafeSEH table) 	//含有安全SEH表，说明程序启用SafeSEH
        	if (handler found in the table)	// 异常处理函数地址出现在安全SEH表中
            	return TRUE;
            else	// 异常处理函数未出现在安全SEH表中
            	return FALSE;
        if (image is a .NET assembly with the ILonly flag set) 	//只包含IL
        	return FALSE;
    }
    if (handler is on a non-executable page){	// 跑到不可执行页上
    	if (ExecuteDispatchEnable bit set in the process flags)	//DEP关闭
        	return TRUE;
        else
        	raise ACESS_VIOLATION; //抛出访问违例异常
    }
    if (handler is not in an image){	// 在加载模块内存之外，并且在可执行页上
    	if (ImageDispatchEnable bit set in the process flags)	// 允许在加载模块内存空间外执行
        	return TRUE;
        else
        	return FALSE;
    }
    return TRUE;	//前面所有条件都满足就允许这个异常处理函数执行
}
</code></pre>

### 3. SafeSEH不能解决的问题

1. 异常处理函数位于加载模块内存范围之外，DEP关闭
2. 异常处理函数位于加载模块内存范围之内，相应模块未启用SafeSEH(安全SEH表为空)，同时相应模块不是纯IL
3. 异常处理函数位于加载模块范围之内，相应模块启用SafeSEH（安全SEH表不为空），异常处理函数地址包含在安全SEH表中

分析三种情况的可行性：
1. 只考虑SafeSEH，不考虑DEP干扰，需要在加载模块内存范围之外找到一个跳板指令就可以转入shellcode中执行
2. 第二种情况中，我们可以利用未启用SafeSEH模块中的指令作为跳板，转入shellcode执行。这也是一再强调SafeSEH需要操作系统与编译器的双重支持。在加载模块中找到一个未启用SafeSEH模块不是很难
3. 第三种情况下，可以考虑：a)清空安全SEH表，造成该模块未启用SafeSEH假象；b)将指令注册到安全SEH表中。由于安全SEH表的信息在内存中加密存放，所以突破它的可能性不大，放弃！！

另外突破SafeSEH的方法
1. 不攻击SEH。使用覆盖返回地址或者虚函数表等信息
2. 利用SEH的安全校验的严重缺陷——如果SEH中的异常函数指针指向堆区，即使安全校验发现SEH不可信，仍会调用其已修改过的异常处理函数。


### 4. 名词解释

#### 4.1 DEP

DEP 数据执行保护 (Data Execution Prevention)。数据执行保护(DEP) 是一套软硬件技术，能够在内存上执行额外检查以帮助防止在系统上运行恶意代码。在 Microsoft Windows XP Service Pack 2及以上版本的Windows中，由硬件和软件一起强制实施 DEP。

启用方法：
修改C:\boot.ini
默认为: /noexecute=option /fastdetect		//启用DEP
修改为：/execute=option /fastdetect		   //关闭DEP

#### 4.2 IL

IL可以指Intermediate Language，同MSIL(Microsoft Intermediate Language),是将.NET代码转化为机器语言的一个中间语言的缩写。

