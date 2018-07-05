---
title: python静态编译
date: 2017-12-05 01:09:50
categories: code
tags: python
---

### 0. 前言

为什么要将python编译器静态编译，主要有以下几个目的：

1. 在其他不具备python环境下的主机上运行python程序
2. 在不具备相同python库的主机上运行python程序

### 1. 工具集

到目前为止我找到了两个工具集合：

#### 1.1 静态编译的python解释器

这是pts大佬的一个工程 [https://github.com/pts/staticpython](https://github.com/pts/staticpython) ， 在该工程中，大佬给出了静态编译脚本，以及最终的release版本！

#### 1.2 结合cython的静态解释器

这个工程也十分庞大，作者结合[http://mdqinc.com/blog/2011/08/statically-linking-python-with-cython-generated-modules-and-packages/](http://mdqinc.com/blog/2011/08/statically-linking-python-with-cython-generated-modules-and-packages/) 这篇文章的思路，完成了[static-python](https://github.com/bendmorris/static-python) 这个工程。

该工程需要用户根据需求，自行设置静态编译后的解释器所包含的库内容！（由于没有实测，只是觉得这样做不太友好，而且中间应该会有不少bug）

但是该工程有一个及其牛逼之处，就是它可以根据独立的py脚本，生成该脚本的静态编译后的二进制文件。

### 2. 自行编译

对于python解释器的编译，我做了N多次实验，但是基本上没有一次成功的。很多时候会缺少某些库文件，甚至有时编译都通不过。所以，这儿仅结合所看到的一些文章，给出一定的猜想。

#### 2.1 实验环境

docker + centos:6 + python-2.7.6.tgz

#### 2.2 实验参考文献

[https://gist.github.com/ajdavis/9632280](https://gist.github.com/ajdavis/9632280)

[https://blog.fluyy.net/post/2016-01-09-static_python](https://blog.fluyy.net/post/2016-01-09-static_python)

[https://wiki.python.org/moin/BuildStatically](https://wiki.python.org/moin/BuildStatically)

[https://askubuntu.com/questions/63711/building-a-static-version-of-python](https://askubuntu.com/questions/63711/building-a-static-version-of-python)

[http://xiaoxia.org/2013/09/13/python-on-tomato/](http://xiaoxia.org/2013/09/13/python-on-tomato/)

[https://codeday.me/bug/20170923/75551.html](https://codeday.me/bug/20170923/75551.html)

#### 2.3 实验步骤

##### 2.3.1 安装镜像源

用docker运行centos:6的环境

> 宿主机：docker run -it --net="host" -d centos:6
>
> 宿主机：docker exec -it container-id /bin/bash

安装镜像源

> 宿主机：wget -O CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo
>
> 宿主机：docker cp CentOS-Base.repo container-id:/etc/yum.repos.d/CentOS-Base.repo
>
> 容器：yum makecache

##### 2.3.2 软件安装

安装基本软件wget、vi等(视情况而定)

安装必要软件glibc-static zlib-static

> 容器：yum install glibc-static zlib-static

##### 2.3.3 编译

在配置之前，我们需要修改Modules/Setup文件：

```
 #*shared* 注释掉这一行
 *static*  添加这一行
```

编译

> 容器：./configure  --disable-shared --enable-profiling --prefix=/path/to/mypy LDFLAGS="-static -static-libgcc" CPPFLAGS="-static"
>
> 容器：make

这个过程会出现问题

```
/usr/bin/ld: dynamic STT_GNU_IFUNC symbol strcmp' with pointer equality in/usr/lib/gcc/x86_64-redhat-linux/4.4.7/../../../../lib64/libc.a(strcmp.o)' can not be used when making an executable; recompile with -fPIE and relink with -pie
```

说实在的，网上没有一篇文章提到如何解决这个问题，所以这个地方我不管了！

我直接做

```
gcc -pthread -static -static-libgcc -o python.exe Modules/python.o libpython2.7.a -lpthread -ldl  -lutil -lm -lz
```

##### 2.3.4 排错

上述操作完成之后，确确实实会出现python.exe文件，但是我们运行的时候，会报错：

```
Could not find platform dependent libraries <exec_prefix>
Consider setting $PYTHONHOME to <prefix>[:<exec_prefix>]
Traceback (most recent call last):
  File "/root/Python-2.7.6/Lib/site.py", line 548, in <module>
    main()
  File "/root/Python-2.7.6/Lib/site.py", line 530, in main
    known_paths = addusersitepackages(known_paths)
  File "/root/Python-2.7.6/Lib/site.py", line 266, in addusersitepackages
    user_site = getusersitepackages()
  File "/root/Python-2.7.6/Lib/site.py", line 241, in getusersitepackages
    user_base = getuserbase() # this will also set USER_BASE
  File "/root/Python-2.7.6/Lib/site.py", line 231, in getuserbase
    USER_BASE = get_config_var('userbase')
  File "/root/Python-2.7.6/Lib/sysconfig.py", line 517, in get_config_var
    return get_config_vars().get(name)
  File "/root/Python-2.7.6/Lib/sysconfig.py", line 469, in get_config_vars
    _init_posix(_CONFIG_VARS)
  File "/root/Python-2.7.6/Lib/sysconfig.py", line 352, in _init_posix
    from _sysconfigdata import build_time_vars
ImportError: No module named _sysconfigdata
```

没有发现\_sysconfigdata.py文件！原因是因为，编译的时候没有正确通过，所以不是产生\_sysconfigdata.py文件！（是不是觉得这个问题是个死结。。。）

解决办法一：

Lib/_sysconfig.py

```python
def _init_posix(vars):
    #from _sysconfigdata import build_time_vars  #注释掉
    #vars.update(build_time_vars)   #注释掉
    pass #添加pass
```

Lib/distuyils/sysconfig.py

```python
def _init_posix():
    #from _sysconfigdata import build_time_vars   #注释掉
    global _config_vars
    _config_vars = {}
    #_config_vars.update(build_time_vars)   #注释掉
```



解决办法二：

找到一个已经编译好的python文件，找到其中的_sysconfig.py文件，直接将其拷贝至实验环境中。



解决办法一，虽然可以让python.exe顺利执行，但是所有包管理都不会成功，这是因为build_time_vars中有一些环境设置，这个是找到对应的包文件的重要凭据。

解决办法二，虽然这个办法看起来靠谱，但是这里忽略了对_sysconfigdata.py中build_time_vars字典的理解与修改过程。这个任务也挺复杂的，所以我没来得及做。