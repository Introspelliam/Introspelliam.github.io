---
title: malloc源码分析——2
date: 2018-05-21 14:39:08
categories: pwn
tags: [heap]
---

# malloc源码分析—_int_malloc

根据上一章的分析，malloc会调用`__libc_malloc`分配内存，`__libc_malloc`会调用`malloc_hook_ini` 进行初始化，然后回调`__libc_malloc`函数，这时候会执行`_int_malloc`开始分配内存，定义在malloc.c中，因为非常长，这里分段来看，

## _int_malloc第一部分

```
static void * _int_malloc(mstate av, size_t bytes) {
    INTERNAL_SIZE_T nb;
    unsigned int idx;
    mbinptr bin;

    mchunkptr victim;
    INTERNAL_SIZE_T size;
    int victim_index;

    mchunkptr remainder;
    unsigned long remainder_size;

    unsigned int block;
    unsigned int bit;
    unsigned int map;

    mchunkptr fwd;
    mchunkptr bck;

    const char *errstr = NULL;

    checked_request2size(bytes, nb);

    if (__glibc_unlikely(av == NULL)) {
        void *p = sysmalloc(nb, av);
        if (p != NULL)
            alloc_perturb(p, bytes);
        return p;
    }

    ...
```

首先调用`checked_request2size`将需要分配的内存大小bytes转换为chunk的大小。`checked_request2size`是个宏定义，主要调用request2size进行计算，

```
#define request2size(req)                                         \
  (((req) + SIZE_SZ + MALLOC_ALIGN_MASK < MINSIZE)  ?             \
   MINSIZE :                                                      \
   ((req) + SIZE_SZ + MALLOC_ALIGN_MASK) & ~MALLOC_ALIGN_MASK)
```

为了说明request2size，首先看一下ptmalloc中关于chunk的定义，

```
struct malloc_chunk {

    INTERNAL_SIZE_T prev_size;
    INTERNAL_SIZE_T size;

    struct malloc_chunk* fd; 
    struct malloc_chunk* bk;

    struct malloc_chunk* fd_nextsize; /* double links -- used only if free. */
    struct malloc_chunk* bk_nextsize;
};
```

当一个chunk为空闲时，至少要有`prev_size`、`size`、`fd`和`bk`四个参数，因此MINSIZE就代表了这四个参数需要占用的内存大小；而当一个chunk被使用时，`prev_size`可能会被前一个chunk用来存储，`fd`和`bk`也会被当作内存存储数据，因此当chunk被使用时，只剩下了`size`参数需要设置，`request2size`中的`SIZE_SZ`就是`INTERNAL_SIZE_T`类型的大小，因此至少需要`req+SIZE_SZ`的内存大小。`MALLOC_ALIGN_MASK`用来对齐，因此request2size就计算出了所需的chunk的大小。

传入的参数av是在上一章`__libc_malloc`中调用`arena_get`获得的分配去指针，如果为null，就表示没有分配区可用，这时候就直接调用`sysmalloc`通过mmap获取chunk。

## sysmalloc

`sysmalloc`的代码很长，但只有前面一小部分是这里需要分析的，

