---
title: malloc源码分析——4
date: 2018-05-21 14:41:58
categories: pwn
tags: [heap]
---

# malloc源码分析—_int_malloc

上一章分析了`_int_malloc`中的fastbin、smallbin和部分largebin的处理，本章继续往下看余下的代码。最后会对整个`_int_malloc`做一个总结。

```
static void * _int_malloc(mstate av, size_t bytes) {

...

    for (;;) {
        int iters = 0;
        while ((victim = unsorted_chunks (av)->bk) != unsorted_chunks (av)){
            bck = victim->bk;
            if (__builtin_expect(victim->size <= 2 * SIZE_SZ, 0)
                    || __builtin_expect(victim->size > av->system_mem, 0))
                malloc_printerr(check_action, "malloc(): memory corruption",
                        chunk2mem(victim), av);
            size = chunksize(victim);

            if (in_smallbin_range (nb) &&
            bck == unsorted_chunks (av) &&
            victim == av->last_remainder &&
            (unsigned long) (size) > (unsigned long) (nb + MINSIZE)) {
                remainder_size = size - nb;
                remainder = chunk_at_offset(victim, nb);
                unsorted_chunks (av)->bk = unsorted_chunks (av)->fd = remainder;
                av->last_remainder = remainder;
                remainder->bk = remainder->fd = unsorted_chunks (av);
                if (!in_smallbin_range(remainder_size)) {
                    remainder->fd_nextsize = NULL;
                    remainder->bk_nextsize = NULL;
                }

                set_head(victim,
                        nb | PREV_INUSE | (av != &main_arena ? NON_MAIN_ARENA : 0));
                set_head(remainder, remainder_size | PREV_INUSE);
                set_foot(remainder, remainder_size);

                check_malloced_chunk (av, victim, nb);
                void *p = chunk2mem(victim);
                alloc_perturb(p, bytes);
                return p;
            }

            unsorted_chunks (av)->bk = bck;
            bck->fd = unsorted_chunks (av);

            if (size == nb) {
                set_inuse_bit_at_offset(victim, size);
                if (av != &main_arena)
                    victim->size |= NON_MAIN_ARENA;
                check_malloced_chunk (av, victim, nb);
                void *p = chunk2mem(victim);
                alloc_perturb(p, bytes);
                return p;
            }

            ...

        }

    ...

    }
}
```

这部分代码的整体意思就是遍历unsortedbin，从中查找是否有符合用户要求大小的chunk并返回。 
第一个while循环从尾到头依次取出unsortedbin中的所有chunk，将该chunk对应的前一个chunk保存在`bck`中，并将大小保存在`size`中。 
如果用户需要分配的内存大小对应的chunk属于smallbin，unsortedbin中只有这一个chunk，并且该chunk属于last remainder chunk且其大小大于用户需要分配内存大小对应的chunk大小加上最小的chunk大小（保证可以拆开成两个chunk），就将该chunk拆开成两个chunk，分别为`victim`和`remainder`，进行相应的设置后，将用户需要的`victim`返回。 
如果不能拆开，就从unsortedbin中取出该chunk（`victim`）。 
再下来，如果刚刚从unsortedbin中取出的`victim`正好是用户需要的大小`nb`，就设置相应的标志位，直接返回该`victim`。

继续往下看`_int_malloc`函数，为了使整个代码结构清晰，这里保留了外层的for循环和while循环。

