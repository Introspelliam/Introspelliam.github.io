---
title: 使用git在github上创建新工程
date: 2017-06-30 14:29:17
categories: tool
tags: git
---

这段时间进经常会忘记如何在github上同步工程，于是又得查资料，查参考书，浪费了很长时间，因此有了感触，写几篇有关此类问题的篇章！

<font color=#f00>这是老手新手都十分容易犯的错误，就是在创建一个新github项目或者以本地已有项目为原型重新创建一个github项目时，容易创建一个空文件夹就直接关联远程仓库，这样做只会返回错误！！！所以，文件夹一定不能为空......</font>

### 创建新工程需要的命令

#### 完成本地项目与git的关联

<pre><code>
cd 工程目录
git init	//初始化本地仓库，当前目录下会出现一个名为 .git 的目录
git add .	//将所有文件添加到缓存区，告诉 Git 开始对这些文件进行跟踪
git commit -am "Hello"	//提交文件到本地仓库

</code></pre>

#### 完成远程项目的创建

在github上创建某个项目，然后可以拷贝处该项目的地址

#### 关联远程仓库（github上创建的地址）

<pre><code>
git remote add origin https://github.com/Introspelliam/Hello.git    //关联远程仓库

</code></pre>

#### push本地项目到远程仓库

<pre><code>
git push origin master     //push项目到master
Username for 'https://github.com': //你的github账户名称

</code></pre>


### github上提供的工程创建方法

<b>…or create a new repository on the command line</b>

    echo "# ctf-challenges" >> README.md
    git init
    git add README.md
    git commit -m "first commit"
    git remote add origin https://github.com/Introspelliam/ctf-challenges.git
    git push -u origin master

<b>…or push an existing repository from the command line</b>

    git remote add origin https://github.com/Introspelliam/ctf-challenges.git
    git push -u origin master
