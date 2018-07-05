---
title: IDA的调试脚本idc
date: 2017-09-18 21:30:24
categories: 安全工具
tags: [ida, 调试]
---

IDA的脚本有两种，一种是idc，另一种是IDAPython。

可以通过File->Script file；File->Script command访问IDA的脚本引擎。

## 1、IDC语言

### 1.1 IDC变量

IDC的3种数据类型：整数（IDA文档使用类型名称long）、字符串和浮点值。当然也包括对象、引用和函数指针

#### 1.1.1 局部变量声明

```
auto addr, reg, val;	//legal, multiple variables declared with no initializers
auto count = 0;			// declaration with initialization
```

IDC认可使用/**/的C风格多行注释，//的行注释

#### 1.1.2 全局变量声明

```
extern outsideGlobal;
static main(){
	extern insideGlobal;
	outsideGlobal = "Global";
	insideGlobal = 1;
}
```

可以在函数内部或外部声明全部变量，但不能子啊声明变量的时候提供初始值。

### 1.2 IDC表达式

除了少数几个特例外，IDC几乎支持C的所有算数和逻辑运算符，包括三元运算(?:)，但是不支持op=（+=、*=、>>=等）形式的符合赋值运算符。

IDC的字符串运算与C的有所不同。在IDC中，支持类python的字符串复制、拼接、分片操作。

```
auto str="String to slice";
auto s1,s2,s3,s4;
s1 = str[7:9];
```

需要注意的是IDC没有数组数据类型。

### 1.3 IDC语句

IDC的语句以很好结束。switch语句是IDC唯一不支持的C风格复合语句。在使用for循环的时候，需要记住的是，IDC不支持复合赋值运算符op=。

并且IDC引入了try/catch块和相关的switch语句，在语法上它们类似C++一场处理。

IDC的块中，可以声明新的变量，只要变量声明位于花括号内的第一个语句即可。但是IDC并不严格限制新引入的变量的作用范围，因此，你可以在声明这些变量的花括号以外引用它们。

### 1.4 IDC函数

IDC仅仅在独立程序(.idc文件)中支持用户定义的函数。iDC命令对话框不支持用户定义的函数。IDC用于声明用户定义的函数的语法与C语言的差异甚大。在IDC中，static关键字用于引入一个用户定义的函数，函数的参数列表仅包含一个以逗号分隔的参数名列表。

```
static my_func(x, y, z){
  auto a,b,c;
  ......  
}
```

并且参数可以采用传值或者传参的方式。

现在已经可以将函数引用作为一个参数传递给另一个函数，并将函数引用作为函数的返回结果。下面的代码清单说明了使用函数参数和函数作为返回值的情况。

```
static getFunc(){
  return Message; //return the built-in Message function as a result
}
static useFunc(func, arg){
  func(arg);  // func here is expected to be a function reference
}
static main(){
  auto f = getFunc();  
  f("Hello world!\n");  // invoke the returned function f
  useFunc(f, "XXS");	// no need for & operator, functions always call-by-reference
}
```

### 1.5 IDC对象

IDC定义了一个成为object的根类，最终所有类都是由它衍生而来，并且在创建新类时支持单一继承。IDC并不使用访问说明符，如public或private，所有类成员均为有效公共类。类声明仅包含类成员函数的定义。要在类中创建数据成员，只需要创建一个给数据成员赋值的赋值语句即可。

```
class ExampleClass{
  ExampleClass(x,y){ // constructor
    this.a = x;	// all ExampleClass objects hava data member a
    this.b = y;	// all ExampleClass objects hava data member b
  }
  ~ExampleClass(){  // destructor
  }
  foo(x){
    this.a = this.a + x;
  }
}

staic main(){
  /* ExampleClass ex;*/ // this is not a valid variable declaration
  auto ex = ExampleClass(1,2);	// this is right
  ex.foo(10);
  ex.z = "string";	// object ex now has a member z, BUT class does not
}
```

### 1.6 IDC程序

需要有主函数，并且主程序文件还必须包含idc.idc文件以获得它包含的有用宏定义。