```
static void * _int_malloc(mstate av, size_t bytes) {

    ...

    for (;;) {
        int iters = 0;
        while ((victim = unsorted_chunks (av)->bk) != unsorted_chunks (av)){

            ...

            if (in_smallbin_range(size)) {
                victim_index = smallbin_index(size);
                bck = bin_at (av, victim_index);
                fwd = bck->fd;
            } else {
                victim_index = largebin_index(size);
                bck = bin_at (av, victim_index);
                fwd = bck->fd;

                if (fwd != bck) {
                    size |= PREV_INUSE;
                    assert((bck->bk->size & NON_MAIN_ARENA) == 0);
                    if ((unsigned long) (size) < (unsigned long) (bck->bk->size)) {
                        fwd = bck;
                        bck = bck->bk;

                        victim->fd_nextsize = fwd->fd;
                        victim->bk_nextsize = fwd->fd->bk_nextsize;
                        fwd->fd->bk_nextsize = victim->bk_nextsize->fd_nextsize =
                                victim;
                    } else {
                        assert((fwd->size & NON_MAIN_ARENA) == 0);
                        while ((unsigned long) size < fwd->size) {
                            fwd = fwd->fd_nextsize;
                            assert((fwd->size & NON_MAIN_ARENA) == 0);
                        }

                        if ((unsigned long) size == (unsigned long) fwd->size)
                            fwd = fwd->fd;
                        else {
                            victim->fd_nextsize = fwd;
                            victim->bk_nextsize = fwd->bk_nextsize;
                            fwd->bk_nextsize = victim;
                            victim->bk_nextsize->fd_nextsize = victim;
                        }
                        bck = fwd->bk;
                    }
                } else
                    victim->fd_nextsize = victim->bk_nextsize = victim;
            }

            mark_bin(av, victim_index);
            victim->bk = bck;
            victim->fd = fwd;
            fwd->bk = victim;
            bck->fd = victim;

    #define MAX_ITERS       10000
            if (++iters >= MAX_ITERS)
                break;
        }

    ...

    }
}
```

这部分代码的整体意思是如果从unsortedbin中取出的chunk不符合用户要求的大小，就将该chunk合并到smallbin或者largebin中。 
首先如果取出的chunk（victim）属于smallbin，就通过`smallbin_index`计算需要插入的位置`victim_index`，然后获取smallbin中对应位置的链表头指针保存在`bck`中，最后直接插入到smallbin中，由于smallbin中的chunk不使用`fd_nextsize`和`bk_nextsize`指针，插入操作只需要更新`bk`和`fd`指针，具体的插入操作在后面。这里需解释一下，`fd_nextsize`指针指向的是chunk双向链表中下一个大小不同的chunk，`bk_nextsize`指向的是chunk双向链表中前一个大小不同的chunk。 
如果取出的chunk（victim）属于largebin，通过`largebin_index`计算需要插入的位置`victim_index`，然后获取largebin链表头指针保存在`bck`中。 
如果`fwd`等于`bck`，即`bck->fd=bck`，则表示largebin中对应位置上的chunk双向链表为空，直接进入后面的else部分中，代码`victim->fd_nextsize = victim->bk_nextsize = victim`表示插入到largebin中的victim是唯一的chunk，因此其`fd_nextsize`和`bk_nextsize`指针都指向自己。 
如果`fwd`不等于`bck`，对应的chunk双向链表存在空闲chunk，这时就要在该链表中找到合适的位置插入了。因为largebin中的chunk链表是按照chunk大小从大到小排序的，如果`victim`的`size`小于`bck->bk->size`即最后一个chunk的大小，则表示即将插入`victim`的大小在largebin的chunk双向链表中是最小的，因此要把`victim`插入到该链表的最后。在这种情况下，经过操作后的结果如下所示（因为我手边的画图软件有限，这里就用符号“|”隔出数组，然后从代码中摘除核心的`fd_nextsize`和`bk_nextsize`指针的修改操作，对照这两个指针的意思，很容易看懂），

```
| fwd（头指针） | fwd->fd | ... | bck | victim（插入到末尾） |
fwd->fd->bk_nextsize = victim
victim->bk_nextsize->fd_nextsize = victim
victim->fd_nextsize = fwd->fd
victim->bk_nextsize = fwd->fd->bk_nextsize
```

