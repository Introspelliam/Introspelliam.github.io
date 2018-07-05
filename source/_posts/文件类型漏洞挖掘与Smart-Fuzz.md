---
title: 文件类型漏洞挖掘与Smart Fuzz
date: 2017-07-28 22:25:03
categories: 安全技术
tags: fuzz
---

### 1. Smart Fuzz

#### 1.1 文件格式Fuzz的基本方法

不管IE还是Office，都有一个共同点，就是用文件作为程序的主要输入。从本质上讲，这些软件都是按照事先约定好的数据结构对文件中不同的数据域进行解析，以决定用什么颜色、在什么位置显示这些数据。

文件格式Fuzz（File Fuzz）就是利用“畸形文件”测试软件鲁棒性的方法。

File Fuzz工具的工作流程大体如下：
1. 以正常的文件模板为基础，按照一定规则生成一批畸形文件
2. 将畸形文件逐一送入软件进行解析，并监视软件是否会抛出异常
3. 记录软件产生的错误星系，如寄存器状态、栈状态等
4. 用日志或其他UI形式向测试人员展示异常信息，以进一步鉴定这些错误是否能被利用

![File Fuzz的一般步骤](/images/2017-07-28/file_fuzz.jpg)

#### 1.2 Blind Fuzz和Smart Fuzz

Blind Fuzz就是“盲测”，也即在随机位置插入随机的数据以生成畸形文件。现代软件往往使用非常复杂的数据结构，而数据结构越复杂，解析逻辑越复杂，就越容易出现漏洞。复杂的数据结构有以下特征：
1. 拥有一批预定义的静态数据，如magic、cmd id等
2. 数据结构的内容是可以动态改变的
3. 数据结构之间是嵌套的 
4. 数据中存在多种数据关系（size of, point to, reference of, CRC）
5. 有意义的数据被编码或压缩，甚至用另一种文件形式来存储。

对于复杂数据结构的复杂文件进行漏洞挖掘，若用Blind Fuzz，则产生测试用例的策略缺少针对性，生成大量无效测试用例，难以发现复杂解析器深层逻辑的漏洞等。

Smart Fuzz的特征：
1. 面向逻辑（Logic Oriented Fuzzing）：目标是解析文件的程序逻辑。即明确测试“深度”以及畸形数据的测试“粒度”。
2. 面向数据类型测试（Data Type Oriented Fuzzing）
    * 算术型，以HEX、ASCII、Unicode、Raw格式存在的各种数值
    * 指针型，Null指针、合法/非法的内存指针等
    * 字符串型，超长字符串、缺少终止符(0x00)的字符串等
    * 特殊字符，#,@,*,<,>,/,\,../等
3. 基于样本（Sample Based Fuzzing）：首先构造合法的样本文件（模板文件），然后以这个文件为模板，每次只改动小部分数据和逻辑来生成畸形文件，这也叫做变异（Mutation）

### 2. 用Peach挖掘文件漏洞

#### 2.1 Peach 介绍与安装

Peach是一款用Python写的开源Smart Fuzz工具，其支持两种文件Fuzz方法：基于生长(Generation Based)和基于变异(Mutation Based)。基于生长的Fuzz方法产生随机或启发性数据来填充给定的数据模型，从而生成畸形文件。基于变异的Fuzz方法在一个给定的样本文件基础上进行修改从而产生畸形文件。

#### 2.2 XML介绍

XML即"Extensible Generalized Markup Language"，可扩展标记性语言；其与HTML一样都是标准通用标记性语言（Standard Generalized Markup Language, SGML）

XML分为文件序言(Prolog)和文件主体两大部分。文件序言为XML第一行，告诉解析器该如何工作（例如：<?xml version="1.0" encoding="utf-8" ?>）。其中version是XML文件所用的标准版本号，必须要有：encoding标明此XML文件的编码类型，如果是Unicode编码时则可以省略。文件主体分为以下几个部分：
1. 元素(Element)：&lt;title&gt; lang="cn"&gt;XML&lt;/title&gt;
2. 标签(Tag)：&lt;tile&gt;
3. 属性(Attribute)：lang就是&lt;title&gt;的属性
4. 根元素(Root Element)：又称文档元素。起始标签
5. 注释(Comment)：&lt;!-- --!&gt;来注释

