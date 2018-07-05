---
title: malloc源码分析——1
date: 2018-05-21 14:35:24
categories: pwn
tags: [heap]
---

# malloc源码分析—`ptmalloc_init`

本文分析malloc的源码，首先从glibc开始，首先看malloc.c文件中的一段定义，

```
strong_alias (__libc_malloc, __malloc) strong_alias (__libc_malloc, malloc)
```

`strong_alias`是GNU C中的定义，编译器判定这里malloc是`__libc_malloc`的别名，`__libc_malloc`定义在malloc.c中，

```
void * __libc_malloc (size_t bytes){

    mstate ar_ptr;
    void *victim;

    void *(*hook) (size_t, const void *) = atomic_forced_read (__malloc_hook);
    if (__builtin_expect (hook != NULL, 0))
        return (*hook)(bytes, RETURN_ADDRESS (0));

    arena_get (ar_ptr, bytes);

    victim = _int_malloc (ar_ptr, bytes);
    if (!victim && ar_ptr != NULL){
        LIBC_PROBE (memory_malloc_retry, 1, bytes);
        ar_ptr = arena_get_retry (ar_ptr, bytes);
        victim = _int_malloc (ar_ptr, bytes);
    }

    if (ar_ptr != NULL)
        (void) mutex_unlock (&ar_ptr->mutex);

    return victim;
}
libc_hidden_def (__libc_malloc)
```

首先看`atomic_forced_read`，

```
# define atomic_forced_read(x) \
  ({ __typeof (x) __x; __asm ("" : "=r" (__x) : "0" (x)); __x; })
```

`__typeof`是原始函数的返回类型，后面是一段汇编代码，”0”是零，即%0，引用时不可以加 %，只能input引用output，这里就是原子读，将`__malloc_hook`的地址放入任意寄存器(r)再取出。`__malloc_hook`的定义如下

```
void *weak_variable (*__malloc_hook)(size_t __size, const void *) = malloc_hook_ini;
```

weak_variable其实就是，

```
__attribute__ ((weak))
```

和编译器有关，这里不管它。`__builtin_expect`其实就是告诉编译器if判断语句里大多数情况下的值，这样编译器可以做优化，避免过多的跳转。回到`__libc_malloc`接下来就是调用`malloc_hook_ini`进行内存的分配。 
`malloc_hook_ini`定义在hooks.c中，

```
static void * malloc_hook_ini (size_t sz, const void *caller){
    __malloc_hook = NULL;
    ptmalloc_init ();
    return __libc_malloc (sz);
}
```

## ptmalloc_init

ptmalloc_init用来对整个ptmalloc框架进行初始化，定义在arena.c中，

```
static void ptmalloc_init(void) {

    if (__malloc_initialized >= 0)
        return;
    __malloc_initialized = 0;

    tsd_key_create(&arena_key, NULL);
    tsd_setspecific(arena_key, (void *) &main_arena);
    thread_atfork(ptmalloc_lock_all, ptmalloc_unlock_all, ptmalloc_unlock_all2);
    const char *s = NULL;
    if (__glibc_likely(_environ != NULL)) {
        char **runp = _environ;
        char *envline;

        while (__builtin_expect((envline = next_env_entry(&runp)) != NULL, 0)) {
            size_t len = strcspn(envline, "=");

            if (envline[len] != '=')
                continue;

            switch (len) {
            case 6:
                if (memcmp(envline, "CHECK_", 6) == 0)
                    s = &envline[7];
                break;
            case 8:
                if (!__builtin_expect(__libc_enable_secure, 0)) {
                    if (memcmp(envline, "TOP_PAD_", 8) == 0)
                        __libc_mallopt(M_TOP_PAD, atoi(&envline[9]));
                    else if (memcmp(envline, "PERTURB_", 8) == 0)
                        __libc_mallopt(M_PERTURB, atoi(&envline[9]));
                }
                break;
            case 9:
                if (!__builtin_expect(__libc_enable_secure, 0)) {
                    if (memcmp(envline, "MMAP_MAX_", 9) == 0)
                        __libc_mallopt(M_MMAP_MAX, atoi(&envline[10]));
                    else if (memcmp(envline, "ARENA_MAX", 9) == 0)
                        __libc_mallopt(M_ARENA_MAX, atoi(&envline[10]));
                }
                break;
            case 10:
                if (!__builtin_expect(__libc_enable_secure, 0)) {
                    if (memcmp(envline, "ARENA_TEST", 10) == 0)
                        __libc_mallopt(M_ARENA_TEST, atoi(&envline[11]));
                }
                break;
            case 15:
                if (!__builtin_expect(__libc_enable_secure, 0)) {
                    if (memcmp(envline, "TRIM_THRESHOLD_", 15) == 0)
                        __libc_mallopt(M_TRIM_THRESHOLD, atoi(&envline[16]));
                    else if (memcmp(envline, "MMAP_THRESHOLD_", 15) == 0)
                        __libc_mallopt(M_MMAP_THRESHOLD, atoi(&envline[16]));
                }
                break;
            default:
                break;
            }
        }
    }
    if (s && s[0]) {
        __libc_mallopt(M_CHECK_ACTION, (int) (s[0] - '0'));
        if (check_action != 0)
            __malloc_check_init();
    }
    void (*hook)(void) = atomic_forced_read (__malloc_initialize_hook);
    if (hook != NULL)
        (*hook)();
    __malloc_initialized = 1;
}
```

