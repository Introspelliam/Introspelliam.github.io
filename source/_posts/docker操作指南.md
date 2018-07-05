---
title: docker操作指南
date: 2017-09-28 00:21:40
categories: 虚拟化
tags: docker
---

### 1、运行ubuntu等容器

- 后台运行系统镜像

> docker run -it -d ubuntu

- 直接运行镜像，退出后这个镜像也停止

> docker run -it ubuntu

- 映射端口(22端口映射出来，一般代表可以通过ssh登录)

> docker run -it -p 80:80 2222:22 -d ubuntu

- 映射文件夹

> docker run -it -v /outer/tmp:/inner/tmp -d ubuntu

- 选择网络模式

> docker run -it --net="host" -d ubuntu

### 2、操作容器

- 直接运行命令

> docker exec -it Container-ID  /bin/cat flag

- attach到容器中（限制极大，多个终端同时进行操纵时，容易发生冲突）

> docker attach-it Container-ID

- 进入容器中运行指令

> docker exec -it Container-ID /bin/bash

- 从容器内拷贝文件到主机上

> docker cp \<containerId\>:/file/path/within/container /host/path/target 

- 从容器内拷贝文件到主机上

> docker cp /host/path/target  \<containerId\>:/file/path/within/container

### 3、网络模式

（1）    bridge模式

使用—net=bridge指定，为Docker的默认设置。这种模式是将容器用docker的网桥连接起来。

作为最常规的格式，bridge模式已经可以满足Docker容器最基本的使用需求。然而其在于外界通信使用NAT协议，增加了通信的复杂性，在复杂的场景下使用会有诸多限制。

（2）    host模式

host模式下，容器不会拥有自己的网络命名空间。Docker容器中的进程处于宿主机的网络环境中，此时Docker容器和宿主机之间网络没有映射关系，外界可以通过该主机的IP地址、端口等进行Docker容器的访问。当然，除了network namespace外，其他内容宿主机是隔离的。host模式不用地址映射，可以直接使用宿主机的IP。但是也降低了隔离性，而且由于网络资源一直被竞争，所以可能造成网络的短暂不可用问题。

（3）    container模式

container模式是指新创建的容器与已有的容器共享网络信息。在此种模式下，新创建的容器与指定的容器共享IP、端口等。当然，两个容器之间除了网络信息共享外，其它内容均不可共用。由于在这种模式下，两个容器的进程使用回环网卡通信，所以通讯速率加快了。container模式的主要用于部署多个相关的应用，最好能成为一个整体。由于container模式的特点，导致了这种模式隔离性不强，可能会存在安全隐患。

（4）    none模式

none模式时，Docker拥有网络协议栈，但是没有对协议栈进行配置。这时，Docker容器的网卡以及IP，均为用户所配置。一般而言，当未给使用这种模式的容器进行网络配置时，用户无法正常使用容器进程，但是优点也很明显，它给用户最大的自由度来自定义容器的网络环境。

### 4、docker CMD执行 容器内没有后台服务的概念

提到 CMD 就不得不提容器中应用在前台执行和后台执行的问题。这是初学者常出现的一个混
淆。

Docker 不是虚拟机，容器中的应用都应该以前台执行，而不是像虚拟机、物理机里面那样，

用 upstart/systemd 去启动后台服务，容器内没有后台服务的概念。

一些初学者将 CMD 写为：

>  CMD service nginx start

然后发现容器执行后就立即退出了。甚至在容器内去使用 systemctl 命令结果却发现根本执

行不了。这就是因为没有搞明白前台、后台的概念，没有区分容器和虚拟机的差异，依旧在

以传统虚拟机的角度去理解容器。

对于容器而言，其启动程序就是容器应用进程，容器就是为了主进程而存在的，主进程退

出，容器就失去了存在的意义，从而退出，其它辅助进程不是它需要关心的东西。

而使用 service nginx start 命令，则是希望 upstart 来以后台守护进程形式启动 nginx 服

