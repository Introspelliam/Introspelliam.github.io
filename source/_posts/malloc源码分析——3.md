---
title: malloc源码分析——3
date: 2018-05-21 14:40:59
categories: pwn
tags: [heap]
---

# malloc源码分析—_int_malloc

上一章分析了`_int_malloc`的前面一小部分，本章继续往下看，

# _int_malloc — fastbin

```
static void * _int_malloc(mstate av, size_t bytes) {

    ...

    if ((unsigned long) (nb) <= (unsigned long) (get_max_fast ())) {
        idx = fastbin_index(nb);
        mfastbinptr *fb = &fastbin(av, idx);
        mchunkptr pp = *fb;
        do {
            victim = pp;
            if (victim == NULL)
                break;
        } while ((pp = catomic_compare_and_exchange_val_acq(fb, victim->fd, victim))
                != victim);
        if (victim != 0) {
            if (__builtin_expect(fastbin_index (chunksize (victim)) != idx, 0)) {
                errstr = "malloc(): memory corruption (fast)";
                errout: malloc_printerr(check_action, errstr, chunk2mem(victim),
                        av);
                return NULL;
            }check_remalloced_chunk (av, victim, nb);
            void *p = chunk2mem(victim);
            alloc_perturb(p, bytes);
            return p;
        }
    }

    ...

}
```

`get_max_fast`返回fastbin可以存储内存的最大值，它在ptmalloc的初始化函数`malloc_init_state`中定义，后面会分析这个函数。 
如果需要分配的内存大小nb落在fastbin的范围内，首先调用`fastbin_index`获得chunk大小`nb`对应的fastbin索引。

```
#define fastbin_index(sz) \
  ((((unsigned int) (sz)) >> (SIZE_SZ == 8 ? 4 : 3)) - 2)
```

减2是根据fastbin存储的内存最小值计算的，本章假设`SIZE_SZ=4`，因此改写后`idx = nb/8-2`。 
获得索引idx后，就通过fastbin取出空闲chunk链表指针，`mfastbinptr`其实就是`malloc_chunk`指针，

```
#define fastbin(ar_ptr, idx) ((ar_ptr)->fastbinsY[idx])
```

下面的do、while循环又是一个CAS操作，其作用是从刚刚得到的空闲chunk链表指针中取出第一个空闲的chunk(victim)，并将链表头设置为该空闲chunk的下一个chunk(victim->fd)。这里注意，fastbin中使用的是单链表，而后面smallbin使用的是双链表。 
获得空闲chunk后，需要转换为可以存储的内存指针，`chunk2mem`上一章分析过了，就是返回`malloc_chunk`结构中fd所在的位置，因为当一个chunk被使用时，`malloc_chunk`结构中`fd`、`bk`包括后面的变量都没有用了。最后调用`alloc_perturb`对用户使用的内存进行初始化，然后就返回该内存的指针了。 
假设fastbin中没有找到空闲chunk，或者fastbin根本没有初始化，或者其他原因，就进入下一步，从smallbin中获取内存，因此继续往下看.

# _int_malloc — smallbin & largebin

```
static void * _int_malloc(mstate av, size_t bytes) {

    ...

    if (in_smallbin_range(nb)) {
        idx = smallbin_index(nb);
        bin = bin_at (av, idx);

        if ((victim = last(bin)) != bin) {
            if (victim == 0)
                malloc_consolidate(av);
            else {
                bck = victim->bk;
                if (__glibc_unlikely(bck->fd != victim)) {
                    errstr = "malloc(): smallbin double linked list corrupted";
                    goto errout;
                }
                set_inuse_bit_at_offset(victim, nb);
                bin->bk = bck;
                bck->fd = bin;

                if (av != &main_arena)
                    victim->size |= NON_MAIN_ARENA;
                check_malloced_chunk (av, victim, nb);
                void *p = chunk2mem(victim);
                alloc_perturb(p, bytes);
                return p;
            }
        }
    }else {
        idx = largebin_index(nb);
        if (have_fastchunks(av))
            malloc_consolidate(av);
    }

    ...

}
```

首先