```
#include <idc.idc>	// useful include directive
static main(){
  // do something
}
```

IDC认可的预处理指令

- \#include <文件>
- \#define<宏名称>[可选值]      创建一个宏，可以选择给它分配指定的值。IDC预定义了许多宏来测试脚本执行环境，如\_NT\_、\_LINUX\_、\_MAC\_、\_GUI\_、\_TXT\_
- \#ifdef<名称>  测试指定的宏是否存在，如果存在，可以选择处理其后的任何语句
- \#else  与上面的\#ifdef配合使用
- \#endif
- \#undef<名称>  删除指定宏

### 1.7 IDC错误处理

运行IDC脚本时，可能遇到两种错误：解析错误、运行时错误。

解析错误指的是令程序无法运行的错误，包括语法错误、引用未定义变量、函数参数数量错误等。

运行时错误会使一段脚本立即终止运行。当然，当一个脚本运行时间过长，也会发生运行时错误。

调试IDC脚本很麻烦，除了大量使用输出语句外，没有其他办法调试IDC脚本。

### 1.8 IDC永久数据存储

前面提到IDC没有传统意义上的数据，即声明一个大型存储块，然后使用下标访问块中的数据项的数组。但是IDC确实有全局永久数组，这可以看成已命名的永久对象，而且这些对象是稀疏数组。数组中的同时保存一个整数值和一个字符串值，IDC的全局数组无法存储浮点值。

- long CreateArray(string name)   返回数组句柄
- long GetArrayId(string name)  返回索引句柄
- long SetArrayLong(long id, long idx, long value)  将整数value存储到数组id中idx位置
- long SetArrayString(long id, long idx, string str)
- string or long GetArrayElement(long tag, long id, long idx)  提取的是整数还是字符串，有tag参数的值决定，必须是常量AR_LONG（整数）或AR_STR（字符串）
- long DelArrayElement(long tag, long id, long idx)
- void DeleteArray(long id) 删除句柄id对应的数组
- long RenameArray(long id, string newname)

## 2、IDC的常用函数

### 2.1 读取和修改数据的函数

- long Byte(long addr)      从虚拟地址addr中读取一个字节值
- long Word(long addr)      从虚拟地址addr中读取一个字（2字节）值
- long Dword(long addr)      从虚拟地址addr中读取一个双字（4字节）值
- void PatchByte(long addr, long val)   设置虚拟地址addr处的一个字节值
- void PatchWord(long addr, long val)   设置虚拟地址addr处的一个字值
- void PatchDword(long addr, long val)   设置虚拟地址addr处的一个双字值
- bool isLoaded(long addr)   如果addr包含有效数据，则返回1，否则0

需要注意的是，我们在做这种操作的时候应该考虑字节顺序。

### 2.2 用户交互函数

- void Message(string format, ...)   格式化打印。接受printf风格的格式化字符串
- void print(...)   在输出窗口打印每个参数的字符串表示形式
- void Wording(string format, ...)   对话框中显示一条格式化信息
- string AskStr(string default, string prompt)  显示一个输入框，要求用户输入一个额字符串值。如果操作成功，则返回用户的字符串；如果对话框被取消，则返回0
- string AskFile(long doSave, string mask, string prompt)  显示一个文件选择对话框，以简化选择文件的任务。新文件保存数据(doSave=1)，或选择现有的文件读取数据(doSave=0)。可以根据mask（如\*.\*或\*.idc）过滤显示的文件列表。如果操作成功，则会返回选定文件的名称；如果对话框被取消，返回0
- string AskYN(long default, string prompt)  用是或否的问题提示用户。突出一个默认的答案（1为是，0为否，-1为取消）。返回值是一个选定答案的整数。
- long ScreenEA()   返回当前光标所在位置的虚拟地址
- bool Jump(long addr)  跳转到反汇编窗口的指定地址

### 2.3 字符串操纵函数