如果要插入的`victim`的`size`不是最小的，就要通过一个while循环遍历找到合适的位置，这里是从双向链表头`bck->fd`开始遍历，利用`fd_nextsize`加快遍历的速度，找到第一个`size>=fwd->size`的chunk。如果`size=fwd->size`，就只是改变`victim`以及前后相应chunk的`bk`、`fd`指针就行。这里要特别注意，先做一个假设，假设chunk双向链表中A、B、C是三个不同大小的chunk集合，A集合有A0=A1=…，B集合有B0=B1=…，C集合有C0=C1=…，然后构造chunk链表， 
| A0 | A1 | A2 | B0 | B1 | B2 | C0 | C1 | C2 | 
特别注意，在ptmalloc中，只有A0、B0、C0可以配置`fd_nextsize`和`bk_nextsize`指针，其他位置是不用配置这两个指针的。因此相同大小的chunk只有最低地址的chunk会设置`fd_nextsize`和`bk_nextsize`指针。根据这个假设，很容易知道当两个size相等时，为什么要执行`fwd = fwd->fd`，因为要保证插入victim的位置是相同大小的chunk的右边，即高地址的地方。插入后的链表如下，

```
...| bck | victim | fwd |...
```

链表中所有chunk的`fd_nextsize` 和`bk_nextsize`指针不变。 
再往下，如果`size`不相等，则直接插入在`fwd`的左边，这样也能保证所有的`fd_nextsize`和`bk_nextsize`指针设置在相同chunk大小的最地地址处（最左边）。插入后的链表如下，

```
...| bck | victim | fwd |...
victim->fd_nextsize = fwd
victim->bk_nextsize = fwd->bk_nextsize;
fwd->bk_nextsize = victim
fwd->bk_nextsize->fd_nextsize = victim
```

再往下，`mark_bin`用来标识`malloc_state`中的`binmap`，标识相应位置的chunk空闲。然后就更改`fd`、`bk`指针，插入到双向链表中，这个插入操作同时适用于smallbin和largebin，因此放在这里。最后如果在unsortedbin中处理了超过10000个chunk，就直接退出循环，这里保证不会因为unsortedbin中chunk太多，处理的时间太长了。 
在这部分代码中，有个`size |= PREV_INUSE`是暂时让我比较费解的地方，经过分析后，暂时认为`size |= PREV_INUSE`是没必要的，虽然不会产生错误，也不会影响largebin中的排序，并且注释说这行代码能加速排序，但没看出能加速的地方，经过分析这里反而会多出一个无效的指针赋值，希望往后看代码时能解决这里的问题，或者希望有人能解答这行代码的具体作用。

回到`_int_malloc`函数中，继续往下看，为了使整个代码结构清晰，这里继续保留了外层的for循环。

```
static void * _int_malloc(mstate av, size_t bytes) {

    ...

    for (;;) {

        ...

        if (!in_smallbin_range(nb)) {
            bin = bin_at (av, idx);

            if ((victim = first(bin)) != bin
                    && (unsigned long) (victim->size) >= (unsigned long) (nb)) {
                victim = victim->bk_nextsize;
                while (((unsigned long) (size = chunksize(victim))
                        < (unsigned long) (nb)))
                    victim = victim->bk_nextsize;

                if (victim != last(bin) && victim->size == victim->fd->size)
                    victim = victim->fd;

                remainder_size = size - nb;
                unlink(av, victim, bck, fwd);

                if (remainder_size < MINSIZE) {
                    set_inuse_bit_at_offset(victim, size);
                    if (av != &main_arena)
                        victim->size |= NON_MAIN_ARENA;
                }
                else {
                    remainder = chunk_at_offset(victim, nb);
                    bck = unsorted_chunks (av);
                    fwd = bck->fd;
                    if (__glibc_unlikely(fwd->bk != bck)) {
                        errstr = "malloc(): corrupted unsorted chunks";
                        goto errout;
                    }
                    remainder->bk = bck;
                    remainder->fd = fwd;
                    bck->fd = remainder;
                    fwd->bk = remainder;
                    if (!in_smallbin_range(remainder_size)) {
                        remainder->fd_nextsize = NULL;
                        remainder->bk_nextsize = NULL;
                    }
                    set_head(victim,
                            nb | PREV_INUSE | (av != &main_arena ? NON_MAIN_ARENA : 0));
                    set_head(remainder, remainder_size | PREV_INUSE);
                    set_foot(remainder, remainder_size);
                }
                check_malloced_chunk (av, victim, nb);
                void *p = chunk2mem(victim);
                alloc_perturb(p, bytes);
                return p;
            }
        }

        ...

    }
}
```

