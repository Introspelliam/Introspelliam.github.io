---
title: XMAN之旅——Misc
date: 2017-08-11 00:49:22
categories: xman
tags: 
---

### 1. Misc概述

MISC，即Miscellaneous，即安全杂项，题目或涉及流量分析、电子取证、人肉搜索、数据分析等等。

MISC，中文即杂项，包括隐写，数据还原，脑洞、社会工程、与信息安全相关的大数据等。

竞赛过程中解MISC时会涉及到各种脑洞，各种花式技巧，主要考察选手的快速理解、学习能力以及日常知识积累的广度、深度。

MISC这一块并不像PWN\REVERSE等需要深厚的理论基础，所以我们直接从经典题目开始入手。

### 2. Misc题目类型

Misc大体上分为Encode编码转换、Steg隐写分析、Forensic数字取证以及其他类型

### 3. 编码转换

由于编码很多种，可以在网上找各种站长工具对编码进行转换，而且效率很高！

常见的编码有：base64、base32、base16、ascii、unicode、url、摩斯编码、曼切斯特编码等

### 4. 取证和隐写分析

#### 4.1 常见的工具

文本编辑工具：
* 010Editor
* UtralEdit
* Winhex

隐写工具：
* StegSolver
* Stegdetect
* wbSteg4
* MP3Stego
* outguess
* stepic
* steghide

其他工具：
* 7zcracker
* archpr
* tweakpng
* audacity
* binwalk
* foremost
* Ffmpeg
* Alternatestreamview
* Dsfok-tools
* Snow


#### 4.2 常见的隐写术

从最早的图种(copy /b test.jpg+test.torrent test.jpg),
CTF比赛中最开始的图片隐写(JPG，PNG，GIF)
Word，PDF等隐写	
音频，视频中的隐写(波形，频谱…….)
Exe中的病毒行为分析
Pcap流量包
磁盘文件(IMG,VMDK)
交换数据流(NTFS数据流)
HTML文件

### 5. 自己的思考

想要深入学习Misc，首先需要熟练掌握一些文件格式，并能够根据相应的格式合理运用工具，如此才能掌握Misc！