#### 2.3 定义简单的Peach Pit

Peach Pit文件包括以下5个模块：
1. GeneralConf
2. DataModel
3. StateModel
4. Agents and Monitors
5. Test and Run Configuration

所有元素都包含在根元素&lt;Peach&gt;里
<pre><code>&lt;?xml version="1.0" encoding="utf-8" ?&gt;
&lt;Peach xmlns="http://phed.org/2008/Peach" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://phed.org/2008/Peach ../peach.xsd" version="1.0"&gt;
</code></pre>

上面的Peach元素的各个属性基本上是固定的，不要轻易改动

一、 GeneralConf
GeneralConf是Peach Pit文件的第一部分，用来定义基本配置信息。包括:
	* include: 要包含的其他Peach Pit文件
	* Import：要导入的Python库
	* PythonPath：要添加的python库路径

在HelloWorld中，GeneralConf部分只需写入:
<pre><code>&lt;!-- Import defaults for Peach instance --&gt;
&lt;Include ns="default" src="file:defaults.xml" /&gt;
</code></pre>

二、 DataModel
DataModel用来定义数据模型，包括数据结构和数据关系等。一个Peach Pit文件中需要包含一个或多个数据类型。常见的有:
	* String：属性有name, size, value, isStatic
	* Number：属性有name, size
	* Blob: 无具体数据类型，属性有name
	* Block： 用于对数据进行分组，属性有name

HelloWorld程序中定义的:
<pre><code>&lt;!-- Create a simple data template containing a single string --&gt;
&lt;DataModel name="HelloWorldTemplate"&gt;
        &lt;String value="Hello World!" /&gt;
&lt;/DataModel&gt;
</code></pre>

三、StateModel
StateModel用于描述如何向目标程序发送/接收数据。StateModel由至少一个State组成，并且用initialState指定一个State；每个State由至少一个Action组成，Action用于定义StateModel中的各种动作，动作类型由type来指定。Action支持的动作类型包括start、stop、open、close、input、output、call等。

当代码中有多个Action时，则从上往下依次执行。
<pre><code>&lt;StateModel name="State" initialState="State1" &gt;
        &lt;State name="State1"&gt;
                &lt;Action type="output" &gt;
                        &lt;DataModel ref="HelloWorldTemplate"/&gt;
                &lt;/Action&gt;
        &lt;/State&gt;
&lt;/StateModel&gt;
</code></pre>

四、Agent
Agent用于定义代理和监视器，可以用来调用Windbg等调试器来检测程序运行的错误信息等，一个Peach Pit文件可以定义多个Agent，每个Agent下可以定义多个Monitor。
Monitor类型为debugger.WindowsDebugEngine，是调用Windbg来执行下面的"notepad.exe filename"命令；而若类型为process.PageHeap，则是为notepad.exe开启页堆调试(Page Heap Debug)。

五、Test and Run configuration
Test元素用来定义一个测试的配置，包括一个StateModel和一个Publisher，以及including/execluding、Agent信息等。其中StateModel和Publisher是必须定义的，其他可选。Publisher用来定义Peach的IO连接，可以构造网络数据流(如TCP，UDP，HTTP)和文件流(如FileWriter，FileReader)等

在HelloWorld程序中，需要的是将畸形数据显示到命令行，所以Publisher用的是标准输出stdout.Stdout
<pre><code>&lt;Test name="HelloWorldTest"&gt;
        &lt;StateModel ref="State"/&gt;
        &lt;!-- Display test cases to the console --&gt;
        &lt;Publisher class="stdout.Stdout" /&gt;
&lt;/Test&gt;
</code></pre>


