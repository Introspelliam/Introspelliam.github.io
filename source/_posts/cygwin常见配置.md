---
title: cygwin常见配置
date: 2018-03-12 22:59:53
categories: tool
tags: cygwin
---

cygwin作为windows下轻便快捷的linux系统，一直深受用户喜爱！当然，现在不少同学也喜欢用xshell连接虚拟机，这样也挺方便的。唯一的不足就是，开启虚拟机需要耗费不小的内存、cpu，这样会影响性能。所以若有替代虚拟机的办法，我尽量会使用替代方式。

### 1. cygwin初始安装须知

cygwin安装时需要安装一系列初始包，太多初始包会使安装时间过长、安装不稳定，故而经常性导致出错导致重新安装，这样十分浪费时间。所以初始安装包时，尽量只安装必要的软件。

- vi、vim、curl、wget、tar、gawk、bzip2、git等

### 2. cygwin包管理软件apt-cyg

```shell
git clone https://github.com/transcode-open/apt-cyg.git
cd apt-cyg
cp apt-cyg /bin/
chmod +x /bin/apt-cyg
```

之后安装，都类似于apt-get

我的源地址： http://mirror.rit.edu/cygwin/

换源：找到/etc/setup/setup.rc中最后几行，将last-mirror中的源换掉

### 3. 必要的安装环节

```shell
apt-cyg install python2
apt-cyg install python3
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
```

上面环节安装了python以及pip，但是如何知道使用的pip是不是cygwin中的呢？

```
ls /bin/ | grep "pip"  #查找/bin/中存在的pip指令，一般会有pip2、pip3
which pip   # 查看pip使用的是哪个地址，有时候会使用windows环境下的pip
```

我的环境中只能使用pip2，使用pip时会直接调用windows下的pip指令，导致下载的内容没用放到cygwin中，也即下载之后根本不能用。

### 4. pip2下载pillow时遇到的问题

下载pillow时会提示如下的内容

```
Can't find lcms2.pc in any of /usr/local/lib/pkgconfig /usr/local/share/pkgconfig /usr/lib/pkgconfig /usr/share/pkgconfig use the PKG_CONFIG_PATH environment variable, or specify extra search paths via 'search_paths'
```

总共有以下的文件没被找到：

```
lcms2.pc
libtiff-5.pc
libtiff-4.pc
freetype2.pc
libimagequant.pc
libjpeg.pc
libopenjp2.pc
zlib.pc
Python.h
```

这时使用

```
apt-cyg install libglib2.0-devel
apt-cyg install liblcms2-devel
apt-cyg install libtiff-devel
apt-cyg install libjpeg-devel
apt-cyg install libimagequant-devel
apt-cyg install libopenjp2-devel
apt-cyg install python2-devel
```

之后仍未找到Python.h，这是因为全局变量PATH没有修正：

```
find / -name "Python.h"  # 找到Python.h对应的位置
PATH=$PATH:Python.h所在文件夹
```

最后发现是gcc使用的window中的gcc，而不是cygwin中的gcc（其实没装）

```
apt-cyg install gcc-core
apt-cyg install gcc-g++
```