```
static void * sysmalloc(INTERNAL_SIZE_T nb, mstate av) {
    mchunkptr old_top;
    INTERNAL_SIZE_T old_size;
    char *old_end;

    long size;
    char *brk;

    long correction;
    char *snd_brk;

    INTERNAL_SIZE_T front_misalign;
    INTERNAL_SIZE_T end_misalign;
    char *aligned_brk;

    mchunkptr p;
    mchunkptr remainder;
    unsigned long remainder_size;

    size_t pagesize = GLRO(dl_pagesize);
    bool tried_mmap = false;

    if (av == NULL
            || ((unsigned long) (nb) >= (unsigned long) (mp_.mmap_threshold)
                    && (mp_.n_mmaps < mp_.n_mmaps_max))) {
        char *mm;

        try_mmap:
        if (MALLOC_ALIGNMENT == 2 * SIZE_SZ)
            size = ALIGN_UP(nb + SIZE_SZ, pagesize);
        else
            size = ALIGN_UP(nb + SIZE_SZ + MALLOC_ALIGN_MASK, pagesize);
        tried_mmap = true;

        if ((unsigned long) (size) > (unsigned long) (nb)) {
            mm = (char *) (MMAP(0, size, PROT_READ | PROT_WRITE, 0));

            if (mm != MAP_FAILED) {

                if (MALLOC_ALIGNMENT == 2 * SIZE_SZ) {
                    assert(
                            ((INTERNAL_SIZE_T) chunk2mem (mm) & MALLOC_ALIGN_MASK) == 0);
                    front_misalign = 0;
                } else
                    front_misalign = (INTERNAL_SIZE_T) chunk2mem(
                            mm) & MALLOC_ALIGN_MASK;
                if (front_misalign > 0) {
                    correction = MALLOC_ALIGNMENT - front_misalign;
                    p = (mchunkptr) (mm + correction);
                    p->prev_size = correction;
                    set_head(p, (size - correction) | IS_MMAPPED);
                } else {
                    p = (mchunkptr) mm;
                    set_head(p, size | IS_MMAPPED);
                }

                int new = atomic_exchange_and_add(&mp_.n_mmaps, 1) + 1;
                atomic_max(&mp_.max_n_mmaps, new);

                unsigned long sum;
                sum = atomic_exchange_and_add(&mp_.mmapped_mem, size) + size;
                atomic_max(&mp_.max_mmapped_mem, sum);

                check_chunk (av, p);

                return chunk2mem(p);
            }
        }
    }
    if (av == NULL)
        return 0;

    ...
```

首先，可以直接通过mmap分配chunk有两个前提条件，一是需要分配的内存大小大于实用mmap进行分配的阀值`mp_.mmap_threshold`，二是通过`mp_.n_mmaps`判断系统还可以有可以使用mmap分配的空间。 
下面就要计算需要分配多少内存，在前面已经通过`request2size`计算了需要分配的内存大小，这里为什么还要计算呢？这是因为通过使用mmap直接分配的chunk不需要添加到链表中，因此不存在前后关系，当一个chunk被使用时，不能借用后一个chunk的`prev_size`字段，这里需要把该字段的长度SIZE_SZ加上。并且这里假设`MALLOC_ALIGNMENT == 2 * SIZE_SZ`。 
接下来判断需要分配的内存大小是否会溢出，然后就调用`MMAP`分配内存，`MMAP`是一个宏定义，最后就是通过系统调用来分配内存，后面来看这个函数。 
再往下就是通过`set_head`在chunk中的size参数里设置标志位，因为chunk是按8字节对齐的，而size标识chunk占用的字节数，所以最后三位是没有用的，ptmalloc将这三位用来作为标志位，这里便是设置其中一个标志位，用来标识该chunk是直接通过mmap分配的。

```
#define set_head(p, s)       ((p)->size = (s))
```

设置完标志位后，接下来就是设置全局变量`_mp`，将`mp_.n_mmaps`加1，表示当前进程通过mmap分配的chunk个数，对应的`mp_.max_n_mmaps`表示最大chunk个数。`mp_.mmapped_mem`标识已经通过mmap分配的内存大小，`mp_.max_mmapped_mem`对应可分配内存的最大值。其中，`atomic_exchange_and_add`b表示原子加，`atomic_max`则是原子取最大值。 
最后，通过chunk2mem返回chunk中内存的起始指针。

```
#define chunk2mem(p)   ((void*)((char*)(p) + 2*SIZE_SZ))
```

这里也可以知道，当chunk被使用时，用户是从结构体中的变量fd开始使用内存的。回到_int_malloc函数中，假设通过sysmalloc分配成功，接下来就需要调用alloc_perturb对刚刚分配的内存进行初始化，

```
static void alloc_perturb(char *p, size_t n) {
    if (__glibc_unlikely(perturb_byte))
        memset(p, perturb_byte ^ 0xff, n);
}
```

