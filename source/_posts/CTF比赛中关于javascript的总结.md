---
title: CTF比赛中关于javascript的总结
date: 2017-11-12 20:06:05
categories: misc
tags: javascript
---

## 前言

在CTF比赛中MISC、CRYPTO、WEB中，经常会遇到有关js方面的题目，这些题目内容很杂，难度不一，所以成套的体系很难总结出来。所以本文只是笔者根据个人经历，总结的一套较为行之有效的工具书！

## 技术介绍

### 0x2.1 JavaScript简介

JavaScript一种动态类型、弱类型、基于原型的客户端脚本语言，用来给HTML网页增加动态功能。

> 动态：在运行时确定数据类型。变量使用之前不需要类型声明，通常变量的类型是被赋值的那个值的类型。
>
> 弱类：计算时可以不同类型之间对使用者透明地隐式转换，即使类型不正确，也能通过隐式转换来得到正确的类型。
>
> 原型：新对象继承对象（作为模版），将自身的属性共享给新对象，模版对象称为原型。这样新对象实例化后不但可以享有自己创建时和运行时定义的属性，而且可以享有原型对象的属性。

PS：新对象指函数，模版对象是实例对象，实例对象是不能继承原型的，函数才可以的。

### 0x2.2 JavaScript组成部分

#### 0x2.2.1 ECMAScript（核心）

作为核心，它规定了语言的组成部分：语法、类型、语句、关键字、保留字、操作符、对象。