Run元素用来定义要运行哪些测试，包括一个或多个Test，另外还可以通过Logger元素配置日志来捕获运行结果。当然，Logger是可选的

HelloWorld程序中，run配置如下：
<pre><code>&lt;!-- Configure a single run --&gt;
&lt;Run name="DefaultRun" description="Stdout HelloWorld Run"&gt;

        &lt;Test ref="HelloWorldTest" /&gt;

&lt;/Run&gt;
</code></pre>


#### 2.4 定义数据之间的依存关系

在Peach Pit中可以用Relation元素来表示数据长度、数据个数以及数据偏移等信息。格式如下:
<pre><code>&lt;Relation type="size" of="Data" /&gt;
&lt;Relation type="count" of="Data" /&gt;
&lt;Relation type="offset" of="Data" /&gt;
</code></pre>

同样，数据校验值也可以通过Fixup来表示。Fixup支持的校验类型包括CRC32、MD5、SHA1、SHA256、EthernetChecksum、SspiAuthentication等，这可参考官方文档。Fixup格式如下:
<pre><code>&lt;Fixup class="FixupClass"&gt;
    &lt;Param name="ref" value="Data" /&gt;
&lt;/Fixup&gt;
</code></pre>

FixupClass可以为checksum.Crc32Fixup、checksum.SHA256Fixup等。

Crc32Fixup数据模型示例:

|Offset|Size|Description|
|--|--|--|
|0x00|4 bytes|Length of Data|
|0x04|4 bytes|Type|
|0x08|Data|
|after data|4 bytes|CRC of Type and Data|

上面数据模型的实现:
<pre><code>&lt;DataModel name="HelloData"&gt;
&lt;Number name="Length" size="32"&gt;
    &lt;Relation type="size" of="Data"/&gt;
&lt;/Number&gt;
&lt;Block name="TypeAndData"&gt;
    &lt;String name="Type" size="32" /&gt;
    &lt;Blob name="Data"/&gt;
&lt;/Block&gt;
&lt;Number name="CRC" size="32"&gt;
    &lt;Fixup class="checksums.Crc32Fixup"&gt;
        &lt;Param name="ref" value="TypeAndData" /&gt;
    &lt;/Fixup&gt;
&lt;/Number&gt;
&lt;/DataModel&gt;
</code></pre>

#### 2.5 用Peach Fuzz PNG文件

首先看看png图片的格式，如图所示:
![png文件格式](/images/2017-07-28/png.jpg)

png最前面是8字节PNG签名，十六进制为89 50 4E 0D 0A 1A 0A。随后是若干个数据区块(Chunk)，包括IDHR、IDAT、IEND等。

png文件Chunk格式

|Name|Size|Description|
|--|--|--|
|Length|4 bytes|Length of data field|
|Type|4 bytes|Chunk type code|
|Data||Data Bytes|
|CRC|4 bytes|CRC of type and data|

可以将Chunk的DataModel定义如下:
<pre><code>&lt;DataModel name="Chunk"&gt;
&lt;Number name="Length" size="32" signed="false"&gt;
    &lt;Relation type="size" of="Data"/&gt;
&lt;/Number&gt;
&lt;Block name="TypeAndData"&gt;
    &lt;String name="Type" size="4" /&gt;
    &lt;Blob name="Data" /&gt;
&lt;/Block&gt;
&lt;Number name="CRC" size="32"&gt;
    &lt;Fixup class="checksums.Crc32Fixup"&gt;
        &lt;Param name="ref" value="TypeAndData" /&gt;
    &lt;/Fixup&gt;
&lt;/Number&gt;
&lt;/DataModel&gt;
</code></pre>

PNG简单地认为是由一个PNG签名和若干个结构相同的Chunk组成。在Chunk数据模型之后将PNG文件的DataModel进行如下定义：
<pre><code>&lt;DataModel name="Png"&gt;
&lt;Blob name="pngMagic" isStatic="true" valueTyp="hex" value="89 50 4E 47 0D 0A 1A 0A" /&gt;
&lt;Block ref="Chunk" minOccurs="1" maxOccurs="1024" /&gt;
&lt;/DataModel&gt;
</code></pre>

