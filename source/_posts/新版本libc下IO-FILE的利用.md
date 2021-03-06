---
title: 新版本libc下IO_FILE的利用
date: 2018-07-05 11:03:51
categories: pwn
tags: IO_FILE
---

# 新版本libc下IO_FILE的利用

## 介绍

在最新版本的glibc中(2.24)，全新加入了针对IO_FILE_plus的vtable劫持的检测措施，glibc 会在调用虚函数之前首先检查vtable地址的合法性。

如果vtable是非法的，那么会引发abort。

首先会验证vtable是否位于_IO_vtable段中，如果满足条件就正常执行，否则会调用_IO_vtable_check做进一步检查。

这里的检查使得以往使用vtable进行利用的技术很难实现

## 新的利用技术

在vtable难以被利用之后，利用的关注点从vtable转移到_IO_FILE结构内部的域中。 前面介绍过_IO_FILE在使用标准IO库时会进行创建并负责维护一些相关信息，其中有一些域是表示调用诸如fwrite、fread等函数时写入地址或读取地址的，如果可以控制这些数据就可以实现任意地址写或任意地址读。

```
struct _IO_FILE {
  int _flags;       /* High-order word is _IO_MAGIC; rest is flags. */
  /* The following pointers correspond to the C++ streambuf protocol. */
  /* Note:  Tk uses the _IO_read_ptr and _IO_read_end fields directly. */
  char* _IO_read_ptr;   /* Current read pointer */
  char* _IO_read_end;   /* End of get area. */
  char* _IO_read_base;  /* Start of putback+get area. */
  char* _IO_write_base; /* Start of put area. */
  char* _IO_write_ptr;  /* Current put pointer. */
  char* _IO_write_end;  /* End of put area. */
  char* _IO_buf_base;   /* Start of reserve area. */
  char* _IO_buf_end;    /* End of reserve area. */
  /* The following fields are used to support backing up and undo. */
  char *_IO_save_base; /* Pointer to start of non-current get area. */
  char *_IO_backup_base;  /* Pointer to first valid character of backup area */
  char *_IO_save_end; /* Pointer to end of non-current get area. */

  struct _IO_marker *_markers;

  struct _IO_FILE *_chain;

  int _fileno;
  int _flags2;
  _IO_off_t _old_offset; /* This used to be _offset but it's too small.  */
};
```

因为进程中包含了系统默认的三个文件流stdin\stdout\stderr，因此这种方式可以不需要进程中存在文件操作，通过scanf\printf一样可以进行利用。

在_IO_FILE中_IO_buf_base表示操作的起始地址，_IO_buf_end表示结束地址，通过控制这两个数据可以实现控制读写的操作。

## 示例

简单的观察一下_IO_FILE对于调用scanf的作用

```
#include "stdio.h"

char buf[100];

int main()
{
 char stack_buf[100];
 scanf("%s",stack_buf);
 scanf("%s",stack_buf);

}
```

在执行程序第一次使用stdin之前，stdin的内容还未初始化是空的

```
0x7ffff7dd18e0 <_IO_2_1_stdin_>:    0x00000000fbad2088  0x0000000000000000
0x7ffff7dd18f0 <_IO_2_1_stdin_+16>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1900 <_IO_2_1_stdin_+32>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1910 <_IO_2_1_stdin_+48>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1920 <_IO_2_1_stdin_+64>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1930 <_IO_2_1_stdin_+80>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1940 <_IO_2_1_stdin_+96>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1950 <_IO_2_1_stdin_+112>:    0x0000000000000000  0xffffffffffffffff
0x7ffff7dd1960 <_IO_2_1_stdin_+128>:    0x0000000000000000  0x00007ffff7dd3790
0x7ffff7dd1970 <_IO_2_1_stdin_+144>:    0xffffffffffffffff  0x0000000000000000
0x7ffff7dd1980 <_IO_2_1_stdin_+160>:    0x00007ffff7dd19c0  0x0000000000000000
0x7ffff7dd1990 <_IO_2_1_stdin_+176>:    0x0000000000000000  0x0000000000000000
0x7ffff7dd19a0 <_IO_2_1_stdin_+192>:    0x0000000000000000  0x0000000000000000
0x7ffff7dd19b0 <_IO_2_1_stdin_+208>:    0x0000000000000000  0x00007ffff7dd06e0 <== vtable
```

调用scanf之后可以看到_IO_read_ptr、_IO_read_base、_IO_read_end、_IO_buf_base、_IO_buf_end等域都被初始化