刚函数没有什么实际意义，所以不管它。

## MMAP

为了方便分析，这里贴一段调用MMAP的代码，

```
    mm = (char *) (MMAP(0, size, PROT_READ | PROT_WRITE, 0));
```

MMAP在glibc中为宏定义，其定义很长，这里简单将它改写，

```
#define INTERNAL_SYSCALL_MAIN_6(name, err, arg1, arg2, arg3,        \
                arg4, arg5, arg6)           \
  struct libc_do_syscall_args _xv =                 \
    {                                   \
      (int) (0),                            \
      (int) (-1),                           \
      (int) (0)                         \
    };                                  \
    asm volatile (                          \
    "movl %1, %%eax\n\t"                        \
    "call __libc_do_syscall"                        \
    : "=a" (resultvar)                          \
    : "i" (__NR_mmap2), "c" (size), "d" (PROT_READ | PROT_WRITE), "S" (MAP_ANONYMOUS|MAP_PRIVATE), "D" (&_xv) \
    : "memory", "cc")
```

`__libc_do_syscall`是一段汇编代码，最后就是系统调用啦，这里就进入了linux内核中的代码，在arch/x86/entry/syscalls/syscall_32.tbl中有如下定义，

```
192 i386    mmap2           sys_mmap_pgoff
```

因此，MMAP最后调用linux内核中的`sys_mmap_pgoff`函数，定义在mm/mmap.c中，

```
SYSCALL_DEFINE6(mmap_pgoff, unsigned long, addr, unsigned long, len,
        unsigned long, prot, unsigned long, flags,
        unsigned long, fd, unsigned long, pgoff){

    struct file *file = NULL;
    unsigned long retval = -EBADF;

    if (!(flags & MAP_ANONYMOUS)) {

        ...

    } else if (flags & MAP_HUGETLB) {

        ...

    }

    flags &= ~(MAP_EXECUTABLE | MAP_DENYWRITE);

    retval = vm_mmap_pgoff(file, addr, len, prot, flags, pgoff);
    return retval;
}
```

`SYSCALL_DEFINE6`是个宏定义，就是将系统调用号和函数联系起来，这里其实就是定义了`sys_mmap_pgoff`函数。根据前面传入的flags，这里直接跳过判断，因此下面主要就是执行`vm_mmap_pgoff`函数，定义在mm/utils.c中，

```
unsigned long vm_mmap_pgoff(struct file *file, unsigned long addr,
    unsigned long len, unsigned long prot,
    unsigned long flag, unsigned long pgoff)
{
    unsigned long ret;
    struct mm_struct *mm = current->mm;
    unsigned long populate;

    ret = security_mmap_file(file, prot, flag);
    if (!ret) {
        down_write(&mm->mmap_sem);
        ret = do_mmap_pgoff(file, addr, len, prot, flag, pgoff,
                    &populate);
        up_write(&mm->mmap_sem);
        if (populate)
            mm_populate(ret, populate);
    }
    return ret;
}
```

这里首先获得进程的`mm_struct`结构，该结构保存了虚拟内存和物理内存的映射关系，`security_mmap_file`和linux安全有关，这里不关心，因此调用`do_mmap_pgoff`执行主要的mmap内容，前后加了信号量。`do_mmap_pgoff`定义在mm/mmap.c中，这里省略了很多不关键的代码，

## do_mmap_pgoff

```
unsigned long do_mmap_pgoff(struct file *file, unsigned long addr,
            unsigned long len, unsigned long prot,
            unsigned long flags, unsigned long pgoff,
            unsigned long *populate){

    struct mm_struct *mm = current->mm;
    vm_flags_t vm_flags;
    *populate = 0;

    if (!(flags & MAP_FIXED))
        addr = round_hint_to_min(addr);
    len = PAGE_ALIGN(len);

    addr = get_unmapped_area(file, addr, len, pgoff, flags);
    vm_flags = calc_vm_prot_bits(prot) | calc_vm_flag_bits(flags) |
            mm->def_flags | VM_MAYREAD | VM_MAYWRITE | VM_MAYEXEC;

    if (file) {

        ...

    } else {
        switch (flags & MAP_TYPE) {
        case MAP_SHARED:
            ...
            break;
        case MAP_PRIVATE:
            pgoff = addr >> PAGE_SHIFT;
            break;
        default:
            return -EINVAL;
        }
    }

    addr = mmap_region(file, addr, len, vm_flags, pgoff);
    return addr;
}
```