```
#define in_smallbin_range(sz)  \
  ((unsigned long) (sz) < (unsigned long) MIN_LARGE_SIZE)
```

基于本章假设，`MIN_LARGE_SIZE`经过换算后为512字节，因此低于512字节大小的内存块都归smallbin管理。 
接下来通过`bin_at`获得smallbin空闲chunk链表指针，

```
#define bin_at(m, i) \
  (mbinptr) (((char *) &((m)->bins[((i) - 1) * 2]))               \
             - offsetof (struct malloc_chunk, fd))
```

这里乘2，并且减去fd相对于`malloc_chunk`中的位置是因为smallbin中存储的是fd和bk指针。 
`last`定义为

```
#define last(b)      ((b)->bk)
```

该函数获得chunk的前一个chunk，由因为该chunk是smallbin的链表头，因此获得的是最后一个chunk，如果两者相等，表示对应的链表为空，什么都不做。 
这里假设不相等，接下来有两种情况，第一种是`victim=0`，表示smallbin还没有初始化，这里需要特别说明一下这里。smallbin初始化为`malloc_chunk`指针数组，虽然定义为指针数组，但实际上存储的是fd和bk指针，如下所示 
|fd|bk|fd|bk|…|fd|bk| 
当smallbin还未初始化时，假设`idx=1`，根据`bin_at`取出的`bin`是一个虚拟的`malloc_chunk`指针，`bin->fd`，是第二个fd，因此`bin->bk`就是对应的bk，其值为0（bin->bk取出的不是地址，而是值）。因此当`victim`为0时，可以断定smallbin未初始化，此时调用`malloc_consolidate`进行初始化，

```
static void malloc_consolidate(mstate av) {

    ...

    if (get_max_fast () != 0) {

        ...

    } else {
        malloc_init_state(av);
        check_malloc_state(av);
    }
}
```

省略代码的if语句里是将fastbin中的chunk进行合并，然后添加到bins中，这里不分析，因为还未初始化，因此`get_max_fast`返回0，后面的章节碰到了再分析。进入else部分，`check_malloc_state`为空函数，`malloc_init_state`就是主要的初始化函数，

```
static void malloc_init_state(mstate av) {
    int i;
    mbinptr bin;

    for (i = 1; i < NBINS; ++i) {
        bin = bin_at (av, i);
        bin->fd = bin->bk = bin;
    }

#if MORECORE_CONTIGUOUS
    if (av != &main_arena)
#endif
        set_noncontiguous(av);
    if (av == &main_arena)
        set_max_fast(DEFAULT_MXFAST);
    av->flags |= FASTCHUNKS_BIT;

    av->top = initial_top (av);
}
```

该函数做了四件事情，第一是初始化`malloc_state`中的`bins`数组，初始化的结果是对`bins`数组中的每一个`fd`和对应的`bk`，都初始化为`fd`的地址，即`fd=bk=&fd`；第二是设置fastbin可管理的内存块的最大值，即`global_max_fast`，`DEFAULT_MXFAST`定义为，

```
#define DEFAULT_MXFAST     (64 * SIZE_SZ / 4)
```

本章假设为64，`set_max_fast`定义为

```
#define set_max_fast(s) \
  global_max_fast = (((s) == 0)                           \
                     ? SMALLBIN_WIDTH : ((s + SIZE_SZ) & ~MALLOC_ALIGN_MASK))
```

第三是设置一些标志位；第四是初始化分配去中的top chunk，就是一个`malloc_chunk`指针，`fd`保存在`bins[0]`中（smallbin中不使用`bins[0]`和`bins[1]`）。 
重新回到`_int_malloc`中，假设`victim`不为0，下面就从双向链表中取出`victim`，设置其中的标志位，然后返回用户可分配的内存指针。 
假设smallbin中没有空闲chunk可用，下面就要开始寻找largebin了，`largebin_index`定义为

```
#define largebin_index(sz) \
  (SIZE_SZ == 8 ? largebin_index_64 (sz)                                     \
   : MALLOC_ALIGNMENT == 16 ? largebin_index_32_big (sz)                     \
   : largebin_index_32 (sz))
```

根据前面`SIZE_SZ`的假设，这里`largebin_index`对应的就是`largebin_index_32`，定义为

