## 前言

block在Objective C开发中应用非常广泛，当然我们知道block会捕获外部对象，也知道使用block要防止循环引用。那么block这套机制在OC中是如何实现的呢？本文通过从C/C++到汇编层面分析block的实现原理。

----
## Clang

clang是XCode的编译器前端，编译器前端负责语法分析，语义分析，生成中间代码(intermediate representation )。

比如当你在XCode中进行build一个.m文件的时候，实际的编译命令如下

```
clang -x objective-c -arch x86_64
 -fmessage-length=0 
 -fobjc-arc... 
 -Wno-missing-field-initializers ... 
 -DDEBUG=1 ... 
 -isysroot iPhoneSimulator10.1.sdk 
 -fasm-blocks ... 
 -I headers.hmap 
 -F 所需要的Framework  
 -iquote 所需要的Framework  ... 
 -c ViewController.m 
 -o ViewController.o

```

Objective C也可以用GCC来编译，不过那超出了本文的范畴，不做讲解。

Clang除了能够进行编译之外，还有其他一些用法。比如本文分析代码的核心命令就是这个：

```
clang -rewrite-objc 文件.m
```

通过这个命令，我们可以把Objective C的代码用C++来表示。

对于想深入理解Clang命令的同学，可以用命令忙自带的工具来查看帮助文档