务。而刚才说了 CMD service nginx start 会被理解为 CMD [ "sh", "-c", "service nginx

start"] ，因此主进程实际上是 sh 。那么当 service nginx start 命令结束后， sh 也就结

束了， sh 作为主进程退出了，自然就会令容器退出。

正确的做法是直接执行 nginx 可执行文件，并且要求以前台形式运行。比如：

> CMD ["nginx", "-g", "daemon off;"]
>
> 或者:
>
> nginx -g "daemon off;"

### 5、解决上述问题的办法

#### 5.1 supervisor

最近看了一个github项目，完美解决这类问题

[https://github.com/nickistre/docker-lamp/tree/ubuntu-14.04](https://github.com/nickistre/docker-lamp/tree/ubuntu-14.04)

主要做法是加入了supervisd。CMD中的指令一般只有一条，所以建议使用run.sh

```
RUN apt-get install -y supervisor
RUN mkdir -p /var/log/supervisor
ADD supervisord.conf /etc/
#ADD test.conf /etc/supervisord/conf.d/
CMD ["supervisord", "-n"]
#CMD ["/run.sh"]
```

改密码的方法

```
RUN echo 'root:changeme' | chpasswd
```

而语法规则可以参考文档[http://supervisord.org/configuration.html](http://supervisord.org/configuration.html)

```
[supervisord]
;logfile=/var/log/supervisor/supervisord-nobody.log  ; (main log file;default $CWD/supervisord.log)
;logfile_maxbytes=50MB       ; (max main logfile bytes b4 rotation;default 50MB)
;logfile_backups=10          ; (num of main logfile rotation backups;default 10)
;loglevel=info               ; (log level;default info; others: debug,warn,trace)
;pidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
nodaemon=true                ; (start in foreground if true;default false)
;user=nobody

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

;[unix_http_server]
;file = /supervisor.sock
;chmod = 0777
;chown= nobody:nogroup
;username = user
;password = 123

[inet_http_server]
port = 127.0.0.1:9001

[supervisorctl]
;serverurl=unix:///tmp/supervisor.sock
serverurl=http://127.0.0.1:9001

[program:apache2]
command=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -DFOREGROUND"
numprocs=1
autostart=true


;autostart=true                 ; start at supervisord start (default: true)
;autorestart=true               ; retstart at unexpected quit (default: true)
;startretries=3                 ; max # of serial start failures (default 3)

[program:mysql]
command = /usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/bin/mysqld_safe
numprocs=1
autostart=true
```

#### 5.2 无限循环

main.sh

```
#!/bin/bash

echo '[+] Starting mysql...'
service mysql start

echo '[+] Starting apache'
service apache2 start

while true
do
    tail -f /var/log/apache2/*.log
    exit 0
done
```

run.sh

```
#!/bin/bash

#sshd
echo "=> start sshd"
exec /usr/sbin/sshd &
echo "=> sshd started"

VOLUME_HOME="/var/lib/mysql"

sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
    -e "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" /etc/php5/apache2/php.ini
if [[ ! -d $VOLUME_HOME/mysql ]]; then
    echo "=> An empty or uninitialized MySQL volume is detected in $VOLUME_HOME"
    echo "=> Installing MySQL ..."
    mysql_install_db > /dev/null 2>&1
    echo "=> Done!"
    /create_mysql_admin_user.sh
else
    echo "=> Using an existing volume of MySQL"
fi

exec supervisord -n
```

Start-apache2.sh

```
#!/bin/bash
source /etc/apache2/envvars
exec apache2 -D FOREGROUND
```

Start-mysql.sh

```
#!/bin/bash
exec mysqld_safe
```

在脚本中，最好使用下面的这类后台指令

```
exec /usr/sbin/sshd &
```

在shell中，内建（builtin）命令exec，格式如下：

```
exec [-cl] [-a name] [command [arguments]]1
```

exec命令，如果指定了command，它就会取代当前的shell而不是创建新的进程，所以命令执行完毕后shell也就退出了。如果设置了“-l”即login选项，在command的第0个参数前会添加符号“-”，这是login所需的。如果设置了“-c”即clear选项，command命令将在一个空的环境中执行。如果指定了“-a name”选项，name会作为第0个参数传给command。若没有指定command，可以使用重定向来影响当前的shell。重定向成功时退出状态为0，否则为1。

exec后面的命令如果是多个简单命令组合而成的复合命令，只执行第一个命令，可以把这些符合命令写入shell脚本中，然后通过exec执行这个脚本，此时脚本中所有的命令都会执行。