这部分代码的整体意思就是要尝试从largebin中取出对应的chunk了。 
这里的`idx`是在前面（上一章分析的`_int_malloc`函数前面一部分中）根据宏`largebin_index`计算的。接下来就要根据`idx`获得largebin中的双向链表头指针`bin`，然后从`bin->bk`开始从尾到头（根据chunk大小从小到大）遍历整个双向链表，找到第一个大于用户需要分配的chunk大小`nb`的chunk指针`victim`。 
找到`victim`后，需要将其拆开成两部分，第一部分是要返回给用户的chunk，第二部分分为两种情况，如果其大小小于`MINSIZE`，则不能构成一个最小chunk，这种情况下就将拆开前的整个`victim`返回给用户；如果大于`MINSIZE`，就将拆开后的第二部分`remainder`插入到unsortedbin中，然后把第一部分`victim`返回给用户。

继续往下看`_int_malloc`函数，

```
static void * _int_malloc(mstate av, size_t bytes) {

    ...

    for (;;) {

        ...

        ++idx;
        bin = bin_at (av, idx);
        block = idx2block(idx);
        map = av->binmap[block];
        bit = idx2bit(idx);

        for (;;) {
            if (bit > map || bit == 0) {
                do {
                    if (++block >= BINMAPSIZE) /* out of bins */
                        goto use_top;
                } while ((map = av->binmap[block]) == 0);

                bin = bin_at (av, (block << BINMAPSHIFT));
                bit = 1;
            }

            while ((bit & map) == 0) {
                bin = next_bin(bin);
                bit <<= 1;
                assert(bit != 0);
            }

            victim = last(bin);
            if (victim == bin) {
                av->binmap[block] = map &= ~bit;
                bin = next_bin(bin);
                bit <<= 1;
            }

            else {
                size = chunksize(victim);
                assert((unsigned long ) (size) >= (unsigned long ) (nb));
                remainder_size = size - nb;
                unlink(av, victim, bck, fwd);
                if (remainder_size < MINSIZE) {
                    set_inuse_bit_at_offset(victim, size);
                    if (av != &main_arena)
                        victim->size |= NON_MAIN_ARENA;
                }
                else {
                    remainder = chunk_at_offset(victim, nb);
                    bck = unsorted_chunks (av);
                    fwd = bck->fd;
                    if (__glibc_unlikely(fwd->bk != bck)) {
                        errstr = "malloc(): corrupted unsorted chunks 2";
                        goto errout;
                    }
                    remainder->bk = bck;
                    remainder->fd = fwd;
                    bck->fd = remainder;
                    fwd->bk = remainder;

                    if (in_smallbin_range(nb))
                        av->last_remainder = remainder;
                    if (!in_smallbin_range(remainder_size)) {
                        remainder->fd_nextsize = NULL;
                        remainder->bk_nextsize = NULL;
                    }
                    set_head(victim,
                            nb | PREV_INUSE | (av != &main_arena ? NON_MAIN_ARENA : 0));
                    set_head(remainder, remainder_size | PREV_INUSE);
                    set_foot(remainder, remainder_size);
                }check_malloced_chunk (av, victim, nb);
                void *p = chunk2mem(victim);
                alloc_perturb(p, bytes);
                return p;
            }
        }

        ...

    }
}
```

