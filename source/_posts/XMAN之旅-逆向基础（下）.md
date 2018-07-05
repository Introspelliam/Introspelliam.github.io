---
title: XMAN之旅_逆向基础（下）
date: 2017-08-03 00:07:08
categories: xman
tags: [调试, 汇编]
---


### 三、 CTF逆向与现实逆向

* CTF逆向特点
	* 代码量小
	* 结构简单
		* 单文件
	* 编码单一
	* 现代语言特性少
		* 面向过程
	* 加密壳/优化少
	* 语言常见
		* C/C++/ASM

* 现实逆向
	* 代码量巨大
	* 结构复杂
		* 大量静态库、动态库
	* 各种乱码
	* 大量现代语言特性
		* OO、Template
	* 优化和加密壳十分常见
	* 语言可能十分神器
		* Go/VB/Delphi

### 四、IDA高级使用

#### 1. 设置字符串编码和格式

* 快捷键：<font color=#f00>Alt+A</font>
* 可以设置字符串类型
	* Unicode字符串 （WCS）
	* 多字节字符串 （MBS）
	* 其他
* 可以设置字符串编码
	* 需要系统支持相应的编码

#### 2. 导入/导出数据

* 快捷键：<font color=#f00>Shift+E</font>
* 菜单名：
	* Edit -> Import Data
	* Edit -> Export Data
* 操作：
	* 选定后按快捷键
* 方便提取数据或修改idb数据库

#### 3. 选定大段数据

* 快捷键： <font color=#f00>Alt+L</font>
* * 菜单名：
	* Edit -> Begin Selection
* 将标定选择起始点
* 滚轮或按g跳转至结束位置

#### 4. 批量应用类型

* 操作
	* 设置好第一个类型
	* 利用选定大量数据的方法选定数据
	* 按*或按d弹出建立数组对话框
	* <font color=#f0f>不勾选Create as array</font>

#### 5. 设置间接跳转地址

* 快捷键：<font color=#f00>Alt+F11</font>
* 菜单名：
	* Edit -> Plugins -> Change the callee address 
* 将利用动态调试获取到的调用/跳转地址填入，可以极大地帮助IDA和F5的分析（不如参数个数、调用约定等），获得更准确的结果

#### 6. 修复跳转表

* 默认无快捷键，可手动设置
* 菜单
	* Edit -> Other -> Specify switch idiom
* 当程序在PIE时可能会导致<font color=#f00>跳转表分析失败</font>，于是需要手动修复来获得更好的分析结果

#### 7. IDAPython

* IDA自带支持的脚本
* 可以使用几乎所有IDA提供的API
* 可以快速完成大量重复性操作
* 可以方便的了解IDA内部的数据和结构

### 五、IDA F5出错处理

#### 1. positive sp value

* 成因：IDA会自动分析SP寄存器的变化量，由于缺少调用约定、参数个数等信息，导致分析出错
* 解决方案
	* 推荐：在<font color=#f00>Option -> General设置显示Stack pointer</font>，然后去检查对应地址附近调用的函数的调用约定以及栈指针变化
	* 不推荐： 在对应地址处按<font color=#f00>Alt+K</font>，然后输入一个较大的负值（有风险）

#### 2. call analysis failed

* 成因：F5在分析调用时，未能成功解析<font color=#f00>参数位置/参数个苏</font>
* 解决方案：
	* 对于间接调用（类似call eax等），可使用之前讲过的<font color=#f0f>设置调用地址</font>的方法解决
	* 对于直接调用，查看<font color=#f0f>调用目标的type</font>是否正确设置。<font color=#f0f>可变参数</font>是引发这种错误的主要原因之一

#### 3. cannot convert to microcode

* 成因：部分指令无法被编译
* 解决方案：
	* 最常见起因是函数中<font color=#f0f>有未设置成指令的数据字节</font>，按c将其设置为指令即可
	* 其次常见的是<font color=#f0f>x86中的rep前缀</font>，比如<font color=#f0f>repxx  jmp</font>等。可以将该指令的<font color=#f0f>第一个字节(repxx前缀的对应位置)patch为0x90 (NOP)</font>

#### 4. stack frame is too big

* 成因：在分析栈帧时，IDA出现异常，导致分析出错
* 解决方案：
	* 找到明显不合常理的stack variable offset，双击进入栈帧界面，<font color=#f0f>按u键删除对应的stack variable</font>
	* 如果是去壳导致的原因，先用OD等软件脱壳
	* 可能由花指令导致，请手动或自动检查并去除花指令
* 非常罕见

#### 5. local variable allocation failed

* 成因： 分析函数时，有部分变量对应的区域<font color=#f0f>发生重叠</font>，多见于ARM平台出现Point、Rect等8字节、16字节、32字节结构
* 解决方案
	* 修改对应参数为多个int
	* 修改ida安装目录下hexrays.cfg中的HO_IGNORE_OVERLAPS

#### 6. F5结果不正确

* 成因：F5会自动删除其认为不可能到达的死代码
* 常见起因是一个函数错误的标注为noretur函数
* 解决方案
	* 进到目前反编译结果，找到<font color=#f0f>最后被调用的函数(被错误分析的函数)，双击进入（迫使HexRays重新分析相应函数）</font>
	* 如果上述方案不成功，那么进到被错误分析的函数，按Tab切换到反汇编界面，按Alt+P进入界面取消函数的Does not return 属性

### 六、IDA F5高级使用

#### 1. 自定义寄存器传参

* 使用IDA中的__usercall和__userpurge调用约定（两个下划线）
* 设置范例
	* int __usercall test&lt;eax&gt; (int al &lt;ebx&gt;);
	* &lt;&gt;中为对应值的位置
	* 第一个&lt;&gt;为返回值位置，注意返回值的位置即使不变也要填写

#### 2. HexRays源码级调试

* 注意
	* F5中显示的变量很可能不是变量原来的值，尤其是寄存器变量，尽量在  值位置断下并查看
	* 对于优化后的代码，F5调试bug很多
	* F5单步不太稳定，在ARM平台可能会跑飞
	* F5的运行至指定位置功能功能不稳定

#### 3. 恢复符号

* 找到程序的旧版本
	* 大量程序早期版本中安全意识薄弱，没有删除符号等各种信息
	* 苹果用户可以在AppAdmin中获取版本应用
* Rizzo匹配
* 看程序自带的String
	* 许多程序自带大量调试信息，从而可以获取符号
* Google搜索源码
	* CS、iOS都有被泄露过
	* 按获得信息搜索源码
		* 大量程序中使用Stack Overflow、CSDN等答案
* 制作Signtature
	* IDA提供自动制作Signature的工具
	* 打开IDASDK68文件夹找到flair 58文件夹

### 七、IDA 插件搞定虚表

#### 1. 虚表简介

虚表是业界难题，虚函数的处理会因编译器采取的ABI的不同而不同

* IDA操作的插件
	* HexraysCodeXplorer
	* hexrays_tool
	* HexRaysPyTools

#### 2. 实验样例

* 快捷键： Shift + F
* 菜单： 右键 -> Deeo Scan Variable
* 操作
	* 在构造函数中执行上述操作、等待扫描完毕
	* 按Alt+F8打开Signature Builder，看到有黄色部分，然后选不正确的field点
	* 清楚所有的黄色部分后即可点击Finalize，在新弹出的窗口中修改名称