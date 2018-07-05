---
title: javascript的调试
date: 2017-11-13 17:36:16
categories: code
tags: javascript
---

javascript作为一种普适性的脚本语言，广泛应用于网页端、移动端。而本文将要讲述的是javascript的调试。

### 调试工具

#### javascript内置命令调试

javascript作为一种脚本语言，内置了大量的输出函数。这里主要讲述的是alert/prompt/confirm、console.log、document.write。

其实上面的"、"已经为我们分好类的。

1. 弹框式输出
2. console命令框输出
3. 网页内输出

**弹框式输出**

优点：可以作为IO中断

缺点：由于是中断操作，频繁的确定会比较麻烦。弹框中所能容纳的字符数有限

**console命令框输出**

优点：输出内容无限制

缺点：不能产生中断，较长的代码调试起来相对而言较麻烦

**网页内输出**

优点：由于是在网页内部输出，所以内容样式可以自定义。输出内容也没有限制

缺点：不能产生中断，较长的代码调试起来相对而言较麻烦

**辅助工具**

由于输出的内容多样化，很多时候我们需要的字符串类型，这时候不妨使用toString函数，以此来方便查看输出结果！

#### Visual Studio Code

vsc是最近我所使用的文本编辑器，以前一直使用sublime作为文本编辑的工具。visual studio code是一款轻量级的IDE，可进行多种脚本语言的调试与编写！而且vsc支持windows、mac、linux，是一款不可多得的调试软件。具体操作步骤就不再赘述，因为与vs基本一致！

优点：支持多种脚本语言的编译调试

缺点：由于visual studio code使用nodejs作为底层调试器，所以不支持弹框式输出以及I网页内输出等方式。这也就意味着，很多在浏览器中能够实现的编写方式在这里很有可能编译不通

#### Chrome开发者模式<font color=#f00>(推荐)</font>

chrome的开发者模式中，sources选项栏中支持了调试。其右上角给出了调试工具、断点信息、监听器信息等等，总而言之功能十分强大。

优点：chrome开发者模式进行调试，能够解决大部分js静态分析问题，功能齐全，支持几乎全部的js命令

缺点：现如今有许多网页在做开发的时候，进行了反调试功能。这个时候，chrome的开发者模式进行调试可能效果不明显。但是我们可以配合<font color=#f00>[Tampermonkey](https://chrome.google.com/webstore/detail/tampermonkey/dhdgffkkebhmkfjojejmpbldmpobfkfo?utm_source=chrome-ntp-icon)</font> 进行脚本设置，封闭/变相禁用反调试功能。

范例：

````javascript
(function() {
    window._setTimeout = window.setTimeout;
    window.setTimeout = function () {};
})();
````

由于在执行网页中的js代码之前，先调用了上述代码。所以setTimeout函数都给更改了，这就导致了反调试的重要一环被截断，这会在后面的章节进行讲述。



### 综合范例

可以说这儿的范例是从网上摘抄的，所以大家擦亮的自己的眼睛，防止被误导。

#### 缘起

最近在研究 PopUnder 的实现方案，通过 Google 搜索 `js popunder` 出来的第一页中有个网站 `popunderjs.com`，当时看了下，这是个提供 popunder 解决方案的一家公司，而且再翻了几页，发现市面上能解决这个问题的，只有2家公司，可见这个市场基本是属于垄断型的。 
popunderjs 原来在 github 上是有开源代码的，但后来估计作者发现这个需求巨大的商业价值，索性不开源了，直接收费。所以现在要研究它的实现方案，只能上官网扒它源码了。

这是它的示例页：`http://code.ptcong.com/demos/bjp/demo.html`
分别加载了几个重要文件：

```
http://code.ptcong.com/demos/bjp/script.js?0.3687041198903791
http://code.ptcong.com/demos/bjp/license.demo.js?0.31109710863616447
```

#### 文件结构

script.js 是功能主体，实现了 popunder 的所有功能以及定义了多个 API 方法
license.demo.js 是授权文件，有这个文件你才能顺利调用 script.js 里的方法

#### 防止被逆向

这么具有商业价值的代码，就这么公开地给你们用，肯定要考虑好被逆向的问题。我们来看看它是怎么反逆向的。 
首先，打开控制台，发现2个问题：

1. 控制台所有内容都被反复清空，只输出了这么一句话：`Console was cleared script.js?0.5309098417125133:1`
2. 无法断点调试，因为一旦启用断点调试功能，就会被定向到一个匿名函数 `(function() {debugger})`