这一部分的整体意思是，前面在largebin中寻找特定大小的空闲chunk，如果没找到，这里就要遍历largebin中的其他更大的chunk双向链表，继续寻找。 
开头的`++idx`就表示，这里要从largebin中下一个更大的chunk双向链表开始遍历。ptmalloc中用一个bit表示`malloc_state`的`bins`数组中对应的位置上是否有空闲chunk，bit为1表示有，为0则没有。ptmalloc通过4个block（一个block 4字节）一共128个bit管理`bins`数组。因此，代码中计算的block表示对应的`idx`属于哪一个block，`map`就表是block对应的bit组成的二进制数字。 
接下来进入for循环，如果`bit > map`，表示该`map`对应的整个`block`里都没有大于`bit`位置的空闲的chunk，因此就要找下一个`block`。因为后面的`block`只要不等于0，就肯定有空闲chunk，并且其大小大于`bit`位置对应的chunk，下面就根据`block`，取出`block`对应的第一个双向链表的头指针。这里也可以看出，设置`map`和`block`也是为了加快查找的速度。如果遍历完所有`block`都没有空闲chunk，这时只能从top chunk里分配chunk了，因此跳转到`use_top`。 
如果有空闲chunk，接下来就通过一个while循环依次比较找出到底在哪个双向链表里存在空闲chunk，最后获得空闲chunk所在的双向链表的头指针`bin`和位置`bit`。 
接下来，如果找到的双向链表又为空，则继续前面的遍历，找到空闲chunk所在的双向链表的头指针`bin`和位置`bit`。如果找到的双向链表不为空，就和上面一部分再largebin中找到空闲chunk的操作一样了，这里就不继续分析了。

继续往下看`_int_malloc`，

```
static void * _int_malloc(mstate av, size_t bytes) {

    ...

    for (;;) {

        ...

        use_top:

        victim = av->top;
        size = chunksize(victim);

        if ((unsigned long) (size) >= (unsigned long) (nb + MINSIZE )) {
            remainder_size = size - nb;
            remainder = chunk_at_offset(victim, nb);
            av->top = remainder;
            set_head(victim,
                    nb | PREV_INUSE | (av != &main_arena ? NON_MAIN_ARENA : 0));
            set_head(remainder, remainder_size | PREV_INUSE);

            check_malloced_chunk (av, victim, nb);
            void *p = chunk2mem(victim);
            alloc_perturb(p, bytes);
            return p;
        }
        else if (have_fastchunks(av)) {
            malloc_consolidate(av);
            if (in_smallbin_range(nb))
                idx = smallbin_index(nb);
            else
                idx = largebin_index(nb);
        }
        else {
            void *p = sysmalloc(nb, av);
            if (p != NULL)
                alloc_perturb(p, bytes);
            return p;
        }
    }
}
```

这里就是`_int_malloc`的最后一部分了，这部分代码的整体意思分为三部分，首先从top chunk中尝试分配内存；如果失败，就检查fastbin中是否有空闲内存了（其他线程此时可能将释放的chunk放入fastbin中了），如果不空闲，就合并fastbin中的空闲chunk并放入smallbin或者largebin中，然后会回到`_int_malloc`函数中最前面的for循环，重新开始查找空闲chunk；如果连fastbin中都没有空闲内存了，这时只能通过`sysmalloc`从系统分配内存了，该函数前面几章里已经分析过了一部分了，下一章会再次进入这个函数进行分析。这部分代码很简单，关键函数前面几章都碰到过了，这里就不详细分析了。

## 总结

下面简单总结一遍`_int_malloc`函数的整体思路。 
第一步：如果进程没有关联的分配区，就通过`sysmalloc`从操作系统分配内存。 
第二步：从fastbin查找对应大小的chunk并返回，如果失败进入第三步。 
第三步：从smallbin查找对应大小的chunk并返回，或者将fastbin中的空闲chunk合并放入unsortedbin中，如果失败进入第四步。 
第四步：遍历unsortedbin，从unsortedbin中查找对应大小的chunk并返回，根据大小将unsortedbin中的空闲chunk插入smallbin或者largebin中。进入第五步。 
第五步：从largebin指定位置查找对应大小的chunk并返回，如果失败进入第六步。 
第六步：从largebin中大于指定位置的双向链表中查找对应大小的chunk并返回，如果失败进入第七步。 
第七步：从topchunk中分配对应大小的chunk并返回，topchunk中没有足够的空间，就查找fastbin中是否有空闲chunk，如果有，就合并fastbin中的chunk并加入到unsortedbin中，然后跳回第四步。如果fastbin中没有空闲chunk，就通过`sysmalloc`从操作系统分配内存。