- string form(string format, ...)   //preIDA5.6  类似c语言的sprintf函数，返回一个新年字符串，该字符串根据所提供的格式化字符串和值进行格式化
- string sprintf(string format, ...)  //IDA5.6+  sprintf用于替代form
- long atol(string val)   将十进制值val转化成对应的整数值
- long xtol(string val)  将十六进制值val（可选择以0x开头）转换成对应的整数值
- string ltoa(long val, long radix)  以指定的radix(2、8、10或16)返回val的字符串值
- string ord(string ch)  返回单字符字符串ch的ASCII值
- long strlen(string str)  返回所提供字符串的长度
- long strstr(string str, string substr)  返回str中substr的索引，如果没有发现子字符串，则返回-1
- string substr(string str, long start, long end)  返回包含str中由start到end-1位置的字符的子字符串。如果使用分片，此字符串等同于str[start:end]

### 2.4 文件输入/输出函数

- long fopen(string filename, string mode)  返回一个整数文件句柄（如果发生错误，则返回0），供所有IDC文件 输入/输出函数使用。mode参数与C语言的fopen函数使用相同的模式(r,w,等)
- void fclose(long handle)  关闭fopen中文件句柄指定的文件
- void filelength(long handle)  返回指定文件的长度，如果发生错误，则返回-1
- long fgetc(long handle)  从给定文件中读取一个字节。如果发生错误，则返回-1
- long fputc(long val, long handle)  写入一个字节到指定文件中，如果操作成功，则返回0；如果发生错误，则返回-1
- long fprintf(long handle, string format, ...)  将格式化字符串写入到指定文件中
- long writestr(long handle, string str)  将指定的字符串写入到给定文件中
- string/long readstr(long handle)  从给定文件中读取一个字符串。这个函数读取到下一个换行符位置的所有字符（包括非ASCII字符），包括换行符本身（ASCII 0x0a）。操作成功，返回字符串；如果读到文件结尾，则返回-1
- long writelong(long handle, long val, long bigendian)  使用大端(bigendian=1)或小端(bigendian=0)字节顺序将一个4字节整数写入到指定文件
- long readlong(long handle, long bigendian)  使用大端(bigendian=1)或小端(bigendian=0)字节顺序从给定文件中读取一个4字节整数
- long writeshort(long handle, long val, long bigendian)  使用大端(bigendian=1)或小端(bigendian=0)字节顺序将一个2字节整数写入到指定文件
- long readshort(long handle, long bigendian)  使用大端(bigendian=1)或小端(bigendian=0)字节顺序从给定文件中读取一个2字节整数
- bool loadfile(long handle, long pos, long addr, long length)  从给定文件的pos位置读取length数量的字节，并将这些字节写入到以addr地址开头的数据库中
- bool savefile(long handle, long pos, long addr, long length)  将以addr数据库地址开头的length数量的字节写入到给定文件的pos位置

### 2.5 操纵数据库名称

- string Name(long addr)  返回与给定地址有关的名称，如果该位置没有名称，则返回空字符串。如果名称被标记为局部名称，这个函数并不敢回用户定义的名称
- string NameEx(long from, long addr)  返回与addr有关的名称。如果该位置没有名称，则返回空字符串。如果from是一个同样包含addr的函数中的地址，则这个函数返回用户定义的局部名称。
- bool MakeNameEx(long addr, string name, long flags)  将给定的名称分配给给定的地址。改名称使用flags位掩码中指定的属性创建而成。这些标志在帮助系统中的MakeNameEx文档中记载描述，可以用于指定各种属性，如名称是局部名称还是公共名称、名称是否应在名称窗口中列出。
- long LockByName(string name)  返回一个位置（名称已给定）的地址。如果数据库中没有该名称，则返回BADADDR(-1)
- long LockByNameEx(long funcaddr, string localname)  在包含funcaddr的函数中搜索给定的局部名称。如果给定的函数中没有这个名称，则返回BADADDR（-1）

### 2.6 处理函数的函数

