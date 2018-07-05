---
title: php全局变量
date: 2017-08-27 23:35:21
categories: web
tags: php
---



### php全局变量

#### $\_REQUEST

$\_REQUEST 收集GET或者POST数据，如果GET和POST同时有数据，则优先取POST数据。使用超级全局变量 $_REQUEST 来收集 input 标签的值。此例是使用本文件处理表单！

```
<html>
<body>

<form method="post" action="<?php echo $_SERVER['PHP_SELF'];?>">
Name: <input type="text" name="fname">
<input type="submit">
</form>

<?php 
$name = $_REQUEST['fname']; 
echo $name; 
?>

</body>
</html>
```

#### $\_POST

$\_POST  广泛用于收集提交 method="post" 的 HTML 表单后的表单数据。$_POST 也常用于传递变量。

#### $\_GET

$_GET   可用于收集提交 HTML 表单 (method="get") 之后的表单数据。也可以收集 URL 中的发送的数据。

#### $\_COOKIE

$\_COOKIE    用于取回 cookie 的值。

#### $\_SESSION

$\_SESSION   存储和取回 session 变量

session中的变量不能通过请求来传递，但是可以响应时通过PHP处理函数进行赋值，而且如果想全局使用，必须加上session_start();

#### $GLOBALS

$GLOBALS 引用全局作用域中可用的全部变量

```
<?php 
$x = 75; 
$y = 25;
 
function addition() { 
  $GLOBALS['z'] = $GLOBALS['x'] + $GLOBALS['y']; 
}
 
addition(); 
echo $z; 
?>
```

#### $\_SERVER

$_SERVER 保存关于报头、路径和脚本位置的信息



