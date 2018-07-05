---
title: hexo使用hexo-math插件支持MathJax
date: 2018-03-27 11:57:57
categories: Hexo搭建博客网站
tags: [hexo, math]
mathjax: true
---

MathJax是使用LaTeX方式输入数学公式的好工具。Hexo虽然可以直接使用mathjax，但是存在一些不方便之处。使用[hexo-math](https://github.com/akfish/hexo-math)这个插件可以大大方便使用。
使用Hexo 3.2.0，主题NexT 5.0.1，hexo-math 3.0.0安装方式如下

在hexo安装目录下执行

```
npm install hexo-math --save
```

然后编辑站点根目录下的`_config.yml`，添加

```
math:
  engine: 'mathjax' # or 'katex'
  mathjax:
    src: custom_mathjax_source
    config:
      # MathJax config
```

之后进入theme的目录，编辑主题的`_config.yml`，找到mathjax字段。NexT 5.0.1中默认mathjax是禁用，需要改成

```
mathjax:
   enable: true
```

最后`hexo g`，就可以部署或者运行server查看效果了。

------

几个测试例子
使用`$`的一行代码：

```
Simple inline $a = b + c$.
```

Simple inline $a=b+c$.

使用`$$`的多行代码：

```
$$\frac{\partial u}{\partial t}
= h^2 \left( \frac{\partial^2 u}{\partial x^2} +
\frac{\partial^2 u}{\partial y^2} +
\frac{\partial^2 u}{\partial z^2}\right)$$
```

$$\frac{\partial u}{\partial t}= h^2 \left( \frac{\partial^2 u}{\partial x^2} +\frac{\partial^2 u}{\partial y^2} +\frac{\partial^2 u}{\partial z^2}\right)$$

使用Tag的块貌似不能用！！！

```
这儿讲了一些细节：首先是不能直接用\\来当换行符，需要用\newline
另外编辑公式的时候，不要使用* {% math %} 双大括号 等容易发生冲突的符号
```

```
$$
\left[
    \begin{array}{cc|c}
      1&2&3\newline
      4&5&6
    \end{array}
\right] 
$$
```

$$
\left[
    \begin{array}{cc|c}
      1&2&3\newline
      4&5&6
    \end{array}
\right] 
$$
