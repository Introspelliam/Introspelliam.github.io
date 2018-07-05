---
title: gdb的调试与使用
date: 2017-08-03 22:22:50
categories: pwn
tags: [gdb, 调试]
---

### 1. 调试的快捷键

<font color=#f00>peda带有的功能，直接输入命令，其就会给予提示（如果不是这样，基本上也是该命令就可以不带参数）。这儿就不多做介绍</font>

#### 1.1 基础的调试快捷键

- s step，si步入
- n 执行下一条指令  ni步入
- b 在某处下断点，可以用 
  - b * adrress
  - b function_name
  - info b  查看断点信息
  - delete 1删除第一个断点
- c 继续
- r 执行
- disas addr 查看addr处前后的反汇编代码

#### 1.2 显示数据

* p 系列
  * p system/main  显示某个函数地址
    * p $esp	显示寄存器
  * p/x  p/a p/b p/s。。。
  * p 0xff - 0xea   <font color=#f00>计算器</font>
  * print &VarName 查看变量地址
  * p * 0xffffebac   查看某个地址处的值
* x系列
  * x/xw addr 显示某个地址处开始的16进制内容，如果有符号表会加载符号表
  * x/x $esp 查看esp寄存器中的值
  * x/s addr 查看addr处的字符串
  * x/b addr 查看addr处的字符
  * x/i  addr 查看addr处的反汇编结果
* info系列
  * info register $ebp  查看寄存器ebp中的内容 (简写为 i r ebp)
  * i r eflags 查看状态寄存器
  * i r ss        查看段寄存器
  * i b            查看断点信息
  * i functions  查看所有的函数
* disas addr 查看addr处前后的反汇编代码
* stack 20   查看栈内20个值
* show args  查看参数
* vmmap 查看映射状况 <font color=#f00>peda带有</font>
* readelf 查看elf文件中各个段的起始地址  <font color=#f00>peda带有</font>
* parseheap 显示堆状况  <font color=#f00>peda带有</font>

#### 1.3 查找数据

* find 查找字符串    <font color=#f00>peda带有</font>
* searchmem 查找字符串  <font color=#f00>peda带有</font>
* ropsearch "xor eax,eax;ret"  0x08048080 0x08050000   查找某段的rop  <font color=#f00>peda带有</font>
* ropgadget  提供多个pop|ret可行结果  <font color=#f00>peda带有</font>

#### 1.4 修改数据

* set $esp=0x110  修改寄存器的值
* set *0xf7ff3234=0x08042334 修改内存的值
* set args "asdasg" "afdasgasg" "agasdsa"  分别给参数1,2,3赋值
* set args "\`python -c 'print "1234\x7f\xde"'\`"    这个参数中用python脚本重写了一下，避免有些字符无法正确设置
* r "arg1" "arg2" "arg3"   设置参数
* run \`$(perl -e 'print "A"x20')\`

#### 1.1 peda插件

```
Enhance the display of gdb: colorize and display disassembly codes, registers, memory information during debugging.
Add commands to support debugging and exploit development (for a full list of commands use peda help):
aslr -- Show/set ASLR setting of GDB
checksec -- Check for various security options of binary
dumpargs -- Display arguments passed to a function when stopped at a call instruction
dumprop -- Dump all ROP gadgets in specific memory range
elfheader -- Get headers information from debugged ELF file
elfsymbol -- Get non-debugging symbol information from an ELF file
lookup -- Search for all addresses/references to addresses which belong to a memory range
patch -- Patch memory start at an address with string/hexstring/int
pattern -- Generate, search, or write a cyclic pattern to memory
procinfo -- Display various info from /proc/pid/
pshow -- Show various PEDA options and other settings
pset -- Set various PEDA options and other settings
readelf -- Get headers information from an ELF file
ropgadget -- Get common ROP gadgets of binary or library
ropsearch -- Search for ROP gadgets in memory
searchmem|find -- Search for a pattern in memory; support regex search
shellcode -- Generate or download common shellcodes.
skeleton -- Generate python exploit code template
vmmap -- Get virtual mapping address ranges of section(s) in debugged process
xormem -- XOR a memory region with a key
Installation
```

**vmmap：查看当前程序映射的内存块**
**dumprop：**

### 2. 查找某个plt、got、plt_2

* plt 可以直接使用pwntools中的ELF(elf).symbols(function_name)
* got 可以直接使用pwntools中的ELF(elf).got(function_name)
* plt_2 可以直接使用pwntools中的ELF(lib).symbols(function_name)

### 3. 查找程序所动态链接的库

* file pwn3
  * pwn3: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, for GNU/Linux 2.6.24, BuildID[sha1]=916959406d0c545f6971223c8e06bff1ed9ae74d, not stripped

* checksec pwn3
  * [*] '/root/Desktop/Pwnable/fmt/normal/fmt_string_write_got/pwn3'
    Arch:     i386-32-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      No PIE (0x8048000)


* ldd pwn3
  * 	linux-gate.so.1 (0xf77ad000)
    libc.so.6 => /lib32/libc.so.6 (0xf75d2000)
    /lib/ld-linux.so.2 (0x56601000)


### 4. 编译32位可执行文件

- gcc -m32 test.c -o test

  -  一般而言此时的目标文件为32位，且不能生成调试信息

- gcc -m32 -g test.c -o test

  - 生成的目标文件是32位，且可以利用操作系统的“原生格式（native format）”生成调试

    信息。GDB 可以直接利用这个信息，其它调试器也可以使用这个调试信息

- 其它保护状态的开启，请参考[*linux程序的常用保护机制*](/2017/09/30/linux程序的常用保护机制/)

### 5. 开启PIE之后的调试

开启PIE之后，地址会一直在变，这十分不利于gdb的调试，所以这时候应该在本地关闭ASLR

常用的方法是：echo 0 > /proc/sys/kernel/randomize_va_space

开启的方式是：echo 2 > /proc/sys/kernel/randomize_va_space

### 6. 运行时查看文件执行

做了一道题，在你不执行的时候，只能找到相对地址，但是下断点需要实际的执行地址。若关闭PIE，那么每次的执行地址将会一致，这个时候就需要找到执行的开始地址。peda的常用指令中有vmmap，可以找到实际地址。

这道题很让人苦恼的是，如果gdb中执行run，那么将陷入循环而不能使用vmmap，若强制结束，最后vmmap会报错。这个时候，就有另外的一些办法：

- 执行./pwn &，这个时候会将pwn程序放入后台，而且你能快速知道这个程序的PID，这个时候cat /proc/pwn的PID/maps，就能找到对应的执行时地址。之后kill -9 pwn的PID
- 编写一个小脚本，任意放置一个断点，并开启gdb调试，这个时候断点会崩溃，但是gdb-peda中使用vmmap仍能找到对应地址