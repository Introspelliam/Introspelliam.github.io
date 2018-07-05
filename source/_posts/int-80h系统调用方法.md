---
title: int 80h系统调用方法
date: 2017-08-07 09:17:48
categories: pwn
tags: linux
---

### 1. int 0x80简介

先看看下面通过系统调用实现的hello world代码：
```assembly
.section .data
msg:
        .ascii "Hello world!\n"

.section .text

.globl _start

_start:
        movl $4, %eax
        movl $1, %ebx
        movl $msg, %ecx
        movl $13, %edx
        int $0x80
        movl $1, %eax
        movl $0, %ebx
        int $0x80
```

系统调用是通过int 0x80来实现的，eax寄存器中为调用的功能号，ebx、ecx、edx、esi等等寄存器则依次为参数，从 /usr/include/asm/unistd.h中可以看到exit的功能号_NR_exit为1，write(_NR_write)功能号为4，因此第一个int $0x80调用之前eax寄存器值为4，ebx为文件描述符，stdout的文件描述符为1，ecx则为buffer的内存地址，edx为buffer长度。第二个int $0x80之前eax为1表示调用exit，ebx为0表示返回0。

### 2. 系统调用功能号

这部分可以参考[System Call Number Definition](http://www.linfo.org/system_call_number.html)
以及[http://asm.sourceforge.net/syscall.html#2](http://asm.sourceforge.net/syscall.html#2)

其实调用功能号放在了/usr/include/asm/unistd.h之中，打开文件发现：
> cat /usr/include/asm/unistd.h | less

```cpp
#define __NR_exit                 1
#define __NR_fork                 2
#define __NR_read                 3
#define __NR_write                4
#define __NR_open                 5
#define __NR_close                6
#define __NR_waitpid              7
#define __NR_creat                8
#define __NR_link                 9
#define __NR_unlink              10
#define __NR_execve              11
#define __NR_chdir               12
#define __NR_time                13
#define __NR_mknod               14
#define __NR_chmod               15
#define __NR_lchown              16
```
总共有383条，就不细细讲述了

### 3. 系统调用及参数传递过程 

这部分具体可以参考：
[系统调用及参数传递过程](http://blog.chinaunix.net/uid-10386087-id-2958669.html)
[深入理解Linux的系统调用](http://blog.chinaunix.net/uid-10386087-id-2958670.html)

我们以x86为例说明：
由于陷入指令是一条特殊指令，而且依赖与操作系统实现的平台，如在x86中，这条指令是int 0x80，这显然不是用户在编程时应该使用的语句，因为这将使得用户程序难于移植。所以在操作系统的上层需要实现一个对应的系统调用库，每个系统调用都在该库中包含了一个入口点（如我们看到的fork, open, close等等），这些函数对程序员是可见的，而这些库函数的工作是以对应系统调用号作为参数，执行陷入指令int 0x80，以陷入核心执行真正的系统调用处理函数。当一个进程调用一个特定的系统调用库的入口点，正如同它调用任何函数一样，对于库函数也要创建一个栈帧。而当进程执行陷入指令时，它将处理机状态转换到核心态，并且在核心栈执行核心代码。

这里给出一个示例（linux/include/asm/unistd.h）：
```cpp
#define _syscallN(type, name, type1, arg1, type2, arg2, . . . ) \
type name(type1 arg1,type2 arg2) \
{ \
long __res; \
__asm__ volatile ("int $0x80" \
: "=a" (__res) \
: "0" (__NR_##name),"b" ((long)(arg1)),"c" ((long)(arg2))); \
. . . . . .
__syscall_return(type,__res); \
}
```
在执行一个系统调用库中定义的系统调用入口函数时，实际执行的是类似如上的一段代码。这里牵涉到一些gcc的嵌入式汇编语言，不做详细的介绍，只简单说明其意义：
其中\_\_NR\_##name是系统调用号，如name == ioctl，则为\_\_NR\_ioctl，它将被放在寄存器eax中作为参数传递给中断0x80的处理函数。而系统调用的其它参数arg1, arg2, …则依次被放入ebx, ecx, . . .等通用寄存器中，并作为系统调用处理函数的参数，这些参数是怎样传入核心的将会在后面介绍。

<font color=#f00>**注意该调用是从左至右依次传参，与普通函数的由右往左依次传参不同**</font>

### 4. 实例介绍

#### 4.1 sys_execve（x86）

从[系统调用约定](/2017/08/06/系统调用约定/) 一文中我们可以找到sys_execve系统调用的内容

|      |                                          | eax  | ebx           | ecx                    | edx                    | esi                                      | edi  |                                          |
| ---- | ---------------------------------------- | ---- | ------------- | ---------------------- | ---------------------- | ---------------------------------------- | ---- | ---------------------------------------- |
| 11   | [sys_execve](http://www.kernel.org/doc/man-pages/online/pages/man2/execve.2.html) | 0x0b | char __user * | char **user \***user * | char **user \***user * | [struct pt_regs *](http://lxr.free-electrons.com/source/arch/alpha/include/asm/ptrace.h?v=2.6.35#L19) | -    | [arch/alpha/kernel/entry.S:925](http://lxr.free-electrons.com/source/arch/alpha/kernel/entry.S?v=2.6.35#L925) |

从此处可以知道sys_execve的系统调用约定

从[Linux中pt_regs结构体](http://www.cnblogs.com/wanghetao/archive/2011/11/06/2238310.html) 可以得到pt_regs的结构介绍

在[http://man7.org/linux/man-pages/man2/execve.2.html](http://man7.org/linux/man-pages/man2/execve.2.html) 中有给出execve的定义

```
#include <unistd.h>
int execve(const char *filename, char *const argv[], char *const envp[]);
```

ebx是执行文件路径，ecx是命令行参数，edx是环境变量

很多时候ecx=0，edx=0。但是有时候若有参数，可以设置ecx

范例shellcode:

```c++
xor    %eax,%eax
push   %eax
push   $0x68732f2f
push   $0x6e69622f
mov    %esp,%ebx
push   %eax
push   %ebx
mov    %esp,%ecx
mov    $0xb,%al
int    $0x80

********************************
#include <stdio.h>
#include <string.h>
 
char *shellcode = "\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69"
		  "\x6e\x89\xe3\x50\x53\x89\xe1\xb0\x0b\xcd\x80";

int main(void)
{
fprintf(stdout,"Length: %d\n",strlen(shellcode));
(*(void(*)()) shellcode)();
return 0;
}
```