传入的flags没有`MAP_FIXED`，表是映射的地址不固定（这里传入的`addr`为0），由内核分配。接下来通过调用`round_hint_to_min`和`PAGE_ALIGN`对地址和长度进行页对齐，并且检查地址是否溢出或者太小。 
下面调用`get_unmapped_area`在进程的用户空间里查找已经分配的虚拟内存。

```
unsigned long get_unmapped_area(struct file *file, unsigned long addr, unsigned long len, unsigned long pgoff, unsigned long flags){

    unsigned long (*get_area)(struct file *, unsigned long,
                  unsigned long, unsigned long, unsigned long);

    ...

    get_area = current->mm->get_unmapped_area;

    ...

    addr = get_area(file, addr, len, pgoff, flags);
    if (IS_ERR_VALUE(addr))
        return addr;

    ...

    return addr;
}
```

这里首先获取`get_area`函数指针用来查找用户空间中已经分配的虚拟内存，这里根据mmap的方向可以获取到`arch_get_unmapped_area_topdown`或者`arch_get_unmapped_area`两个函数指针，其`arch_get_unmapped_area_topdown`对应的mmap方向是从高地址往低地址方向扩展的，本章还是分析传统的从低地址往高地址拓展对应的`arch_get_unmapped_area`函数，

```
unsigned long
arch_get_unmapped_area(struct file *filp, unsigned long addr,
        unsigned long len, unsigned long pgoff, unsigned long flags){

    struct mm_struct *mm = current->mm;
    struct vm_area_struct *vma;
    struct vm_unmapped_area_info info;
    unsigned long begin, end;

    if (flags & MAP_FIXED)
        return addr;

    ...

    if (addr) {
        addr = PAGE_ALIGN(addr);
        vma = find_vma(mm, addr);
        if (end - len >= addr &&
            (!vma || addr + len <= vma->vm_start))
            return addr;
    }

    ...

}
```

首先，如果是固定地址映射，直接返回addr地址。本章分析的不是这种情况，省略的代码和一些随机映射有关，这里省略了不分析。这样就进入了底下的if语句里，对地址对齐后，就调用find_vma查找addr地址开始已经分配出去的虚拟内存vma，最后addr到addr+len这个地址范围内没有虚拟内存，就将地址返回。

```
struct vm_area_struct *find_vma(struct mm_struct *mm, unsigned long addr)
{
    struct rb_node *rb_node;
    struct vm_area_struct *vma;

    vma = vmacache_find(mm, addr);
    if (likely(vma))
        return vma;

    rb_node = mm->mm_rb.rb_node;
    vma = NULL;

    while (rb_node) {
        struct vm_area_struct *tmp;

        tmp = rb_entry(rb_node, struct vm_area_struct, vm_rb);

        if (tmp->vm_end > addr) {
            vma = tmp;
            if (tmp->vm_start <= addr)
                break;
            rb_node = rb_node->rb_left;
        } else
            rb_node = rb_node->rb_right;
    }

    if (vma)
        vmacache_update(addr, vma);
    return vma;
}
```

这里就不往下继续看代码的，简单来说，进程已经分配的虚拟内存保存在一个红黑树中，红黑树简单的作用就是防止一个树结构不平衡，出现某个左子树严重大于右子树的情况。为了加快查找的速度，这里设立了缓存。通过观察while结构，这里就是查找第一个结束地址大于addr的已经分配的虚拟内存，然后返回。