- long GetFunctionAttr(long addr, long attrib)  返回包含给定地址的函数的被请求的属性。文档中有属性常量。如要查找一个函数的结束地址，可以使用GetFunctionAttr(addr, FUNCTION_END)
- string GetFunctionName(long addr)  返回包含给定地址的函数的名称。如果给定地址并不属于一个函数，则返回一个空字符串
- long NextFunction(long addr)  返回给定地址后的下一个函数的起始地址。如果数据库中给定地址后没有其他函数，则返回-1
- long PrevFunction(long addr)  返回给定地址之前距离最近的函数的起始地址。如果数据库中给定地址后没有其他函数，则返回-1

当然，也可以通过函数名，使用LockByName函数查找函数的起始地址

### 2.7 代码交叉引用函数

- long Rfirst(long from)  返回给定地址向其转交控制权的第一个位置。如果给定地址没有引用其他地址，则返回BADAADDR（-1）
- long Rnext(long from, long current)  如果current已经在前一次调用Rfirst或Rnext时返回，则返回给定地址(from)转交控制权的下一个位置。如果没有其他交叉引用存在，则返回BADADDR
- long XrefType()  返回一个常量，说明某个交叉引用查询函数（如Rfirst）返回的最后一个交叉引用的类型。对于代码交叉引用，这些常量包括fl_CN（近调用）、fl_CF（远调用）、fl_JN（近跳转）、fl_JF（远跳转）和fl_F（普通顺序流）
- long RfirstB(long to)  返回转交控制权到给定地址的第一个位置。如果不存在对给定地址的交叉引用，则返回BADADDR（-1）
- long RnextB(long to, long current)  如果current已经在前一次调用RfirstB或RnextB时返回，则返回下一个转交控制权给给定地址(to)的位置。如果不存在其他堆给定位置的交叉引用，则返回BADADDR（-1）

每次调用一个交叉引用函数，IDA都会设置一个内部IDC状态变量，指出返回的最后一个交叉引用的类型。如果需要知道你收到的交叉引用的类型，那么在调用其他交叉引用查询函数之前，必须调用XrefType函数

### 2.8 数据交叉引用函数

- long Dfirst(long from)  返回给定地址引用一个数据值得第一个位置。如果给定地址没有引用其他地址，则返回BADADDR
- long Dnext(long from, long current)   如果current已经在前一次调用Dfirst或Dnext时返回，则返回给定地址(from)向其引用一个数据值的下一个位置。如果没有其他交叉引用存在，则返回BADADDR
- long XrefType()   返回一个常量，说明某个交叉引用查询函数（如Dfirst）返回的最后一个交叉引用的类型。对于数据交叉引用，这些常量包括dr_0（提供的偏移量）、dr_w（数据写入）和dr_R（数据读取）
- long DfirstB(long to)  返回将给定地址作为数据引用的第一个位置。如果不存在引用给定地址的交叉引用，则返回BADADDR
- long DnextB(long to, long current)  如果current已经在前一次调用DfirstB或DnextB时返回，则返回将给定地址（to）作为数据引用的下一个位置。如果没有其他对给定地址的交叉引用存在，则返回BADADDR

和代码交叉引用一样，如果需要知道你收到的交叉引用的类型，那么在调用另一个交叉引用查询函数之前，必须调用XrefType函数

### 2.9 数据库操纵函数

- void MakeUnkn(long addr, long flags)  取消位于指定地址的项的定义。这里的标志指出是否也取消随后的想的定义，以及是否删除任何与取消定义的项有关的名称。
- long MakeCode(long addr)  将位于指定地址的字节转换成一条指令
- long MakeByte(long addr)   将位于指定地址的项目转换成一个数据字节
- long MakeWord(long addr)
- long MakeDword(long addr)
- bool MakeComm(long addr, string comment)  在给定的地址处添加一条常规注释
- bool MakeFunction(long begin, long end)  将有begin到end的指令转换成一个函数。如果end被指定为BADADDR（-1），IDA会尝试通过定位函数的返回指令，来自动确定该函数的结束地址
- bool MakeStr(long begin, long end)  创建一个当前字符串(由GetStringType返回)类型的字符串，涵盖由begin到end-1之间的所有字节。如果end被指定为BADADDR，IDA会尝试自动确定字符串的结束地址