minOccurs="1" maxOccurs="1024"表示该区块最少重复1次，最多重复1024次

然后配置StateModel:第一步修改文件生成畸形文件；第二部需要把文件关闭；第三步需要调用适当的程序打开生成的畸形文件（这里使用pngcheck）。
<pre><code>&lt;StateModel name="TheState" initialState="Initial"&gt;
    &lt;State name="Initial"&gt;
        &lt;!-- Write out our png file --&gt;
        &lt;Action type="output"&gt;
            &lt;DataModel ref="Png" /&gt;
            &lt;!-- This is our sample file to read in --&gt;
            &lt;Data name="data" fileName="sample.png" /&gt;
        &lt;/Action&gt;
    &lt;/State&gt;

    &lt;!-- Close file --&gt;
    &lt;Action type="close"/&gt;

    &lt;!-- Launch the target process --&gt;
    &lt;Action type="call" method="D:\tweakpng.exe"&gt;
        &lt;Param name="png file" type="in"&gt;
            &lt;DataModel ref="Param" /&gt;
            &lt;Data name="fileName"&gt;
                &lt;!-- Name of Fuzzed output file --&gt;
                &lt;Field name="Value" value="peach.png" /&gt;
            &lt;/Data&gt;
        &lt;/Param&gt;
    &lt;/Action&gt;
&lt;/StateModel&gt;
</code></pre>

在call动作中我们引入了"Param"的数据类型，这个数据模型用来存放传达给pngcheck.exe/tweakpng.exe的参数，即畸形文件的文件名。所以"Param"需要包含一个名为"Value"的字符型静态数据。
所以需要在StateModel之前定义该数据模型:
<pre><code>&lt;DataModel name="Param"&gt;
    &lt;String name="Value" isStatic="true" /&gt;
&lt;/DataModel&gt;
</code></pre>

然后在Test元素中配置Publisher信息。这里需要FileWriterLauncher，它能在写完文件后使用call动作启用一个线程。
<pre><code>&lt;Test name="TheTest"&gt;
    &lt;StateModel ref="TheState"/&gt;
    &lt;Publisher class="file.FileWriterLauncher"&gt;
        &lt;Param name="filename" value="peach.png" /&gt;
    &lt;/Publisher&gt;
&lt;/Test&gt;
</code></pre>

最后在Run信息配置中指定要运行的测试名称
<pre><code>&lt;Run name="DefaultRun"&gt;
    &lt;Test ref="TheTest" /&gt;
&lt;/Run&gt;
</code></pre>

接下来对png_dumb.xml进行一些改动，让程序调用windows资源管理器打开畸形文件。
首先，在StateModel的Action中将tweakpng.exe程序替换为"explorer"
然后，在Publisher配置中将class改为file.FileWriterLauncherGui，并且为Publisher增加一个名为WindowName、值为peach.png的参数

FileWriterLauncherGui与FileWriterLauncher的区别:前者用于运行带界面的GUI程序，并且在运行后会自动关闭窗口标题中含有WindowName的值的GUI窗口。

为了捕获程序的异常，还需配置Agent and Monitor，调用WinDbg进行测试。

首先将StateModel中最后一个Action删掉，并添加这一行
<pre><code>&lt;Action type="call" method="ScoobySnacks" /&gt;
</code></pre>

然后在StateModel下面加入Agent配置

<pre><code>&lt;Agent name="LocalAgent"&gt;
    &lt;Monitor class="debugger.WindowsDebugEngine"&gt;
        &lt;Param name="CommandLine" value="explorer peach.png"/&gt;
        &lt;Param name="StartOnCall" value="ScoobySnacks" /&gt;
    &lt;/Monitor&gt;

    &lt;Monitor class="process.PageHeap"&gt;
        &lt;Param name="Executable" value="explorer" /&gt;
    &lt;/Monitor&gt;
