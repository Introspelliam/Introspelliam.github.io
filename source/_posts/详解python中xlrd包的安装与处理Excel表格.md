---
title: 详解python中xlrd包的安装与处理Excel表格
date: 2017-07-03 10:18:20
categories: misc
tags: [python, excel]
---

### 1. 安装xlrd

<pre><code>
pip install xlrd
</code></pre>

### 2. python处理excel表格

#### 2.1 打开excel表格

<pre><code>
# -*- coding: utf-8 -*-
import xlrd

# 获取一个Book对象
book = xlrd.open_workbook("1.xls")

# 获取一个sheet对象的列表
sheets = book.sheets()

# 遍历每一个sheet，输出这个sheet的名字（如果是新建的一个xls表，可能是sheet1、sheet2、sheet3）
for sheet in sheets:
	print(sheet.name)

</code></pre>

open_workbook(): 打开工作簿，这就打开了Excel表。

返回的是一个Book对象，通过Book对象我们可以获得一个Sheet的列表，上面的程序就简单地把每个sheet的名字都输了出来。

#### 2.2 读出指定单元格内的数据

<pre><code>
# -*- coding: utf-8 -*-
import xlrd

# 获取一个Book对象
book = xlrd.open_workbook("1.xls")

# 获取一个sheet对象的列表
sheets = book.sheets()

# 遍历每一个sheet，输出这个sheet的名字（如果是新建的一个xls表，可能是sheet1、sheet2、sheet3）
for sheet in sheets: 
	print(sheet.cell_value(0, 0))

</code></pre>

读出单元格内数据函数 cell_value(row, col) ，行列均从0起。

除此之外，可以通过：

<font color=#f00>sheet.cell(row, col) # 获取单元格对象 
sheet.cell_type(row, col) # 获取单元格类型
</font>

#### 2.3 读取日期数据

<pre><code>
# -*- coding: utf-8 -*-
from datetime import datetime 
from xlrd import xldate_as_tuple

# 获取一个Book对象
book = xlrd.open_workbook("1.xls")

# 获取一个sheet对象的列表
sheets = book.sheets()

timeVal = sheets[0].cell_value(0,0)

timestamp = datetime(*xldate_as_tuple(timestamp, 0))

print(timestamp)

</code></pre>

如果Excel存储的某一个单元格数据是日期的话，需要进行一下处理，转换为datetime类型

#### 2.4 遍历每行的数据

<pre><code>
rows = sheet.get_rows()
for row in rows:
	print(row[0].value) # 输出此行第一列的数据
</code></pre>