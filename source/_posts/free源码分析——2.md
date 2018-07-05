---
title: free源码分析——2
date: 2018-05-21 14:46:00
categories: pwn
tags: [heap]
---

# free源码分析—_int_free

根据上一章的分析可知，如果一个chunk不是由mmap分配得到，就会调用`_int_free`进行释放。下面来看，

```
void __libc_free(void *mem) {

    ...

    p = mem2chunk(mem);
    if (chunk_is_mmapped(p)){
        ...
    }

    ar_ptr = arena_for_chunk(p);
    _int_free(ar_ptr, p, 0);
}
```

## _int_free第一部分

首先来看`_int_free`第一部分，为了便于分析，这里省略了一些不关键的代码，

```
static void _int_free(mstate av, mchunkptr p, int have_lock) {
    INTERNAL_SIZE_T size;
    mfastbinptr *fb;
    mchunkptr nextchunk;
    INTERNAL_SIZE_T nextsize;
    int nextinuse;
    INTERNAL_SIZE_T prevsize;
    mchunkptr bck;
    mchunkptr fwd;

    const char *errstr = NULL;
    int locked = 0;
    size = chunksize(p);

    if (__glibc_unlikely(size < MINSIZE || !aligned_OK (size))) {
        goto errout;
    }

    check_inuse_chunk(av, p);

    if ((unsigned long) (size) <= (unsigned long) (get_max_fast ())) {

        free_perturb(chunk2mem(p), size - 2 * SIZE_SZ);
        set_fastchunks(av);
        unsigned int idx = fastbin_index(size);
        fb = &fastbin(av, idx);

        mchunkptr old = *fb, old2;
        unsigned int old_idx = ~0u;
        do {
            if (have_lock && old != NULL)
                old_idx = fastbin_index(chunksize(old));
            p->fd = old2 = old;
        } while ((old = catomic_compare_and_exchange_val_rel(fb, p, old2)) != old2);
    }

    ...

}
```

第一部分首先是检查`size`变量的合法性，然后比较`get_max_fast()`判断`size`是否在fastbin的范围内，如果在fastbin的管理范围内，就通过`set_fastchunks`设置分配区的标志位表示fastbin有空闲chunk，接下来根据`size`获得即将添加的chunk在fastbin中的索引`idx`，并通过该索引获得头指针`fb`，最后通过CAS操作将该chunk添加到fastbin中。这里需要注意fastbin中存放的chunk是按照单向链表组织的。

## _int_free第二部分

继续往下看，为了使整个代码结构清晰，这里保留了上一部分的if，

```
static void _int_free(mstate av, mchunkptr p, int have_lock) {

    ...

    if ((unsigned long) (size) <= (unsigned long) (get_max_fast ())) {

        ...

    }
    else if (!chunk_is_mmapped(p)) {

        nextchunk = chunk_at_offset(p, size);
        nextsize = chunksize(nextchunk);

        free_perturb(chunk2mem(p), size - 2 * SIZE_SZ);

        if (!prev_inuse(p)) {
            prevsize = p->prev_size;
            size += prevsize;
            p = chunk_at_offset(p, -((long ) prevsize));
            unlink(av, p, bck, fwd);
        }

        if (nextchunk != av->top) {
            nextinuse = inuse_bit_at_offset(nextchunk, nextsize);

            if (!nextinuse) {
                unlink(av, nextchunk, bck, fwd);
                size += nextsize;
            } else
                clear_inuse_bit_at_offset(nextchunk, 0);

            bck = unsorted_chunks(av);
            fwd = bck->fd;
            if (__glibc_unlikely(fwd->bk != bck)) {
                errstr = "free(): corrupted unsorted chunks";
                goto errout;
            }
            p->fd = fwd;
            p->bk = bck;
            if (!in_smallbin_range(size)) {
                p->fd_nextsize = NULL;
                p->bk_nextsize = NULL;
            }
            bck->fd = p;
            fwd->bk = p;

            set_head(p, size | PREV_INUSE);
            set_foot(p, size);

            check_free_chunk(av, p);
        }

        else {
            size += nextsize;
            set_head(p, size | PREV_INUSE);
            av->top = p;
            check_chunk(av, p);
        }

        ...

    }

    ...

}
```

