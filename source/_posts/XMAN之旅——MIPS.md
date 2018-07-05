---
title: XMAN之旅——MIPS
date: 2017-08-16 15:10:28
categories: xman
tags: mips
---

### IOT(Internet of Things) 物联网

CAN协议
TTP协议
介质访问控制模式CSMA/CD
GPS系统遥控
obd
定位解锁功能

智能联网汽车信息安全状况

### MIPS

RISC架构
通用寄存器 32个
特殊寄存器 PC hI IO
指令定长
有大端和小端两种
指令还有地址 都是 4字节对齐的
数据访问严格4 字节对其
流水线

xss(不是很严重)
CSRF
认证漏洞
命令注入（针对后端的lua 脚本)

mips不会自动刷新
shellcode 被存于数据的cache中
cacch incoherency


使用busybox 启用 reverse shell

由于不能直接与cgi进行交互，可以使用 reverse shell
wget一个

-W hexdump
-A 分析指令架构 寻找各种架构的函数projoque

binwalk -M

使用 ROP或者其他啊手段一次请求启动reverse shell
定位 binary 地组织，可以在同样的环境中进行调试，或者调用其他漏洞的leak

MIPS的shellcode 开发

ropgadget
使用 IDA的插件 MIPS ROP Finder(可以支持定制搜索)

找可用gadget
向已知地址执行shellcode
rop执行system


binutils-mips-linux-gnu
qemu-mipsel -L /usr/mipsel-linux-gnu/ ./pwn300


qemu-mipsel
MIPS库环境库安装

qemu-mips
user mode 直接运行用户程序
需要完整的library
system mode 直接模拟mips系统


gdb server
gdb-multiarch
IDA debugger


mips rop gadget
MIPS汇编语言
逆向工具


基于 MIPS或者 ARM架构的 openwrt
普通用户没有 root shell
基于 busybox
libc 和一般的linux 不同 使用 uclibc(提供基本的嵌入式函数，比较小，节省内存空间)

binwalk
firmware-mod-kit


用于开发板的调试
输出root Image 或者之际给出系统的rootshell
辅助分析

USB2TL
Tx端链接开发板Rx
Rx端链接开发板Tx
GND链接GND


与UART交互


GDN ground
TX transmit 发送引脚 3.3v
RX recive 接受引脚 3.3。v
VCC 电源 一般电压为3.3-5v

openwrt
Embedded linux
VxWorks
uClinux
FreeRTOS


与段 与攻击一个web站点类似(比较少，和攻击一个web差不多）
正对设备与网关，网关与云端之间的嗅探
身份伪造等
通过针对设备以及网关的固件你想利用漏洞获取权限 