| 元素/代码                                    | 描述                                       |
| ---------------------------------------- | ---------------------------------------- |
| $_SERVER['PHP_SELF']                     | 返回当前执行脚本的文件名。<br>http://example.com/test.php/foo.bar 的脚本中使用 $_SERVER['PHP_SELF'] 将得到 /test.php/foo.bar |
| $_SERVER['argv']                         | 传递给该脚本的参数的数组。当脚本以命令行方式运行时，argv 变量传递给程序 C 语言样式的命令行参数。当通过 GET 方式调用时，该变量包含query string。 |
| $_SERVER['argc']                         | 包含命令行模式下传递给该脚本的参数的数目(如果运行在命令行模式下)。       |
| $_SERVER['GATEWAY_INTERFACE']            | 返回服务器使用的 CGI 规范的版本。                      |
| $_SERVER['SERVER_ADDR']                  | 返回当前运行脚本<font color=#f00>所在的服务器的 IP 地址。</font> |
| $_SERVER['SERVER_NAME']                  | 返回当前运行脚本所在的服务器的主机名（比如 www.w3school.com.cn）。如果脚本运行于虚拟主机中，该名称是由那个虚拟主机所设置的值决定。<br>**Note**: 在 Apache 2 里，必须设置 *UseCanonicalName = On* 和 *ServerName*。 否则该值会由客户端提供，就有可能被伪造。 上下文有安全性要求的环境里，不应该依赖此值。 |
| $_SERVER['SERVER_SOFTWARE']              | 返回服务器标识字符串,在响应请求时的头信息中给出（比如 Apache/2.2.24）。 |
| $_SERVER['SERVER_PROTOCOL']              | 返回请求页面时通信协议的名称和版本（例如，“HTTP/1.0”）。        |
| $_SERVER['REQUEST_METHOD']               | 返回访问页面使用的请求方法（例如 POST/HEAD/PUT/GET）。<br>**Note**:如果请求方法为 *HEAD*，PHP 脚本将在发送 Header 头信息之后终止(这意味着在产生任何输出后，不再有输出缓冲)。 |
| $_SERVER['REQUEST_TIME']                 | 返回请求开始时的时间戳（例如 1577687494）。>5.1.0        |
| $_SERVER['REQUEST_TIME_FLOAT']           | 返回请求开始时的时间戳，微秒级别的精准度。>5.4.0              |
| $_SERVER['DOCUMENT_ROOT']                | 当前运行脚本所在的文档根目录。在服务器配置文件中定义。              |
| $_SERVER['QUERY_STRING']                 | 返回查询字符串，如果是通过查询字符串访问此页面。                 |
| $_SERVER['HTTP_ACCEPT']                  | 返回来自当前请求的请求头。                            |
| $_SERVER['HTTP_ACCEPT_CHARSET']          | 返回来自当前请求的 Accept-Charset 头（ 例如 utf-8,ISO-8859-1） |
| $_SERVER['HTTP_ACCEPT_LANGUAGE']         | 当前请求头中 Accept-Language: 项的内容，如果存在的话。例如：“en”。 |
| $_SERVER['HTTP_ACCEPT_ENCODING']         | 当前请求的 Accept-Encoding: 头部的内容。例如：“gzip”。  |
| $_SERVER['HTTP_CONNECTION']              | 当前请求头中 Connection: 项的内容，如果存在的话。例如：“Keep-Alive”。 |
| $_SERVER['HTTP_HOST']                    | 返回来自当前请求的 Host 头。                        |
| $_SERVER['HTTP_REFERER']                 | 引导用户代理到当前页的前一页的地址（如果存在）。由 user agent 设置决定。并不是所有的用户代理都会设置该项，有的还提供了修改 HTTP_REFERER 的功能。简言之，该值并不可信。 |
| $_SERVER['HTTP_USER_AGENT']              | 当前请求头中 User-Agent: 项的内容，如果存在的话。该字符串表明了访问该页面的用户代理的信息。一个典型的例子是：Mozilla/4.5 [en] (X11; U; Linux 2.2.9 i586)。除此之外，你可以通过 get_browser() 来使用该值，从而定制页面输出以便适应用户代理的性能。 |
| $_SERVER['HTTPS']                        | 是否通过安全 HTTP 协议查询脚本。<br>**Note**: 注意当使用 IIS 上的 ISAPI 方式时，如果不是通过 HTTPS 协议被访问，这个值将为 *off*。 |
| $_SERVER['HTTP_VIA']                     | 返回Via中的代理服务器IP                           |
| $_SERVER['HTTP_CLIENT_IP']               | 返回Client-IP中的客户端IP                       |
| $_SERVER['REMOTE_ADDR']                  | 返回浏览当前页面的用户的 IP 地址。                      |
| $_SERVER['HTTP_X\_FORWARDED\_FOR']       | 返回X-Forwarded-For内容                      |
| $_SERVER['REMOTE_HOST']                  | 返回浏览当前页面的用户的主机名。<br>**Note**: 你的服务器必须被配置以便产生这个变量。例如在 Apache 中，你需要在 httpd.conf 中设置 *HostnameLookups On* 来产生它。参见 [gethostbyaddr()](http://php.net/manual/zh/function.gethostbyaddr.php)。 |
| $_SERVER['REMOTE_PORT']                  | 返回用户机器上连接到 Web 服务器所使用的端口号。               |
| $_SERVER['REMOTE_USER']                  | 经验证的用户                                   |
| $_SERVER['REDIRECT_REMOTE_USER']         | 验证的用户，如果请求已在内部重定向。                       |
| $_SERVER['SCRIPT_FILENAME']              | 返回当前执行脚本的绝对路径。<br>**Note**:如果在命令行界面（Command Line Interface, CLI）使用相对路径执行脚本，例如 file.php 或 ../file.php，那么 $_SERVER['SCRIPT_FILENAME'] 将包含用户指定的相对路径。 |
| $_SERVER['SERVER_ADMIN']                 | 该值指明了 Apache 服务器配置文件中的 SERVER_ADMIN 参数。如果脚本运行在一个虚拟主机上，则该值是那个虚拟主机的值。 |
| $_SERVER['SERVER_PORT']                  | Web 服务器使用的端口。默认值为 “*80*”。如果使用 SSL 安全连接，则这个值为用户设置的 HTTP 端口。<br>**Note**: 在 Apache 2 里，为了获取真实物理端口，必须设置 *UseCanonicalName = On* 以及 *UseCanonicalPhysicalPort = On*。 否则此值可能被伪造，不一定会返回真实端口值。 上下文有安全性要求的环境里，不应该依赖此值。 |
| $_SERVER['SERVER_SIGNATURE']             | 返回服务器版本和虚拟主机名。                           |
| $_SERVER['PATH_TRANSLATED']              | 当前脚本所在文件系统（非文档根目录）的基本路径。这是在服务器进行虚拟到真实路径的映像后的结果。<br>**Note**: 自 PHP 4.3.2 起，PATH_TRANSLATED 在 Apache 2 SAPI 模式下不再和 Apache 1 一样隐含赋值，而是若 Apache 不生成此值，PHP 便自己生成并将其值放入 SCRIPT_FILENAME 服务器常量中。这个修改遵守了 CGI 规范，PATH_TRANSLATED 仅在 PATH_INFO 被定义的条件下才存在。 Apache 2 用户可以在 httpd.conf 中设置 *AcceptPathInfo = On* 来定义 PATH_INFO。 |
| $_SERVER['SCRIPT_NAME']                  | 返回当前脚本的路径                                |
| $_SERVER['SCRIPT_URI']                   | 返回当前页面的 URI。                             |
| $_SERVER['HTTP_UPGRADE_INSECURE_REQUESTS'] | 返回Upgrade-Insecure-Requests中的数据          |
| $_SERVER["HTTP_CACHE_CONTROL"]           | 返回Cache-Control中的数据                      |
| 'PHP_AUTH_DIGEST'                        | 当作为 Apache 模块运行时，进行 HTTP Digest 认证的过程中，此变量被设置成客户端发送的“Authorization” HTTP 头内容（以便作进一步的认证操作）。 |
| 'PHP_AUTH_USER'                          | 当 PHP 运行在 Apache 或 IIS（PHP 5 是 ISAPI）模块方式下，并且正在使用 HTTP 认证功能，这个变量便是用户输入的用户名。 |
| 'PHP_AUTH_PW'                            | 当 PHP 运行在 Apache 或 IIS（PHP 5 是 ISAPI）模块方式下，并且正在使用 HTTP 认证功能，这个变量便是用户输入的密码。 |
| 'AUTH_TYPE'                              | 当 PHP 运行在 Apache 模块方式下，并且正在使用 HTTP 认证功能，这个变量便是认证的类型。 |
| 'PATH_INFO'                              | 包含由客户端提供的、跟在真实脚本名称之后并且在查询语句（query string）之前的路径信息，如果存在的话。例如，如果当前脚本是通过 URL http://www.example.com/php/path_info.php/some/stuff?foo=bar 被访问，那么 $_SERVER['PATH_INFO'] 将包含 /some/stuff。 |
| 'ORIG_PATH_INFO'                         | 在被 PHP 处理之前，“PATH_INFO” 的原始版本。           |

#### $\_FILES


$_FILES 可以从客户计算机向远程服务器上传文件。
    第一个参数是表单的 input name，第二个下标可以是 "name", "type", "size", "tmp_name" 或 "error"
    例子：        
        $_FILES["file"]["name"] - 被上传文件的名称
        $_FILES["file"]["type"] - 被上传文件的类型
        $_FILES["file"]["size"] - 被上传文件的大小，以字节计
        $_FILES["file"]["tmp_name"] - 存储在服务器的文件的临时副本的名称
        $_FILES["file"]["error"] - 由文件上传导致的错误代码

#### $\_ENV

$_ENV   通过环境方式传递给当前脚本的变量的数组。

这些变量被从 PHP 解析器的运行环境导入到 PHP 的全局命名空间。很多是由支持 PHP 运行的 Shell 提供的，并且不同的系统很可能运行着不同种类的 Shell，所以不可能有一份确定的列表。请查看你的 Shell 文档来获取定义的环境变量列表。
其他环境变量包含了 CGI 变量，而不管 PHP 是以服务器模块还是 CGI 处理器的方式运行。

| 元素/代码                           | 描述                                       |
| ------------------------------- | ---------------------------------------- |
| $_ENV["ALLUSERSPROFILE"]        | C:\Documents and Settings\All Users      |
| $_ENV["ClusterLog"]             | C:\WINDOWS\Cluster\cluster.log           |
| $_ENV["CommonProgramFiles"]     | C:\Program Files\Common Files            |
| $_ENV["COMPUTERNAME"]           | LIUBO                                    |
| $_ENV["ComSpec"]                | C:\WINDOWS\system32\cmd.exe              |
| $_ENV["FP_NO_HOST_CHECK"]       | NO                                       |
| $_ENV["NUMBER_OF_PROCESSORS"]   | 1                                        |
| $_ENV["OS"]                     | Windows_NT                               |
| $_ENV["Path"]                   | C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;E:\Program Files\MySQL\MySQL Server 5.0\bin;c:\php;c:\php\ext |
| $_ENV["PATHEXT"]                | .COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH |
| $_ENV["PROCESSOR_ARCHITECTURE"] | x86                                      |
| $_ENV["PROCESSOR_IDENTIFIER"]   | x86 Family 15 Model 4 Stepping 1, GenuineIntel |
| $_ENV["PROCESSOR_LEVEL"]        | 15                                       |
| $_ENV["PROCESSOR_REVISION"]     | 0401                                     |
| $_ENV["ProgramFiles"]           | C:\Program Files                         |
| $_ENV["SystemDrive"]            | C:                                       |
| $_ENV["SystemRoot"]             | C:\WINDOWS                               |
| $_ENV["TEMP"]                   | d:\                                      |
| $_ENV["TMP"]                    | d:\                                      |
| $_ENV["USERPROFILE"]            | C:\Documents and Settings\Default User   |
| $_ENV["windir"]                 | C:\WINDOWS                               |

