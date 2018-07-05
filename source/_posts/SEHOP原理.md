---
title: SEHOP原理
date: 2017-07-17 18:48:47
categories: 安全技术
tags: [SEH, windows]
---

### 1. SEHOP简介

SEHOP(Structured Exception Handling Overwrite Protection)是一种比SafeSEH更为严厉的保护机制。截至2009年，Windows Vista SP1、Windows 7、Windows Server 2008和Windows Server 2008 R2均支持SEHOP。

SEHOP在Windows Server 2008是默认启用，而在Windows Vista和Windows 7中SEHOP默认是关闭的，可以通过下面两种方法启用SEHOP：
1. 手工在注册表中HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session\Manager\kernel下面找到DisableExceptionChainValidation项，将其值设置为0，即可以启用SEHOP

SEHOP的核心任务是检查这条SEH链的完整性，在程序转入异常处理前SEHOP会检查SEH链上最后一个异常处理函数是否为系统固定的终极异常处理函数。如果是，则说明这条SEH链没有被破坏，程序可以执行当前的异常处理函数；如果检测到最后一个异常处理函数不是最终的默认异常处理，则说明SEH链被破坏，可能发生了SEH覆盖攻击，程序将不会去执行当前的异常处理函数。

验证代码如下：
<pre><code>
BOOL RtlIsValidHandler(handler)
{
        if (handler is in an image) {
                if (image has the IMAGE_DLLCHARACTERISTICS_NO_SEH flag set)
                        return FALSE;
                if (image has a SafeSEH table)
                if (handler found in the table)
                        return TRUE;
                else
                        return FALSE;
                if (image is a .NET assembly with the ILonly flag set)
                        return FALSE;
                // fall through
        }
        if (handler is on a non-executable page) {
                if (ExecuteDispatchEnable bit set in the process flags)
                        return TRUE;
                else
                // enforce DEP even if we have no hardware NX
                raise ACCESS_VIOLATION;
        }
        if (handler is not in an image) {
                if (ImageDispatchEnable bit set in the process flags)
                        return TRUE;
                else
                        return FALSE; // don't allow handlers outside of images
        }
// everything else is allowed
return TRUE;
}
[...]
// Skip the chain validation if the
DisableExceptionChainValidation bit is set
if (process_flags & 0x40 == 0) {
        // Skip the validation if there are no SEH records on the
        // linked list
        if (record != 0xFFFFFFFF) {
                // Walk the SEH linked list
                do {
                        // The record must be on the stack
                        if (record < stack_bottom || record > stack_top)
                                goto corruption;
                        // The end of the record must be on the stack
                        if ((char*)record + sizeof(EXCEPTION_REGISTRATION) > stack_top)
                                goto corruption;
                        // The record must be 4 byte aligned
                        if ((record & 3) != 0)
                                goto corruption;
                        handler = record->handler;
                        // The handler must not be on the stack
                        if (handler >= stack_bottom && handler < stack_top)
                                goto corruption;
                        record = record->next;
                } while (record != 0xFFFFFFFF);
                // End of chain reached
                // Is bit 9 set in the TEB->SameTebFlags field?
                // This bit is set in ntdll!RtlInitializeExceptionChain,
                // which registers FinalExceptionHandler as an SEH handler
                // when a new thread starts.
                if ((TEB->word_at_offset_0xFCA & 0x200) != 0) {
                        // The final handler must be ntdll!FinalExceptionHandler
                        if (handler != &FinalExceptionHandler)
                                goto corruption;
                }
        }
}
</code></pre>

### 2. 攻击SEHOP的理论方法

作为对SafeSEH强有力的补充，SEHOP检查是在SafeSEH的RtlIsValidHandler函数校验前进行的，也就是说利用攻击加载模块之外的地址、堆地址和未启用SafeSEH模块的方法都行不通了。理论上还有三条路可以：
1. 不去攻击SEH，而是攻击函数返回地址或者虚函数等
2. 利用未启用SEHOP的模块
3. 伪造SEH链