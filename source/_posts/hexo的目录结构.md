---
title: hexo的目录结构
date: 2017-06-20 10:37:13
categories: Hexo搭建博客网站
tags: hexo
---

由于上一篇博文的要求，所以需要整理一下hexo的目录结构，了解hexo每个目录的作用，并且设置全局配置文件 _config.yml 的相关参数，初步定义属于你自己的博客。

### 1.主目录结构

主目录，简洁明了

    |-- _config.yml
    |-- package.json
    |-- scaffolds
    |-- scripts
    |-- source
       |-- _drafts
       |-- _posts
    |-- themes

### 2.主目录介绍

#### _config.yml

全局配置文件，网站的很多信息都在这里配置，诸如网站名称，副标题，描述，作者，语言，主题，部署等等参数。这个文件下面会做较为详细的介绍。

#### package.json

hexo框架的参数，如果不小心把它删掉了，没关系，新建一个文件，将内容写入文件，保存就OK了。里面的参数基本上是固定的，如下：

    {
      "name": "hexo-site",
      "version": "0.0.0",
      "private": true,
      "hexo": {
        "version": "3.3.7"
      },
      "dependencies": {
        "hexo": "^3.2.0",
        "hexo-deployer-git": "^0.3.0",
        "hexo-generator-archive": "^0.1.4",
        "hexo-generator-baidu-sitemap": "^0.1.2",
        "hexo-generator-category": "^0.1.3",
        "hexo-generator-feed": "^1.2.0",
        "hexo-generator-index": "^0.2.0",
        "hexo-generator-json-content": "^2.2.0",
        "hexo-generator-sitemap": "^1.2.0",
        "hexo-generator-tag": "^0.2.0",
        "hexo-renderer-ejs": "^0.2.0",
        "hexo-renderer-jade": "^0.4.1",
        "hexo-renderer-marked": "^0.2.10",
        "hexo-renderer-stylus": "^0.3.3",
        "hexo-server": "^0.2.0"
      }
    }

参数也很容易理解，一看就明白，该文件基本上也不需要操作，就不多解释了。

#### scaffolds

scaffolds是“脚手架、骨架”的意思，当你新建一篇文章（hexo new 'title'）的时候，hexo是根据这个目录下的文件进行构建的。基本不用关心。一般而言会有三个不同的选择，分别是draft、post、page三个模板，其中可以自定义需要的项目：

    ---
    title: {{ title }}
    date: {{ date }}
    categories:
    tags:
    ---

#### scripts

脚本目录，此目录下的JavaScript文件会被自动执行。

#### source

这个目录很重要，新建的文章都是在保存在这个目录下的，有两个子目录： _drafts ， _posts 。需要新建的博文都放在 _posts 目录下。

_posts 目录下是一个个 markdown 文件。你应该可以看到一个 hello-world.md 的文件，文章就在这个文件中编辑。

_posts 目录下的md文件，会被编译成html文件，放到 public （此文件现在应该没有，因为你还没有编译过）文件夹下。

#### themes

网站主题目录，hexo有非常好的主题拓展，支持的主题也很丰富。该目录下，每一个子目录就是一个主题，我的子目录如下：

    |-- landscape
       |--
    |-- BlueLake
       |--

我装了两个主题， landscape 是我这个hexo版本的默认主题，我自己下载了一个 BlueLake 主题。

你也可以自己下载主题放到该文件下， [hexo主题传送门](https://github.com/tommy351/hexo/wiki/Themes)

主题目录下我们可以进行很多自定义的操作，诸如，给网站添加微博秀、添加评论组件、添加分享组件、添加统计等等，让自己的博客网站更丰富、有趣、实用。

themes目录结构及优化自己的博客，这些内容我会在下一篇博文中介绍。

#### node_module
这个目录下存放是通过nodejs下载的相应的hexo插件。

4.后记

好了，本地运行一下

hexo server
浏览器访问 localhost:4000/ ，网站的标题，副标题等信息是不是都已经更改了！恭喜你，对自己的博客网站的简单的全局设置已经成功了。