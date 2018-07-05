---
title: android逆向准备工作
date: 2018-02-08 15:59:12
categories: re
tags: [android, 调试]
---

### 0、笔者自述

说实话，对于Android逆向，我还只处在开始调试开发的阶段，但是实在是受不了Android中的流氓软件以及流氓事件，我打算进行简单的安卓逆向。刚开始的目标是去除app中的广告页（现在发现十分困难）！

### 1、安卓逆向的环境安装

#### 1.1 jdk安装

jdk安装实在指导很多，但是这儿还是得提醒一句，是jdk的安装，不是jre！

参考：[https://jingyan.baidu.com/article/0202781175839b1bcc9ce529.html](https://jingyan.baidu.com/article/0202781175839b1bcc9ce529.html)

#### 1.2 Android Studio安装

貌似现在很多的书籍和网上的提示都是建议用ADT，也即安装Eclipse之后再安装ADT bundle（包含SDK），这中间配置极其麻烦，并且网上很多指导建议都已经过时，毕竟Google已经取消对ADT的支持，只推荐使用Android Studio。如果你们还不死心，那你除了安装上述内容外，还需要安装原生开发包（NDK）。

但是如果你安装Android Studio，这些内容都可以快速配置完毕！其包含SDK_Manager、AVD_Manager等工具。

#### 1.3 模拟器的使用

其实我很早就使用Android Studio了，在对比了1.0和现在的3.0版本之后，我发现Android Studio最大的改进就是加快了模拟器的启动速度。这应该会让许许多多的开发者爱上原生态的开发编辑器。现在使用的模拟器最大的问题在于，“窗口标题栏”不见了，没法进行拖拽，没法直接关闭，我真的要疯了！

所以我在网上搜了好多，最后决定使用Genymotion和夜神模拟器！

##### 1.3.1 Genymotion的安装与配置

Genymotion支持多种版本的手机，所以比较适用于开发。但是，它并不值得夸奖。

不知道你们在安装Genymotion的时候，是否会出现登录错误、下载贼慢等稀奇古怪的问题，这些问题曾耽搁了我半天的时间。当然，最让人头疼的问题是：

**问题a：**Genymotion基于Virtualbox平台，但是从Genymotion中启动模拟器时出现了"Unable to start the Virtual Device..."错误，最后我锁定的问题是virtualbox版本不太稳定，换了一个，重启了电脑；

**问题b：**我成功的启动了Genymotion中的模拟器，但是我随便拖个应用进去都安装不上，提示“An error occured while deploying the file. This probably means that the app contains ARM native code and your Genymotion device cannot run ARM instructions. You should either build your native code to x86 or install an ARM translation tool in your device. ”错误，其实这是因为没有[Genymotion-ARM-Translation.zip](/others/files/Genymotion-ARM-Translation.zip) 。这就需要我们打开模拟器，将此zip文件拖入模拟器中，一直点击yes，最后就可用了。

**问题c：** 虽然有些应用已经可以在Genymotion的模拟器中运行了，但是还是有不少应用运行不了，如微信、知乎等。网上有说换个低版本sdk的模拟器就可以，实测了几个，还是会有这类问题。比较玄学，没法做答！

**问题d：**既然我们使用的是Android Studio进行开发，那我们如何让其发现这个模拟器呢？首先在Android Studio->File->Settings->Plugins中找到genymotion插件，安装之后并重启。然后点击Android Studio->View->ToolBar，你会在工具栏中看到一个红色的Genymotion管理工具图标，现在基本上没问题了。

**问题e：**如何在Genymotion模拟器中运行工程？只需要点击绿色的run图标，并在Edit Configuration中选定Target为"Open Select Deployment Target Dialog"，接着点击run，选择genymotion中的模拟器（此模拟器在运行工程之前就已打开）。

你可以看到，genymotion的配置与安装问题多多，而且解决的还不全面，基本上每次配置都要花费一两个小时，有点得不偿失，所以我十分建议使用夜神模拟器。

##### 1.3.2 夜神模拟器的安装与配置

夜神模拟器安装基本上没有问题，所以这儿只讲配置问题。

（1）运行夜神模拟器，

（2）打开命令行窗口，

（3）打开到夜神安装目录（如cd D:\Program Files (x86)\NOX\Nox\bin），

（4）执行命令：nox_adb.exe connect 127.0.0.1:62001，连接模拟器，

（5）若Android Studio连接不上夜神，重启模拟器即可。

这五步就能让Android Studio连上夜神模拟器，而且运行速度很快。

但是我们发现，貌似没法用android-sdk\platform-tool\adb devices发现这个模拟器，这就给测试造成了一定困难。由于版本不同，目前运行服务器端的adb（夜神）版本，比客户端的版本（SDK）低，所以系统就把当前运行的服务给杀掉了。

**解决方案：**

- 1、关掉AS和夜神模拟器。同时去任务管理器里看下，adb.exe以及nox_adb.exe这2个进程有没有在运行？有的话就结束掉。
- 2、找到SDK的目录和夜神模拟器的目录，将SDK目录下的adb.exe文件，复制到夜神模拟器的目录下，因为夜神模拟器目录下原本的adb文件名字叫做nox_adb.exe，因此复制过去之后也得改名为nox_adb.exe。
- 3、这样就将AS目录下的adb文件和模拟器目录下的adb文件完全同步了，版本号也一致了。

### 2、入门级操作

#### 2.1 AVD操作

```
#可使用的系统镜像列表
android-sdk/tools/android list targets

#创建AVD
android-sdk/tools/android create avd -n [name of your new avd]
android-sdk/tools/android create avd -n [avd设备名] -t [镜像id] -c [大小][K|M]

#运行AVD
android-sdk/tools/emulator -avd [avd的名字]
android-sdk/tools/emulator -avd [avd的名字] -partition-size [size in MBs]
```

#### 2.2 ADB调试

```
#运行AVD
android-sdk/tools/emulator -avd [avd的名字]

####使用Android连接桥(ADB)与AVD交互####
#获取所有连接的android设备
android-sdk/platform-tools/adb devices

# 连接到android设备
android-sdk/platform-tools/adb shell （当只有一个设备时）
android-sdk/platform-tools/adb shell -s [指定设备] (当有多个设备时)
此时，我们进入了android设备的后台，可以用常用的linux操作进行
```

#### 2.3 从AVD中复制出/入文件

```
#从avd中复制出文件
android-sdk/platform-tools/adb {参数} pull [要复制的文件路径] [存放复制出来的文件的本地路径]

#把文件拷贝至avd中
android-sdk/platform-tools/adb {参数} push [要复制的文件在本地的路径] [该文件在avd中的存放路径]
```

#### 2.4 通过ADB在AVD中安装app

```
# 安装计算机中的apk
adb {参数} install [apk的存放路径]

# 使用指定设备的命令，缩小要安装APK的设备范围
adb { -e | -d | -p } install [apk的存放路径] 
```