&lt;/Agent&gt;
</code></pre>

然后在Test配置的第一行加入:
<pre><code>&lt;Agent ref="LocalAgent" /&gt;
</code></pre>

并且在Publisher的最后一行加入名为debugger，值为true的参数
<pre><code>&lt;Param name="debugger" value="true" /&gt;
</code></pre>

最后在Run配置的Test元素后面加入日志配置:
<pre><code>&lt;Logger class="logger.Filesystem"&gt;
    &lt;Param name="path" value="logs" /&gt;
&lt;/Logger&gt;
</code></pre>

重新运行Fuzzer，实验效果是Fuzzer程序启动了一个Local Peach Agent，通过该Agent控制WinDbg进行调试并捕获异常事件。

<font color=#f00>
本次实验其实很简单，但是环境一定得按照要求来。
windbg 版本为 6.8，是否是x86，抑或是amd64，得与python安装版本一致；
python 版本为2.5+，一定是版本2
peach 版本为v2.3。该版本能与windbg 6.8兼容，但是不能与6.12兼容。
</font>

### 3. 010脚本

#### 3.1 010 Editor简介

010 Editor是文本/十六进制编辑器，还包括文件解析、计算器、文本比较等功能。其可以通过官方网站提供的脚本(Binary Template)对avi、bmp、png、exe等简单格式的文件进行解析，当然也可以根据需求来自己编写文件解析脚本。

以PNG文件解析为例：用010 Editor打开PNG文件，然后通过Templates->Open Template菜单打开PNGTemplate.bt，按F5键运行脚本，在窗口中选择该PNG文件，就可以看到解析结果。

#### 3.2 010脚本编写入门

010 Editor分析脚本与C/C++的结构体定义比较类似。但是其是一个自上而下执行的程序，可以使用if、for、while等语句。

<pre><code>char header[4];
int numRecords;
</code></pre>

意味着文件 首4个字节将会映射到字符数组header中，下4个字节则会映射到整型变量numRecords中，并最终显示在解析结果中。
但是也可能有这种情况：需要定义一些变量，但是这些变量并不对应着文件中的任何字节，而仅仅是程序运行中所需要的，这时可用哪个local关键字来定义变量。
<pre><code>local int i, total=0;
int RecordCounts[5];
for(i=0; i&lt;5; i++)
	total += recordCounts[i];
double records[total];
</code></pre>

另外在数据的定义中，可以加上一些附加属性，如格式、颜色、注释等。附加属性用尖括号&lt;&gt;括起来。常用的属性包括：
<pre><code>&lt;format=hex|decimal|octal|binary, fgcolor=&lt;color&gt;, bgcolor=&lt;color&gt;, comment="&lt;string&gt;", open=true|false|suppress, hidden=true|false, read=&lt;function_name&gt;, write=&lt;function_name&gt; &gt;
</code></pre>

实例：
文件格式示例如图所示:
![文件格式](/images/2017-07-28/file_structure.jpg)
脚本如下：
<pre><code>struct FILE{
    struct HEADER{
        char type[4];
        int version;
        int numRecords;
    } header;

    struct RECORD{
        int len;
        char name[20];
        if(file.header.version == 1)
            char data[len];
        if(file.header.version == 2)
            byte data[len];
    } record[file.header.numRecords];

} file;
</code></pre>

#### 3.3 010脚本编写提高——PNG文件解析

首先定义PNG签名和Chunk两种结构，PNG文件签名：
<pre><code>const uint64 PNGMAGIC = 0x89504E470D0A1A0AL;
</code></pre>

然后是PNG的Chunk格式:
<pre><code>typedef struct{
    uint32 length;
    char ctype[4];
    ubyte data[length];
    uint32 crc &lt;format=hex&gt;;
} CHUNK
</code></pre>

还需定义CHUNK结构体的read函数，以便在显示解析结果时能够给出每个Chunk的名字，显然ctype的值可以作为Chunk的名字。在ctype中，每个字节的第三位还分别标识了该Chunk的一些附加信息：

