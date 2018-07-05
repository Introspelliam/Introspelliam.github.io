---
title: python OS 文件/目录方法
date: 2017-09-04 21:28:26
categories: code
tags: python
---

**os** 模块提供了非常丰富的方法用来处理文件和目录。

#### [os.pipe()](http://www.runoob.com/python/os-pipe.html)

创建一个管道，返回一对文件描述符(r,w)分别为读和写

```python
stdinr,stdinw = os.pipe()
stderrr,stderrw = os.pipe()
os.write(stdinw, "\x00\x0a\x00\xff")
os.write(stderrw, "\x00\x0a\x02\xff")

proc = subprocess.Popen(["./input"] + args, env=dict(os.environ, **env), stdin=stdinr, stderr=stderrr)
```

> 上述表示从标准输入中读入"\x00\x0a\x00\xff"，从标准错误中读入"\x00\x0a\x02\xff"



#### [os.popen(command[, mode[, bufsize\]])](http://www.runoob.com/python/os-popen.html)

从一个 command 打开一个管道

- **command** -- 使用的命令。
- **mode** -- 模式权限可以是 'r'(默认) 或 'w'。
- **bufsize** -- 指明了文件需要的缓冲大小：0意味着无缓冲；1意味着行缓冲；其它正值表示使用参数大小的缓冲（大概值，以字节为单位）。负的bufsize意味着使用系统的默认值，一般来说，对于tty设备，它是行缓冲；对于其它文件，它是全缓冲。如果没有改参数，使用系统的默认值。

**返回值**

​	返回一个文件描述符号为fd的打开的文件对象



#### [os.open(file, flags[, mode])](http://www.runoob.com/python/os-open.html)

打开一个文件，并且设置需要的打开选项，mode参数是可选的

- **file** -- 要打开的文件
- **flags** -- 该参数可以是以下选项，多个使用 "|" 隔开：
  - **os.O_RDONLY:** 以只读的方式打开
  - **os.O_WRONLY:** 以只写的方式打开
  - **os.O_RDWR :** 以读写的方式打开
  - **os.O_NONBLOCK:** 打开时不阻塞
  - **os.O_APPEND:** 以追加的方式打开
  - **os.O_CREAT:** 创建并打开一个新文件
  - **os.O_TRUNC:** 打开一个文件并截断它的长度为零（必须有写权限）
  - **os.O_EXCL:** 如果指定的文件存在，返回错误
  - **os.O_SHLOCK:** 自动获取共享锁
  - **os.O_EXLOCK:** 自动获取独立锁
  - **os.O_DIRECT:** 消除或减少缓存效果
  - **os.O_FSYNC :** 同步写入
  - **os.O_NOFOLLOW:** 不追踪软链接
- **mode** -- 类似 [chmod()](http://www.runoob.com/python/os-chmod.html)。

**返回值**

返回新打开文件的描述符。



#### [os.read(fd, n)](http://www.runoob.com/python/os-read.html)

从文件描述符 fd 中读取最多 n 个字节，返回包含读取字节的字符串，文件描述符 fd对应文件已达到结尾, 返回一个空字符串。



#### [os.write(fd, str)](http://www.runoob.com/python/os-write.html)

写入字符串到文件描述符 fd中. 返回实际写入的字符串长度



#### [os.close(fd)](http://www.runoob.com/python/os-close.html)

关闭文件描述符 fd