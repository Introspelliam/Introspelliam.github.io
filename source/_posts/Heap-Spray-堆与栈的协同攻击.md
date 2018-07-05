---
title: 'Heap Spray: 堆与栈的协同攻击'
date: 2017-09-10 11:27:08
categories: 安全技术
tags: heap-spray
---

针对浏览器的攻击中，常常会结合使用堆和栈协同利用漏洞

1. 当浏览器或其使用ActiveX空间中存在溢出漏洞时，攻击者就可以生成一个特殊的HTML文件来触发这个漏洞。
2. 不管是堆溢出还是栈溢出，漏洞触发后最终能够获得EIP
3. 有时我们可能很难在浏览器中复杂的内存环境中布置完整的shellcode
4. 页面中的Javascript可以申请堆内存，因此把shellcode通过Javascript布置在堆中成为可能

在使用Heap Spray，一般会将EIP指向堆区的0x0C0C0C0C位置，然后用JavaScript申请大量堆内存，并用包含着0x90的“内存片”覆盖这些内存

通常JavaScript从内存地址向内存高址分配内存，因此申请的内存超过200MB（200MB=200 X 1024 X 1024=0x0C800000 > 0x0C0C0C0C）后，0x0C0C0C0C将被含有shellcode的内存片覆盖。只要内存片中的0x90能够命中0x0C0C0C0C位置，shellcode就能执行。

可以用下面的方式覆盖内存

```
var nop=unescape("%u9090%u9090");
while (nop.length <= 0x100000/2)
{
    nop += nop;
}//生成一个1MB充满0x90的数据块

nop = nop.substring(0, 0x100000/2 -32/2 -4/2 -shellcode.length -2/2);
var slide = new Arrat();
for (var i=0; i < 200; i++)
{
    slide[i] = nop + shellcode;
}

```

- 每个内存片1MB
- 首先产生一个1MB且全为0x90的内存块
- JavaScript会添加一些额外信息，得减去。堆块信息 32字节； 字符串长度 4字节； 结束符 2个字节的NULL