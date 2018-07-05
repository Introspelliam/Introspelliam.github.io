---
title: XMAN之旅——Android
date: 2017-08-11 08:47:57
categories: xman
tags: 
---


### 1. 赵帅讲android基础

#### 1.1 APK的文件结构

**重要的标签及属性**
* Minsdklevel
* Targetsdklevel
* android:enable
* android:export
* Android:process
* Browerable

**jar包和apk包**


#### 1.2 常见的基本类型

反编译采用的是dalvik字节码，反编译之后成为smali文件。

dalvik字节码有两种类型，原始类型和引用类型。对象和数组是引用类型，其它都是原始类型。

smali数据类型都是用一个字母表示，如果你熟悉Java的数据类型，你会发现表示smali数据类型的字母其实是Java基本数据类型首字母的大写，除boolean类型外，在smail中用大写的”Z”表示boolean类型。

|标识|类型|
|--|--|
|V	|void，只能用于返回值类型|
|Z	|boolean|
|B	|byte|
|S	|short|
|C	|char|
|I	|int|
|J	|long (64 bits)|
|F	|float|
|D	|double (64 bits)|
|L	|对象类型|
|[	|数据类型|

对象以Lpackage/name/ObjectName;的形式表示。前面的L表示这是一个对象类型，package/name/是该对象所在的包，ObjectName是对象的名字，“;”表示对象名称的结束。相当于java中的package.name.ObjectName。

**类的表示形式**
> Ljava/lang/String;相当于java.lang.String

**数组的表示形式**
> \[ 表示一个整型一维数组，相当于java中的int[]
> 对于多维数组，只要增加\[就行了。\[\[I相当于int\[]\[]，\[\[\[I相当于int\[]\[]\[]。注意每一维的最多255个。

**对象数组的表示**
> [Ljava/lang/String;表示一个String对象数组。

**方法表示形式**

方法通常必须详细的指定方法类型: 方法名，参数类型，返回类型，所有这些信息都是为虚拟机是能够找到正确的方法并执行。

> Lpackage/name/ObjectName;->MethodName(III)Z

在上面的例子中，Lpackage/name/ObjectName;表示类，MethodName是方法名。III为参数（在此是3个整型参数），Z是返回类型（bool型）。方法的参数是一个接一个的，中间没有隔开。

>一个更复杂的例子：method(I[[IILjava/lang/String;[Ljava/lang/Object;)Ljava/lang/String;

在java中则为：String method(int, int[][], int, String, Object[])

#### 1.3 Dalvik Code

掌握以上的字段和方法的描述,只能说我们懂了如何描述一个字段和方法,而关于方法中具体的逻辑则需要了解Dalvik中的指令集.因为Dalvik是基于寄存器的架构的,因此指令集和JVM中的指令集区别较大,反而更类似x86的中的汇编指令.

[Davilk指令集大全](http://pallergabor.uw.hu/androidblog/dalvik_opcodes.html)

#### 1.3 ELF

可以链接第三方库，可以解决历史代码问题，可以进行逻辑保护，一般用so文件表示。

#### 1.4 常见组件

**[组件一：Intent](http://www.cnblogs.com/shen-hua/p/5811195.html)**
* Action
* Component
* Category
* data

> Android中提供了Intent机制来协助应用间的交互与通讯，或者采用更准确的说法是，Intent不仅可用于应用程序之间，也可用于应用程序内部的activity, service和broadcast receiver之间的交互。Intent这个英语单词的本意是“目的、意向、意图”。
> 
>Intent是一种运行时绑定（runtime binding)机制，它能在程序运行的过程中连接两个不同的组件。通过Intent，你的程序可以向Android表达某种请求或者意愿，Android会根据意愿的内容选择适当的组件来响应。

![组件详情](/images/2017-08-11/Intent.png)

**组件二：Service**
* onStart
* onStartCommand
* Exported
* Android:process

**组件三：Activity**

**组件四：Webview**
* setSavePassword
* setJavascriptEnabled
* addJavascriptInterface
* Loadurl

**组件五：PendingIntent**
* Notification
* getActivity
* getService
* getBroadcast

#### 1.5 运行时的目录结构

私有目录
* /data/data/packagename

sdcard


#### 1.6 工具

**反编译工具**
* Dex2jar
* jd-gui	——jar包反编译
* jadx		——Apk反编译
* jeb		——Apk解包、反汇编、反编译

**其他工具**
* Burpsuite
* Akana
* Janus

#### 1.7 ctf中常用的方法

**HOOK**
* 代码分析
* 目标方法筛选
* 编写脚本
* 运行测试

**重打包**
* 解包  apktool d
* 修改
* 打包  apktool b
* 签名

#### 1.8 工业界漏洞

**组件暴露相关信息**
* Enabled  => true
* exported  => false   (有intent-filter，默认值就是true)   关键
* Action => 系统Action 非系统Action
* Permission											关键
* ContentProvider

**攻击窗口**
* 动态注册
* 窗口期

**组件劫持**
* Activity劫持
* Receiver劫持
* Service劫持
* intent嗅探

**Webview组件问题**
* 远程代码执行



