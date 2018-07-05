---
title: Hexo+Github搭建静态博客
date: 2017-06-16 13:51:24
categories: Hexo搭建博客网站
tags: hexo
---

### 开始之前
在安装hexo之前，必须确认你已经安装了[Node.js](http://nodejs.org/)和[Git](http://git-scm.com/)。

#### 1.创建GitHub仓库
注册GitHub账号，创建一个以”用户名.github.io”命名的仓库，如我的用户名为Introspelliam,那我的仓库名为：[Introspelliam.github.io](https://github.com/Introspelliam/Introspelliam.github.io)，仓库默有master分支，用于托管生成的静态文件，再新建一个develop(名字自定)分支，用于托管后台文件，方便以后换电脑时后台文件不会丢失。

#### 2.配置Git
设置Git的用户名和邮件地址（邮箱就是你注册Github时候的邮箱），打开Git Bash,键入：

    $ git config --global user.name "username"
    $ git config --global user.email "email@example.com"

#### 3.本地Git与GitHub建立联系
这里介绍SSH的配置，先检查电脑是否已经有SSH

	$ ls -al ~/.ssh

如果不存在就没有关系，如果存在的话，直接删除.ssh文件夹里面所有文件。
输入以下指令后，一路回车就好:

	$ ssh-keygen -t rsa -C "emailt@example.com"

然后键入以下指令：

	$ ssh-agent -s
	$ ssh-add ~/.ssh/id_rsa

如果出现这个错误:Could not open a connection to your authentication agent，则先执行如下命令即可：

	$ ssh-agent bash

再重新输入指令：

	ssh-add ~/.ssh/id_rsa

到了这一步，就可以添加SSH key到你的Github账户了。
在github上点击你的头像–>Your profile–>Edit profile–>SSH and GPG keys–>New SSH key
Title自己随便取，然后这个Key就是刚刚拷贝的，你直接粘贴就好（也可以文本打开id_rsa.pub复制其内容），最后Add SSH key。
最后还是测试一下吧，键入以下命令：

	$ ssh -T git@github.com

你可能会看到有警告，没事，输入“yes”就好。

#### 4.初始化hexo文件夹
到GitHub的Introspelliam.github.io仓库下，点击Clone or download,复制里面的HTTPS地址。
在E盘或是你喜爱的文件夹下，右键Git Bash Here: 键入git clone -b develop <刚复制的地址>

	$ git clone -b develop https://github.com/Introspelliam/Introspelliam.github.io.git
	$ mkdir Hexo-admin

### Hexo安装配置
#### 1.Hexo初始化
进入Hexo-admin文件夹

	$ cd Hexo-admin

接下来只需要使用 npm 即可完成 Hexo 的安装:

	$ npm install -g hexo-cli

安装 Hexo 完成后，请执行下列命令，Hexo 将会在指定文件夹中新建所需要的文件:

	$ hexo init
	$ npm install

接下来也可以本地预览博客，执行下列命令,然后到浏览器输入localhost:4000看看。

	$ hexo generate
	$ hexo server

输入Ctrl+C停止服务。
#### 2.Hexo配置
用编辑器打开 Hexo-admin/ 下的配置文件_config.yml找到：

	# Deployment
	## Docs: https://hexo.io/docs/deployment.html
	deploy:
  	  type:
  	  repository:

到GitHub的chaooo.github.io仓库下，点击Clone or download,复制里面的HTTPS地址到repository:，添加branch: master。

	# Deployment
	## Docs: https://hexo.io/docs/deployment.html
	deploy:
      type: git
      repository: https://github.com/Introspelliam/Introspelliam.github.io.git
      branch: master

#### 3.完成部署
最后一步，快要成功了，键入指令：

	$ npm install hexo-deployer-git --save
	$ hexo generate
	$ hexo deploy

输入弹出框的用户名与密码(首次使用git会弹出)。
OK，我们的博客就已经完全搭建起来了，在浏览器输入（当然，是你的Repository名），例如我的：[Introspelliam.github.io/](https://github.com/Introspelliam/Introspelliam.github.io.git)
每次修改本地文件后，需要键入hexo generate才能保存，再键入hexo deploy上传文件。
当然，不要忘了回退到父文件夹提交网站相关的文件以备今后迁移，依次执行git add .、git commit -m “…”、git push origin develop。
### 日常操作
#### 1.写文章
执行new命令，生成指定名称的文章至 Admin-blog\source_posts\文章标题.md 。

	$ hexo new [layout] "文章标题" #新建文章

然后用编辑器打开“文章标题.md”按照[Markdown语法](http://www.appinn.com/markdown/)书写文章。
其中layout是可选参数，默认值为post。到 scaffolds 目录下查看现有的layout。当然你可以添加自己的layout，
同时你也可以编辑现有的layout，比如post的layout默认是 hexo\scaffolds\post.md

	title: {{ title }}
	date: {{ date }}
	tags:
	---

我想添加categories，以免每次手工输入，只需要修改这个文件添加一行，如下：

	title: {{ title }}
	date: {{ date }}
	categories:
	tags:
	---

文件标题也是md文件的名字，同时也出现在你文章的URL中，postName如果包含空格，必须用”将其包围。
请注意，大括号与大括号之间在不同版本间可能需要空格，否则会被转义，不能正常显示；所有文件"："后面都必须有个空格，不然会报错。
#### 2.提交
每次在本地对博客进行修改后，先执行下列命令提交网站相关的文件。

	$ git add .
	$ git commit -m "..."
	$ git push origin develop

然后才执行hexo generate -d发布网站到master分支上。

	$ hexo generate -d

#### 3.本地仓库丢失
当你想在其他电脑工作，或电脑重装系统后，安装Git与Node.js后，可以使用下列步骤：
##### 3.1拷贝仓库

	$ git clone -b develop https://github.com/Introspelliam/Introspelliam.github.io.git

##### 3.2配置Hexo
在本地新拷贝的chaooo.github.io文件夹下通过Git bash依次执行下列指令:

	$ npm install -g hexo-cli
	$ npm install hexo
	$ npm install
	$ npm install hexo-deployer-git --save

### 小Tips:hexo 命令

	hexo new "postName" #新建文章
    hexo new page "pageName" #新建页面
    hexo generate #生成静态页面至public目录
    hexo server #开启预览访问端口（默认端口4000，'ctrl + c'关闭server）
    hexo deploy #将.deploy目录部署到GitHub
    hexo help  # 查看帮助
    hexo version  #查看Hexo的版本
    hexo deploy -g  #生成加部署
    hexo server -g  #生成加预览
    #命令的简写
    hexo n == hexo new
    hexo g == hexo generate
    hexo s == hexo server
    hexo d == hexo deploy

### 参考文献
本文转载[Hexo3.2+GitHub搭建静态博客](http://chaoo.oschina.io/2016/05/23/Hexo3-2-github%E6%90%AD%E5%BB%BA%E9%9D%99%E6%80%81%E5%8D%9A%E5%AE%A2.html)