```
0x7ffff7dd18e0 <_IO_2_1_stdin_>:    0x00000000fbad2288  0x0000000000602013
0x7ffff7dd18f0 <_IO_2_1_stdin_+16>: 0x0000000000602014  0x0000000000602010
0x7ffff7dd1900 <_IO_2_1_stdin_+32>: 0x0000000000602010  0x0000000000602010
0x7ffff7dd1910 <_IO_2_1_stdin_+48>: 0x0000000000602010  0x0000000000602010
0x7ffff7dd1920 <_IO_2_1_stdin_+64>: 0x0000000000602410  0x0000000000000000
0x7ffff7dd1930 <_IO_2_1_stdin_+80>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1940 <_IO_2_1_stdin_+96>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1950 <_IO_2_1_stdin_+112>:    0x0000000000000000  0xffffffffffffffff
0x7ffff7dd1960 <_IO_2_1_stdin_+128>:    0x0000000000000000  0x00007ffff7dd3790
0x7ffff7dd1970 <_IO_2_1_stdin_+144>:    0xffffffffffffffff  0x0000000000000000
0x7ffff7dd1980 <_IO_2_1_stdin_+160>:    0x00007ffff7dd19c0  0x0000000000000000
0x7ffff7dd1990 <_IO_2_1_stdin_+176>:    0x0000000000000000  0x0000000000000000
0x7ffff7dd19a0 <_IO_2_1_stdin_+192>:    0x00000000ffffffff  0x0000000000000000
0x7ffff7dd19b0 <_IO_2_1_stdin_+208>:    0x0000000000000000  0x00007ffff7dd06e0
```

进一步思考可以发现其实stdin初始化的内存是在堆上分配出来的，在这里堆的基址是0x602000，因为之前没有堆分配因此缓冲区的地址也是0x602010

```
Start              End                Offset             Perm Path
0x0000000000400000 0x0000000000401000 0x0000000000000000 r-x /home/vb/桌面/tst/1/t1
0x0000000000600000 0x0000000000601000 0x0000000000000000 r-- /home/vb/桌面/tst/1/t1
0x0000000000601000 0x0000000000602000 0x0000000000001000 rw- /home/vb/桌面/tst/1/t1
0x0000000000602000 0x0000000000623000 0x0000000000000000 rw- [heap]
```

分配的堆大小是0x400个字节，正好对应于_IO_buf_base～_IO_buf_end 在进行写入后，可以看到缓冲区中有我们写入的数据，之后目的地址栈中的缓冲区也会写入数据

```
0x602000:   0x0000000000000000  0x0000000000000411 <== 分配0x400大小
0x602010:   0x000000000a333231  0x0000000000000000 <== 缓冲数据
0x602020:   0x0000000000000000  0x0000000000000000
0x602030:   0x0000000000000000  0x0000000000000000
0x602040:   0x0000000000000000  0x0000000000000000
```

接下来我们尝试修改_IO_buf_base来实现任意地址读写，全局缓冲区buf的地址是0x7ffff7dd2740。修改_IO_buf_base和_IO_buf_end到缓冲区buf的地址

```
0x7ffff7dd18e0 <_IO_2_1_stdin_>:    0x00000000fbad2288  0x0000000000602013
0x7ffff7dd18f0 <_IO_2_1_stdin_+16>: 0x0000000000602014  0x0000000000602010
0x7ffff7dd1900 <_IO_2_1_stdin_+32>: 0x0000000000602010  0x0000000000602010
0x7ffff7dd1910 <_IO_2_1_stdin_+48>: 0x0000000000602010  0x00007ffff7dd2740 <== _IO_buf_base
0x7ffff7dd1920 <_IO_2_1_stdin_+64>: 0x00007ffff7dd27c0  0x0000000000000000 <== _IO_buf_end
0x7ffff7dd1930 <_IO_2_1_stdin_+80>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1940 <_IO_2_1_stdin_+96>: 0x0000000000000000  0x0000000000000000
0x7ffff7dd1950 <_IO_2_1_stdin_+112>:    0x0000000000000000  0xffffffffffffffff
0x7ffff7dd1960 <_IO_2_1_stdin_+128>:    0x0000000000000000  0x00007ffff7dd3790
0x7ffff7dd1970 <_IO_2_1_stdin_+144>:    0xffffffffffffffff  0x0000000000000000
0x7ffff7dd1980 <_IO_2_1_stdin_+160>:    0x00007ffff7dd19c0  0x0000000000000000
0x7ffff7dd1990 <_IO_2_1_stdin_+176>:    0x0000000000000000  0x0000000000000000
0x7ffff7dd19a0 <_IO_2_1_stdin_+192>:    0x00000000ffffffff  0x0000000000000000
0x7ffff7dd19b0 <_IO_2_1_stdin_+208>:    0x0000000000000000  0x00007ffff7dd06e0
```

之后scanf的读入数据就会写入到0x7ffff7dd2740的位置

```
0x7ffff7dd2740 <buf>:   0x00000a6161616161  0x0000000000000000
0x7ffff7dd2750 <buffer>:    0x0000000000000000  0x0000000000000000
0x7ffff7dd2760 <buffer>:    0x0000000000000000  0x0000000000000000
0x7ffff7dd2770 <buffer>:    0x0000000000000000  0x0000000000000000
0x7ffff7dd2780 <buffer>:    0x0000000000000000  0x0000000000000000
```