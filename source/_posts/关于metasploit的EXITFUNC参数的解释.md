---
title: 关于metasploit的EXITFUNC参数的解释
date: 2017-06-22 13:54:52
categories: 安全工具
tags: metasploit
---

这个简单的介绍是从Google上搜的，当我们使用metasploit框架时经常会遇到EXITFUNC这个参数，这个参数是干什么用的呢？

<font color=#f00>EXITFUNC有4个不同的值：none，seh，thread和process。通常它被设置为线程或进程，它对应于ExitThread或ExitProcess调用。 “none”参数将调用GetLastError，实际上是无操作，线程然后将继续执行，允许您简单地将多个有效负载一起串行运行。

在某些情况下，EXITFUNC是有用的，在利用一个exploit之后，我们需要一个干净地退出 </font>

#### SEH：

<font color=#00f>This method should be used when there is a structured exception handler (SEH) that will restart the thread or process automatically when an error occurs.</font>

当存在结构化异常处理程序（SEH），且触发该SEH将自动重启线程或进程时，应使用此方法。


#### THREAD：

<font color=#00f>This method is used in most exploitation scenarios where the exploited process (e.g. IE) runs the shellcode in a sub-thread and exiting this thread results in a working application/system (clean exit)</font>

此方法用于大多数场景，其中被利用的进程（例如IE）在子线程中运行shellcode并退出此线程会导致正在工作的应用程序/系统（清除退出）。


#### PROCESS：

<font color=#00f>This method should be used with multi/handler. This method should also be used with any exploit where a master process restarts it on exit.</font>

此方法应与multi/handler这个利用模块一起使用。此方法也应该与任何主进程在退出时会重新启动的漏洞一起使用。
