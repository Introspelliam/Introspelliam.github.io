---
title: free源码分析——1
date: 2018-05-21 14:44:59
categories: pwn
tags: [heap]
---

# free源码分析—__libc_free

本章继续之前的glibc中的《malloc源码分析》系列开始分析free的源代码，malloc的源码分析可以查看博客里同类别文章下的《malloc源码分析—1》到《malloc源码分析—5》，因此free的源码中有一些结构和malloc相似的地方就不会做过多的介绍了。

首先在glibc的malloc.c中有如下定义，

```
strong_alias( __libc_free, __cfree)
weak_alias( __libc_free, cfree)
strong_alias( __libc_free, __free)
strong_alias( __libc_free, free)
```

因此，`free`是`__libc_free`的别名，实际执行的是`__libc_free`函数，下面来看，

```
void __libc_free(void *mem) {
    mstate ar_ptr;
    mchunkptr p;

    void (*hook)(void *, const void *) = atomic_forced_read (__free_hook);
    if (__builtin_expect(hook != NULL, 0)) {
        (*hook)(mem, RETURN_ADDRESS(0));
        return;
    }

    if (mem == 0)
        return;

    p = mem2chunk(mem);

    if (chunk_is_mmapped(p)){
        if (!mp_.no_dyn_threshold
                && p->size
                        > mp_.mmap_threshold&& p->size <= DEFAULT_MMAP_THRESHOLD_MAX) {
            mp_.mmap_threshold = chunksize(p);
            mp_.trim_threshold = 2 * mp_.mmap_threshold;
            LIBC_PROBE (memory_mallopt_free_dyn_thresholds, 2,
                    mp_.mmap_threshold, mp_.trim_threshold);
        }
        munmap_chunk(p);
        return;
    }

    ar_ptr = arena_for_chunk(p);
    _int_free(ar_ptr, p, 0);
}
```

`__libc_free`首先查看是否有`__free_hook`函数，如果有就直接调用，这里假设没有默认函数可用。接下来通过`mem2chunk`将虚拟内存的指针`mem`转换为对应的chunk指针`p`，

```
#define mem2chunk(mem) ((mchunkptr)((char*)(mem) - 2*SIZE_SZ))
```

因为一个使用中的chunk结构体只使用其`prev_size`和`size`字段，因此这里只需要减去`2*SIZE_SZ`。 
接下来，`chunk_is_mmapped`用来检查size最低三位中的标志位，判断该chunk是否是由mmap分配的，如果是，就调用`munmap_chunk`释放该chunk并返回，在调用`munmap_chunk`之前，需要更新全局的mmap阀值和收缩阀值。 
再往下，如果该chunk不是由mmap分配的，就通过`arena_for_chunk`获得分配区指针`ar_ptr`，并调用`_int_free`释放内存。`_int_free`放在下一章分析，本章重点分析`munmap_chunk`函数。

## munmap_chunk

munmap_chunk用来释放由mmap分配的chunk，下面来看，

```
static void internal_function munmap_chunk(mchunkptr p) {
    INTERNAL_SIZE_T size = chunksize(p);

    assert(chunk_is_mmapped (p));

    uintptr_t block = (uintptr_t) p - p->prev_size;
    size_t total_size = p->prev_size + size;

    if (__builtin_expect(((block | total_size) & (GLRO(dl_pagesize) - 1)) != 0,
            0)) {
        malloc_printerr(check_action, "munmap_chunk(): invalid pointer",
                chunk2mem(p), NULL);
        return;
    }

    atomic_decrement(&mp_.n_mmaps);
    atomic_add(&mp_.mmapped_mem, -total_size);

    __munmap((char *) block, total_size);
}
```

首先获得前一个chunk的指针`block`，计算这两个chunk的`size`之和至`total_size`，接着对全局结构`mp_`进行相应的设置后，就通过`__munmap`释放这两个chunk。根据malloc的源码可知，由mmap分配的chunk是独立的，大部分情况下，`p->prev_size`为0，因此这里还是释放一个chunk，特殊情况下需要释放两个chunk，特殊情况请参考`_int_malloc`中的代码。 
`__munmap`再往下就是系统调用了，定义在linux内核代码的mmap.c中，

