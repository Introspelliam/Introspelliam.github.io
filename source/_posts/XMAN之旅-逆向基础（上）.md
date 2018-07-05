---
title: XMAN之旅_逆向基础（上）
date: 2017-08-02 12:43:02
categories: xman
tags: [调试, 汇编]
---

这堂课是由Nu1L著名队员Misty所讲，内容很多，范围很广，是作为逆向的基础入门知识——实际上内容还是有点难度的。

### 一、 初级工具使用

<br>

#### 1. 二进制编辑器

Misty作为一位资深的逆向大佬，向我们推荐了两款好用的二进制编辑器：010Editor 和 Editplus

010 Editor是文本/十六进制编辑器，还包括文件解析、计算器、文本比较等功能。其可以通过官方网站提供的脚本(Binary Template)对avi、bmp、png、exe等简单格式的文件进行解析，当然也可以根据需求来自己编写文件解析脚本。

010Editor的文本解析功能，方便了我们分析文件，理清文件内容。


Editplus则是Misty的二次元之心作祟，要支持各种编码，这个确实是不错的选择。

#### 2. 可执行文件查看

对于这部分，我的感触就是看书，看《加密与解密(第三版)》-看雪安全论坛

PE: CFF Explorer
MachO: MachOView
ELF: IDA

#### 3. 格式转换工具

推荐使用shellcode helper

#### 4. 反汇编器

推荐使用IDA
IDA的功能十分强大，而且其超前的意识也让它被大家广泛使用！

* 界面转换
	* d: 设置Data（多次使用可以在1字节、2字节、4字节、8字节间转换）
	* c: 设置Code
	* x: Cross Reference
	* Shift+F12：查看所有字符串
* 反编译器使用
	* y：设置类型（变量、函数）、设置Calling Conversion
* 其他快捷键
	* N：对（变量、函数）重命名

#### 5. 调试器

* 命令行调试器有：
	* gdb: 用于linux等多种系统中
	* windbg：用于windows调试

* 图形界面调试器：
	* OllyDbg：调试win32程序
	* x64_dbg：调试win32/64程序
	* IDA内置调试器

#### 6. 搭建调试环境

在IDA PRO中有dbgsrv文件夹。里面放置了一些远程可执行程序。只需要在远程启用这些程序，就可以在本地远程调试。

#### 6. 去除软件保护

* 侦壳
	* PEiD、ExeInfo
* 脱壳
	* 搜索脱壳机（比较多的有upx、ASPack。对于upx，推荐使用upx shell）
	* ESP定律快速脱壳
		* 原理：脱壳前后位置不变
		* 适用环境：只针对压缩壳
		* 范例：
		首先进入程序，并设置ESP处的硬件断点，如图所示
        ![first](/images/2017-08-02/first.png)
        然后运行至硬件断点处，发现后面有个长跳转，在其位置上设置断点
        ![second](/images/2017-08-02/second.jpg)
        最后运行至长跳转位置处，然后直接步进，进入程序的正式入口，选用插件OllyDump，设置起始地址和入口点修正地址，然后脱壳即可！
        ![third](/images/2017-08-02/third.jpg)
* 去除花指令
	* 使用OllyDbg脚本
	* 手动总结特征码，然后修改
* 去除混淆
	* .net反混淆器 de4dot

#### 7. 定位验证代码

* 任务：
	* 破除保护外壳
	* 理解程序逻辑
	* 找到验证函数
	* 逆推获取flag

* 方法
	* 正向（从main开始）
	* 逆向（从输入输出函数回溯）

### 二、 逆向方法总结

#### 1. 算法分析与逆向

* 没算法（签到题）
* 常见算法
	* 简单异或
	* 带雪崩效应的异或（CBC）
	* 加密算法（RSA、AES）
		* RSA中会引用大数库函数
		* AES如果出得简单，那么解密函数应该在程序中，否则就得理清程序逻辑
	* 散列算法（MD5、SHA1）
		* MD5中会出现常数，所以应该会有0123456789ABCDEF这一串数
		* SHA1中也会出现常数，google一下就能判断
	* 解方程
		* 推荐使用z3，使用时注意与python配合，十分简单
		* python的数学运算库
