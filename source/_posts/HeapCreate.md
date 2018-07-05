---
title: HeapCreate()
date: 2017-06-23 13:23:37
categories: 安全技术
tags: [windows, heap]
---

HeapCreate
这个函数创建一个只有调用进程才能访问的私有堆。进程从虚拟地址空间里保留出一个连续的块并且为这个块特定的初始部分分配物理空间。

HANDLE HeapCreate(DWORD flOptions , DWORD dwInitialSize , DWORD dwMaxmumSize);

#### 参数

flOptions：堆的可选属性。这些标记影响以后对这个堆的函数操作，函数有：HeapAlloc , HeapFree , HeapReAlloc , HeapSize .
下面给_出在此可以指定的标记：
HEAP_NO_SERIALIAZE：指定当函数从堆里分配和释放空间时不互斥（不使用互斥锁）。当不指定该标记时默认为使用互斥。序列化允许多个线程操作同一个堆而不会错误。这个标记是可忽略的。
HEAP_SHARED_READONLY：这个标记指定这个堆只能由创建它的进程进行写操作，对其他进程是只读的。如果调用者不是可靠的，调用将会失败，错误代码ERROR_ACCESS_DENIDE 。
注解：为了使用标记为HEAP_SHARED_READONLY的堆，运行在kernel mode（核心状态）是必须的。

dwInitialSize：堆的初始大小，单位为Bytes。这个值决定了分配给堆的初始物理空间大小。这个值将向上舍入知道下个page boundary（页界）。若需得到主机的页大小，使用GetSystemInfo 函数。

dwMaxmumSize：如果该参数是一个非零的值，它指定了这个堆的最大大小，单位为Bytes。该函数会向上舍入该值直到下个页界，然后为这个堆在进程的虚拟地址里保留舍入后大小的块。如果函数 HeapAlloc 和 HeapReAlloc 要求分配的空间超过参数 dwInitialSize 指定的大小，系统会分配额外的空间给该堆直到这个堆的最大大小。If dwMaximumSize is nonzero, the heap cannot grow and an absolute limitation arises where all allocations are fulfilled within the specified heap unless there is not enough free space. （如果该参数非零，除非没有足够的空间，这个堆总可以增长到该大小）。如果该参数为零，那么该堆大小的唯一限制是可用的内存空间。分配大小超过 0x0018000 Bytes的空间总会失败，因为获得这么大的空间需要系统调用 VirtualAlloc 函数。需要使用大空间的应用应该把该参数设置为零。

#### 返回值

成功：一个指向新创建的堆的指针。
失败：NULL
调用函数 GetLastError 获得更多的错误信息。

<h4>附注</h4>

这个函数在调用进程里创建一个私有堆，进程可调用 HeapAlloc 函数分配内存空间。这些页在进程的虚拟空间内创建了一个块，在那里堆可以增长。
如果 HeapAlloc 函数请求的空间超过了现有的页大小，如果物理空间足够的话，额外的空间将会从已保留的空间里附加。
只有创建私有堆的进程可以访问私有堆。
如果一个DLL（动态链接库）创建了一个私有堆，那么这么私有堆是在调用该DLL的进程的地址空间内，且仅该进程可访问。
系统会使用私有堆的一部分空间去储存堆的结构信息，所以，不是所有的堆内空间对进程来说是可用的。例如：HeapAlloc函数从一个最大大小为 64KB 的堆里申请 64KB 的空间，由于系统占用的一部分空间，这个请求通常会失败。

#### 要求

|   |    |
|--|--|
|Minimum supported client|Windows XP [desktop apps or Windows Store apps]|
|Minimum supported server | Windows Server 2003 [desktop apps or Windows Store apps]|
|Minimum supported phone | Windows Phone 8|
|Header|HeapApi.h (include Windows.h);<br>WinBase.h on Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, Windows Server 2003 and Windows XP (include Windows.h)|
|Library|Kernel32.lib|
|DLL|Kernel32.dll|

#### 参考文献

[HeapCreate in MSDN](https://msdn.microsoft.com/en-us/library/windows/desktop/aa366597.aspx)
[HeapCreate()](http://blog.csdn.net/windroid/article/details/42302519)