```
SYSCALL_DEFINE2(munmap, unsigned long, addr, size_t, len){

    profile_munmap(addr);
    return vm_munmap(addr, len);
}
```

`profile_munmap`为空函数，下面看vm_munmap，

```
int vm_munmap(unsigned long start, size_t len){

    int ret;
    struct mm_struct *mm = current->mm;

    down_write(&mm->mmap_sem);
    ret = do_munmap(mm, start, len);
    up_write(&mm->mmap_sem);
    return ret;
}
```

这里就是信号量的操作，最主要是执行`do_munmap`释放内存，为了方便分析和查看，只复制了`do_munmap`的关键代码，

```
int do_munmap(struct mm_struct *mm, unsigned long start, size_t len){

    unsigned long end;
    struct vm_area_struct *vma, *prev, *last;

    if ((start & ~PAGE_MASK) || start > TASK_SIZE || len > TASK_SIZE-start)
        return -EINVAL;
    len = PAGE_ALIGN(len);

    vma = find_vma(mm, start);
    prev = vma->vm_prev;
    end = start + len;
    if (vma->vm_start >= end)
        return 0;

    if (start > vma->vm_start) {
        int error;

        if (end < vma->vm_end && mm->map_count >= sysctl_max_map_count)
            return -ENOMEM;

        error = __split_vma(mm, vma, start, 0);
        if (error)
            return error;
        prev = vma;
    }

    last = find_vma(mm, end);
    if (last && end > last->vm_start) {
        int error = __split_vma(mm, last, end, 1);
        if (error)
            return error;
    }
    vma = prev ? prev->vm_next : mm->mmap;

    detach_vmas_to_be_unmapped(mm, vma, prev, end);
    unmap_region(mm, vma, prev, start, end);
    arch_unmap(mm, vma, start, end);
    remove_vma_list(mm, vma);

    return 0;
}
```

首先对传入的参数进行检查，需要释放的虚拟内存的开始地址`start`和长度`len`必须按页对齐，且不能释放内核空间的内存。 
接着通过`find_vma`在进程的管理内存的AVL树上查找第一个结束地址大于`start`的虚拟内存`vma`，如果`vma->vm_start >= end`，说明需要释放的虚拟内存本来就不存在，因此什么也不做返回；如果`start > vma->vm_start`，则表示找到的`vma`包含了需要释放的内存，这时候通过`__split_vma`函数将该`vma`根据`start`地址划分成两块，因此需要判断虚拟内存的数量是否超过了系统的限制`sysctl_max_map_count`。为了方便分析，下面只给出了`__split_vma`的几行关键代码，

```
static int __split_vma(struct mm_struct *mm, struct vm_area_struct *vma,
          unsigned long addr, int new_below){

    struct vm_area_struct *new;
    new = kmem_cache_alloc(vm_area_cachep, GFP_KERNEL);
    *new = *vma;

    if (new_below)
        new->vm_end = addr;
    else {
        new->vm_start = addr;
        new->vm_pgoff += ((addr - vma->vm_start) >> PAGE_SHIFT);
    }

    if (new_below)
        err = vma_adjust(vma, addr, vma->vm_end, vma->vm_pgoff +
            ((addr - new->vm_start) >> PAGE_SHIFT), new);
    else
        err = vma_adjust(vma, vma->vm_start, addr, vma->vm_pgoff, new);

    if (!err)
        return 0;
}
```

首先分配一个`vm_area_struct`结构体`new`，然后将`vma`中的所有内容拷贝到`new`中，`new_below`决定将原`vma`按照`addr`决定的地址分割成两个后，`vma`中保存低地址部分还是高地址部分。`do_munmap`第一次进入`__split_vma`时`new_below`为0，因此返回的`vma`保存低地址部分。然后调用`vma_adjust`对低地址部分的`vma`进行相应的设置，主要是更改其`end`变量为`addr`，并将高地址部分插入进程内存的管理树中。

