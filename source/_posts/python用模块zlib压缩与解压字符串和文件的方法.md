---
title: python用模块zlib压缩与解压字符串和文件的方法
date: 2017-07-02 17:20:22
categories: misc
tags: [python, zlib]
---

python中zlib模块是用来压缩或者解压缩数据，以便保存和传输。它是其他压缩工具的基础。下面来一起看看python用模块zlib压缩与解压字符串和文件的方法。话不多说，直接来看示例代码。

### 1. 压缩与解压字符串

<pre><code>
import zlib
message = 'abcd1234'
compressed = zlib.compress(message)
decompressed = zlib.decompress(compressed)

print 'original:', repr(message)
print 'compressed:', repr(compressed)
print 'decompressed:', repr(decompressed)
</code></pre>

<b>结果</b>
<pre><code>
original: 'abcd1234'
compressed: 'x\x9cKLJN1426\x01\x00\x0b\xf8\x02U'
decompressed: 'abcd1234'
</code></pre>

### 2. 压缩与解压文件

<pre><code>
import zlib
def compress(infile, dst, level=9):
    infile = open(infile, 'rb')
    dst = open(dst, 'wb')
    compress = zlib.compressobj(level)
    data = infile.read(1024)
    while data:
        dst.write(compress.compress(data))
        data = infile.read(1024)
    dst.write(compress.flush())

def decompress(infile, dst):
    infile = open(infile, 'rb')
    dst = open(dst, 'wb')
    decompress = zlib.decompressobj()
    data = infile.read(1024)
    while data:
        dst.write(decompress.decompress(data))
        data = infile.read(1024)
    dst.write(decompress.flush())

if __name__ == "__main__":
    compress('in.txt', 'out.txt')
    decompress('out.txt', 'out_decompress.txt')
</code></pre>

### 3. 问题——处理对象过大异常

<pre><code>
>>> import zlib
>>> a = '123'
>>> b = zlib.compress(a)
>>> b
'x\x9c342\x06\x00\x01-\x00\x97'
>>> a = 'a' * 1024 * 1024 * 1024 * 10
>>> b = zlib.compress(a)
Traceback (most recent call last):
 File "&lt;stdin&gt;", line 1, in &lt;module&gt;
OverflowError: size does not fit in an int
</code></pre>