首先检查全局变量`__malloc_initialized`是否大于等于0，如果该值大于0，表示ptmalloc已经初始化，如果改值为0，表示ptmalloc正在初始化，全局变量`__malloc_initialized`用来保证全局只初始化ptmalloc一次。 
`tsd_key_create`创建线程私有实例`arena_key`，该私有实例保存的是分配区（arena）的`malloc_state`实例指针。`arena_key`指向的可能是主分配区的指针，也可能是非主分配区的指针，这里将调用`ptmalloc_init()`的线程的`arena_key`绑定到主分配区上。意味着本线程首选从主分配区分配内存。arena_key在glibc中是一个线程私有变量，

```
#define tsd_key_create(key, destr)  ((void) (key))
#define tsd_setspecific(key, data)  __libc_tsd_set (void *, MALLOC, (data))
#define __libc_tsd_set(TYPE, KEY, VALUE)    (__libc_tsd_##KEY = (VALUE))
```

`tsd_setspecific(arena_key, (void *) &main_arena);`就是`__libc_tsd_MALLOC = &main_arena` 
thread_atfork用来设置进程在fork创建子进程时关于锁设置的各个函数，`ptmalloc_lock_all`和`ptmalloc_unlock_all`用来给父进程加锁解锁，`ptmalloc_unlock_all2`用来给子进程调用以解锁。

```
# define thread_atfork(prepare, parent, child) \
  atfork_mem.prepare_handler = prepare;                       \
  atfork_mem.parent_handler = parent;                         \
  atfork_mem.child_handler = child;                       \
  atfork_mem.dso_handle = &__dso_handle == NULL ? NULL : __dso_handle;        \
  atfork_mem.refcntr = 1;                             \
  __linkin_atfork (&atfork_mem)
```

其中，`atfork_mem`是一个全局的fork时的函数子针结构体fork_handler，

```
#define ATFORK_MEM static struct fork_handler atfork_mem1
```

`__linkin_atfork`用于将刚刚构造的fork_handler添加进全局链表`__fork_handlers`中而不用加锁，其实就是一个CAS锁，关于该锁，可以查阅网上资料，

```
void attribute_hidden __linkin_atfork(struct fork_handler *newp) {
    do
        newp->next = __fork_handlers;
    while (catomic_compare_and_exchange_bool_acq(&__fork_handlers, newp,
            newp->next) != 0);
}
```

`catomic_compare_and_exchange_bool_acq`最后是一个宏定义，将之改写后如下

```
    {
        fork_handler* __atg4_old = newp->next;
        long __gmemp = &__fork_handlers;
        ATOMIC();
        fork_handler* __gret = *__gmemp;
        fork_handler* __gnewval = newp;
        if (__gret == __atg4_old)
           *__gmemp = newp;
        ENDATOMIC();
        __gret;
     }
```

gcc会将这段代码进行编译，生成的代码无法被中断。因此简单说来，`__linkin_atfork`就是将`fork_handler`原子添加进全局链表`__fork_handlers`中。

回到ptmalloc_init函数中，接下来就是进行环境变量的设置，`__glibc_likely`和gcc的编译优化相关，不管他。`_environ`就是`__environ`，里面保存了环境变量，下面就是根据各个环境变量调用`__libc_mallopt`进行设置，后面来看这个函数。

`ptmalloc_init`然后获取`__malloc_initialize_hook`函数指针并执行，由于该函数和malloc没有直接关系，这里不管它。最后将`__malloc_initialized`设置为1，表是初始化完成。

## __libc_mallopt

`__libc_mallopt`定义在malloc.c中，