回到`do_munmap`中，`find_vma(mm, end)`获得最尾部的`last`，如果该`last`包含了需要释放的虚拟内存，就继续将其拆成两部分，这时候由于`new_below`为1，因此返回的`last`为高地址部分。返回后，`vma`将指向低地址部分。

结合前面的分析，在执行`detach_vmas_to_be_unmapped`之前，原来的vma被拆成如下所示 
| prev | vma | … | vma | last | 
`mm->mmap`的赋值是在`vma_adjust`中，其实就是拆分后低地址处那块虚拟内存。 
接下来`detach_vmas_to_be_unmapped`用于将所有和要释放的内存有交集的`vma`从红黑树中删除，并形成一个以`vma`为链表头的链表。根据刚刚`vma`被拆开成的结果，其实就是取数组中所有除了`prev`和`last`的元素构成一个链表。即 
| prev | vma | … | vma | last | 
经过`detach_vmas_to_be_unmapped`后变成， 
| prev| last | 
| vma | … | vma | 
往下就是要释放第二部分。

```
static void detach_vmas_to_be_unmapped(struct mm_struct *mm, struct vm_area_struct *vma,
    struct vm_area_struct *prev, unsigned long end){

    struct vm_area_struct **insertion_point;
    struct vm_area_struct *tail_vma = NULL;

    insertion_point = (prev ? &prev->vm_next : &mm->mmap);
    vma->vm_prev = NULL;
    do {
        vma_rb_erase(vma, &mm->mm_rb);
        mm->map_count--;
        tail_vma = vma;
        vma = vma->vm_next;
    } while (vma && vma->vm_start < end);
    *insertion_point = vma;
    if (vma) {
        vma->vm_prev = prev;
        vma_gap_update(vma);
    } else
        mm->highest_vm_end = prev ? prev->vm_end : 0;
    tail_vma->vm_next = NULL;

    vmacache_invalidate(mm);
}
```

回到`do_munmap`中，`unmap_region`就是用于释放内存了。下面来看，

```
static void unmap_region(struct mm_struct *mm,
        struct vm_area_struct *vma, struct vm_area_struct *prev,
        unsigned long start, unsigned long end){

    struct vm_area_struct *next = prev ? prev->vm_next : mm->mmap;
    struct mmu_gather tlb;

    lru_add_drain();
    tlb_gather_mmu(&tlb, mm, start, end);
    update_hiwater_rss(mm);
    unmap_vmas(&tlb, vma, start, end);
    free_pgtables(&tlb, vma, prev ? prev->vm_end : FIRST_USER_ADDRESS,
                 next ? next->vm_start : USER_PGTABLES_CEILING);
    tlb_finish_mmu(&tlb, start, end);
}
```

`lru_add_drain`用于将`percpu`变量`pagevec`对应的每个`page`放回其对应的`zone`的`lru`链表中，因为马上要解映射了，这些缓存的page变量由可能被改变。 
`tlb_gather_mmu`构造了一个`mmu_gather`变量并初始化。 
接下来的`unmap_vmas`用于解映射，即释放存在物理页面映射的虚拟内存，

```
void unmap_vmas(struct mmu_gather *tlb, struct vm_area_struct *vma, unsigned long start_addr, unsigned long end_addr){

    struct mm_struct *mm = vma->vm_mm;

    mmu_notifier_invalidate_range_start(mm, start_addr, end_addr);
    for ( ; vma && vma->vm_start < end_addr; vma = vma->vm_next)
        unmap_single_vma(tlb, vma, start_addr, end_addr, NULL);
    mmu_notifier_invalidate_range_end(mm, start_addr, end_addr);
}
```

这里开始遍历`vma`链表，对每个`vma`调用`unmap_single_vma`进行释放，

