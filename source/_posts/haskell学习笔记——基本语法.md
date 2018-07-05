---
title: haskell学习笔记——基本语法
date: 2017-10-15 00:11:49
categories: code
tags: haskell
---

挖了Haskell这个坑,希望在纯函数式环境锻炼自己的函数式编程思维
首先来说一下环境,首先安装Haskell Platform也就是GHC
推荐Mac下Haskell这个IDE,也可以在GHCI这样的REPL下练习
话不多说,现在来学习一下Haskell的基本语法

参考： [https://wiki.haskell.org/Haskell](https://wiki.haskell.org/Haskell)

# 文件执行

方法1: 编译后执行

> ghc --make hello
>
> ./hello

方法2：解释执行

> ghci hello.hs 

# 基本运算符

Haskell中的基本运算符与其他语言类似

- 加 减 乘 除 + - * / 
  `1+1`
- 布尔运算符 与 或 非 && || not
  `not True`
- 关系运算符 等于 不等 == /=
  `not True == False`

# 函数调用

Haskell中的函数调用使用空格的方式
`succ 8`
`succ`单参数函数,返回一个数的后继
`min 8 9`
`min`返回较大的元素

> 可以用``(数字1前的按键)将函数括起来作为中缀函数使用,如下

9 \`div\` 3

# 函数定义

> ### 函数式编程语言特点
>
> 在Haskell这门纯函数式语言中,Haskell中只有定义没有赋值,已经定义的值是不能修改的,类似于数学中的变量,它的意义是这个变量代表了一个值,而非这个变量处在这个值的状态,所以说**纯**函数式编程中函数只能去引用数的计算结果,不会产生副作用,无论何时以同样的参数call函数都会获得一样的结果,所以函数很适合作为first class, 获得与其他语言中变量同等的地位

### let关键词用于声明常量

```
let doubleMe x = x + x
doubleMe 2

let doubleUs x y =
      {- 在函数中定义函数 -}
      let doublex = 2 * x
          doubley = 2 * y
      in doublex + doubley
```

- 可以在函数中调用其他函数

```
let doubleUs x y = doubleMe x + doubleMe y
doubleUs 2 3
```

## 基本语句

### if then else语句

Haskell中if语句实际上是一个表达式
每个if都要有thenelse两部分,else不是可选的,这也就保证了表达式一定有其返回值

```
let doubelSmallNumber x = if x > 100
                         then x
                         else doubleMe x
```

> Haskell中常在函数名后加单引号'来区分一个相似的函数

### case语句

case语句可以用来进行多值匹配

```
let isOneOrTwo x = case x of 1 -> "1:One"
                             2 -> "2:No Two"
                             otherwise -> "otherwise"
```

### where语句

where语句其实是对变量的定义

```
let doubleUs x y = doublex + doubley
                    where doublex = 2 * x
                          doubley = 2 * y
```

### 模式匹配

```
let lucky 7 = "You are lucky"
let lucky x = "Sorry, you are not lucky"
lucky 7
lucky 8
--另例
foo 0 x = x + 1
foo 1 x = x - 1
foo 2 x = 0
```

上例表明：如果lucky 7，就返回"You are lucky"，否则"Sorry, you are not lucky"

### guard

有时，模式匹配单独无法有效描述一个函数，引入一个称为guard的模式，如果这个模式匹配，每个guard的测试表达式将按顺序检查，如果测试表达式匹配，guard的值将被使用。

Guard开始使用 | ，后面是一个测试表达式，其返回结果或真或假，后面跟着 =，然后是返回的值，otherwise能够捕获其他所有情况。

```
let mydiv x y
      | y == 0 = "Can not divide"
      | x / y > 10 = "first number is larger than the second number"
      | x / y < 1  = "first number is less than the second number"
      | otherwise = "almost equal"
```

### 递归

```
--配合guard
let mysum x y
      | x > y = mysum y x
      | x == y = x
      | otherwise = x + mysum (x+1) y
```

> 模式匹配与guard的区别:区别就在于一个对比的是对象，一个对比的是布尔值。

### 函数定义

下面是我们定义一个函数addone，输入参数是整数，输出也是整数：

```
addOne :: Integer -> Integer
addOne n = n + 1
```

第一行是我们定义一个函数名称为addOne，这个函数有一个Integer参数，返回一个Integer。第二行表示对于我们函数的任何输入，我们将把这个输入表示为n，那么我们将返回n+1。

注意，这里 = 是数学中的意义，在我们程序中任何地方有addOne n，我们能够使用n+1来替代它，得到的都是精确同样的结果，这其实是引用透明的案例，因为我们的函数对于任何给定输入总是返回同样的值。

addOne 10
返回11

调用这个函数的方式是函数名称后跟着参数，之间都是有空格分开，没有任何逗号和括号，

### 函数与模式匹配

让我们定义另外一个函数，它是对于输入一个姓氏能够输出其姓名:

```
lastName :: String -> String
lastName "anthony" = "gillis"
lastName "michelle" = "jocasta"
lastName "gregory" = "tragos"
```

Haskell函数定义依赖于模式匹配，如果你使用参数"anthony"调用lastName函数，，那么函数就会返回字符串"gillis"，如果你使用"michelle"，那么就会返回"jocasta"

但是如果我们输入一个在这三个中不存在姓呢？

lastName "bob"

就会得到一个exception: Non-exhaustive patterns in function lastName。这是因为我们的函数不是total，它并没有对于每个可能的输入有一个定义好的输出，通常函数应该是无论任何可能都是确定的，那么我们重新定义函数如下：

lastName :: String -> String
lastName "anthony" = "gillis"
lastName "michelle" = "jocasta"
lastName "gregory" = "tragos"
lastName n = "<unknown>"

现在我们的函数是total了，最后一个会捕获所有情况，如果上面三个不匹配，那么最后一个总是将参数绑定到n，<font color=#f00>我们能够使用_ 来代表n 表示我们其实不关心其值。</font>

### 多个参数函数

让我们定义一个函数areAscending，它有三个整数参数，如果它们是严格递增那么就返回真：

```
areAscending :: Integer -> Integer -> Integer -> Bool
areAscending a b c = a < b && b < c
```

我们的类型语法看上去是不是有点奇怪？参数之间有箭头，且返回一个值类型？这种多参数函数称为curried，柯里化是将多个参数的一个函数作为输入，转入一系列只有一个参数的函数，返回另外一个函数，比如用伪Swift代码如下：

myFunc(a: A, b: B, c: C) -> Z

函数func1(a: A)当被调用时，返回一个函数func2(b: B)，它又返回一个函数func3(c: C)，它被调用最后返回Z类型结果。

请注意，在我们的模式匹配中，我们分配第一个参数到a，第二个是b，第三个是c，这样我们能够在=后面使用它们来执行我们的计算：

```
areAscending 1 2 3
-- = True

areAscending 3 4 2
-- = False
```

如果我们希望使用一个表达式调用这个函数，而不是一个个参数遍历，那么我们需要使用括号包围：

```
areAscending 1 (1 + 1) 3
-- = True
```

而没有括号的areAscending 1 1 + 1 3则被解释为(areAscending 1 1) + (1 3)，这是没有意义。

### 零参数函数

如果参数没有怎么办？零参数函数也是一个函数，总是返回一个值，这又是引用透明的原理了，因为只有一个办法调用无参数函数，这个函数也总是返回一个值：

```
someValue :: String

someValue = "hello world"
```

零参数函数类似于常量，只要看到someValue，我们都可以使用"hello world"来替代，这正是我们从一个常量中应该预期到结果。

### 绑定Binding与变量不可变

Haskell使用=实现绑定，前面我们说=是引用透明的案例，是一种数学意义，实际是将两者绑定了。

Binding名称不能大写，绑定可以定义一个或多个参数的函数，函数和参数使用空格，这是Haskell区别其他语言的简洁之处

<font color=#f00>括号可以包装复合表达式，当然也可以使用\$符号</font>



与命令式语言变量不同,Haskell绑定变量 不可变的

特点有两个：

1. order-independent ——绑定在源代码的顺序并不重要
2. Lazy懒赋值 ——定义变量只在需要的时候进行赋值

此外，变量名的scope是只在自己定义的范围内递归的

### 表达式和绑定都有一个类型

- Bool - 有两个元素： True 或 False
- Char - unicode符合集合
- Int - 固定大小整数
- Integer - 无限大小整数
- Double - IEEE 浮点数字
- *type1* -> *type2* - 一个输入类型*type1* 到输出类型 *type2*的函数
- (*type1*, *type2*, ..., *typeN*) - 类型数组tuple
- () - 零数组tuple, 称为*unit* (类似C的void); 这个类型只有一个值：空。

### Monoid

首先，需要了解[什么是Monoid](http://www.jdon.com/idea/monoid.html)。在形式语言与自动机中有介绍！在Haskell中，表达三个函数的Monoid可以如下表达：

```
add :: Integer -> (Integer -> Integer)
add arg1 arg2 = arg1 + arg2
```

这里使用括号，其实这个Monoid符合结合律，括号是没有必要的，等同于如下：

```
 add :: Integer -> Integer -> Integer
```

### Lambda抽象

- 你可以通过lambda实现匿名函数

- 符号是： \\*variable(s)* -> *body* ( \被称为"lambda")

- 案例:

  ```
  countLowercaseAndDigits :: String -> Int
  countLowercaseAndDigits = length . filter (\c -> isLower c || isDigit c)
  ```

- lambda使用模式匹配能够分解值：

  ```
          ... (\(Right x) -> x) ...
  ```

  - But note that guards or multiple bindings are not allowed
  - Patterns must have the right constructor or will get run-time error