```
#define largebin_index_32(sz)                                                \
  (((((unsigned long) (sz)) >> 6) <= 38) ?  56 + (((unsigned long) (sz)) >> 6) :\
   ((((unsigned long) (sz)) >> 9) <= 20) ?  91 + (((unsigned long) (sz)) >> 9) :\
   ((((unsigned long) (sz)) >> 12) <= 10) ? 110 + (((unsigned long) (sz)) >> 12) :\
   ((((unsigned long) (sz)) >> 15) <= 4) ? 119 + (((unsigned long) (sz)) >> 15) :\
   ((((unsigned long) (sz)) >> 18) <= 2) ? 124 + (((unsigned long) (sz)) >> 18) :\
   126)
```

这里就不多解释了，如果需要知道sz和索引的对应关系，可以自己计算一下。 
再接下来`have_fastchunks`根据标志位判断fastbin中是否有空闲chunk，如果有，就调用`malloc_consolidate`将这些chunk和并，然后加入到unsortedbin中。

# _int_malloc — 合并fastbin

下面重新看一下`malloc_consolidate`函数。

```
static void malloc_consolidate(mstate av) {
    mfastbinptr* fb;
    mfastbinptr* maxfb;
    mchunkptr p;
    mchunkptr nextp;
    mchunkptr unsorted_bin;
    mchunkptr first_unsorted;

    mchunkptr nextchunk;
    INTERNAL_SIZE_T size;
    INTERNAL_SIZE_T nextsize;
    INTERNAL_SIZE_T prevsize;
    int nextinuse;
    mchunkptr bck;
    mchunkptr fwd;

    if (get_max_fast () != 0) {
        clear_fastchunks(av);
        unsorted_bin = unsorted_chunks(av);

        maxfb = &fastbin(av, NFASTBINS - 1);
        fb = &fastbin(av, 0);
        do {
            p = atomic_exchange_acq(fb, 0);
            if (p != 0) {
                do {
                    check_inuse_chunk(av, p);
                    nextp = p->fd;

                    size = p->size & ~(PREV_INUSE | NON_MAIN_ARENA);
                    nextchunk = chunk_at_offset(p, size);
                    nextsize = chunksize(nextchunk);

                    if (!prev_inuse(p)) {
                        prevsize = p->prev_size;
                        size += prevsize;
                        p = chunk_at_offset(p, -((long ) prevsize));
                        unlink(av, p, bck, fwd);
                    }

                    if (nextchunk != av->top) {
                        nextinuse = inuse_bit_at_offset(nextchunk, nextsize);

                        if (!nextinuse) {
                            size += nextsize;
                            unlink(av, nextchunk, bck, fwd);
                        } else
                            clear_inuse_bit_at_offset(nextchunk, 0);

                        first_unsorted = unsorted_bin->fd;
                        unsorted_bin->fd = p;
                        first_unsorted->bk = p;

                        if (!in_smallbin_range(size)) {
                            p->fd_nextsize = NULL;
                            p->bk_nextsize = NULL;
                        }

                        set_head(p, size | PREV_INUSE);
                        p->bk = unsorted_bin;
                        p->fd = first_unsorted;
                        set_foot(p, size);
                    }

                    else {
                        size += nextsize;
                        set_head(p, size | PREV_INUSE);
                        av->top = p;
                    }

                } while ((p = nextp) != 0);

            }
        } while (fb++ != maxfb);
    } else {

        ...

    }
}
```

因为ptmalloc前面已经初始化过了，这里直接进入if内部，首先通过`clear_fastchunks`设置标志位表示fastbin中存在空闲chunk，

```
#define clear_fastchunks(M)    catomic_or (&(M)->flags, FASTCHUNKS_BIT)
```

然后通过`unsorted_chunks`获得bins数组中unsortedbin对应的`malloc_chunk`指针（其`fd`和`bk`指针对应`bins[0]`和`bins[1]`）。

```
#define unsorted_chunks(M)          (bin_at (M, 1))
```