如果将要释放的chunk不属于fastbin，且不是由mmap分配的，就首先获得下一个chunk的指针`nextchunk`和大小`nextsize`，如果前一个chunk空闲，就和前一个chunk合并，并通过`unlink`将该chunk从空闲链表中脱离。接下来，如果刚才前面取出的下一个chunk也为空闲，并且该chunk不是top chunk，则继续合并，否则将其设为空闲。再往下，就是取出unsortedbin的头指针，将合并后的chunk插入unsortedbin链表头部，并进行相应的设置。 
如果下一个chunk为top chunk，就将要释放的chunk合并到top chunk中。

## _int_free第三部分

继续往下看，

```
static void _int_free(mstate av, mchunkptr p, int have_lock) {

    ...

    if ((unsigned long) (size) <= (unsigned long) (get_max_fast ())) {

        ...

    }
    else if (!chunk_is_mmapped(p)) {

        ...

        if ((unsigned long) (size) >= FASTBIN_CONSOLIDATION_THRESHOLD) {
            if (have_fastchunks(av))
                malloc_consolidate(av);

            if (av == &main_arena) {
    #ifndef MORECORE_CANNOT_TRIM
                if ((unsigned long) (chunksize(av->top))
                        >= (unsigned long) (mp_.trim_threshold))
                    systrim(mp_.top_pad, av);
    #endif
            } else {
                heap_info *heap = heap_for_ptr(top(av));
                heap_trim(heap, mp_.top_pad);
            }
        }
        if (!have_lock) {
            assert(locked);
            (void) mutex_unlock(&av->mutex);
        }
    }
    else {
        munmap_chunk(p);
    }
}
```

如果前面释放的chunk比较大，就需要做一些处理了。首先对fastbin中的chunk进行合并并添加到unsortedbin中。然后，如果是主分配区，并且主分配区的top chunk大于一定的值，就通过`systrim`缩小top chunk。如果是非主分配区，就获得top chunk对应的非主分配区的`heap_info`指针，调用`heap_trim`尝试缩小该heap。后面来看`systrim`和`heap_trim`这两个函数。 
最后，说明chunk还是通过mmap分配的，就调用`munmap_chunk`释放它。`munmap_chunk`函数已经在上一章介绍了。

## systrim

`systrim`用于缩小主分配区的top chunk大小，下面来看，

```
static int systrim(size_t pad, mstate av) {
    long top_size;
    long extra;
    long released;
    char *current_brk;
    char *new_brk;
    size_t pagesize;
    long top_area;

    pagesize = GLRO(dl_pagesize);
    top_size = chunksize(av->top);

    top_area = top_size - MINSIZE - 1;
    if (top_area <= pad)
        return 0;

    extra = (top_area - pad) & ~(pagesize - 1);

    if (extra == 0)
        return 0;

    current_brk = (char *) (MORECORE(0));
    if (current_brk == (char *) (av->top) + top_size) {

        MORECORE(-extra);
        void (*hook)(void) = atomic_forced_read (__after_morecore_hook);
        if (__builtin_expect(hook != NULL, 0))
            (*hook)();
        new_brk = (char *) (MORECORE(0));

        LIBC_PROBE (memory_sbrk_less, 2, new_brk, extra);

        if (new_brk != (char *) MORECORE_FAILURE) {
            released = (long) (current_brk - new_brk);

            if (released != 0) {
                av->system_mem -= released;
                set_head(av->top, (top_size - released) | PREV_INUSE);
                check_malloc_state (av);
                return 1;
            }
        }
    }
    return 0;
}
```

首先，如果主分配区的top chunk本来就没什么空间，就直接返回，否则就将主分配区中可以缩小的大小保存在`extra`中。下面检查当前堆的`brk`指针是否和top chunk的结束地址相等，如果相等就可以通过`MORECORE`降低堆的大小，`MORECORE`是brk的系统调用，最后也是通过`do_munmap`释放虚拟内存的。`__after_morecore_hook`函数指针为空，不管它。再下来，获得释放后的堆指针保存在`new_brk`中，计算释放的虚拟内存的大小`released`，并将该信息更新到主分配区中，然后设置新top chunk的`size`。

## heap_trim

`heap_trim`用来缩小非主分配区的heap大小，下面来看，