|位置|1|0|
|--|--|--|
|第1字节的第3位|Ancillary|Critical|
|第2字节的第3位|Private|Public|
|第3字节的第3位|ERROR_RESERVED||
|第4字节的第3位|Safe to Copy|UnSafe to Copy|

说明:
* Ancillary标识该区块是辅助区块，该区块可有可无；Critical表示该区块是关键区块，这些区块是必须的
* Private表示该区块是不在PNG标准规格(PNG specification)区块中，属于该PNG文件私有，其名称的第二个字母是小写；Public表示该区块属于PNG标准区块，其名称的第二个字母是大写。
* Safe to Copy表示该区块与图像数据无关，可以随意复制到改动过的PNG文件中；Unsafe to Copy表示该区块内容与图像数据息息相关，如果对文件的Critical区块进行了增删改等操作，则该区块也需要进行相应的修改

于是CHUNK结构定义如下函数：
<pre><code>string readCHUNK(local CHUNK &c){
    local string s;
    s = c.ctype + "  (";
    s += (c.ctype[0] & 0x20) ? "Ancillary, " : "Critical, ";
    s += (c.ctype[1] & 0x20) ? "Private, "   : "Public, ";
    s += (c.ctype[2] & 0x20) ? "ERROR_RESERVED, " : "";
    s += (c.ctype[3] & 0x20) ? "Safe to Copy)" : "Unsafe to Copy)";
    return s;
}
</code></pre>

同时在定义好的CHUNK结构体后加上read属性，即把“} CHUNK;”改为:
<pre><code>} CHUNK &lt;read=readCHUNK&gt;
</code></pre>

最后写入解析"主函数":
<pre><code>uint64 pngid &lt;format=hex&gt;;

if(pngid != PNGMAGIC){
    Warning("Invalid PNG File: Bad Magic Number");
    return -1;
}

while(!FEof()){
    CHUNK chunk;
}
</code></pre>

另外，由于PNG文件是按照BigEndian格式进行存储的，所以需要在脚本的第一行加入:
<pre><code>BigEndian();
</code></pre>

<b>漏洞</b>

实验环境
操作系统： Win XP SP3
GdiPlus.dll版本： 5.1.3102.5512

在之前的PNG解析结果中找到IHDR Chunk的length位置，也就是第9-12字节，通常情况下其值为13(0x0D)，现在换成0xFFFFFFF4，并将文件另存为poc.png。
在实验环境下打开poc.png，打开资源管理器，会发现explorer.exe的CPU占用率升至100%，使系统接近宕机状态，只有强行结束或者重启explorer.exe进程才能使系统恢复正常。

实际上gdiplus.dll在处理IHDR时存在整数溢出漏洞。该漏洞的危害：
1. 打开poc.png或者打开poc.png所在文件夹的未打补丁的用户死机
2. 将poc.png挂载某网页上，访问该页面的未打补丁用户死机
3. 设为QQ或MSN头像，查看头像的未打补丁用户死机

#### 3.4 PPT文件解析

office系列软件使用的文件格式分为两个：
Office97~Office2003：使用基于二进制的文件格式，文件名后缀为doc、ppt、xls等
Office2003及更高版本：使用基于XML的文件格式，文件名后缀为docx、pptx、xlsx等。

本节以PowerPoint97~2003所用的二进制文件格式，PPT文件的解析过程从逻辑上分为如下四层：

|测试深度|解析逻辑|数据粒度|Fuzz方法|
|--|--|--|--|
|Level1|OLE2 解析器|离散分布的512字节数据段|修改OLE文件头、FAT区块、目录区块等位置的数据结构|
|Level2|PPT 记录解析器|流和信息库|修改流中的数据，破坏记录头和数据的关系|
|Level3|PPT 对象创建器|原子和容器|用负载替换原子数据|
|Level4|PPT 对象内部逻辑|原子记录内部的integer、bool、string等类型数据|用相关的负载修改字节数据|