```
static void unmap_single_vma(struct mmu_gather *tlb, struct vm_area_struct *vma,                        unsigned long start_addr, unsigned long end_addr, struct zap_details *details){
    unsigned long start = max(vma->vm_start, start_addr);
    unsigned long end;

    if (start >= vma->vm_end)
        return;
    end = min(vma->vm_end, end_addr);
    if (end <= vma->vm_start)
        return;

    if (vma->vm_file)
        uprobe_munmap(vma, start, end);

    if (unlikely(vma->vm_flags & VM_PFNMAP))
        untrack_pfn(vma, 0, 0);

    if (start != end) {
        if (unlikely(is_vm_hugetlb_page(vma))) {
            if (vma->vm_file) {
                i_mmap_lock_write(vma->vm_file->f_mapping);
                __unmap_hugepage_range_final(tlb, vma, start, end, NULL);
                i_mmap_unlock_write(vma->vm_file->f_mapping);
            }
        } else
            unmap_page_range(tlb, vma, start, end, details);
    }
}
```

这里主要就是通过`unmap_page_range`进行释放。再往下因为涉及太多linux内核内存管理的知识，这里就不深入分析了，最后就是通过虚拟地址找到页表`pte`，解开和物理页面之间的映射，并设置一些page结构。 
由于`unmap_vmas`后，一些页表里没有了相对应的物理页面，`free_pgtables`将这些页表释放。

```
void free_pgtables(struct mmu_gather *tlb, struct vm_area_struct *vma,
        unsigned long floor, unsigned long ceiling){

    while (vma) {
        struct vm_area_struct *next = vma->vm_next;
        unsigned long addr = vma->vm_start;

        unlink_anon_vmas(vma);
        unlink_file_vma(vma);

        if (is_vm_hugetlb_page(vma)) {
            hugetlb_free_pgd_range(tlb, addr, vma->vm_end,
                floor, next? next->vm_start: ceiling);
        } else {

            while (next && next->vm_start <= vma->vm_end + PMD_SIZE
                   && !is_vm_hugetlb_page(next)) {
                vma = next;
                next = vma->vm_next;
                unlink_anon_vmas(vma);
                unlink_file_vma(vma);
            }
            free_pgd_range(tlb, addr, vma->vm_end,
                floor, next? next->vm_start: ceiling);
        }
        vma = next;
    }
}
```

这里主要是调用`free_pgd_range`。该函数中，假设要释放的虚拟内存为vma，其前一个vma为`prev`，后一个为`last`，如果释放完`vma`后，`prev->vm_end`到`last->vm_start`大于一个pgd管理的内存大小（32位系统下为4MB），就释放pgd里的所有页表，如果小于4MB，就什么也不做返回。

再回到`do_munmap`中，`arch_unmap`是一些体系结构相关的操作，不管它。`remove_vma_list`释放每个`vma`对应的`vm_area_struct`结构至slab分配器中。

```
static void remove_vma_list(struct mm_struct *mm, struct vm_area_struct *vma){
    unsigned long nr_accounted = 0;

    update_hiwater_vm(mm);
    do {
        long nrpages = vma_pages(vma);

        if (vma->vm_flags & VM_ACCOUNT)
            nr_accounted += nrpages;
        vm_stat_account(mm, vma->vm_flags, vma->vm_file, -nrpages);
        vma = remove_vma(vma);
    } while (vma);
    vm_unacct_memory(nr_accounted);
    validate_mm(mm);
}
```

主要的函数是`remove_vma`，该函数通过`kmem_cache_free`释放对应的`vma`，并返回链表上的下一个`vma`。

```
static struct vm_area_struct *remove_vma(struct vm_area_struct *vma){

    struct vm_area_struct *next = vma->vm_next;

    might_sleep();
    if (vma->vm_ops && vma->vm_ops->close)
        vma->vm_ops->close(vma);
    if (vma->vm_file)
        fput(vma->vm_file);
    mpol_put(vma_policy(vma));
    kmem_cache_free(vm_area_cachep, vma);
    return next;
}
```