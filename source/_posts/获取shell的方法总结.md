---
title: 获取shell的方法总结
date: 2017-09-10 01:31:58
categories: 安全技术
tags: [shell, linux]
---

最近做了一下pwnable.kr上面的题，对某些内容有了一定的感想，特别是获取shell这方面！

#### 姿势1

>  linux下的C++程序中：
>
>  system('set -s');  
>
> 其执行效果相当于获取一个shell