回到`do_mmap_pgoff`中，`calc_vm_prot_bits`和`calc_vm_flag_bits`用来将prot和flags中的标志位转化为vm的标志位，例如prot中的`PROT_READ`转化为`VM_READ`，flags中的`MAP_GROWSDOWN`转化为`VM_GROWSDOWN`。根据前面prot和flags中的值，这里转化后，`vm_flags`为`VM_READ|VM_WRITE|mm->def_flags | VM_MAYREAD | VM_MAYWRITE | VM_MAYEXEC`。最后就调用mmap_region构造一个vma用来保存刚刚获得的虚拟内存。

## mmap_region

为了方便分析和查看，这里对mmap_region代码做了适当的删除和改写，

```
unsigned long mmap_region(struct file *file, unsigned long addr,
        unsigned long len, vm_flags_t vm_flags, unsigned long pgoff)
{
    struct mm_struct *mm = current->mm;
    struct vm_area_struct *vma, *prev;
    int error;
    struct rb_node **rb_link, *rb_parent;
    unsigned long charged = 0;

    if (!may_expand_vm(mm, len >> PAGE_SHIFT)) {

        ...

    }

    error = -ENOMEM;
    while (find_vma_links(mm, addr, addr + len, &prev, &rb_link,
                  &rb_parent)) {
        if (do_munmap(mm, addr, len))
            return -ENOMEM;
    }

    vm_flags |= VM_ACCOUNT;

    vma = vma_merge(mm, prev, addr, addr + len, vm_flags, NULL, file, pgoff,
            NULL);
    if (vma)
        goto out;

    vma = kmem_cache_zalloc(vm_area_cachep, GFP_KERNEL);
    vma->vm_mm = mm;
    vma->vm_start = addr;
    vma->vm_end = addr + len;
    vma->vm_flags = vm_flags;
    vma->vm_page_prot = vm_get_page_prot(vm_flags);
    vma->vm_pgoff = pgoff;
    INIT_LIST_HEAD(&vma->anon_vma_chain);

    vma_link(mm, vma, prev, rb_link, rb_parent);
out:

    vm_stat_account(mm, vm_flags, file, len >> PAGE_SHIFT);
    if (vm_flags & VM_LOCKED) {
        if (!((vm_flags & VM_SPECIAL) || is_vm_hugetlb_page(vma) ||
                    vma == get_gate_vma(current->mm)))
            mm->locked_vm += (len >> PAGE_SHIFT);
        else
            vma->vm_flags &= ~VM_LOCKED;
    }

    if (file)
        uprobe_mmap(vma);

    vma->vm_flags |= VM_SOFTDIRTY;

    vma_set_page_prot(vma);

    return addr;
}
```

`may_expand_vm`用于判断加上即将分配的虚拟内存，是否超过了系统的限制，如果超过了就需要进行相应的操作或者返回错误，这里假设不会超过系统限制，不管它。 
`find_vma_links`的定义如下，

```
static int find_vma_links(struct mm_struct *mm, unsigned long addr,
        unsigned long end, struct vm_area_struct **pprev,
        struct rb_node ***rb_link, struct rb_node **rb_parent){

    struct rb_node **__rb_link, *__rb_parent, *rb_prev;

    __rb_link = &mm->mm_rb.rb_node;
    rb_prev = __rb_parent = NULL;

    while (*__rb_link) {
        struct vm_area_struct *vma_tmp;

        __rb_parent = *__rb_link;
        vma_tmp = rb_entry(__rb_parent, struct vm_area_struct, vm_rb);

        if (vma_tmp->vm_end > addr) {
            if (vma_tmp->vm_start < end)
                return -ENOMEM;
            __rb_link = &__rb_parent->rb_left;
        } else {
            rb_prev = __rb_parent;
            __rb_link = &__rb_parent->rb_right;
        }
    }

    *pprev = NULL;
    if (rb_prev)
        *pprev = rb_entry(rb_prev, struct vm_area_struct, vm_rb);
    *rb_link = __rb_link;
    *rb_parent = __rb_parent;
    return 0;
}
```