### 2.10 数据库搜索函数

三个最常见的标志为

1. SEARCH_DOWN  搜索操作扫描高位地址
2. SEARCH_NEXT  略过当前匹配项，扫描下一个匹配项
3. SEARCH_CASE  区分大小写的方式进行二进制和文本搜索

- long FindCode(long addr, long flags)  从给定的地址搜索一条指令
- long FindDate(long addr, long flags)   从给定的地址搜索一个数据项
- long FindBinary(long addr, long flags, string binary)  从给定的地址搜索一个字节序列。字符串binary指定一个十六进制字节序列值。如果没有设置SEARCH_CASE，且一个字节值指定一个大写或小写ASCII字母，则搜索仍然会匹配对应的互补值。例如"41 42"将匹配"61 62"、"61 42"等
- long FindText(long addr, long flags, long row, long column, string text)  在约定的地址，从给定行(row)的给定列搜索字符串text。注意，某个给定地址的反汇编文本可能会跨越几行，因此要指定从哪一行开始搜索

### 2.11 反汇编行组件

- string GetDisasm(long addr)  返回给定地址的反汇编文本。返回的文本包括任何注释，但不包括地址信息
- string GetMnem(long addr)  返回位于给定地址的指令的助记符部分
- string GetOpnd(long addr, long opnum)  返回给定地址的指定操作数的文本形式。IDA以0为其实编号，从左向右对操作数编号
- long GetOpType(long addr, long opnum)  返回一个整数，指出给定地址的给定操作数的类型。
- long GetOperandValue(long addr, long opnum)  返回与给定地址的给定操作数有关的整数值。返回值的性质取决于GetOpType指定的给定操作数的类型
- string CommentEx(long addr, long type)  返回给定地址处的注释文本。如果type为0，则返回常规注释文本；如果type为1，则返回可重复注释的文本。如果给定地址没注释，则返回空字符串。

## 3、IDC脚本示例

### 3.1 pwnable.kr中Codemap的idc脚本

```
#include <idc.idc>  

static main(){  

    auto max_eax, max_ebx, second_eax, second_ebx, third_eax, third_ebx;  
    auto eax, ebx;  

    // 依次为前三大堆块分配完成时的eax和ebx值
    max_eax = 0;  
    second_eax = 0;  
    third_eax = 0;  
    max_ebx = 0;  
    second_ebx = 0;  
    third_ebx = 0;  

    AddBpt(0x1173E65);      // 在提示位置添加断点，在IDA中该地址为0x1173E65
    StartDebugger("","","");  
    auto count;  
    for(count = 0; count < 999; count ++){  
        auto code = GetDebuggerEvent(WFNE_SUSP|WFNE_CONT, -1);  
        eax = GetRegValue("EAX");     // 中断时得到所需的值
        ebx = GetRegValue("EBX");  

        // 判断是否应刷新前三大堆块的值
        if(max_eax < eax){  
            third_eax = second_eax;  
            third_ebx = second_ebx;  
            second_eax = max_eax;  
            second_ebx = max_ebx;  
            max_eax = eax;  
            max_ebx = ebx;  
        }else if(second_eax < eax){  
            third_eax = second_eax;  
            third_ebx = second_ebx;  
            second_eax = eax;  
            second_ebx = ebx;  
        }else if(third_eax < eax){  
            third_eax = eax;  
            third_ebx = ebx;  
        }  
    }  
    // 输出
    Message("max eax: %d, ebx: %x, second eax: %d, ebx: %x, third eax: %d, ebx: %x\n", max_eax, max_ebx, second_eax, second_ebx, third_eax, third_ebx);  
}
```

- AddBpt(0x1173E65)   设置断点
- StartDebugger("","","")   这里是直接启用本地调试器
- auto code = GetDebuggerEvent(WFNE_SUSP|WFNE_CONT, -1)
- eax = GetRegValue("EAX");     // 中断时得到所需的值