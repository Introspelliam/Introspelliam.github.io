---
title: malloc源码分析——5
date: 2018-05-21 14:42:38
categories: pwn
tags: [heap]
---

# malloc源码分析—sysmalloc

本章主要分析`sysmalloc`的代码，在《malloc源码分析—2》中已经分析了部分`sysmalloc`的代码，主要用于对分配区进行初始化。本章查看余下的代码，

## 第一部分

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

    ...

    old_top = av->top;
    old_size = chunksize(old_top);
    old_end = (char *) (chunk_at_offset(old_top, old_size));
    brk = snd_brk = (char *) (MORECORE_FAILURE);

    if (av != &main_arena) {
        heap_info *old_heap, *heap;
        size_t old_heap_size;

        old_heap = heap_for_ptr(old_top);
        old_heap_size = old_heap->size;
        if ((long) (MINSIZE + nb - old_size) > 0
                && grow_heap(old_heap, MINSIZE + nb - old_size) == 0) {
            av->system_mem += old_heap->size - old_heap_size;
            arena_mem += old_heap->size - old_heap_size;
            set_head(old_top,
                    (((char *) old_heap + old_heap->size) - (char *) old_top) | PREV_INUSE);
        } else if ((heap = new_heap(nb + (MINSIZE + sizeof(*heap)), mp_.top_pad))) {
            heap->ar_ptr = av;
            heap->prev = old_heap;
            av->system_mem += heap->size;
            arena_mem += heap->size;
            top (av) = chunk_at_offset(heap, sizeof(*heap));
            set_head(top (av), (heap->size - sizeof (*heap)) | PREV_INUSE);

            old_size = (old_size - MINSIZE ) & ~MALLOC_ALIGN_MASK;
            set_head(chunk_at_offset (old_top, old_size + 2 * SIZE_SZ),
                    0 | PREV_INUSE);
            if (old_size >= MINSIZE) {
                set_head(chunk_at_offset (old_top, old_size),
                        (2 * SIZE_SZ) | PREV_INUSE);
                set_foot(chunk_at_offset (old_top, old_size), (2 * SIZE_SZ));
                set_head(old_top, old_size | PREV_INUSE | NON_MAIN_ARENA);
                _int_free(av, old_top, 1);
            } else {
                set_head(old_top, (old_size + 2 * SIZE_SZ) | PREV_INUSE);
                set_foot(old_top, (old_size + 2 * SIZE_SZ));
            }
        } else if (!tried_mmap)
            goto try_mmap;
    }
    else{

        ...

    }

    ...

}
```

首先，`old_top`、`old_size`和`old_end`分别保存了top chunk的指针，大小以及尾部的地址。 
如果是非主分配区，首先通过`heap_for_ptr`获得原top chunk对应的`heap_info`指针，

```
#define heap_for_ptr(ptr) \
  ((heap_info *) ((unsigned long) (ptr) & ~(HEAP_MAX_SIZE - 1)))