也就是说，常用的断点调试方法已经无法使用了，我们只能看看源代码，看能不能理解它的逻辑了。但是，它源代码是这样的：

```javascript
var a = typeof window === S[0] && typeof window[S[1]] !== S[2] ? window : global;
try {
    a[S[3]](S[4]);
    return function() {}
    ;
} catch (a) {
    try {
        (function() {}
        [S[11]](S[12])());
        return function() {}
        ;
    } catch (a) {
        if (/TypeError/[S[15]](a + S[16])) {
            return function() {}
            ;
        }
    }
}
```

可见源代码是根本不可能阅读的，所以还是得想办法破掉它的反逆向措施。

#### 利用工具巧妙破解反逆向

首先在断点调试模式一步步查看它都执行了哪些操作，突然就发现了这么一段代码：

```javascript
(function() {
    (function a() {
        try {
            (function b(i) {
                if (('' + (i / i)).length !== 1 || i % 20 === 0) {
                    (function() {}
                    ).constructor('debugger')();
                } else {
                    debugger ;
                }
                b(++i);
            }
            )(0);
        } catch (e) {
            setTimeout(a, 5000);
        }
    }
    )()
}
)();
```

这段代码主要有2部分，一是通过 try {} 块内的 b() 函数来判断是否打开了控制台，如果是的话就进行自我调用，反复进入 debugger 这个断点，从而达到干扰我们调试的目的。如果没有打开控制台，那调用 debugger 就会抛出异常，这时就在 catch {} 块内设置定时器，5秒后再调用一下 b() 函数。

这么说来其实一切的一切都始于 setTimeout 这个函数（因为 b() 函数全是闭包调用，无法从外界破掉），所以只要在 setTimeout 被调用的时候，不让它执行就可以破解掉这个死循环了。

所以我们只需要简单地覆盖掉 setTimeout 就可以了……比如：

```javascript
(function() {
    window._setTimeout = window.setTimeout;
    window.setTimeout = function () {};
})();
```

但是！这个操作无法在控制台里面做！因为当你打开控制台的时候，你就必然会被吸入到 b() 函数的死循环中。这时再来覆盖 setTimeout 已经没有意义了。

这时我们的工具 TamperMonkey 就上场了，把代码写到 TM 的脚本里，就算不打开控制台也能执行了。

<font color=#f00>TM 脚本写好之后，刷新页面，等它完全加载完，再打开控制台，这时 debugger 已经不会再出现了！**接下来就轮到控制台刷新代码了**</font>

通过 `Console was cleared` 右侧的链接点进去定位到具体的代码，点击 `{}` 美化一下被压缩过的代码，发现其实就是用 setInterval 反复调用 console.clear() 清空控制台并输出了 `<div>Console was cleared</div>` 信息，但是注意了，不能直接覆盖 setInterval 因为这个函数在其他地方也有重要的用途。

所以我们可以通过覆盖 console.clear() 函数和过滤 log 信息来阻止它的清屏行为。

同样写入到 TamperMonkey 的脚本中，代码：

```
window.console.clear = function() {};
window.console._log = window.console.log;
window.console.log = function (e) {
    if (e['nodeName'] && e['nodeName'] == 'DIV') {
        return ;
    }
    return window.console.error.apply(window.console._log, arguments);
};
```

之所以用 error 来输出信息，是为了查看它的调用栈，对理解程序逻辑有帮助。

------

基本上，做完这些的工作之后，这段代码就可以跟普通程序一样正常调试了。但还有个问题，它主要代码是经常混淆加密的，所以调试起来很有难度。下面简单讲讲过程。

#### 混淆加密方法一：隐藏方法调用，降低可读性

从 license.demo.js 可以看到开头有一段代码是这样的：

```javascript
var zBCa = function T(f) {
    for (var U = 0, V = 0, W, X, Y = (X = decodeURI("+TR4W%17%7F@%17.....省略若干"),
    W = '',
    'D68Q4cYfvoqAveD2D8Kb0jTsQCf2uvgs'); U < X.length; U++,
    V++) {
        if (V === Y.length) {
            V = 0;
        }
        W += String["fromCharCode"](X["charCodeAt"](U) ^ Y["charCodeAt"](V));
    }
    var S = W.split("&&");
```

通过跟踪执行，可以发现 S 变量的内容其实是本程序所有要用到的类名、函数名的集合，类似于 `var S = ['console', 'clear', 'console', 'log']`。如果要调用 console.clear() 和 console.log() 函数的话，就这样

