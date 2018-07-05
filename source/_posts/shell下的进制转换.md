---
title: shell下的进制转换
date: 2017-09-09 21:44:35
categories: 安全技术
tags: [shell, linux]
---

最近一直在学filter绕过的姿势，所以急需shell下绕过的方法，其中关键的一环就是shell下的进制转换！

主要参考：

[https://stackoverflow.com/questions/1604765/linux-shell-scripting-hex-string-to-bytes](https://stackoverflow.com/questions/1604765/linux-shell-scripting-hex-string-to-bytes)

[https://stackoverflow.com/questions/6292645/convert-binary-data-to-hex-in-shell-script](https://stackoverflow.com/questions/6292645/convert-binary-data-to-hex-in-shell-script)

进制转换有多种工具，在linux上常见的有hexdump、od -x、xxd等

下面我们来简单介绍一下这些命令

### xxd

xxd比较常用，也比较好用

```shell
Usage:
       xxd [options] [infile [outfile]]
    or
       xxd -r [-s [-]offset] [-c cols] [-ps] [infile [outfile]]
Options:
    -a          toggle autoskip: A single '*' replaces nul-lines. Default off.
    -b          binary digit dump (incompatible with -ps,-i,-r). Default hex.
    -c cols     format <cols> octets per line. Default 16 (-i: 12, -ps: 30).
    -E          show characters in EBCDIC. Default ASCII.
    -e          little-endian dump (incompatible with -ps,-i,-r).
    -g          number of octets per group in normal output. Default 2 (-e: 4).
    -h          print this summary.
    -i          output in C include file style.
    -l len      stop after <len> octets.
    -o off      add <off> to the displayed file position.
    -ps         output in postscript plain hexdump style.
    -r          reverse operation: convert (or patch) hexdump into binary.
    -r -s off   revert with <off> added to file positions found in hexdump.
    -s [+][-]seek  start at <seek> bytes abs. (or +: rel.) infile offset.
    -u          use upper case hex letters.
    -v          show version: "xxd V1.10 27oct98 by Juergen Weigert".
    -p：以一个整块输出所有的hex， 不使用空格进行分割
```

上面的是xxd的用法，下面我们来逐步介绍！

>  将0x313233解释成123
>
>  root@test:/# echo 0x313233| xxd -r
>  123root@test:/#



> 将123解释成0x313233
>
> root@test:/# echo 123|xxd -ps
> 3132330a

<font color=#f00>需要注意的是，我们不能直接使用xxd -r 0x313233，原因是xxd后面只能接文件！而echo 123，并用管道连接，其实就是创建了一个临时文件交给xxd来处理</font>

#### 局限

​	每行有限定字符个数，xxd -ps限定每行最多有60个16进制数

​	而xxd -r则至多转换16个字符

#### 解决办法

```shell
root@test:/# echo "export FF=\"/tmp/flag\";cat \$FF;echo vunerable"|xxd -p
6578706f72742046463d222f746d702f666c6167223b636174202446463b
6563686f2076756e657261626c650a
root@test:/# echo "export FF=\"/tmp/flag\";cat \$FF;echo vunerable"|xxd -p|tr -d '\n'
6578706f72742046463d222f746d702f666c6167223b636174202446463b6563686f2076756e657261626c650aroot@test:/# 
```



```shell
root@test:/# echo "export FF=\"/tmp/flag\""|xxd -p
6578706f72742046463d222f746d702f666c6167220a
root@test:/# echo 0x6578706f72742046463d222f746d702f666c616722|xxd -rp
export FF="/tmp/root@test:/# echo 0x6578706f72742046463d222f746d702f666c616722|xxd -r -p
export FF="/tmp/flag"root@test:/# 
```

#### 注意

- 对于字符串转16进制中每行60个16进制的限制，可以使用echo 123|xxd -p|tr -d '\n'


- 对于16进制转字符串中至多转换16个字符的限制，可以使用xxd -r -p中的r和p一定得分开

#### 应用

```shell
root@test:/# echo "flag is here" > /tmp/flag
root@test:/# echo "\"export FF='/tmp/flag';cat \$FF\""|xxd -p|tr -d '\n'
226578706f72742046463d272f746d702f666c6167273b63617420244646220aroot@test:/# 
root@test:/# echo 0x226578706f72742046463d272f746d702f666c6167273b6361742024464622|xxd -r -p|xargs bash -c
flag is here
```

上面的应用综合利用了所学的知识，其中前两步是铺垫，最后一步才是真正的poc。需要注意的是bash -c 一定接字符串，而且该字符串需要用双引号括起来！



```shell
root@test:/# echo "flag is here" > /tmp/flag
root@test:/# echo "export FF='/tmp/flag';cat \$FF"|xxd -p|tr -d '\n'
6578706f72742046463d272f746d702f666c6167273b636174202446460aroot@test:/# 
root@test:/# echo 0x6578706f72742046463d272f746d702f666c6167273b63617420244646|xxd -r -p|bash -i
root@test:/# export FF='/tmp/flag';cat $FF
flag is here
root@test:/# exit
```

上面同样是十分完美的应用，主要特点是使用了bash -i，这相当于一个交互式的应用，管道线前面输出的内容会在这个交互中完成，完成后立刻退出！注意，管道线前面输出的内容不能用双引号括起来！

### perl的妙用

```
cat found | sed 's/.*: "//g;s/ .*//;s/^0*//' | xargs python -c 'import sys; print "".join([bin(int(x)).lstrip("0b") for x in sys.argv[1:]])' | perl -lpe '$_=pack("B*",$_)'
最后的代码意思是前面管道输入的01字符串打包成8字节的字符串

将A\B两种不同代码替换，并输出成字符串
echo ABBBAAAABBBBBABBABBBABBB | perl -pe 'BEGIN { binmode \*STDOUT } chomp; tr/AB/\0\1/; $_ = pack "B*", $_'
```