```
int __libc_mallopt(int param_number, int value) {
    mstate av = &main_arena;
    int res = 1;

    if (__malloc_initialized < 0)
        ptmalloc_init();
    (void) mutex_lock(&av->mutex);
    malloc_consolidate(av);

    LIBC_PROBE (memory_mallopt, 2, param_number, value);

    switch (param_number) {
    case M_MXFAST:
        if (value >= 0 && value <= MAX_FAST_SIZE) {
            LIBC_PROBE (memory_mallopt_mxfast, 2, value, get_max_fast ());
            set_max_fast(value);
        } else
            res = 0;
        break;

    case M_TRIM_THRESHOLD:
        LIBC_PROBE (memory_mallopt_trim_threshold, 3, value,
                mp_.trim_threshold, mp_.no_dyn_threshold);
        mp_.trim_threshold = value;
        mp_.no_dyn_threshold = 1;
        break;

    case M_TOP_PAD:
        LIBC_PROBE (memory_mallopt_top_pad, 3, value,
                mp_.top_pad, mp_.no_dyn_threshold);
        mp_.top_pad = value;
        mp_.no_dyn_threshold = 1;
        break;

    case M_MMAP_THRESHOLD:
        if ((unsigned long) value > HEAP_MAX_SIZE / 2)
            res = 0;
        else {
            LIBC_PROBE (memory_mallopt_mmap_threshold, 3, value,
                    mp_.mmap_threshold, mp_.no_dyn_threshold);
            mp_.mmap_threshold = value;
            mp_.no_dyn_threshold = 1;
        }
        break;

    case M_MMAP_MAX:
        LIBC_PROBE (memory_mallopt_mmap_max, 3, value,
                mp_.n_mmaps_max, mp_.no_dyn_threshold);
        mp_.n_mmaps_max = value;
        mp_.no_dyn_threshold = 1;
        break;

    case M_CHECK_ACTION:
        LIBC_PROBE (memory_mallopt_check_action, 2, value, check_action);
        check_action = value;
        break;

    case M_PERTURB:
        LIBC_PROBE (memory_mallopt_perturb, 2, value, perturb_byte);
        perturb_byte = value;
        break;

    case M_ARENA_TEST:
        if (value > 0) {
            LIBC_PROBE (memory_mallopt_arena_test, 2, value, mp_.arena_test);
            mp_.arena_test = value;
        }
        break;

    case M_ARENA_MAX:
        if (value > 0) {
            LIBC_PROBE (memory_mallopt_arena_max, 2, value, mp_.arena_max);
            mp_.arena_max = value;
        }
        break;
    }
    (void) mutex_unlock(&av->mutex);
    return res;
}
libc_hidden_def( __libc_mallopt)
```

首先通过`__malloc_initialized`判断如果ptmalloc还未初始化，就调用`ptmalloc_init`进行初始化。`malloc_consolidate`用来将fast bins中的chunk合并，并且里面会初始化主分配区，后面的章节会分析到这个函数。然后就根据传入的`param_number`设置`mp_`，`mp_`代表ptmalloc的各个全局参数，其默认定义如下

```
static struct malloc_par mp_ = { 
    .top_pad = DEFAULT_TOP_PAD, 
    .n_mmaps_max = DEFAULT_MMAP_MAX, 
    .mmap_threshold = DEFAULT_MMAP_THRESHOLD, 
    .trim_threshold = DEFAULT_TRIM_THRESHOLD,
#define NARENAS_FROM_NCORES(n) ((n) * (sizeof (long) == 4 ? 2 : 8))
    .arena_test = NARENAS_FROM_NCORES(1) 
};
```

这里不分析里面各个参数的意义，到后面用到时再来分析。`malloc_hook_ini`最后会回调`__libc_malloc`函数，这次`__malloc_hook`为null，因此继续看下面的代码。

## arena_get

接下来通过`arena_get`获得一个分配区，`arena_get`是个宏定义，定义在arena.c中，

```
#define arena_get(ptr, size) do { \
      arena_lookup (ptr);                             \
      arena_lock (ptr, size);                             \
  } while (0)
```

`arena_lookup`从私有变量里获取分配区指针，

```
#define arena_lookup(ptr) do { \
      void *vptr = NULL;                              \
      ptr = (mstate) tsd_getspecific (arena_key, vptr);               \
  } while (0)
```

`tsd_getspecific`也是个宏定义，就是获取前面调用`tsd_setspecific`设置的分配区指针，这里取出的可能是主分配去指针，也可能是非主分配去指针，然后调用`arena_lock`对`malloc_state`中的`mutex`加锁。

```
#define arena_lock(ptr, size) do {                        \
      if (ptr && !arena_is_corrupt (ptr))                     \
        (void) mutex_lock (&ptr->mutex);                      \
      else                                    \
        ptr = arena_get2 (ptr, (size), NULL);                     \
  } while (0)
```

获得分配去的指针后，就会调用`_int_malloc`开始分配内存了，下一章分析这个函数。