具体参考es6  [http://es6.ruanyifeng.com/](http://es6.ruanyifeng.com/)

如果想查看每种浏览器的兼容性情况，可以参考以下博客

es5兼容性： http://kangax.github.io/compat-table/es5/

es6兼容性： http://kangax.github.io/compat-table/es6/

#### 0x2.2.2 DOM（文档对象模型）

DOM把整个页面映射为一个多层节点结果，开发人员可借助DOM提供的API，轻松地删除、添加、替换或修改任何节点。

#### 0x2.2.3 BOM （浏览器对象模型）

支持可以访问和操作浏览器窗口的浏览器对象模型，开发人员可以控制浏览器显示的页面以外的部分。

### 0x2.3 javascript中部分常见的书写方式

说实在的，很多小伙伴表示javascript的表达方式太多了，而且其中有太多不为人知的利用策略。所以熊师傅给出一种套路，翻看工具书，上面已经给出了es6的参考博客！

#### 0x2.3.1 对象的变量或函数

```javascript
> var s = "class";
> s.length	// 等价于 s["length"]
5
> s.substr(2,2)		// 等价于 s["substr"](2,2)
as
```

这里说明了javascript中对象访问属性有两种方法

obj.paramName，使用.访问

obj[parameName]，使用中括号属性名访问

#### 0x2.3.2 类和函数的定义与使用

1. 构造函数法定义类

   ```javascript
   function Cat() {
   	this.name = "大毛";
   }
   // 类的属性和方法
   Cat.prototype.makeSound = function(){
   	alert("喵喵喵");
   }

   var cat1 = new Cat();
   alert(cat1.name); // 大毛
   ```

2. Object.create()法

   ```javascript
   var Cat = {
   	name: "大毛",
   	makeSound: function(){ alert("喵喵喵"); }
   };

   var cat1 = Object.create(Cat);
   alert(cat1.name); // 大毛
   cat1.makeSound(); // 喵喵喵
   ```

   ```javascript
   // 兼容性考虑, 自己定义一个create函数
   if (!Object.create) {
   	Object.create = function (o) {
   		function F() {}
   		F.prototype = o;
   		return new F();
   	};
   }
   ```

3. 极简主义法（用得最多）

   ```javascript
   var Cat = {
   	createNew: function(){		// createNew为构造函数，定义一个实例对象，把实例对象作为返回值
   		var cat = {};
   		cat.name = "大毛";
   		cat.makeSound = function(){ alert("喵喵喵"); };
   		return cat;
   	}
   };

   var cat1 = Cat.createNew();
   cat1.makeSound(); // 喵喵喵
   ```

   ```javascript
   // 此处演示的是继承
   var Animal = {
   	createNew: function(){
   		var animal = {};
   		animal.sleep = function(){ alert("睡懒觉"); };
   		return animal;
   	}
   };

   var Cat = {
   	createNew: function(){
   		var cat = Animal.createNew();
   		cat.name = "大毛";
   		cat.makeSound = function(){ alert("喵喵喵"); };
   		return cat;
   	}
   };

   var cat1 = Cat.createNew();
   cat1.sleep(); // 睡懒觉
   ```

## CTF实践

### 0x3.1 js压缩与解压缩

#### 0x3.1.1 js压缩

压缩js文件可以减少文件体积方便传输，还可以让别人看不懂。

简单的压缩一般是：删除注释和空白符，替换变量名。

更激进点的做法还包括：删除无用代码，内联函数，等价语句替换等。 

开始压缩的时候必须要做到以下几点：

> 1. 压缩前的代码格式要标准。因为去掉换行与空格时，所有语句就变成一行了，如果你的代码有瑕疵（比如某行少了个分号），那就会导致整个文件报错。当然，现在有的压缩工具已经比较智能了。
> 2. 备份原文件
> 3. 压缩很可能不会一次成功，一般要多试，多改

压缩js的工具，常见的有：[YUI Compressor](http://ganquan.info/yui/)、[UglifyJS](https://tool.css-js.com/)、[Google Closure Compiler]((http://closure-compiler.appspot.com/)) 、[JSMin](https://tool.css-js.com/)等。

#### 0x3.1.2 js解压缩

那么既然能压缩，那也应该能够解压缩，但是需要注意的是，如果按照上面给的标准，我们无法实现完全的解压缩，但是可以还原出一个多行且具有鲜明的层次化结构的js代码。

js解压缩的工具有：chrome开发者模式支持解压缩

​			菜鸟工具  [https://c.runoob.com/front-end/51](https://c.runoob.com/front-end/51)

​			Chinaz	[http://tool.chinaz.com/js.aspx](http://tool.chinaz.com/js.aspx)

​			tool.lu在线工具	[http://tool.lu/js/](http://tool.lu/js/)

​			CSS-JS	[https://tool.css-js.com/](https://tool.css-js.com/)

### 0x3.2 js加密与解密

#### 0x3.2.1 escape加密\unescape解密

```javascript
//加密
> escape('alert("黑客防线"); ')
"alert%28%22%u9ED1%u5BA2%u9632%u7EBF%22%29%3B"

//解密
> unescape("alert%28%22%u9ED1%u5BA2%u9632%u7EBF%22%29%3B")
"alert("黑客防线"); "
```

工具   [http://www.haokuwang.com/unescape.htm](http://www.haokuwang.com/unescape.htm)

#### 0x3.2.2 转义字符加解密

转义字符""，对于JavaScript提供了一些特殊字符如：n （换行）、 r （回车）、' （单引号）等应该是有所了解 

的吧？其实""后面还可以跟八进制或十六进制的数字，如字符"a"则可以表示为："141"或"x61"（注意是小写字符"x"），至于双字节字符如汉字"黑"则仅能用十六进制表示为"u9ED1"（注意是小写字符"u"），其中字符"u"表示是双字节字符，根据这个原理例子代码则可以表示为： 

八进制转义字符串如下: 

```javascript
// 使用console.log 或者 alert 或者confirm 或者 prompt调试 或者 document.write
> console.log("\141\154\145\162\164\50\42\u9ED1\u5BA2\u9632\u7EBF\42\51\73")
alert("黑客防线");
```

十六进制转义字符串如下: 

```javascript
> console.log("\x61\x6C\x65\x72\x74\x28\x22\u9ED1\u5BA2\u9632\u7EBF\x22\x29\x3B")
alert("黑客防线");
```

常见工具：	工具包->其他辅助工具->编码转换

​			[http://web2hack.org/xssee/](http://web2hack.org/xssee/)

#### 0x3.2.3 Script Encoder来进行编码 

脚本编码器Script Encoder是Microsoft出品的脚本编码器。这里需要调用控件Scripting.Encoder完成的编码！由于很多电脑上没有安装这个控件，所以很多时候，你的主机运行不起来这个js代码。

```javascript
<SCRIPT LANGUAGE="JavaScript"> 
var Senc=new ActiveXObject("Scripting.Encoder"); 
var code='12345'; 
var Encode=Senc.EncodeScriptFile(".htm",code,0,""); 
alert(Encode); 
</SCRIPT> 
```

编码后的结果如下：

```javascript
<SCRIPT LANGUAGE="JScript.Encode">#@~^BQAAAA==qy&*l/wAAAA==^#~@</SCRIPT> 
```

解密方法

```
<SCRIPT LANGUAGE="JScript.Encode"> 
function decode() 
alert(decode.toString()); 
</SCRIPT> 
```

它是原理是：编码后的代码运行前IE会先对其进行解码，如果我们先把加密的代码放入一个自定义函数如上面的decode()中，然后对自定义函数decode调用toString()方法，得到的将是解码后的代码！ 

如果你觉得这样编码得到的代码LANGUAGE属性是JScript.Encode，很容易让人识破，那么还有一个几乎不为人知的window对象的方法execScript() ，其原形为： window.execScript( sExpression, sLanguage)

ps: 现在的es6中，已经不支持execScript了!!!

参数： 
sExpression: 必选项。字符串(String)。要被执行的代码。 
sLanguage　: 必选项。字符串(String)。指定执行的代码的语言。默认值为 Microsoft JScript 



**工具选择**：

加密工具： srcenc.exe

解密工具：srcdec18-VC8.exe

#### 0x3.2.4  任意添加NUL空字符（十六进制00H） 

一次偶然的实验，使我发现在HTML网页中任意位置添加任意个数的"空字符"，IE照样会正常显示其中的内容，并正常执行其中的JavaScript 代码，而我们在用一般的编辑器查看时，添加的"空字符"会显示形如空格或黑块，使得原码很难看懂，如用记事本查看"空字符"则会变成"空格"，

利用这个原理加密结果如下：（其中显示的"空格"代表"空字符"） 

```javascript
<S C RI P T L ANG U A G E =" J a v a S c r i p t "> 
a l er t (" S w e e t") ; 
< / SC R I P T>
```

如何？是不是显得乱七八糟的？如果不知道方法的人很难想到要去掉里面的"空字符"（00H）的！

#### 0x3.2.5 无用内容混乱以及换行空格TAB大法 

在JAVASCRIPT代码中我们可以加入大量的无用字符串或数字，以及无用代码和注释内容等等，使真正的有用代码埋没在其中，并把有用的 代码中能加入换行、空格、TAB的地方加入大量换行、空格、TAB，并可以把正常的字符串用""来进行换行，这样就会使得代码难以看懂。

```javascript
<SCRIPT LANGUAGE="JavaScript"> 
"xajgxsadffgds";1234567890 
625623216;var $=0;alert//@$%%&*()(&(^%^ 
//cctv function// 
(//hhsaasajx xc 
/* 
asjgdsgu*/ 
"Sweet"//ashjgfgf 
/* 
@#%$^&%$96667r45fggbhytjty 
*/ 
//window 
) 
;"#@$#%@#432hu";212351436 
</SCRIPT> 
```

#### 0x3.2.6 JSPacker加解密

这类最突出的特点就是eval(function(p,a,c,k,e,r).....

所以当你遇到这类代码的时候，不妨试着使用一下JSPacker解密工具

```javascript
//源代码
eval(1);
//加密后代码
eval(function(p,a,c,k,e,r){e=String;if(!''.replace(/^/,String)){while(c--)r[c]=k[c]||c;k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}('0(1);',2,2,'alert|'.split('|'),0,{}))
```

加解密工具：

tool.lu在线解密		[http://tool.lu/js/](http://tool.lu/js/)

CSS-JS				[https://tool.css-js.com/](https://tool.css-js.com/)

手动解密：			其实将加密后的代码美化之后，会发现return p语句，在此之前，你只需要加上一句console.log(p)就能获得对应的解密后代码。

#### 0x3.2.7 JSFuck加解密

JSFuck 可以让你只用 6 个字符 `[ ]( ) ! +` 来编写 JavaScript 程序，所以很明显

jsfuck加密工具		[http://www.jsfuck.com/](http://www.jsfuck.com/)

jsfuck解密工具		[https://enkhee-osiris.github.io/Decoder-JSFuck/](https://enkhee-osiris.github.io/Decoder-JSFuck/)

​			手动：	其实jjencode的最后是一个函数，为此，我们只需要最后的()改成.toString()即可

#### 0x3.2.8 jjencode/aaencode

jjencode将JS代码转换成只有符号的字符串，类似于rrencode，但是符号大多数为\$+\~\[\]\￥等

加密工具				[http://utf-8.jp/public/jjencode.html](http://utf-8.jp/public/jjencode.html)

解密工具				[https://github.com/jacobsoo/Decoder-JJEncode](https://github.com/jacobsoo/Decoder-JJEncode)

​			手动：	其实jjencode的最后是一个函数，为此，我们只需要最后的()改成.toString()即可



aaencode将JS代码转换成只有符号的字符串，aaencode可以将JS代码转换成常用的网络表情，也就是我们说的颜文字js加密。纯粹的表情

加密工具				[http://utf-8.jp/public/aaencode.html](http://utf-8.jp/public/aaencode.html)

解密工具				[https://cat-in-136.github.io/2010/12/aadecode-decode-encoded-as-aaencode.html](https://cat-in-136.github.io/2010/12/aadecode-decode-encoded-as-aaencode.html)

​			手动：	其实aaencode的最后是一个函数，为此，我们只需要最后的('_')改成.toString()即可

#### 0x3.2.9 jother加解密

jother是一种运用于javascript语言中利用少量字符构造精简的匿名函数方法对于字符串进行的编码方式。其中8个少量字符包括： `! + ( ) [ ] { }` 。只用这些字符就能完成对任意字符串的编码。不同于jsfuck，它多了{}这两个大括号

这里可以参考文章[jother编码之谜](http://wps2015.org/drops/drops/jother%E7%BC%96%E7%A0%81%E4%B9%8B%E8%B0%9C.html)

加密工具				工具包->Misc->jother

解密工具				由于jother执行之后所得到的结果分为字符串和函数两种，所以解密的方法也不相同。

​			字符串：直接在Console界面中输入并回车即可

​			函数：	对于函数类型的jother加密结果，我们只需要将最后的()改成.toString()即可

#### 0x3.2.10 自定义加密算法

这无疑是这里面最难的一类。这样的一类算法，有可能是非对称的，经过加密之后仍能完成对应的功能！

当然有些对称的，如果作者给出解密算法，可能就比较容易。关键是作者会不会这么做了

ps：基于大多数情况下，js代码加密之后，对应代码不一定能执行，所以通常js文件中会有对应的解密算法！

### 0x3.3 js混淆

混淆应该是工业界和ctf题中用得最多的方式之一了。Javascript 作为一种运行在客户端的脚本语言，其源代码对用户来说是完全可见的。但不是每一个 js 开发者都希望自己的代码能被直接阅读，比如恶意软件的制造者们。为了增加代码分析的难度，混淆（obfuscate）工具被应用到了许多恶意软件（如 0day 挂马、跨站攻击等）当中。分析人员为了掀开恶意软件的面纱，首先就得对脚本进行反混淆（deobfuscate）处理。

**这一节的js混淆，强调的只是复杂化表达式**

代码混淆不一定会调用 eval，也可以通过在代码中填充无效的指令来增加代码复杂度，极大地降低可读性。Javascript 中存在许多称得上丧心病狂的特性，这些特性组合起来，可以把原本简单的字面量（Literal）、成员访问（MemberExpression）、函数调 用（CallExpression）等代码片段变得难以阅读。

Js 中的字面量有字符串、数字、正则表达式

下面简单举一个例子。

- 访问一个对象的成员有两种方法——点运算符和下标运算符。调用 window 的 eval 方法，既可以写成 `window.eval()`，也可以 `window['eval']`；
- 为了让代码更变态一些，混淆器选用第二种写法，然后再在字符串字面量上做文章。先把字符串拆成几个部分：`'e' + 'v' + 'al'`；
- 这样看上去还是很明显，再利用一个数字进制转换的技巧：`14..toString(15) + 31..toString(32) + 0xf1.toString(22)`；
- 一不做二不休，把数字也展开：`(0b1110).toString(4<<2) + (' '.charCodeAt() - 1).toString(Math.log(0x100000000) / Math.log(2)) + 0xf1.toString(11 << 1)`；
- 最后的效果：`window[(2*7).toString(4<<2) + (' '.charCodeAt() - 1).toString(Math.log(0x100000000) / Math.log(2)) + 0xf1.toString(11 << 1)]('alert(1)')`

在 js 中可以找到许多这样互逆的运算，通过使用随机生成的方式将其组合使用，可以把简单的表达式无限复杂化。

#### 0x3.3.1 解析和变换代码

本文对 Javascript 实现反混淆的思路是模拟执行代码中可预测结果的部分，编写一个简单的脚本执行引擎，只执行符合某些预定规则的代码块，最后将计算结果替换掉原本冗长的代码，实现表达式的简化。

如果对脚本引擎解释器的原理有初步了解的话，可以知道解释器在为了“读懂”代码，会对源代码进行词法分析、语法分析，将代码的字符串转换为抽象语法树（[Abstract Syntax Tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree), AST）的数据形式。

如这段代码：

``````javascript
var a = 42; var b = 5; function addA(d) { return a + d; } var c = addA(2) + b;
``````

对应的语法树如图：

![](/images/2017-11-12/31.png)

（由 [JointJS](http://jointjs.com/demos/javascript-ast)的在线工具生成）

不考虑 JIT 技术，解释器可以从语法树的根节点开始，使用深度优先遍历整棵树的所有节点，根据节点上分析出来的指令逐个执行，直到脚本结束返回结果。

通过 js 代码生成抽象语法树的工具很多，如压缩器 [UglifyJS](https://github.com/mishoo/UglifyJS) 带的 parser，还有本文使用的 [esprima](http://esprima.org/)。

esprima 提供的接口很简单：

```javascript
var ast = require('esprima').parse(code)
```

另外 Esprima 提供了一个在线工具，可以把任意（合法的）Javascript 代码解析成为 AST 并输出： [http://esprima.org/demo/parse.html](http://esprima.org/demo/parse.html)

再结合 estools 的几个辅助库即可对 js 进行静态代码分析：

- [escope](https://github.com/estools/escope) Javascript 作用域分析工具
- [esutil](https://github.com/estools/esutils) 辅助函数库，检查语法树节点是否满足某些条件
- [estraverse](http://github.com/estools/estraverse)语法树遍历辅助库，接口有一点类似 SAX 方式解析 XML
- [esrecurse](http://github.com/estools/esrecurse) 另一个语法树遍历工具，使用递归
- [esquery](https://github.com/estools/esquery) 使用 css 选择器的语法从语法树中提取符合条件的节点
- [escodegen](http://github.com/estools/escodegen)与 esprima 功能互逆，将语法树还原为代码

项目中使用的遍历工具是 estraverse。其提供了两个静态方法，`estraverse.traverse` 和 `estraverse.replace`。前者单纯遍历 AST 的节点，通过返回值控制是否继续遍历到叶子节点；而 replace 方法则可以在遍历的过程中直接修改 AST，实现代码重构功能。具体的用法可以参考其官方文档，或者本文附带的示例代码。

#### 0x3.3.2 规则设计

从实际遇到的代码入手。最近在研究一些 XSS 蠕虫的时候遇到了类似如下代码混淆：

![](/images/2017-11-12/41.png)

观察其代码风格，发现这个混淆器做了这几件事：

- 字符串字面量混淆：首先提取全部的字符串，在全局作用域创建一个字符串数组，同时转义字符增大阅读难度，然后将字符串出现的地方替换成为数组元素的引用
- 变量名混淆：不同于压缩器的缩短命名，此处使用了下划线加数字的格式，变量之间区分度很低，相比单个字母更难以阅读
- 成员运算符混淆：将点运算符替换为字符串下标形式，然后对字符串进行混淆
- 删除多余的空白字符：减小文件体积，这是所有压缩器都会做的事

经过搜索，这样的代码很有可能是通过 [javascriptobfuscator.com](http://javascriptobfuscator.com/Javascript-Obfuscator.aspx)的免费版生成的。其中免费版可以使用的三个选项（`Encode Strings / Move Strings / Replace Names`）也印证了前面观察到的现象。

这些变换中，变量名混淆是不可逆的。要是可以智能给变量命名的工具也不错，比如这个 [jsnice](http://jsnice.org/) 网站提供了一个在线工具，可以分析变量具体作用自动重命名。就算不能做到十全十美，实在不行就用人工的方式，使用 IDE（如 WebStorm）的代码重构功能，结合代码行为分析进行手工重命名还原。

再看字符串的处理。由于字符串将会被提取到一个全局的数组，在语法树中可以观察到这样的特征： 在全局作用域下，出现一个 VariableDeclarator，其 init 属性为 ArrayExpression，而且所有元素都是 Literal ——这说明这个数组所有元素都是常量。简单地将其求值，与变量名（标识符）关联起来。注意，此处为了简化处理，并没有考虑变量名作用域链的问题。在 js 中，作用域链上存在变量名的优先级，比如全局上的变量名是可以被局部变量重新定义的。如果混淆器再变态一点，在不同的作用域上使用相同的变量名，反混淆器 又没有处理作用域的情况，将会导致解出来的代码出错。

在测试程序中我设置了如下的替换规则：

- 全局变量声明的字符串数组，在代码中直接使用数字下标引用其值
- 结果确定的一连串二元运算，如 `1 * 2 + 3 / 4 - 6 % 5`
- 正则表达式字面量的 source，字符串字面量的 length
- 完全由字符串常量组成的数组，其`join / reverse / slice` 等方法的返回值
- 字符串常量的 `substr / charAt` 等方法的返回值
- decodeURIComponent 等全局函数，其所有参数为常量的，替换为其返回值
- 结果为常数的数学函数调用，如 `Math.sin(3.14)`

至于缩进的还原，这是 escodegen 自带的功能。在调用 `escodegen.generate`方法生成代码的时候使用默认的配置（忽略第二个参数）即可。

#### 0x3.3.3 DEMO 程序

这个反混淆器的原型放在 GitHub 上：[https://github.com/ChiChou/etacsufbo](https://github.com/ChiChou/etacsufbo)

运行环境和使用方法参考仓库的 README。

从  [YOU MIGHT NOT NEED JQUERY](http://youmightnotneedjquery.com/)上摘抄了一段代码，放入 [javascriptobfuscator.com](https://javascriptobfuscator.com/Javascript-Obfuscator.aspx) 测试混淆：

![](/images/2017-11-12/52.png)

将混淆结果[https://github.com/ChiChou/etacsufbo/blob/master/tests/cases/jsobfuscator.com.js](https://github.com/ChiChou/etacsufbo/blob/master/tests/cases/jsobfuscator.com.js)进行解开，结果如下：

![](/images/2017-11-12/61.png)

虽然变量名可读性依旧很差，但已经可以大体看出代码的行为了。

演示程序目前存在大量局限性，只能算一个半自动的辅助工具，还有许多没有实现的功能。

一些混淆器会对字符串字面量进行更复杂的保护，将字符串转换为 f(x) 的形式，其中 f 函数为一个解密函数，参数 x 为密文的字符串。也有原地生成一个匿名函数，返回值为字符串的。这种方式通常使用的函数表达式具有上下文无关的特性——其返回值只与函数的输入有关，与当 前代码所处的上下文（比如类的成员、DOM 中取到的值）无关。如以下代码片段中的 xor 函数：

```javascript
var xor = function(str, a, b) {
```

```javascript
return String.fromCharCode.apply(null, str.split('').map(function(c, i) { var ascii = c.charCodeAt(0); 
```

如何判断某个函数是否具有这样的特性呢？首先一些库函数可以确定符合，如 `btoa，escape，String.fromCharCode` 等，只要输入值是常量，返回值就是固定的。建立一个这样的内置函数白名单，接着遍历函数表达式的 AST，若该函数参与计算的参数均没有来自外部上下文，且其所有 CallExpression 的 callee 在函数白名单内，那么通过递归的方式可以确认一个函数是否满足条件。

还有的混淆器会给变量创建大量的引用实例，也就是给同一个对象使用了多个别名，阅读起来非常具有干扰性。可以派出 escope 工具对变量标识符进行数据流分析，替换为所指向的正确值。还有利用数学的恒等式进行混淆的。如声明一个变量 a，若 a 为 Number，则表达式 `a-a`、`a * 0` 均恒为 0。但如果 a 满足 `isNaN(a)`，则表达式返回 `NaN`。要清理这类代码，同样需要借助数据流分析的方法。

目前还没有见到使用扁平化流程跳转实现的 js 混淆样本，笔者认为可能跟 js 语言本身的使用场景和特点有关。一般 js 的代都是偏业务型的，不会有太复杂的流程控制或者算法，混淆起来效果不一定理想。

#### 0x3.3.4 工具总结

混淆工具：		[https://javascriptobfuscator.com/Javascript-Obfuscator.aspx](https://javascriptobfuscator.com/Javascript-Obfuscator.aspx)	( Encode Strings / Move Strings / Replace Names )

​				[http://tool.lu/js/](http://tool.lu/js/)		( Replace Names )

​				[https://jscrambler.com](https://jscrambler.com)

去混淆工具：		[https://github.com/ChiChou/etacsufbo](https://github.com/ChiChou/etacsufbo)  ( 该工具去混淆能力太差 )

​				[http://jsnice.org/](http://jsnice.org/)

​				[http://www.bm8.com.cn/jsConfusion/](http://www.bm8.com.cn/jsConfusion/)

​		反混淆终极工具： [https://prepack.io/](https://prepack.io/)

​		最终推荐： 如果代码量不是特别大的化，手动去混淆吧，少年！

这儿找到了一个手动去混淆的栗子，供大家观摩[https://www.blackglory.me/l1l-document-all-features-detailed-js-confused-with-anti-aliasing-process/](https://www.blackglory.me/l1l-document-all-features-detailed-js-confused-with-anti-aliasing-process/)



​				

















​			