```
static int
internal_function heap_trim(heap_info *heap, size_t pad) {
    mstate ar_ptr = heap->ar_ptr;
    unsigned long pagesz = GLRO(dl_pagesize);
    mchunkptr top_chunk = top(ar_ptr), p, bck, fwd;
    heap_info *prev_heap;
    long new_size, top_size, top_area, extra, prev_size, misalign;

    while (top_chunk == chunk_at_offset(heap, sizeof(*heap))) {
        prev_heap = heap->prev;
        prev_size = prev_heap->size - (MINSIZE - 2 * SIZE_SZ);
        p = chunk_at_offset(prev_heap, prev_size);
        misalign = ((long) p) & MALLOC_ALIGN_MASK;
        p = chunk_at_offset(prev_heap, prev_size - misalign);
        p = prev_chunk(p);
        new_size = chunksize(p) + (MINSIZE - 2 * SIZE_SZ) + misalign;
        if (!prev_inuse(p))
            new_size += p->prev_size;
        if (new_size + (HEAP_MAX_SIZE - prev_heap->size)
                < pad + MINSIZE + pagesz)
            break;
        ar_ptr->system_mem -= heap->size;
        arena_mem -= heap->size;
        delete_heap(heap);
        heap = prev_heap;
        if (!prev_inuse(p)){
            p = prev_chunk(p);
            unlink(ar_ptr, p, bck, fwd);
        }
        top (ar_ptr) = top_chunk = p;
        set_head(top_chunk, new_size | PREV_INUSE);
    }

    top_size = chunksize(top_chunk);
    top_area = top_size - MINSIZE - 1;
    if (top_area < 0 || (size_t) top_area <= pad)
        return 0;

    extra = ALIGN_DOWN(top_area - pad, pagesz);
    if ((unsigned long) extra < mp_.trim_threshold)
        return 0;

    if (shrink_heap(heap, extra) != 0)
        return 0;

    ar_ptr->system_mem -= extra;
    arena_mem -= extra;

    set_head(top_chunk, (top_size - extra) | PREV_INUSE);
    return 1;
}
```

第一个while表示，如果top chunk指针正好在`heap_info`上，则考虑删掉整个heap。这是因为此时，该heap只有一个top chunk。再删掉该heap之前，需要检查该heap的前一个heap是否有足够的空间，否则删掉该heap后，剩余的空间太小。 
经过计算后，`newsize`保存了前一个heap高地址处的fencepost和前一个空闲chunk（如果存在）的总大小组成，如果`newsize`加上该heap还未使用的内存（`HEAP_MAX_SIZE - prev_heap->size`）太小，就`break`退出循环，取消对整个heap的释放。否则，在更新了相应的信息后，调用`delete_heap`删除整个heap，`delete_heap`是一个宏，定义如下

```
#define delete_heap(heap) \
  do {                                        \
      if ((char *) (heap) + HEAP_MAX_SIZE == aligned_heap_area)           \
        aligned_heap_area = NULL;                         \
      __munmap ((char *) (heap), HEAP_MAX_SIZE);                  \
    } while (0)
```

`delete_heap`其最终通过`__munmap`释放整个heap，大小为`HEAP_MAX_SIZE`。 
删除掉整个heap后，如果前一个heap的fencepost的前面有一个空闲chunk，就将该空闲chunk从空闲链表中脱离，然后设置fencepost或者该空闲chunk（如果存在）的地址为新的top chunk，该top chunk的大小为前面计算的`new_size`。 
然后返回`while`继续检查，如果新的top chunk指针又正好在`heap_info`上，就表示该heap也就只有一个chunk即top chunk，就继续释放该heap。 
再往下，如果新的top chunk剩余空间`top_area`太小，就直接返回了。如果还有足够的空间，且`top_area`大于收缩阀值，就调用`shrink_heap`进一步将新的top chunk的大小减少`extra`。最后设置一些分配区的信息，并设置减少后的top chunk的大小为`top_size - extra`。

```
static int shrink_heap(heap_info *h, long diff) {
    long new_size;

    new_size = (long) h->size - diff;
    if (new_size < (long) sizeof(*h))
        return -1;

    h->size = new_size;
    return 0;
}
```

这里其实就是减小`heap_info`的`size`变量。

## 总结

下面对整个`_int_free`函数做个总结。 
首先检查将要释放的chunk是否属于fastbin，如果属于就将其添加到fastbin中。 
然后检查该chunk是否是由mmap分配的，如果不是，就根据其下一个chunk的类型添加到unsortedbin或者合并到top chunk中。 
接着，如果释放的chunk的大小大于一定的阀值，就需要通过`systrim`缩小主分配区的大小，或者通过`heap_trim`缩小非主分配区的大小。 
最后如果该chunk是由mmap的分配的，通过`munmap_chunk`释放。