* 有趣的算法
	* 走迷宫

#### 2. 边信道攻击(side channel attack 简称SCA)

原理： 检测程序执行的行指令数、
应用：逐字节验证的题目

<b>范例：采用codegate-preliminary-2014/dodocrackme/</b>
<pre><code>$ file crackme 
crackme: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, BuildID[sha1]=92ef00b31d91a827a5aed6b0fe03fe38fe20fb4d, stripped
$ ./crackme 
root@localhost's password: bla
Permission denied (password).
$ objdump -d crackme | wc -l
15809
</code></pre>

我们使用pin进行测试得到：
<pre><code>$ pin -t inscount0 -o out -- ./crackme ; cat out
root@localhost's password: a
Permission denied (password).
Count 715821
$ pin -t inscount0 -o out -- ./crackme ; cat out
root@localhost's password: b
Permission denied (password).
Count 716328
$ pin -t inscount0 -o out -- ./crackme ; cat out
root@localhost's password: c
Permission denied (password).
Count 716835
$ bc -lq
716328 -715821
507
716835 - 716328
507
</code></pre>

使用所有可见字符，最后得到的测试结果如下：
<pre><code>$ python bf.py 
Input [!] -> [717933] delta [507]
Input ["] -> [718440] delta [507]
Input [#] -> [718947] delta [507]
Input [$] -> [719454] delta [507]
Input [%] -> [719961] delta [507]
Input [&] -> [720468] delta [507]
Input ['] -> [720975] delta [507]
Input [(] -> [721482] delta [507]
Input [)] -> [721989] delta [507]
Input [*] -> [722496] delta [507]
Input [+] -> [723003] delta [507]
Input [,] -> [723510] delta [507]
Input [-] -> [724017] delta [507]
Input [.] -> [724524] delta [507]
Input [/] -> [725031] delta [507]
Input [0] -> [725538] delta [507]
Input [1] -> [726045] delta [507]
Input [2] -> [726552] delta [507]
Input [3] -> [727059] delta [507]
Input [4] -> [727566] delta [507]
Input [5] -> [728073] delta [507]
Input [6] -> [728580] delta [507]
Input [7] -> [729087] delta [507]
Input [8] -> [729594] delta [507]
Input [9] -> [730101] delta [507]
Input [:] -> [730608] delta [507]
Input [;] -> [731115] delta [507]
Input [<] -> [731622] delta [507]
Input [=] -> [732129] delta [507]
Input [>] -> [732636] delta [507]
Input [?] -> [733143] delta [507]
Input [@] -> [733650] delta [507]
Input [A] -> [734157] delta [507]
Input [B] -> [734664] delta [507]
Input [C] -> [735171] delta [507]
Input [D] -> [735678] delta [507]
Input [E] -> [736185] delta [507]
Input [F] -> [736692] delta [507]
Input [G] -> [737199] delta [507]
Input [H] -> [701989] delta [-35210]
Input [I] -> [703653] delta [1664]
Input [J] -> [704160] delta [507]
Input [K] -> [704667] delta [507]
Input [L] -> [705174] delta [507]
Input [M] -> [705681] delta [507]
Input [N] -> [706188] delta [507]
Input [O] -> [706695] delta [507]
Input [P] -> [707202] delta [507]
Input [Q] -> [707709] delta [507]
Input [R] -> [708216] delta [507]
Input [S] -> [708723] delta [507]
Input [T] -> [709230] delta [507]
Input [U] -> [709737] delta [507]
Input [V] -> [710244] delta [507]
Input [W] -> [710751] delta [507]
Input [X] -> [711258] delta [507]
Input [Y] -> [711765] delta [507]
Input [Z] -> [712272] delta [507]
Input [[] -> [712779] delta [507]
Input [\] -> [713286] delta [507]
Input []] -> [713793] delta [507]
Input [^] -> [714300] delta [507]
Input [_] -> [714807] delta [507]
Input [`] -> [715314] delta [507]
Input [a] -> [715821] delta [507]
Input [b] -> [716328] delta [507]
Input [c] -> [716835] delta [507]
Input [d] -> [717342] delta [507]
Input [e] -> [717849] delta [507]
Input [f] -> [718356] delta [507]
Input [g] -> [718863] delta [507]
Input [h] -> [719370] delta [507]
Input [i] -> [719877] delta [507]
Input [j] -> [720384] delta [507]
Input [k] -> [720891] delta [507]
Input [l] -> [721398] delta [507]
Input [m] -> [721905] delta [507]
Input [n] -> [722412] delta [507]
Input [o] -> [722919] delta [507]
Input [p] -> [723426] delta [507]
Input [q] -> [723933] delta [507]
Input [r] -> [724440] delta [507]
Input [s] -> [724947] delta [507]
Input [t] -> [725454] delta [507]
Input [u] -> [725961] delta [507]
Input [v] -> [726468] delta [507]
Input [w] -> [726975] delta [507]
Input [x] -> [727482] delta [507]
Input [y] -> [727989] delta [507]
Input [z] -> [728496] delta [507]
Input [{] -> [729003] delta [507]
Input [|] -> [729510] delta [507]
Input [}] -> [730017] delta [507]
Input [~] -> [730524] delta [507]
</code></pre>

于是得到首字母为H

我们使用下面的脚本进行测试，得到结果：
<pre><code>#!/usr/bin/python
import os, pexpect, time
from subprocess import Popen,PIPE

pinpath="/ctf/TOOLS/pin/pin"

def try_list(lst):
    procs = {}
	ret_dict = {}
    for (idx, s) in enumerate(lst):
		out_file = s.encode('hex')
        p = Popen([pinpath, "-t", "inscount0", "-o", "tmp/" + out_file, "--", "./crackme"], stdout = PIPE, stdin = PIPE)
        procs[s] = p
		p.stdin.write(s + "\n")

	prev = 0
	show_delta = False
	delta = {}
    for (idx,s) in enumerate(lst):
        while procs[s].poll() is None:
            time.sleep(0.5)
		if "denied" not in procs[s].stdout.read():
			print "Output different for password [%s]" % s
			exit(-1)
		out_file = s.encode('hex')
        output = open("tmp/" + out_file).read().split(" ")[1].strip()
		instr_count = int(output)
		if show_delta:
	        #print "Input [%s] -> [%s] delta [%s]" % (s, instr_count, instr_count - prev)
			delta[s] = instr_count - prev
		else:
			show_delta = True
		prev = instr_count

	for (idx,s) in enumerate(lst):
		if idx < 2:
			continue
		if delta[s] != delta[lst[idx-1]]:
			return s

prefix = ""
while True:
	lst = [prefix + chr(i) for i in range(32,127)]
	prefix = try_list(lst)
	print "Trying input -> %s" % prefix

</code></pre>

#### 3. 逆向小技巧

* 快速找main入口
	* 寻找一个<font color=#f00>大跳转</font>
* 快速定位关键位置
	* 从Function List靠前位置开始乱翻
		* 编译时不同源文件会被分别编译为.o，再由编译器合并
		* 编译命令行中标准库一般在最前面
	* 从main函数旁边翻
* 应对MFC程序
	* 使用xspy工具查看消息处理函数
		* 将xspy上的放大镜拖到感兴趣的函数（如OnClick、OnCommand等
* 手动加载Signature
	* 碰到无法自动识别库函数时
		* Shift+F5: View -> Open Subviews -> Signatures (注意要选择好Library，如果使用mfc，就应该选择vc32mfc文件)
		* Shift+F11: View -> Open Subviews -> Type Libraries
* 如何得知MessageBox弹框后，程序在哪继续进行
	* 在OD或x64dbg中找到内存布局列表
    	* OD：<font color=#f00>Alt+M</font> -> 内存
    	* x64dbg：在窗口栏点击<font color=#f00>内存布局</font>
	* 找到自己程序的代码段（通常是本程序的.text，按F2，<font color=#f00>设置区断点</font>）
	* 返回程序点击确定即可