```
man clang
```
或者阅读官方文档：[文档地址](http://clang.llvm.org/)。

----
## 查看汇编代码
在XCode中，对于一个源文件，我们可以通过如下方式查看其汇编代码。这对我们分析代码深层次的实现原理非常有用，这个在后面也会遇到。

<img src="http://img.blog.csdn.net/20170416205130868?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="300">

----
## Objective C对象内存模型
为了本文讲解的更清楚，我们首先来看看一个Objective C对象的内存模型。我们首先新建一个类，内容如下

DemoClass.h

```
@interface DemoClass : NSObject
@property (nonatomic, copy) NSString * value;
@end
```

DemoClass.m

```
@implementation DemoClass
- (void)demoFunction{
    DemoClass * obj = [[DemoClass alloc] init];
}
@end
```

然后，我们用上文提到的Clang命令将DemoClass.m转成C++的表示。

```
clang -rewrite-objc DemoClass.m
```

转换完毕后当前目录会多一个DemoClass.cpp文件，这个文件很大，接近十万行。

我们先搜索这个方法名称`demoFunction`，以方法作为切入

```
static void _I_DemoClass_demoFunction(DemoClass * self, SEL _cmd) {
    DemoClass * obj = ((DemoClass *(*)(id, SEL))(void *)objc_msgSend)((id)((DemoClass *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("DemoClass"), sel_registerName("alloc")), sel_registerName("init"));
}
```

可以看到，转换成C++后，一个实例方法转换为一个静态方法，这个方法的内容看起来很乱，因为有各种的类型强制转换，去掉后就比较清楚了。

```
static void _I_DemoClass_demoFunction(DemoClass * self, SEL _cmd) {
 	DemoClass * obj = objc_msgSend(objc_msgSend(objc_getClass("DemoClass"), sel_registerName("alloc")), sel_registerName("init"));
}
```

可以看到：

- 转换后增加了两个参数：`self`和`_cmd`
- 方法的调用转换成了`objc_msgSend`，这是一个C函数，两个参数分别是`Class`和`SEL`

关于`objc_msgSend`内发生的事情，参见我之前的一篇博客：

- [iOS Runtime详解(消息机制，类元对象，缓存机制，消息转发)](http://blog.csdn.net/hello_hwc/article/details/49687543)

到这里，我们知道了一个OC的实例方法具体是怎么实现的了。

那么，一个OC对象在内存中是如何存储的呢？我们在刚刚的方法的上下可以找到这个类的完整实现，

```
//类对应的结构体
struct DemoClass_IMPL {
	struct NSObject_IMPL NSObject_IVARS;
	NSString *_value;
};
//demoFunction方法
static void _I_DemoClass_demoFunction(DemoClass * self, SEL _cmd) {
    DemoClass * obj = objc_msgSend(objc_msgSend(objc_getClass("DemoClass"), sel_registerName("alloc")), sel_registerName("init"));
}
//属性value的getter方法
static NSString * _I_DemoClass_value(DemoClass * self, SEL _cmd) { return (*(NSString **)((char *)self + OBJC_IVAR_$_DemoClass$_value)); }
extern "C" __declspec(dllimport) void objc_setProperty (id, SEL, long, id, bool, bool);

//属性value的setter方法
static void _I_DemoClass_setValue_(DemoClass * self, SEL _cmd, NSString *value) { objc_setProperty (self, _cmd, __OFFSETOFIVAR__(struct DemoClass, _value), (id)value, 0, 1); }

```
我们侧重来看看类对应的结构体

```
struct DemoClass_IMPL {
	struct NSObject_IMPL NSObject_IVARS;
	NSString *_value;
};
//我们依次查找不清楚的定义
struct NSObject_IMPL {
	Class isa;
};
typedef struct objc_class *Class;
struct objc_class {
    Class isa ;
};
```
可以看到，OC类实际是按照以下方式来存储对象的

- isa指针。指向objc_class类型的结构体，这个结构体中存储了方法的列表等类相关的信息，因为objc_msgSend中，发给对象的实际是一个字符串，运行时就是通过isa找到类对象，然后通过字符串找到方法的实际执行的。
- ivar。属性背后的存储对象，到这里也能看出来一个普通的属性就是`ivar+getter+setter`.


> **也就是说，只要有isa指针，指向一个类对象，那么这个结构就能处理OC的消息机制，也就能当成OC的对象来用。**

----
## Block的本质

我们修改DemoClass.m中的内容如下

```
typedef void(^VoidBlock)(void);
@implementation DemoClass

- (void)demoFunction{
    NSInteger variable = 10;
    VoidBlock temp = ^{
        NSLog(@"%ld",variable);
    };
    temp();
}
@end
```
然后，重新用clang转换为C++代码，有关这段代码的内容如下：

```
struct __block_impl {
  void *isa;
  int Flags;
  int Reserved;
  void *FuncPtr;
};
struct __DemoClass__demoFunction_block_impl_0 {
  struct __block_impl impl;
  struct __DemoClass__demoFunction_block_desc_0* Desc;
  NSInteger variable;
  __DemoClass__demoFunction_block_impl_0(void *fp, struct __DemoClass__demoFunction_block_desc_0 *desc, NSInteger _variable, int flags=0) : variable(_variable) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __DemoClass__demoFunction_block_func_0(struct __DemoClass__demoFunction_block_impl_0 *__cself) {
  NSInteger variable = __cself->variable; // bound by copy

        NSLog((NSString *)&__NSConstantStringImpl__var_folders_hj_392p68d55td2kdxrbd9h15g40000gn_T_Test_c7592d_mi_0,variable);
}

static struct __DemoClass__demoFunction_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __DemoClass__demoFunction_block_desc_0_DATA = { 0, sizeof(struct __DemoClass__demoFunction_block_impl_0)};

static void _I_DemoClass_demoFunction(DemoClass * self, SEL _cmd) {
    NSInteger variable = 10;
    VoidBlock temp = ((void (*)())&__DemoClass__demoFunction_block_impl_0((void *)__DemoClass__demoFunction_block_func_0, &__DemoClass__demoFunction_block_desc_0_DATA, variable));
    ((void (*)(__block_impl *))((__block_impl *)temp)->FuncPtr)((__block_impl *) temp);
}

```

我们还是以方法作为切入点，看俺具体是怎么实现的。`_I_DemoClass_demoFunction `是`DemoFunction`转换后的方法。我们去掉一些强制转化代码，这样看起来更清楚

```
static void _I_DemoClass_demoFunction(DemoClass * self, SEL _cmd) {
    NSInteger variable = 10;
    VoidBlock temp = &__DemoClass__demoFunction_block_impl_0(__DemoClass__demoFunction_block_func_0, &__DemoClass__demoFunction_block_desc_0_DATA, variable));
    (temp->FuncPtr)(temp);
}
```
从上至下，三行的左右依次是

- 初始化一个variable（也就是block捕获的变量）
- 调用结构体`__DemoClass__demoFunction_block_impl_0`的构造函数来新建一个结构体，并且把地址赋值给temp变量（也就是初始化一个block）
- 通过调用temp变量内的函数指针（C的函数指针）来执行实际的函数。

通过这些分析，我们知道了Block的大致实现

> **block背后的内存模型实际上是一个结构体，这个结构体会存储一个函数指针来指向block的实际执行代码。**

接着，我们来深入的研究下block背后的结构体，也就是这个结构体`__DemoClass__demoFunction_block_impl_0`:

```
struct __block_impl {
  void *isa; //和上文提到的OC对象isa一样，指向的类对象，用来找到方法的实现
  int Flags; //标识位
  int Reserved; //保留
  void *FuncPtr; //Block对应的函数指针
};

struct __DemoClass__demoFunction_block_impl_0 {
  //结构体的通用存储结构
  struct __block_impl impl;
  //本结构体的描述信息
  struct __DemoClass__demoFunction_block_desc_0* Desc;
  //捕获的外部变量
  NSInteger variable;
  //构造函数（也就是初始化函数，用来在创建结构体实例的时候，进行必要的初始化工作）
  struct __DemoClass__demoFunction_block_impl_0 {
  struct __block_impl impl;
  struct __DemoClass__demoFunction_block_desc_0* Desc;
  NSInteger variable;
  __DemoClass__demoFunction_block_impl_0(void *fp,
                                         struct __DemoClass__demoFunction_block_desc_0 *desc,
                                         NSInteger _variable,
                                         int flags=0) : variable(_variable) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```
我们在回头看看block初始化那句代码

```
//OC
VoidBlock temp = ^{
        NSLog(@"%ld",variable);
};
//C++
VoidBlock temp = &__DemoClass__demoFunction_block_impl_0(__DemoClass__demoFunction_block_func_0, 
&__DemoClass__demoFunction_block_desc_0_DATA, 
variable));

```
在对应之前代码块的构造函数，我们可以清楚的看到，在初始化的时候三个参数依次是

- 函数指针`__DemoClass__demoFunction_block_func_0`
- block的描述结构体（全局静态结构体）`__DemoClass__demoFunction_block_desc_0_DATA `
- 捕获的变量`variable`

接着，我们来看看block背后的C函数`__DemoClass__demoFunction_block_func_0 `

```
static void __DemoClass__demoFunction_block_func_0(struct __DemoClass__demoFunction_block_impl_0 *__cself) {
  NSInteger variable = __cself->variable; // bound by copy
  NSLog((NSString *)&__NSConstantStringImpl__var_folders_hj_392p68d55td2kdxrbd9h15g40000gn_T_DemoClass_c7592d_mi_0,variable);
}
```

Tips：
> 内存中存储区域可分为以下几个区域：
> 
> - TEXT 代码区
> - DATA 数据区
> - Stack 栈区
> - HEAP 堆区
> 
> 上文的字符串@"%ld"，对应C++代码是`)&__NSConstantStringImpl__var_folders_hj_392p68d55td2kdxrbd9h15g40000gn_T_DemoClass_c7592d_mi_0`，是存储在数据区的。这样即使程序中有多个@"%ld"，也不会创建多个实例。


可以看到，这个C函数的参数是`__DemoClass__demoFunction_block_impl_0`，也就是一个block类型。然后在方法体内部，使用这个block类型的参数。

最后，我们分析下block的描述信息，也就是这段代码

```
static struct __DemoClass__demoFunction_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __DemoClass__demoFunction_block_desc_0_DATA = { 0, sizeof(struct __DemoClass__demoFunction_block_impl_0)};
```

这段代码不难理解，就是声明一个描述信息的结构体，然后初始化这个结构体类型的全局静态变量。

分析到这里，上面代码的大多数内容我们都理解了，但是有一点我们还没有搞清楚，就是isa指向的内容`_NSConcreteStackBlock`

```
impl.isa = &_NSConcreteStackBlock;
```

> 但是，到这里我们知道了为什么Block可以当作OC对象来用的原因：就是这个指向类对象的isa指针。


----
## Block的类型

上文提到了`_NSConcreteStackBlock`是Block一种，block一共有三种类型

- NSConcreteStackBlock 栈上分配，作用域结束后自动释放
- NSConcreteGlobalBlock 全局分配，类似全局变量，存储在数据段，内存中只有一份
- NSConcreteHeapBlock 堆上分配

我们仍然尝试用Clang转换的方式，来验证我们的理论。将DemoClass.m内容修修改为

```
#import "DemoClass.h"

typedef void(^VoidBlock)(void);

@interface DemoClass()
@property (copy, nonatomic) VoidBlock heapBlock;

@end
VoidBlock globalBlock = ^{};

@implementation DemoClass

- (void)demoFunction{
    VoidBlock stackBlock = ^{};
    stackBlock();
    _heapBlock = ^{};
}

@end
```

然后，转成C++后，分别对应如下

全局globalBlock

```
impl.isa = &_NSConcreteGlobalBlock;
```
栈上stackBlock

```
impl.isa = &_NSConcreteStackBlock;
```

属性Block

```
impl.isa = &_NSConcreteStackBlock;
```

What the fuck! 怎么属性的block是栈类型的，难道不该是堆类型的吗？

<img src="http://img.blog.csdn.net/20170416210456590?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast">


到这里，C/C++层面的代码已经无法满足我们的需求了。我们试着把代码转成汇编，一探究竟：

方便分析属性block究竟是怎么实现的，我们修改.m文件

```
#import "DemoClass.h"
typedef void(^VoidBlock)(void);
@interface DemoClass()
@property (copy, nonatomic) VoidBlock heapBlock;
@end
@implementation DemoClass
- (void)demoFunction{
    _heapBlock = ^{};
}
@end
```
转换成汇编后，在方法`demoFunction`部分，我们能看到类似汇编代码

```
bl	_objc_retainBlock
	adrp	x8, _OBJC_IVAR_$_DemoClass._heapBlock@PAGE
	add	x8, x8, _OBJC_IVAR_$_DemoClass._heapBlock@PAGEOFF
	.loc	1 0 0                   ; /Users/hl/Desktop/OCTest/OCTest/DemoClass.m:0:0
	ldr	x1, [sp, #8]
	.loc	1 21 5                  ; /Users/hl/Desktop/OCTest/OCTest/DemoClass.m:21:5
	ldrsw		x8, [x8]
	add		x8, x1, x8
	.loc	1 21 16 is_stmt 0       ; /Users/hl/Desktop/OCTest/OCTest/DemoClass.m:21:16
	ldr		x1, [x8]
	str		x0, [x8]
	.loc	1 21 16 discriminator 1 ; /Users/hl/Desktop/OCTest/OCTest/DemoClass.m:21:16
	mov	 x0, x1
	bl	_objc_release
```

也就是说，在方法返回之前，依次调用了

```
_objc_retainBlock
_objc_release
```

那么，`_objc_retainBlock`就是block从栈到堆的黑魔法。

我们通过[Runtime的源码](https://opensource.apple.com/source/objc4/objc4-706/runtime)来分析这个方法的实现：

```
id objc_retainBlock(id x) {
    return (id)_Block_copy(x);
}

// Create a heap based copy of a Block or simply add a reference to an existing one.
// This must be paired with Block_release to recover memory, even when running
// under Objective-C Garbage Collection.
BLOCK_EXPORT void *_Block_copy(const void *aBlock)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
```

到这里我们就清楚了，编译器为我们自动插入了`_objc_retainBlock`，而这个函数会把栈上的block拷贝到堆上。

> Tips: 通常在写属性的时候，block都会声明为copy。这是显式的表示，即使block是栈上的，也会拷贝到堆上。其实在赋值的时候，编译器已经自动帮我们做了这些，所以其实使用strong也可以。

那么，一个临时变量的block会被拷贝到堆上么？

修改`demoFunction`:

```
- (void)demoFunction{
    VoidBlock stackBlock = ^{};
}
```

继续查看汇编：

```
Ltmp7:
	.loc	1 23 15 prologue_end    ; /Users/hl/Desktop/OCTest/OCTest/Test.m:23:15
	mov	 x0, x8
	bl	_objc_retainBlock
	mov	x8, #0
	add	x1, sp, #8              ; =8
	str	x0, [sp, #8]
	.loc	1 24 1                  ; /Users/hl/Desktop/OCTest/OCTest/Test.m:24:1
	mov	 x0, x1
	mov	 x1, x8
	bl	_objc_storeStrong
	ldp	x29, x30, [sp, #32]     ; 8-byte Folded Reload
	add	sp, sp, #48             ; =48
	ret
```

**我们仍然看到了`_objc_retainBlock`，也就是说即使是一个在函数中的block，在ARC开启的情况下，仍然会拷贝到堆上。**

----
## __block

通过之前的讲解，我们知道了block如何捕获外部变量，也知道了block的几种类型。那么block如何修改外部变量呢？

block是不可以直接修改外部变量的，比如

```
NSInteger variable = 0;
_heapBlock = ^{
    variable = 1;
};
```

直接这么写，编译器是不会通过的，想想也很简单，因为变量可能在block执行之前就被释放掉了，直接这么赋值会导致野指针。

在OC层面，我们可以通过增加`__block`关键字，那么加了这个关键字后，实际的C++层面代码是什么样的呢？

```
- (void)demoFunction{
    __block NSInteger variable = 0;
    VoidBlock stackBlock = ^{
        variable = 1;
    };
}

```

在转换成C++代码后，如下：

```
static void _I_DemoClass_demoFunction(DemoClass * self, SEL _cmd) {
    __Block_byref_variable_0 variable = {0,&variable, 0, sizeof(__Block_byref_variable_0), 0};
    VoidBlock stackBlock = &__DemoClass__demoFunction_block_impl_0(( __DemoClass__demoFunction_block_func_0,
                                                                    &__DemoClass__demoFunction_block_desc_0_DATA,
                                                                    (__Block_byref_variable_0 *)&variable,
                                                                    570425344);
}
```

可以看到，`__block NSInteger variable = 0`转换成了一个结构体

```
__Block_byref_variable_0 variable = {0,&variable, 0, sizeof(__Block_byref_variable_0), 0};
```

这个结构体定义如下：

```
struct __Block_byref_variable_0 {
  void *__isa;
__Block_byref_variable_0 *__forwarding;
  int __flags;
  int __size;
  NSInteger variable; //这个是要修改的变量
};
```

通过初始化我们可以看到

- `__isa`指向0
- `__forwarding` 指向`__Block_byref_variable_0`自身
- `__flags`为0
- `__size`就是结构题的大小
- `variable`是我们定义的原始值0

到这里，我们有一点疑惑

- 为什么要存在一个`__forwarding`来指向自身呢？

我们来看看block的方法体，也就是这部分

```
^{
   variable = 1;
 }
```

转换成C++后：

```
static void __DemoClass__demoFunction_block_func_0(struct __DemoClass__demoFunction_block_impl_0 *__cself) {
  __Block_byref_variable_0 *variable = __cself->variable; // bound by ref
    variable->__forwarding->variable) = 1;
}
```

> 也就是说`__forwarding`存在的意义就是通过它来访问到变量的地址，如果这个指针一直指向自身，那么它也就没有存在的意义，也就是在将来的某一个时间点，它一定会指向另外一个数据结构。

我们在上文中讲到，ARC开启的时候，栈上的block会被复制到堆上。

在没有复制之前：

<img src="http://img.blog.csdn.net/20170417123417033?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="300">

复制之后

<img src="http://img.blog.csdn.net/20170417123424771?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="600">

这样，我们就清楚原因了：

> 即使发生了复制，只要修改`__forwarding`的指向，我们就能够保证栈上和堆上的block都访问同一个对象。

----
## Block对对象的捕获
到这里，我们分析的block都是捕获一个外部值，并不是对象。值和对象最大的区别就是对象有生命周期，对象我们需要考虑引用计数。

修改`DemoFunction`

```
- (void)demoFunction{
    NSObject * obj = [[NSObject alloc] init];
    VoidBlock stackBlock = ^{
        [obj description];
    };
    stackBlock();
}
```

再转换成C++后，我们对比之前捕获`NSInteger`，发现多了两个生命周期管理函数

```
static void __DemoClass__demoFunction_block_copy_0(struct __DemoClass__demoFunction_block_impl_0*dst, struct __DemoClass__demoFunction_block_impl_0*src)
{
    _Block_object_assign((void*)&dst->obj, (void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);
}

static void __DemoClass__demoFunction_block_dispose_0(struct __DemoClass__demoFunction_block_impl_0*src)
{
    _Block_object_dispose((void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);
}
```

我们再查看下`Block_object_assign`和`Block_object_dispose`的定义

```
// Used by the compiler. Do not call this function yourself.
BLOCK_EXPORT void _Block_object_assign(void *, const void *, const int);
// Used by the compiler. Do not call this function yourself.
BLOCK_EXPORT void _Block_object_dispose(const void *, const int);
```

也就是说，编译器通过这两个函数来管理Block捕获对象的生命周期。其中

- `_Block_object_assign`相当于ARC中的reatain，在block从栈上拷贝到堆上的时候调用
- `_Block_object_dispose`相当于ARC中的release，在block堆上废弃的时候调用



----
## 总结

- block在C语言层面就是结构体，结构体存储了函数指针和捕获的变量列表
- block分为全局，栈上，堆上三种，ARC开启的时候，会自动把栈上的block拷贝到堆上
- `__block`变量在C语言层面也是一个结构体
- block捕获对象的时候会增加对象的引用计数。