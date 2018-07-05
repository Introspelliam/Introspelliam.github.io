---
title: JavaScript反混淆与混淆
date: 2017-11-14 00:10:18
categories: misc
tags: javascript
---

本文摘抄于岚光的博客[https://0x0d.im/archives/javascript-anti-debug-and-obfuscator.html](https://0x0d.im/archives/javascript-anti-debug-and-obfuscator.html)

前些时候因为人机识别和反作弊业务的需求调研了[浏览器指纹和追踪](https://0x0d.im/archives/broswer-fingerprint-and-tracking.html)的一些方法，那么当我们把检测代码上线后，怎么保护它，不被攻击者迅速分析破解呢？

常见的编码（如 [Base62](http://dean.edwards.name/packer/)）、压缩（如 [UglifyJS](https://github.com/mishoo/UglifyJS2)）、复杂化表达式（如填充无用代码，拆分字符串）就不细说了。
至于将 JavaScript 代码隐藏在图片中类似隐写术的方法，一般是恶意程序为了逃避杀毒软件检测所用，正常业务很少用到。

通常用各种编码“加密”的代码，无论怎样变形，其最终都要调用一次 `eval` 等函数执行。
只需劫持关键函数调用的行为，改为文本输出（如 `console.log`）即可得到载体中隐藏的代码。

```javascript
eval = function() {
	console.log('eval', JSON.stringify(arguments));
};

eval('console.log("Hello world!")');
```

去除空格、换行，缩短函数、变量名之类的压缩代码可以直接用浏览器的开发者工具格式化，或是使用 [jsbeautifier](http://jsbeautifier.org/) 等在线工具美化。
复杂化表达式会增加代码复杂度，极大地降低可读性，但有经验和耐心的研究者依然能慢慢调试还原出功能来。

(下面代码在 Chrome 59 上测试通过）

#### Console

检测到浏览器 Console 打开（[Detect all browser console open or not](http://stackoverflow.com/questions/40153206/detect-all-browser-console-open-or-not)）时阻塞 Javascript 执行：

```javascript
var checkStatus;
var element = new Image();
// var element = document.createElement('any');
element.__defineGetter__('id', function() {
    checkStatus = 'on';
});
setInterval(function() {
    checkStatus = 'off';
    console.log(element);
    console.clear();
    if(checkStatus = 'on') {
        alert('Prohibit the use of console!');
    }
}, 1000)
```

#### Debugger

Console 调试时会自动停在断点处，借此可以插入随机的 debugger 干扰正常调试。

```javascript
!function test() {
    // 捕获异常，递归次数过多调试工具会抛出异常。
    try{
        !function cir(i)
        {
            // 当打开调试工具后，抛出异常，setTimeout执行test无参数，此时i == NaN，("" + i / i).length == 3
            // debugger设置断点
            ( 1 !== ( "" + i / i).length || 0===i ) && function({}.constructor("debugger")(),cir(++i);
        } (0)
    } catch(e) {
        setTimeout(test,500)
    }
}()
```

**demo：**[https://jsfiddle.net/ftpgxm/t4ux8xp4/2/](https://jsfiddle.net/ftpgxm/t4ux8xp4/2/)

当然，为了能够调试，我们可以使用Tampermonkey，在执行js代码之前，先执行下列代码

```
window._setTimeout = window.setTimeout;
window.setTimeout = function () {};
```

具体可参考：

- [http://www.jianshu.com/p/9148d215c119](http://www.jianshu.com/p/9148d215c119)
- [https://zhuanlan.zhihu.com/p/29214928](https://zhuanlan.zhihu.com/p/29214928)

#### AST

通过修改 [AST(Abstract Syntax Tree)](https://en.wikipedia.org/wiki/Abstract_syntax_tree) 生成一个新的 AST，混淆规则有拆分字符串、拆分数组，增加废代码等。
如在同构语法的基础上提取出所有 key 值到闭包的参数中，破坏代码的可读性：

```javascript
var a = document.getElementById('a');
a.innerHTML = 'test';
```

混淆之后是：

```javascript
(function(a,b,c,d,e,f){
    var g=a[b][c](d);
    g[e]=f
})(window,'document', 'getElementById', 'a', 'innerHTML', 'test');
```

#### WebAssembly

[WebAssembly](https://en.wikipedia.org/wiki/WebAssembly) 是可用于浏览器的字节码格式，比 JS 更高效，能从 `C/C++` 编译。
如一个简单的 `add` 和 `square`：

```javascript
WebAssembly.compile(new Uint8Array(`
  00 61 73 6d  01 00 00 00  01 0c 02 60  02 7f 7f 01
  7f 60 01 7f  01 7f 03 03  02 00 01 07  10 02 03 61
  64 64 00 00  06 73 71 75  61 72 65 00  01 0a 13 02
  08 00 20 00  20 01 6a 0f  0b 08 00 20  00 20 00 6c
  0f 0b`.trim().split(/[\s\r\n]+/g).map(str => parseInt(str, 16))
)).then(module => {
  const instance = new WebAssembly.Instance(module)
  const { add, square } = instance.exports
  console.log('2 + 4 =', add(2, 4))
  console.log('3^2 =', square(3))
  console.log('(2 + 5)^2 =', square(add(2 + 5)))
})
```

它可能是终极的解决办法，因为作为二进制编码它自带“混淆”，还可以进一步加壳或虚拟机保护。

#### 绕过方法

对于大部分的 JS 代码混淆加密，其实都可以用 [Partial evaluation](https://en.wikipedia.org/wiki/Partial_evaluation) 解决（参见讨论：[https://www.v2ex.com/t/367641](https://www.v2ex.com/t/367641)）。
如 Google 的 [Closure Compiler](https://closure-compiler.appspot.com/) 和 FaceBook 的 [Prepack](https://prepack.io/)，虽然是用于 JS 代码优化的工具，
但它们都会在编译期重构 AST、计算函数、初始化对象等，最终还原出正常的可读的代码。

对于干扰 Console 调试的方法，可以用 Fiddler 或 Burp Suite 抓包，拦截页面请求，删除或注释掉干扰代码。

#### 参考

> - [使用 estools 辅助反混淆](http://blog.knownsec.com/2015/08/use-estools-aid-deobfuscate-javascript/)
> - [Javascript 移动时代的前端加密](http://div.io/topic/1220)
> - [可信前端之路-代码保护](https://jaq.alibaba.com/community/art/show?spm=a313e.7916648.0.0.foiOcx&articleid=503)
> - [混淆恶意JavaScript代码的检测与反混淆方法研究](http://infosec.bjtu.edu.cn/wangwei/wp-content/uploads/2016/10/%E6%B7%B7%E6%B7%86%E6%81%B6%E6%84%8FJavaScript%E4%BB%A3%E7%A0%81%E7%9A%84%E6%A3%80%E6%B5%8B%E4%B8%8E%E5%8F%8D%E6%B7%B7%E6%B7%86%E6%96%B9%E6%B3%95%E7%A0%94%E7%A9%B6-%E8%AE%A1%E7%AE%97%E6%9C%BA%E5%AD%A6%E6%8A%A5.pdf)
> - [怎样理解 Partial Evaluation](https://www.zhihu.com/question/29266193)
> - [WebAssembly 实践：如何写代码](https://segmentfault.com/a/1190000008402872)