再往下，将fastbin中的最大和最小的chunk对应的`malloc_chunk`指针赋值给`maxfb`和`fb`，然后通过do，while循环遍历fastbin中的每个chunk链表，`atomic_exchange_acq`又是一个CAS操作，该函数取出`fb`指针，并将原来的chunk链表头指针的值设为0，表示chunk链表空闲了。然后开始进入内层的循环，这里遍历的是每个chunk链表中的每个`malloc_chunk`指针。 
接下来首先去除chunk中的`PREV_INUSE`和`NON_MAIN_ARENA`标志，为了获得chunk的大小（size中的最低三位被用来作为标志位，并且fastbin中chunk的标志位`IS_MMAPPED`默认为0）。然后通过`chunk_at_offset`和`chunksize`获得下一个chunk以及其大小，

```
#define chunk_at_offset(p, s)  ((mchunkptr) (((char *) (p)) + (s)))
#define SIZE_BITS (PREV_INUSE | IS_MMAPPED | NON_MAIN_ARENA)
#define chunksize(p)         ((p)->size & ~(SIZE_BITS))
```

再往下，如果chunk的前一个chunk没在使用中，就合并该chunk与前一个chunk，主要是重新计算`malloc_chunk`的指针，并调用`unlink`将前一个chunk从bins数组中删除，

```
#define unlink(AV, P, BK, FD) {                                            \
    FD = P->fd;                                   \
    BK = P->bk;                                   \
    if (__builtin_expect (FD->bk != P || BK->fd != P, 0))             \
      malloc_printerr (check_action, "corrupted double-linked list", P, AV);  \
    else {                                    \
        FD->bk = BK;                                  \
        BK->fd = FD;                                  \
        if (!in_smallbin_range (P->size)                      \
            && __builtin_expect (P->fd_nextsize != NULL, 0)) {            \
        if (__builtin_expect (P->fd_nextsize->bk_nextsize != P, 0)        \
        || __builtin_expect (P->bk_nextsize->fd_nextsize != P, 0))    \
          malloc_printerr (check_action,                      \
                   "corrupted double-linked list (not small)",    \
                   P, AV);                        \
            if (FD->fd_nextsize == NULL) {                    \
                if (P->fd_nextsize == P)                      \
                  FD->fd_nextsize = FD->bk_nextsize = FD;             \
                else {                                \
                    FD->fd_nextsize = P->fd_nextsize;                 \
                    FD->bk_nextsize = P->bk_nextsize;                 \
                    P->fd_nextsize->bk_nextsize = FD;                 \
                    P->bk_nextsize->fd_nextsize = FD;                 \
                  }                               \
              } else {                                \
                P->fd_nextsize->bk_nextsize = P->bk_nextsize;             \
                P->bk_nextsize->fd_nextsize = P->fd_nextsize;             \
              }                                   \
          }                                   \
      }                                       \
}
```

简单来说，该宏定义就是将前一个chunk从两个双线链表中删除，`fd`和`bk`指针构成的双向链表存在于smallbin和largebin中，`fd_nextsize`和`bk_nextsize`指针构成的双向链表只存在于largebin中。 
再往下，如果相邻的下一个chunk不是top chunk，并且下一个chunk不在使用中，就继续合并，否则，就清除下一个chunk的`PREV_INUSE`，表示该chunk已经空闲了。 
然后将刚刚合并完的chunk添加进`unsorted_bin`中，`unsorted_bin`也是一个双向链表。 
如果合并完的chunk属于smallbin的大小，则需要清除`fd_nextsize`和`bk_nextsize`，因为smallbin中的chunk不会使用这两个指针。并且通过`setHead`保证不会有相邻的两个chunk都空闲，并且通过`setFoot`设置下一个chunk的`prev_size`。 
如果相邻的下一个chunk是top chunk，则将合并完的chunk继续合并到top chunk中。 
至此，`malloc_consolidate`就分析完了，总结一下，`malloc_consolidate`就是遍历fastbin中每个chunk链表的每个`malloc_chunk`指针，合并前一个不在使用中的chunk，如果后一个chunk是top chunk，则直接合并到top chunk中，如果后一个chunk不是top chunk，则合并后一个chunk并添加进`unsorted_bin`中。

下一章继续往下分析_int_malloc函数。