```

对于非主分配区，因为每个heap是按照`HEAP_MAX_SIZE`的大小分配且对齐的，而每个topchunk存在于每个heap的剩余空间（高地址处），因此通过`heap_for_ptr`就能取出`heap_info`指针，`heap_info`保存了每个heap的相关信息。获得`heap_info`指针后，就能获得该heap当前被使用的大小并将其保存在`old_heap_size`中。 
根据《malloc源码分析—4》，进入到sysmalloc前会尝试在top chunk分配内存，因此代码执行到这里肯定失败了。所以这里只有`MINSIZE + nb - old_size>0`这一种情况，即这时的top chunk空间不足了，因此首先通过`grow_heap`尝试向heap的高地址处增加heap当前使用的大小，即top chunk的大小，

```
static int grow_heap(heap_info *h, long diff) {
    size_t pagesize = GLRO(dl_pagesize);
    long new_size;

    diff = ALIGN_UP(diff, pagesize);
    new_size = (long) h->size + diff;
    if ((unsigned long) new_size > (unsigned long) HEAP_MAX_SIZE)
        return -1;

    if ((unsigned long) new_size > h->mprotect_size) {
        if (__mprotect((char *) h + h->mprotect_size,
                (unsigned long) new_size - h->mprotect_size,
                PROT_READ | PROT_WRITE) != 0)
            return -2;

        h->mprotect_size = new_size;
    }

    h->size = new_size;
    LIBC_PROBE(memory_heap_more, 2, h, h->size);
    return 0;
}
```

这段代码其实最关键的是`h->size = new_size`这一样，表示重新设置heap的大小至`new_size`。 
回到sysmalloc中，假设`grow_heap`成功，即将top chunk的大小设置为`MINSIZE + nb`，则重新设置分配区使用的内存大小，并且设置top chunk的`size`至新值（注意这里的`size`不能直接设置为`MINSIZE + nb`是因为在`grow_heap`中有对齐操作）。

假设`grow_heap`失败，大部分情况下说明heap的使用大小已经接近其最大值`HEAP_MAX_SIZE`了，此时只能通过`new_heap`重新分配一个heap，注意传入的参数`mp_.top_pad`表示在分配内存时，额外多分配的内存。

```
static heap_info * internal_function new_heap(size_t size, size_t top_pad) {
    size_t pagesize = GLRO(dl_pagesize);
    char *p1, *p2;
    unsigned long ul;
    heap_info *h;

    if (size + top_pad < HEAP_MIN_SIZE)
        size = HEAP_MIN_SIZE;
    else if (size + top_pad <= HEAP_MAX_SIZE)
        size += top_pad;
    else if (size > HEAP_MAX_SIZE)
        return 0;
    else
        size = HEAP_MAX_SIZE;
    size = ALIGN_UP(size, pagesize);

    p2 = MAP_FAILED;
    if (aligned_heap_area) {
        p2 = (char *) MMAP(aligned_heap_area, HEAP_MAX_SIZE, PROT_NONE,
                MAP_NORESERVE);
        aligned_heap_area = NULL;
        if (p2 != MAP_FAILED && ((unsigned long) p2 & (HEAP_MAX_SIZE - 1))) {
            __munmap(p2, HEAP_MAX_SIZE);
            p2 = MAP_FAILED;
        }
    }
    if (p2 == MAP_FAILED) {
        p1 = (char *) MMAP(0, HEAP_MAX_SIZE << 1, PROT_NONE, MAP_NORESERVE);
        if (p1 != MAP_FAILED) {
            p2 = (char *) (((unsigned long) p1 + (HEAP_MAX_SIZE - 1))
                    & ~(HEAP_MAX_SIZE - 1));
            ul = p2 - p1;
            if (ul)
                __munmap(p1, ul);
            else
                aligned_heap_area = p2 + HEAP_MAX_SIZE;
            __munmap(p2 + HEAP_MAX_SIZE, HEAP_MAX_SIZE - ul);
        } else {
            p2 = (char *) MMAP(0, HEAP_MAX_SIZE, PROT_NONE, MAP_NORESERVE);
            if (p2 == MAP_FAILED)
                return 0;

            if ((unsigned long) p2 & (HEAP_MAX_SIZE - 1)) {
                __munmap(p2, HEAP_MAX_SIZE);
                return 0;
            }
        }
    }
    if (__mprotect(p2, size, PROT_READ | PROT_WRITE) != 0) {
        __munmap(p2, HEAP_MAX_SIZE);
        return 0;
    }
    h = (heap_info *) p2;
    h->size = size;
    h->mprotect_size = size;
    LIBC_PROBE(memory_heap_new, 2, h, h->size);
    return h;
}
```

首先对需要分配的内存大小size做相应的调整。`aligned_heap_area`表示上一次`MMAP`分配后的结束地址，如果存在，就首先尝试从该地址分配大小为`HEAP_MAX_SIZE`的内存。`MMAP`最后是系统调用，对应的内核函数在《malloc源码分析—2》中已经介绍过了，这里只是一些标志位的区别。分配完后，会检查地址是否对齐，如果不对齐也是失败。 
如果第一次分配失败了，就会再尝试一次，这次分配`HEAP_MAX_SIZE*2`大小的内存，并且新内存的起始地址由内核决定。因为尝试分配了`HEAP_MAX_SIZE*2`大小的内存，其中必定包含了大小为`HEAP_MAX_SIZE`且和`HEAP_MAX_SIZE`对齐的内存，因此一旦分配成功，就从中截取出这部分内存。 
如果连第二次也分配失败了，就会通过`MMAP`进行第三次分配，这次只分配`HEAP_MAX_SIZE`大小的内存，并且起始地址由内核决定，如果又失败了就返回0。 
如果三面三次分配内存任何一次成功，就设置相应的可读写位置，并且返回分配区的`heap_info`指针。

重新回到`sysmalloc`中，假设分配成功，就会对刚刚分配得到的heap做相应的设置，其中`ar_ptr`表示所属的分配区的指针，`prev`表示上一个heap，所有的heap通过`prev`形成单向链表，然后通过`set_head`设置av分配区top chunk的`size`，这里也可以看出，对于刚分配的heap，包含了`heap_info`指针、top chunk、以及大于size的未被使用的部分。 
再接下来就要对原来的top chunk进行最后的处理，这里假设对齐，如果原top chunk的大小不够大，就将其分割成`old_size + 2 * SIZE_SZ`和`2 * SIZE_SZ`大小；如果原top chunk的大小足够大，就将其分割成`old_size`，`2 * SIZE_SZ`和`2 * SIZE_SZ`大小，并通过`_int_free`进行释放。

## 第二部分

继续往下看`sysmalloc`，上面一部分代码主要是针对非主分配区的操作，下面的这段代码就是针对主分配区的操作了。

```
static void * sysmalloc(INTERNAL_SIZE_T nb, mstate av) {

    ...

    if (av != &main_arena) {

        ...

    }
    else{
        size = nb + mp_.top_pad + MINSIZE;
        if (contiguous(av))
            size -= old_size;
        size = ALIGN_UP(size, pagesize);

        if (size > 0) {
            brk = (char *) (MORECORE(size));
            LIBC_PROBE (memory_sbrk_more, 2, brk, size);
        }

        if (brk != (char *) (MORECORE_FAILURE)) {
            void (*hook)(void) = atomic_forced_read (__after_morecore_hook);
            if (__builtin_expect (hook != NULL, 0))
            (*hook)();
        }
        else{
            if (contiguous (av))
                size = ALIGN_UP (size + old_size, pagesize);

            if ((unsigned long) (size) < (unsigned long) (MMAP_AS_MORECORE_SIZE))
                size = MMAP_AS_MORECORE_SIZE;

            if ((unsigned long) (size) > (unsigned long) (nb)){
                char *mbrk = (char *) (MMAP (0, size, PROT_READ | PROT_WRITE, 0));

                if (mbrk != MAP_FAILED){
                    brk = mbrk;
                    snd_brk = brk + size;
                    set_noncontiguous (av);
                }
            }
        }

        ...

    }

    ...

}
```

`MORECORE`是一个宏定义，其最终是通过系统调用分配内存，定义在linux内核的mmap.c文件中，

```
SYSCALL_DEFINE1(brk, unsigned long, brk){

    unsigned long retval;
    unsigned long newbrk, oldbrk;
    struct mm_struct *mm = current->mm;
    unsigned long min_brk;
    bool populate;

    down_write(&mm->mmap_sem);
    min_brk = mm->start_brk;
    if (brk < min_brk)
        goto out;

    if (check_data_rlimit(rlimit(RLIMIT_DATA), brk, mm->start_brk,
                  mm->end_data, mm->start_data))
        goto out;

    newbrk = PAGE_ALIGN(brk);
    oldbrk = PAGE_ALIGN(mm->brk);
    if (oldbrk == newbrk)
        goto set_brk;

    if (brk <= mm->brk) {
        if (!do_munmap(mm, newbrk, oldbrk-newbrk))
            goto set_brk;
        goto out;
    }

    if (find_vma_intersection(mm, oldbrk, newbrk+PAGE_SIZE))
        goto out;

    if (do_brk(oldbrk, newbrk-oldbrk) != oldbrk)
        goto out;

set_brk:
    mm->brk = brk;
    populate = newbrk > oldbrk && (mm->def_flags & VM_LOCKED) != 0;
    up_write(&mm->mmap_sem);
    if (populate)
        mm_populate(oldbrk, newbrk - oldbrk);
    return brk;

out:
    retval = mm->brk;
    up_write(&mm->mmap_sem);
    return retval;
}
```

首先会对传入堆的新地址`brk`做一些检查，然后该新地址小于原本的`brk`，就需要通过`do_munmap`释放虚拟内存，以减少堆的大小；反之，就通过`do_brk`增加堆得大小。其中`find_vma_intersection`用来判断增加堆空间后，是否会占用已经被分配的虚拟内存，

```
static inline struct vm_area_struct * find_vma_intersection(struct mm_struct * mm, unsigned long start_addr, unsigned long end_addr){
    struct vm_area_struct * vma = find_vma(mm,start_addr);

    if (vma && end_addr <= vma->vm_start)
        vma = NULL;
    return vma;
}
```

因为是增加堆的大小，因此只需要关心`do_brk`函数，

```
static unsigned long do_brk(unsigned long addr, unsigned long len){

    struct mm_struct *mm = current->mm;
    struct vm_area_struct *vma, *prev;
    unsigned long flags;
    struct rb_node **rb_link, *rb_parent;
    pgoff_t pgoff = addr >> PAGE_SHIFT;
    int error;

    len = PAGE_ALIGN(len);
    if (!len)
        return addr;

    flags = VM_DATA_DEFAULT_FLAGS | VM_ACCOUNT | mm->def_flags;

    error = get_unmapped_area(NULL, addr, len, 0, MAP_FIXED);
    if (error & ~PAGE_MASK)
        return error;

    error = mlock_future_check(mm, mm->def_flags, len);
    if (error)
        return error;

    verify_mm_writelocked(mm);

    while (find_vma_links(mm, addr, addr + len, &prev, &rb_link,
                  &rb_parent)) {
        if (do_munmap(mm, addr, len))
            return -ENOMEM;
    }

    if (!may_expand_vm(mm, len >> PAGE_SHIFT))
        return -ENOMEM;

    if (mm->map_count > sysctl_max_map_count)
        return -ENOMEM;

    if (security_vm_enough_memory_mm(mm, len >> PAGE_SHIFT))
        return -ENOMEM;

    vma = vma_merge(mm, prev, addr, addr + len, flags,
                    NULL, NULL, pgoff, NULL);
    if (vma)
        goto out;

    vma = kmem_cache_zalloc(vm_area_cachep, GFP_KERNEL);
    if (!vma) {
        vm_unacct_memory(len >> PAGE_SHIFT);
        return -ENOMEM;
    }

    INIT_LIST_HEAD(&vma->anon_vma_chain);
    vma->vm_mm = mm;
    vma->vm_start = addr;
    vma->vm_end = addr + len;
    vma->vm_pgoff = pgoff;
    vma->vm_flags = flags;
    vma->vm_page_prot = vm_get_page_prot(flags);
    vma_link(mm, vma, prev, rb_link, rb_parent);
out:
    perf_event_mmap(vma);
    mm->total_vm += len >> PAGE_SHIFT;
    if (flags & VM_LOCKED)
        mm->locked_vm += (len >> PAGE_SHIFT);
    vma->vm_flags |= VM_SOFTDIRTY;
    return addr;
}
```

这段代码和第二章中分析的`mmap_region`函数很类似，这里简单分析如下，`get_unmapped_area`用来检查需要分配的虚拟内存地址是否已经被使用，`find_vma_links`用来查找需要插入的虚拟内存在红黑树的位置，`may_expand_vm`用来检查虚拟内存是否会超过系统的限制，`vma_merge`用来合并虚拟内存，如果不能合并，就通过slab分配一个`vma`，进行相应的设置，并通过`vma_link`插入到进程的红黑树中。

从linux的代码中回来，继续看`sysmalloc`，假设分配成功，会查找是否有`__after_morecore_hook`函数并执行，这里假设该函数指针为null。 
假设分配失败，则进入`else`部分，首先对需要分配的大小按地址对齐，并且设置分配`size`的最小值为`MMAP_AS_MORECORE_SIZE`（1MB），然后通过`MMAP`宏分配内存，该函数已经在《malloc源码分析—2》分析过了。这里注意，如果是通过mmap分配的内存，则设置分配区为不连续标志位。

## 第三部分

继续往下看sysmalloc，

```
static void * sysmalloc(INTERNAL_SIZE_T nb, mstate av) {

    ...

    if (av != &main_arena) {

        ...

    }
    else{

        ...

        if (brk != (char *) (MORECORE_FAILURE)) {
            if (mp_.sbrk_base == 0)
                mp_.sbrk_base = brk;
            av->system_mem += size;

            if (brk == old_end && snd_brk == (char *) (MORECORE_FAILURE))
                set_head(old_top, (size + old_size) | PREV_INUSE);
            else if (contiguous (av) && old_size && brk < old_end) {
                malloc_printerr(3, "break adjusted to free malloc space", brk, av);
            }
            else {
                front_misalign = 0;
                end_misalign = 0;
                correction = 0;
                aligned_brk = brk;

                if (contiguous(av)) {
                    if (old_size)
                        av->system_mem += brk - old_end;

                    front_misalign = (INTERNAL_SIZE_T) chunk2mem(
                            brk) & MALLOC_ALIGN_MASK;
                    if (front_misalign > 0) {
                        correction = MALLOC_ALIGNMENT - front_misalign;
                        aligned_brk += correction;
                    }

                    correction += old_size;
                    end_misalign = (INTERNAL_SIZE_T) (brk + size + correction);
                    correction += (ALIGN_UP(end_misalign, pagesize)) - end_misalign;

                    assert(correction >= 0);
                    snd_brk = (char *) (MORECORE(correction));

                    if (snd_brk == (char *) (MORECORE_FAILURE)) {
                        correction = 0;
                        snd_brk = (char *) (MORECORE(0));
                    } else {
                        void (*hook)(
                        void) = atomic_forced_read (__after_morecore_hook);
                        if (__builtin_expect (hook != NULL, 0))
                        (*hook)();
                    }
                }

                ...
            }
        }
    }

    ...

}
```

假设增加了主分配区的top chunk成功，则更新`sbrk_base`和分配区已分配的内存大小。 
然后，第一个判断表示，新分配的内存地址和原来的`top chunk`连续，并且不是通过`MMAP`分配的，这时只需要更新原来top chunk的大小`size`。 
第二个判断表示如果分配区的连续标志位置位，top chunk的大小大于0，但是分配的`brk`小于原来的top chunk结束地址，这里就判定出错了。 
进入第三个判断表示新分配的内存地址大于原来的top chunk的结束地址，但是不连续。这种情况下，如果分配区的连续标志位置位，则表示不是通过MMAP分配的，肯定有其他线程调用了`brk`在堆上分配了内存，`av->system_mem += brk - old_end`表示将其他线程分配的内存一并计入到该分配区分配的内存大小。然后将刚刚分配的地址`brk`按`MALLOC_ALIGNMENT`对齐。 
再往下就要处理地址不连续的问题了，因为地址不连续，就要放弃原来top chunk后面一部分的内存大小，并且将这一部分内存大小“补上”到刚刚分配的新内存后面。首先计算堆上补上内存后的结束地址并保存在`correction`中，然后调用`MORECORE`继续分配一次，将新分配内存的开始地址保存在`snd_brk`中。如果分配失败，则将`correction`设为0，并将`snd_brk`重置为原来分配的内存的结束地址，表示放弃该次补偿操作；如果分配成功，就调用`__after_morecore_hook`函数，这里假设该函数指针为`null`。

## 第四部分

继续往下看sysmalloc，

```
static void * sysmalloc(INTERNAL_SIZE_T nb, mstate av) {

    ...

    if (av != &main_arena) {

        ...

    }
    else{

        ...

        if (brk != (char *) (MORECORE_FAILURE)) {

            ...

            if (brk == old_end && snd_brk == (char *) (MORECORE_FAILURE))
                ...
            else if (contiguous (av) && old_size && brk < old_end) {
                ...
            }
            else {

                ...

                if (contiguous(av)) {

                    ...

                }

                else{
                    if (MALLOC_ALIGNMENT == 2 * SIZE_SZ)
                    assert (((unsigned long) chunk2mem (brk) & MALLOC_ALIGN_MASK) == 0);
                    else{
                        front_misalign = (INTERNAL_SIZE_T) chunk2mem (brk) & MALLOC_ALIGN_MASK;
                        if (front_misalign > 0){
                            aligned_brk += MALLOC_ALIGNMENT - front_misalign;
                        }
                    }

                    if (snd_brk == (char *) (MORECORE_FAILURE)){
                        snd_brk = (char *) (MORECORE (0));
                    }
                }

                if (snd_brk != (char *) (MORECORE_FAILURE)) {
                    av->top = (mchunkptr) aligned_brk;
                    set_head(av->top,
                            (snd_brk - aligned_brk + correction) | PREV_INUSE);
                    av->system_mem += correction;

                    if (old_size != 0) {
                        old_size = (old_size - 4 * SIZE_SZ) & ~MALLOC_ALIGN_MASK;
                        set_head(old_top, old_size | PREV_INUSE);

                        chunk_at_offset (old_top, old_size)->size = (2 * SIZE_SZ)
                                | PREV_INUSE;

                        chunk_at_offset (old_top, old_size + 2 * SIZE_SZ)->size = (2
                                * SIZE_SZ) | PREV_INUSE;

                        if (old_size >= MINSIZE) {
                            _int_free(av, old_top, 1);
                        }
                    }
                }
            }
        }
    }

    ...

}
```

开头的`else`表示分配区的连续标志没有置位，这时只要按照`MALLOC_ALIGNMENT`做简单的对齐就行了，如果是通过`brk`分配的内存，则通过`MORECORE (0)`得到新分配的内存的结束地址并保存在`snd_brk`中。 
再往下进入`if`，设置分配区的top指针为经过对齐之后的起始地址`aligned_brk`，设置top chunk的大小`size`，`aligned_brk`表示对齐造成的误差，`correction`是因为要补偿原来top chunk剩余内存造成的误差，然后设置分配区已分配的内存大小。 
因为不连续，最后`if`内是设置原top chunk的`fencepost`，将原来top chunk的剩余空间拆成两个`SIZE_SZ*2`大小的chunk，如果剩下的大小大于可分配的chunk的最小值`MINSIZE`，就通过`_int_free`释放掉整个剩余内存。

## 第五部分

继续往下看sysmalloc最后一部分，

```
static void * sysmalloc(INTERNAL_SIZE_T nb, mstate av) {

    ...

    if ((unsigned long) av->system_mem > (unsigned long) (av->max_system_mem))
        av->max_system_mem = av->system_mem;
    check_malloc_state (av);

    p = av->top;
    size = chunksize(p);

    if ((unsigned long) (size) >= (unsigned long) (nb + MINSIZE )) {
        remainder_size = size - nb;
        remainder = chunk_at_offset(p, nb);
        av->top = remainder;
        set_head(p, nb | PREV_INUSE | (av != &main_arena ? NON_MAIN_ARENA : 0));
        set_head(remainder, remainder_size | PREV_INUSE);
        check_malloced_chunk (av, p, nb);
        return chunk2mem(p);
    }

    __set_errno(ENOMEM);
    return 0;
}
```

这里就是获得前面所有代码更新后的top chunk，然后从该top chunk中分配用户需要的大小chunk并返回，如果失败则返回0。

## 总结

简单总结一下`sysmalloc`函数，这里不包含《malloc源码分析—2》中的代码，该代码用于初始化。首先进入`sysmalloc`函数就表示top chunk的空间不够了。 
假设当前分配区不是主分配区，就通过`grow_heap`增加top chunk的空间，如果失败就通过`new_heap`重新分配一个heap，并将该分配区的top chunk指针指向新分配的heap的空闲内存。 
如果当前分配区是主分配区，首先会通过`brk`在堆上分配内存以增加top chunk的空间，如果失败再通过`MMAP`分配。假设新分配内存的地址不连续，而分配区的连续标志位置位，就会继续分配内存以补偿。 
最后，只要分配成功，就可以从被更新的top chunk分配所需的内存。