### 前言

最近工作中写了很多Python，基本是一边Goolge一边写，虽然也能正常运行，但效率还挺低的，于是整理了这篇Python快速入门的教程，有时间的同学还是建议仔细阅读下[官方文档](https://docs.python.org/zh-cn/3/tutorial/index.html)。

本文环境: macOS 10.14 / [python 3.7.3](https://www.python.org/downloads/release/python-373/)


### Python

python是一门解释型，面向对象的高级程序设计语言，广泛用于DevOps，网络爬虫，机器学习等领域。Mac命令行自带的版本是2.7.3，最新的版本是3.7.x，大版本的升级并不会考虑向下兼容，所以本文的一些内容可能不适用于2.x版本的python。

查看python版本：

```
➜  ~ python --version
Python 2.7.10
➜  ~ python3 --version
Python 3.7.3
``` 

### IDE

IDE可以选择[PyCharm](https://www.jetbrains.com/pycharm/download/#section=mac)，PyCharm有两个版本，专业版(收费)和社区版(免费)，个人选择社区版就行了，基本功能都有。专业版提供Django、web2py框架支持，提供了远程调试，虚拟化部署等功能。

笔者用的比较多的IDE是[VSCode](https://code.visualstudio.com/)，简单的自动补全对我来说就够了。

### Hello world

新建文件hello_world.py，修改为可执行权限

```
➜  ~ mkdir ~/Desktop/py-scripts 
➜  ~ touch ~/Desktop/py-scripts/hello-world.py
➜  ~ chmod 777 ~/Desktop/py-scripts/hello-world.py 
```
修改hello-world.py，内容如下

```
#!/usr/bin/env python3
 
print("Hello, World!")
```

执行这个脚本：

```
➜  ~ python3 ~/Desktop/py-scripts/hello-world.py 
Hello, World!
```

第一行的语法`#!`是告诉系统用python3解释器来执行这个脚本，这样就可以直接执行：

```
~/Desktop/py-scripts/hello-world.py
Hello, World!
```

### 基础语法

**注释**

以#开头的为注释，多行注释可以是`"""`或者`'''`

```
#注释1

"""
多行注释1
多行注释2
"""
```

**缩进**

和其他语言用大括号来区分代码块不同，python用缩进来表示代码块，空格和Tab均可，如果是空格要保证同一代码块的空格数量相同。

```
if s > 0:
	print("1")
else:
	print("2")
```

**查看函数定义**

可以通过help查看函数定义：

```
➜  python3
>>> help(print)

print(...)
    print(value, ..., sep=' ', end='\n', file=sys.stdout, flush=False)
    
    Prints the values to a stream, or to sys.stdout by default.
    Optional keyword arguments:
    file:  a file-like object (stream); defaults to the current sys.stdout.
    sep:   string inserted between values, default a space.
    end:   string appended after the last value, default a newline.
    flush: whether to forcibly flush the stream.

```

**打印**

刚刚通过help函数，已经能够找到打印函数print的用法了

```
#默认以空格分割
>>> print("a","b","c")
a b c
#修改分隔符
>>> print("a","b","c",sep=",")
a,b,c
#结尾不换行
>>> print("a","b","c",sep=",",end=".") 
a,b,c.
```

格式化打印会在之后的字符串部分详细介绍。


### 变量和类型

- 变量以数字字母和下划线命名，不能以数字开头
- 命名中多个单词以下划线分开，大小写敏感，不需要提前声明。
- protected实例变量以下划线开头(具体见类一小节)
- private实例变量以双下划线开头(具体见类一小节)

```
file_name = "temp.txt" #变量赋值
a,b = 1,2  #多个变量可以同时赋值，以逗号分开
```

常见基本类型：

- 整型，支持任意大小的整型，只有int没有long
- 浮点数，支持科学计数法，比如111e-2表示1.11
- 布尔，True和False（注意大写），可以通过比较获得 temp = a > b
- 复数，虚部用j来表示，比如64.23+3j
- 字符串，单引号或者双引号包裹的文本，python中没有char的概念，char就是长度为1的字符串

类型之间可以进行转换：

```
>>> s="12"
>>> int(s) #字符串转int
12
>>> s="12.3"
>>> float(s) #字符串转float
12.3
>>> num=16
>>> hex(num) #整数转16进制字符串
'0x10'
```

### 运算符

**下标:[]**

下标支持从左到右：以0开始；从右到左：以-1开始

```
>>> s="123"
>>> s[0]
'1'
>>> s[-1]
'3'
```
关于下标可以参考这一张图：

```
 +---+---+---+---+---+---+
 | P | y | t | h | o | n |
 +---+---+---+---+---+---+
 0   1   2   3   4   5   6
-6  -5  -4  -3  -2  -1
```

**切片:[left:right]**

切片支持按照索引来返回子序列，包含left，不包含right

```
>>> s="123456789"
>>> s[0:2]
'12'
>>> s[4:]
'56789'
>>> s[:-3]
'123456'
```

**成员运算符: in/not in**

```
>>> "123" in "12345"
True
>>> "123" not in "12345"
False
```

**逻辑运算符: and or not**

```
>>> s = 'Python'
>>> s.startswith("P") and s.endswith("n")
True
>>> s.startswith("P") or s.endswith("K")
True
>>> not s.startswith("P")
False
```



### 字符串

用三引号(`"""`或者`'''`)表示一个多行字符串，换行符会自动包含在里面：

```
>>> print('''First line 
... second line
... third line''')
First line
second line
third line
```

用加号可以连接字符串：

```
>>> "Hello" + " " + "Leo"
'Hello Leo'
```

格式化字符字面值：在字符串开始加上f/F，然后就可以在字符串内部用{}引用表达式的值，这点和shell很像：

```
>>> year=2019
>>> month=6
>>> day=18
>>> f"Today is {year} {month} {day}"
'Today is 2019 6 18'
```

格式化的时候可以指定字符串的最小宽度，这样能够打印出对齐的列：

```
>>> info={'year':2019,'day':18,'month':6}
>>> for key,value in info.items():
...     print(f'{key:10} : {value:10}')
... 
year       :       2019
day        :         18
month      :          6
```

str.format同样可以格式化字符串

```
>>> "a{}{}".format("b","c")
'abc'
```
可以指定引用顺序：

```
>>> "a{0}{1}".format("b","c")
'abc'
>>> "a{1}{0}".format("b","c")
'acb'
```
也可以用关键字参数引用：

```
>>> "Today is {year} {month} {day}".format(year=2019,month=6,day=18)
'Today is 2019 6 18'
```
可以用**符号，将map作为关键字传递：

```
>>> info={'year':2019,'day':18,'month':6}
>>> "Today is {year} {month} {day}".format(**info)
'Today is 2019 6 18'
```

内置函数vars()会把局部变量以字典返回，可以配合**来做格式化：

```
>>> "Today is {year} {month} {day}".format(**vars())
'Today is 2019 6 18'
```

上文提到过，字符串支持切片，但不能用索引修改字符串的值，因为字符串是[不可变的](https://docs.python.org/zh-cn/3/glossary.html#term-immutable)：

```
>>> s="Python"
>>> s[2:]
'thon'
>>> s[0]="T" #字符串是不可变的s
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: 'str' object does not support item assignment
```

### 流程控制

**if**

```
>>> s="Python"
>>> if len(s) < 3:
...     print("length less than 3")
... elif len(s) < 5:
...     print("length less than 5")
... else:
...     print("length greater than 5")
... 
length greater than 5
```

**for in**

python的for语句是用来遍历序列：

```
>>> words = ['Hello','Leo']
>>> for word in words:
...     print(word)
... 
Hello
Leo
```

用range函数，可以创建以一个数字序列

```
>>> for i in range(3):
...     print(i)
...
0
1
2
```

字典可以同时遍历key，value：

```
>>> info={'year':2019,'day':18,'month':6}
>>> for key,value in info.items():
...     print(f'{key:10} : {value:10}')
```

序列可以用enumerate函数同时遍历index，value：

```
>>> for index,word in enumerate(words):
...     print(index,word)
... 
0 Hello
1 Leo
```

break/continue可以跳出和继续循环，这点和C语言一样：

```
>>> for i in range(5):
...     if i > 3:
...             break
...     print(i)
... 
0
1
2
3
```

**while**

while的语法和C语言也类似

```
>>> i = 0
>>> while i < 5:
...     print(i)
...     i = i + 1
```

**else**

while和for都支持else语句，当循环条件不满足的时候执行，但是注意break语句不会触发else语句：

```
>>> i = 0
>>> while i < 5:
...     print(i)
...     i = i + 1
... else:
...     print("Not less than 5")
... 
0
1
2
3
4
Not less than 5
```

**pass**

当你在语法上需要一个占位符的时候，可以用pass语句，这个分支结构啥也不做：

```
#定义一个空函数，如果没有pass语句，python会报错
>>> def initlog(*args):
...     pass   
...
```

### 列表

列表和其他语言的数组一样，用来存储一组值，列表支持索引和切片，是可变类型：

```
#创建列表
>>> l=[1,2,3]
#列表最后添加一个元素
>>> l.append(4)
#修改列表的第一个元素
>>> l[0]=5
#对列表切片，返回一个新的列表
>>> l1=l[0:1]
#删除列表的最后一个元素，并返回
>>> l.pop()
#删除指定位置元素
>>> del l[0]
#删除全部元素
>>> del l[:]
```

### 元组

元组是用逗号分隔的一组值，通常由括号包裹，和列表的区别是元组是不可变的：

```
>>> t=(1,2,'3')
#索引访问值
>>> t[0]
1
#序列解包，同时解开多个值
>>> a,b,c=t
>>> print(a,b,c)
1 2 3
```

### 集合

集合用来表示**不重复元素的无序**的集，可以用`{}`或者set创建，空集合只能用set()创建，集合是可变的。

```
>>> a={1,2,3}
>>> b=set([2,3,4])
#遍历
>>> for element in a:
...     print(element)
... 
1
2
3
#添加元素
>>> a.add(5)
#删除元素
>>> a.remove(5)
#元素是否存在
>>> 1 in a
#集合运算
>>> print(a-b)
{1}
>>> print(a|b)
{1, 2, 3, 4}
>>> print(a&b)
{2, 3}
```

### 字典
字典是一种key-value的数据结构，任何不可变的类型都可以作为key。

```
#初始化值
>>> temp={'a':1,'b':2}
#修改值
>>> temp['a']=3
#访问值
>>> temp['a']
3
#遍历
>>> for key,value in temp.items():
...     print(key,value)
... 
a 3
b 2
#删除
>>> del temp['a']
#按插入顺序返回key
>>> list(temp)
['b', 'c']
#字典的构造函数可以从键值对里创建
>>> temp=dict([('a',1),('b',2),('c',3)])
#也可以
```

### 函数

函数可以让你灵活的组织和复用代码，定义一个函数，以def表示函数定义，括号来表示参数，return来返回值，函数体以缩紧表示：

```
>>> def add(a,b):
...     sum=a+b
...     return sum
... 
>>> add(1,2)
3
```

函数内部的变量存储在**局部符号表**里，在进行符号访问的时候，依次查找局部符号表，然后是外层函数的布局符号表，最后是内置符号表。

所以：

- 函数内可以访问全局变量
- 局部变量和全局变量重名，会访问到全局变量

```
>>> def add(a,b):
...     print(temp)
...     return a+b
... 
>>> temp=1
>>> temp = "Hi"
>>> add(1,2)
Hi
3
```

函数内部不能直接修改变全局变量，但是可以通过global关键字重定义后可修改：

```
>>> def add(a,b):
...     global c
...     c = 11
...     return a + b + c
... 
>>> c = 1
>>> add(1,2)
14
```

函数参数可以有默认值，这样在调用的时候可以提供更少的参数：

```
def ask_ok(promot,retries=4,reminder="Please try again~"):
    while True:
        ok = input(promot)
        if ok in ('y','ye','yes'):
            return True
        if ok in ('n','no','nope'):
            return False
        retries = retries - 1
        if retries < 0:
            raise ValueError("Invalid input")
        print(reminder)
```

调用的时候，有默认值的参数可以不提供：

```
ask_ok("Developer ?")
ask_ok("Developer ?",2)
ask_ok("Developer ?",reminder="Oh no")
```

注意，默认值只会执行一次，所以当你要修改默认值的时候要慎重，比如：

```
def f(a, L=[]):
    L.append(a)
    return L
print(f(1))
print(f(2))
print(f(3))
```
输出是

```
[1]
[1, 2]
[1, 2, 3]
```
这种情况，可以用None来代替：

```
def f(a, L=None):
    if L is None:
        L = []
    L.append(a)
    return L
```

参数解包：

- `*`解包元组或者列表
- `**`解包字典


```
>>> def add(a,b):
...     return a+b
... 
>>> l = [2,3]
>>> add(*l)
5
>>> dic={'a':3,'b':4}
>>> add(**dic)
7
```

lambda表达式可以用来表示一类无序定义标识符的函数或者子程序：冒号前作为参数，冒号后为表达式：

```
>>> a = lambda x,y:x*y
>>> a(3,4)
12
```
### 模块 

代码多了之后，就产生了两个核心问题

1. 如何组织代码：很明显所有代码写到一个文件里是不合理的
2. 如何复用代码：通用的代码没必要每次都写一遍

在python中，解决这两个问题的方式就是模块。模块是一个包含Python定义和语句的文件，模块名就是文件名去掉.py后缀。

模块还能解决函数重名的问题。同一个文件里，如果定义了两个一样的函数，那么第二个会把第一个覆盖掉，但是在两个模块里，允许出现同名函数。

新建两个文件，logger1和logger2

```
logger1.py
#!/usr/bin/env python3
 
def log():
  print('hello leo')
  

logger2.py
#!/usr/bin/env python3
 
def log():
  print('hello lina')
```

然后，引用这两个文件，并调用里面的log函数

```
import logger1,logger2

logger1.log()
logger2.log()
``` 

输出

```
➜ python3 demo.py
hello leo
hello lina
```

引用的时候，可以用别名

```
import logger1 as l1
import logger2 as l2

l1.log()
l2.log()
```

模块在import的时候，python脚本会从上之下执行，可以通过判断`__name__=='__main__'`来判断是被import，还是直接执行的：

```
#!/usr/bin/env python3

def log():
    print('hello leo')

#import的时候，不要执行这个方法
if __name__ == '__main__':
   log()

```

### 类

用`class`关键字来定义类，`__init__`来定义构造哈数，属性直接通过在构造函数中赋值即可，不像其他语言那样需要证明

```
class Logger:
    def __init__(self,prefix):
        self.prefix = prefix
    def log_message(self,content):
        print(self.prefix + ":" + content)
```

创建对象和调用方法

```
l = Logger("Leo")
l.log_message("hi~")
```

属性分为公开和私有的，双下划线开头的表示私有：

```
class Logger:
    def __init__(self,prefix):
        self.__prefix = prefix
    def log_message(self,content):
        print(self.__prefix + ":" + content)

l = Logger("Leo")
l.log_message("hi~")
print(l.__prefix)
```
然后执行，会发现报错属性找不到

```
➜  python python demo.py  
Leo:hi~
Traceback (most recent call last):
  File "demo.py", line 9, in <module>
    print(l.__prefix)
AttributeError: Logger instance has no attribute '__prefix'
```

### 文件

通过open可以打开文件，然后进行读写。

- '`r`' 读(默认)
- `'w'` 写(截断之前的内容)
- `'x'` 写，如果之前存在内容会触发异常
- `'a'` 追加内容到文件结尾
- `'b'` 二进制模式
- `'t'` 文本模式(默认)
- `'t'` 读写模式

比如，一个文本文件content.txt：

```
Environment in Bristol
Economic history of the Russian Federation
Energy in Chile
Employee monitoring
E-Government in South Korea
```
然后，通过read函数读取文件内容，注意打开文件后要关闭

```
def read_file(file_name):
    f = open(file_name, 'r', encoding='utf-8')
    print(f.read())
    f.close()

if __name__ == '__main__':
    read_file('content.txt')
```

也可以通过with语句，来指定文件对象的上下文，然后离开上下文的时候自动释放；可以通过for in逐行读取，或者通过readlines()把内容读取到一个容器里：

```
def read_file(file_name):
    with open(file_name,'r',encoding='utf-8') as f:
        for line in f:
            print(line.rstrip())

    with open(file_name,'r',encoding='utf-8') as f:
        print(f.readlines())

if __name__ == '__main__':
    read_file('content.txt')
```

### 异常

python中的异常可以用try-expect-finally来处理

- try 执行可能会抛出异常的代码块
- expect 捕获异常
- finally 一定会执行的代码，一般用来释放资源等等

```
def read_file(file_name):
    try:
        with open(file_name,'r',encoding='utf-8') as f:
            for line in f:
                print(line.rstrip())
    except FileNotFoundError as ex:
        print(ex)
        print("File not found")
    finally:
        print("Code always run")

if __name__ == '__main__':
    read_file('abcd.txt')

```

程序里也可以手动抛出异常

```
raise NameError("test error")
```

python3中，可以通过以下方式查找内置的error

```
>>> import builtins
>>> dir(builtins)
```