```javascript
var a = window;
a[S[0]][S[1]]();
a[S[2]][S[3]]();
```

#### 混淆加密方法二：将函数定义加入到证书验证流程

license.demo.js 中有多处这样的代码：

```
a['RegExp']('/R[\S]{4}p.c\wn[\D]{5}t\wr/','g')['test'](T + '')
```

这里的 a 代表 window，T 代表某个函数，`T + ''` 的作用是把 T 函数的定义转成字符串，所以这段代码的意思其实是，验证 T 函数的定义中是否包含某些字符。

每次成功的验证，都会返回一个特定的值，这些个特定的值就是解密核心证书的参数。

可能是因为我重新整理了代码格式，所以在重新运行的时候，这个证书一直运行不成功，所以后来就放弃了通过证书来突破的方案。

#### 逆向思路：输出所有函数调用和参数

通过断点调试，我们可以发现，想一步一步深入地搞清楚这整个程序的逻辑，是十分困难，因为它大部分函数之间都是相互调用的关系，只是参数的不同，结果就不同。

所以我后来想了个办法，就是只查看它的系统函数的调用，通过对调用顺序的研究，也可以大致知道它执行了哪些操作。

要想输出所有系统函数的调用，需要解决以下问题：

1. 覆盖所有内置变量及类的函数，我们既要覆盖 `window.console.clear()` 这样的依附在实例上的函数，也要覆盖依附在类定义上的函数，如 `window.HTMLAnchorElement.__proto__.click()`
2. 需要正确区分内置函数和自定义函数

经过搜索后，找到了区分内置函数的代码：

```
  // Used to resolve the internal `[[Class]]` of values
  var toString = Object.prototype.toString;

  // Used to resolve the decompiled source of functions
  var fnToString = Function.prototype.toString;

  // Used to detect host constructors (Safari > 4; really typed array specific)
  var reHostCtor = /^\[object .+?Constructor\]$/;

  // Compile a regexp using a common native method as a template.
  // We chose `Object#toString` because there's a good chance it is not being mucked with.
  var reNative = RegExp('^' +
    // Coerce `Object#toString` to a string
    String(toString)
    // Escape any special regexp characters
    .replace(/[.*+?^${}()|[\]\/\\]/g, '\\$&')
    // Replace mentions of `toString` with `.*?` to keep the template generic.
    // Replace thing like `for ...` to support environments like Rhino which add extra info
    // such as method arity.
    .replace(/toString|(function).*?(?=\\\()| for .+?(?=\\\])/g, '$1.*?') + '$'
  );

  function isNative(value) {
    var type = typeof value;
    return type == 'function'
      // Use `Function#toString` to bypass the value's own `toString` method
      // and avoid being faked out.
      ? reNative.test(fnToString.call(value))
      // Fallback to a host object check because some environments will represent
      // things like typed arrays as DOM methods which may not conform to the
      // normal native pattern.
      : (value && type == 'object' && reHostCtor.test(toString.call(value))) || false;
  }
```

然后结合网上的资料，写出了递归覆盖内置函数的代码：

```
function wrapit(e) {
    if (e.__proto__) {
        wrapit(e.__proto__);
    }
    for (var a in e) {
        try {
            e[a];
        } catch (e) {
            // pass
            continue;
        }
        var prop = e[a];
        if (!prop || prop._w) continue;

        prop = e[a];
        if (typeof prop == 'function' && isNative(prop)) {
            e[a] = (function (name, func) {
                return function () {
                    var args = [].splice.call(arguments,0); // convert arguments to array
                    if (false && name == 'getElementsByTagName' && args[0] == 'iframe') {
                    } else {
                        console.error((new Date).toISOString(), [this], name, args);
                    }
                    if (name == 'querySelectorAll') {
                        //alert('querySelectorAll');
                    }
                    return func.apply(this, args);
                };
            })(a, prop);
            e[a]._w = true;
        };
    }
}
```

使用的时候只需要：

```
wrapit(window);
wrapit(document);
```

然后模拟一下正常的操作，触发 PopUnder 就可以看到它的调用过程了。

------

参考资料：

[A Beginners’ Guide to Obfuscation](https://blog.nettitude.com/uk/beginners-guide-obfuscation) 
[Detect if function is native to browser](https://stackoverflow.com/questions/6598945/detect-if-function-is-native-to-browser) 
[Detect if a Function is Native Code with JavaScript](https://davidwalsh.name/detect-native-function)

