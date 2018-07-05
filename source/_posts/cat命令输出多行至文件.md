---
title: cat命令输出多行至文件
date: 2017-12-04 02:07:50
categories: code
tags: linux
---

#### **一、cat和EOF**

cat命令是linux下的一个文本输出命令，通常是用于观看某个文件的内容的；
EOF是“end of file”，表示文本结束符。
结合这两个标识，即可避免使用多行echo命令的方式，并实现多行输出的结果。

#### **二、使用**

看例子是最快的熟悉方法：

```
# cat << EOF > test.sh
> #!/bin/bash
> #you Shell script writes here.
> EOF
```