该函数做了两件事，第一件事是重新检查一遍即将分配的虚拟内存是否已经被使用，主要是其他进程可能在这期间分配了该虚拟内存，第二件事是确定即将插入红黑树中的位置，保存在`prev`、`rb_link`和`rb_parent`中。`prev`保存了虚拟内存结束地址小于即将分配的虚拟内存开始地址的红黑树节点，`rb_link`一般为null，`rb_parent`简单说就是保存了离即将分配的虚拟内存开始地址最近的红黑树节点。

再往下通过vma_merge函数查看是否有虚拟空间可以合并，如果有则合并并返回。

```
struct vm_area_struct *vma_merge(struct mm_struct *mm,
            struct vm_area_struct *prev, unsigned long addr,
            unsigned long end, unsigned long vm_flags,
            struct anon_vma *anon_vma, struct file *file,
            pgoff_t pgoff, struct mempolicy *policy){

    pgoff_t pglen = (end - addr) >> PAGE_SHIFT;
    struct vm_area_struct *area, *next;
    int err;

    if (vm_flags & VM_SPECIAL)
        return NULL;

    if (prev)
        next = prev->vm_next;
    else
        next = mm->mmap;
    area = next;
    if (next && next->vm_end == end)
        next = next->vm_next;

    if (prev && prev->vm_end == addr &&
            mpol_equal(vma_policy(prev), policy) &&
            can_vma_merge_after(prev, vm_flags,
                        anon_vma, file, pgoff)) {

        if (next && end == next->vm_start &&
                mpol_equal(policy, vma_policy(next)) &&
                can_vma_merge_before(next, vm_flags,
                    anon_vma, file, pgoff+pglen) &&
                is_mergeable_anon_vma(prev->anon_vma,
                              next->anon_vma, NULL)) {

            err = vma_adjust(prev, prev->vm_start,
                next->vm_end, prev->vm_pgoff, NULL);
        } else
            err = vma_adjust(prev, prev->vm_start,
                end, prev->vm_pgoff, NULL);
        if (err)
            return NULL;
        khugepaged_enter_vma_merge(prev, vm_flags);
        return prev;
    }

    if (next && end == next->vm_start &&
            mpol_equal(policy, vma_policy(next)) &&
            can_vma_merge_before(next, vm_flags,
                    anon_vma, file, pgoff+pglen)) {
        if (prev && addr < prev->vm_end)
            err = vma_adjust(prev, prev->vm_start,
                addr, prev->vm_pgoff, NULL);
        else                    
            err = vma_adjust(area, addr, next->vm_end,
                next->vm_pgoff - pglen, NULL);
        if (err)
            return NULL;
        khugepaged_enter_vma_merge(area, vm_flags);
        return area;
    }

    return NULL;
}
```

这里就不详细分析这个函数了，主要通过`prev->vm_end == addr`判断即将分配的虚拟内存能否往前合并，通过`end == next->vm_start`判断即将分配的虚拟内存能否往后合并。其中，合并函数为`vma_adjust`。再往下就不分析了。

回到函数中，假设不能合并，就要通过slab构造一个`vm_area_struct`结构体，并设置相应的信息，slab是linux内核中分配小块内存的框架。然后通过`vma_link`插入到进程的红黑树中，

```
static void vma_link(struct mm_struct *mm, struct vm_area_struct *vma,
            struct vm_area_struct *prev, struct rb_node **rb_link,
            struct rb_node *rb_parent){

    __vma_link(mm, vma, prev, rb_link, rb_parent);
    mm->map_count++;
}
```

`__vma_link`执行实际的插入操作，就是一些红黑树的操作，不往下看了。

回到`mmap_region`中，最后通过`vma_set_page_prot`继续设置一些标志位，然后就返回分配到的虚拟内存的起始地址addr了，该返回值一直向上返回，然后退出系统调用，返回到glibc中。 
到这里简单总结一下MMAP，其实质就是通过mmap在进程的内存管理结构中的红黑树中分配一块没有使用的虚拟内存。

下一章继续往下分析glibc中的`_int_malloc`函数。