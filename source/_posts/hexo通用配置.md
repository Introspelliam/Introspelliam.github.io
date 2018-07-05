---
title: hexo通用配置
date: 2017-06-20 15:26:47
categories: Hexo搭建博客网站
tags: hexo
---


### 开始之前
当确定使用Hexo这种静态博客，并使用前面几篇博客所说明的几种安装配置方法之后，基本上自己的博客就已经能够使用了。但是如何解决细节方面的问题呢？这一节就是专门解决这方面问题所开设的博文，博文将会根据自身遇见的问题以及评论者遇到的问题进行汇总整理，不断更新以确保问题能够及时得到解决！

##### 1. hexo文章中如何插入图片
解决这个问题前，首先得了解[Hexo的结构](/2017/06/20/hexo的目录结构/)。

可以看出source目录是创建博文所需要的基本文件，那么可想而知图片也应该放到这个文件夹下。

<font color=#f00>使用本地路径</font>：在hexo/source目录下新建一个images文件夹，将图片放入该文件夹下，插入图片时链接即为/images/图片名称。

<font color=#f00>使用微博图床</font>，地址http://weibotuchuang.sinaapp.com/，将图片拖入区域中，会生成图片的URL，这就是链接地址。

毫无疑问推荐使用第一种方法，而markdown引用图片的方法：

	![Alt text](/path/to/img.jpg)

##### 2. hexo如何分享
bluelake主题十分友好的是将这些内容封装起来，用户只需要在themes/bluelake/_config.yml中进行配置即可！

相关代码是：

    #Share
    baidu_share: ## 百度分享
    JiaThis_share: ##true ##JiaThis分享
    duoshuo_share: #true ##true 多说分享必须和多说评论一起使用。
    addToAny_share: # AddToAny share. Empty list hides. List items are service name at url. For ex: email for '<a href="https://www.addtoany.com/add_to/email?linkurl=...'
    #  - twitter
    #  - baidu
    #  - facebook
    #  - google_plus
    #  - linkedin
    #  - email
    #  - qzone
    #  - wechat
    #  - sina_weibo

如果想启用百度分享（包括facebook、twitter、linkedin、有道云笔记、印象笔记、微信、QQ空间、sina微薄），就只需要在baidu_share设置为true就行。

如果想启用JiaThis分享或者多说分享，都是类似的操作，但是问题是这些分享貌似都不可用！

所以笔者采用的是addToAny_share这种方式，这时候只需要将取消上面的特定注释即可。而如果大家还想添加其他类型的分享，也可以使用下面的办法：
首先访问网站[https://www.addtoany.com/share#url=https%3A%2F%2Fwww.addtoany.com%2F](https://www.addtoany.com/share#url=https%3A%2F%2Fwww.addtoany.com%2F)

然后画面中会出现下列分享位置
![分享地址图片](/images/2017-06-20/share.jpg)

点击某个想分享的地址后，页面会出现类似
https://www.addtoany.com/add_to/wechat?url=.....

大家只需要将add_to/后的名字填到addToAny_share后面即可，注意使用yaml语法，也即空两格，横线，空格，分享名


