## 前言

[Toll-Free Bridging](https://developer.apple.com/library/content/documentation/General/Conceptual/CocoaEncyclopedia/Toll-FreeBridgin/Toll-FreeBridgin.html)本身不是什么新技术，那为什么还要写这篇博客呢？

原因是今天和一个同事讨论到相关问题的时候，发现其实理解并不够深入，于是仔细研究了下，整理成了这篇博客。

---
## Toll-Free Bridging是什么？

摘自[文档](https://developer.apple.com/library/content/documentation/General/Conceptual/CocoaEncyclopedia/Toll-FreeBridgin/Toll-FreeBridgin.html)：

> There are a number of data types in the Core Foundation framework and the Foundation framework that can be used interchangeably。在Core Foundation中Foundation中，有一些类型是可以交换使用的。

比如，`NSString`和`CFStringRef`就可以交替使用:

`NSString` as `CFStringRef`

```
NSString * str = @"hello world";
NSLog(@"%ld",CFStringGetLength((__bridge CFStringRef)(str)));

```

`CFStringRef` as `NSString`

```
CFStringRef cf_str = CFStringCreateWithCString(kCFAllocatorDefault, "hello world", kCFStringEncodingUTF8); 
NSLog(@"%zd",[(__bridge NSString *)cf_str length]);
CFRelease(cf_str);
```
	
---
## 生命周期

Foundation对象是可以通过ARC进行管理的，而Core Foundation则需要调用`CFRetain`,`CFRelease`等方法手动管理生命周期。那么bridge的时候生命周期是如何移交的呢？

我们需要告诉编译器如何管理生命周期。通过以下三个关键字来控制：

### `__bridge`

> 进行OC指针和CF指针之间的转换，不涉及对象所有权转换。

那么，什么叫做对象的所有权转换呢？再理解之前记住两点：

1. Foundation对象是由ARC管理的（这里不考虑MRC的情况），你不需要手动retain和release。
2. Core Foundation的指针是需要手动管理生命周期。

**举例：OC -> CF，所有权在Foundation，不需要手动管理**

```
NSString * str = [NSString stringWithFormat:@"%ld",random()];
CFStringRef cf_str = (__bridge CFStringRef)str;
NSLog(@"%ld",(long)CFStringGetLength(cf_str));
```
**举例：CF -> OC，所有权在CF，需要手动管理内存**

```
CFStringRef cf_str = CFStringCreateWithFormat (NULL, NULL, CFSTR("%d"), rand());
NSString * str = (__bridge NSString *)cf_str;
NSLog(@"%ld",(long)str.length);
//这一行很有必要，不然会内存泄漏
CFRelease(cf_str);
```

### `__bridge_retained`

> 将一个OC指针转换为一个CF指针，同时移交所有权，意味着你需要手动调用`CFRelease`来释放这个指针。这个关键字等价于`CFBridgingRetain`函数。

**举例**

```
NSString * str = [NSString stringWithFormat:@"%ld",random()];
CFStringRef cf_str = (__bridge_retained CFStringRef)str;
NSLog(@"%ld",(long)CFStringGetLength(cf_str));
CFRelease(cf_str);
```


### `__bridge_transfer`

> 将一个CF指针转换为OC指针，同时移交所有权，ARC负责管理这个OC指针的生命周期。这个关键字等价于`CFBridgingRelease`

**举例**

```
CFStringRef cf_str = CFStringCreateWithFormat(NULL, NULL, CFSTR("%d"), rand());
NSString * str = (__bridge_transfer  NSString *)cf_str;
NSLog(@"%ld",(long)str.length);
```

### 小结

总结一句话，所有权在Foundation，则不需要手动管理内存；所有权在CF，需要调用CFRetain/CFRelease来管理内存。

---
## 原理

Foundation和CF是如何实现这种toll-free bridge的呢？

首先，我们查看CFString.h的头文件，找到`CFStringRef`的定义：

```
typedef const struct CF_BRIDGED_TYPE(NSString) __CFString * CFStringRef;
```

可以看到，CFStringRef就是一个常量的结构体`__CFString`的指针，那么这个宏定义`CF_BRIDGED_TYPE`又是什么呢？

在CFBase.h头文件中，我们找到了这个宏定义的答案：

```
#if __has_attribute(objc_bridge) 
	&& __has_feature(objc_bridge_id) 
	&& __has_feature(objc_bridge_id_on_typedefs)

#define CF_BRIDGED_TYPE(T)  __attribute__((objc_bridge(T)))
#else
#define CF_BRIDGED_TYPE(T)
#endif
```

`__has_attribute`是Clang Attribute的表达式：表示编译器满足某种条件。

比如这里就是判断满足可以进行TFB(toll-free bridging)的编译条件，如果满足的话，那么用`__attribute__((objc_bridge(NSString )))`去声明这个结构体，表示CFStringRef和NSString满足toll-free bridging。

```
NSString * str = [NSString stringWithFormat:@"%ld",random()];
//正常编译
CFStringRef cf_str = (__bridge_retained CFStringRef)str;
//编译器warning
CFStringRef cf_arry = (__bridge_retained CFArrayRef)str;
```

### class cluster

NSString等支持TFB的都是采用class cluster的设计模式来实现的，

> Class clusters group a number of private concrete subclasses under a public abstract superclass. The grouping of classes in this way simplifies the publicly visible architecture of an object-oriented framework without reducing its functional richness. Class clusters are based on the Abstract Factory design pattern.

简单来说，[Class cluster](https://developer.apple.com/library/content/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html)采用一个公开的抽象的基类提供对外接口，封装了具体的子类实现。

举个例子：

```
NSString * str1 = @"1234";
NSString * str2 = [NSString stringWithFormat:@"%ld",random()];
NSLog(@"%@", object_getClass(str1));
NSLog(@"%@", object_getClass(str2));
```
输出

```
__NSCFConstantString
__NSCFString
```

可以看到，**NSString只是一个抽象的基类，实际内存中存在的对象是子类的对象**。

### CoreFundation -> Foundation

> CF的对象能够bridge到Foundation指针的原因：Foundation的相关类采用**class cluster**的设计模式，比如NSString实际是子类`__NSCFString`实现，而`__NSCFString`则是用`CFString`来实现的。

测试代码，

```
CFStringRef cf_str = CFStringCreateWithFormat (NULL, NULL, CFSTR("%d"), rand());
```

lldb中打印其isa

```
(lldb) po object_getClass((id)cf_str)
NSTaggedPointerString
```

> 到这里就不难看出为什么这个CFStringRef可以当作NSString来使用了，**因为它的内存模型中有isa，通过isa就可以走Objective C对象运行时那一套东西**。


### Foundation -> CoreFundation

> Foundation的对象能够bridge CF到指针的原因：NSString的运行时实际创建的是`__NSCFString`等子类，子类的`length`等方法实现实际是把`self`作为参数传递给CF方法。

**验证：子类实际调用的是CF方法，并且传入self为指针**

测试代码

<img src="./images/toll_bridge.png">

运行测试代码，打印出字符串的地址和值：

```
0x1c00369e0 1804289383
```

由于Core Foundation是[开源的](https://opensource.apple.com/source/CF)，翻翻[CFString.m](https://opensource.apple.com/source/CF/CF-855.17/CFString.c.auto.html)的源码，找到`[NSString length]`对应调用的CF函数：

```
/* This one is for NSCFString; it does not ObjC dispatch or assertion check
*/
CFIndex _CFStringGetLength2(CFStringRef str) {
    return __CFStrLength(str);
}
```

然后，设置两个符号断点

```
(lldb) breakpoint set -n "-[__NSCFString length]"
Breakpoint 4: where = CoreFoundation`-[__NSCFString length], address = 0x0000000184d6146c
(lldb) breakpoint set -n "_CFStringGetLength2"
Breakpoint 5: where = CoreFoundation`_CFStringGetLength2, address = 0x0000000184d59898
```

继续运行代码，在第二个断点处检查寄存器状态，发现地址和值都和NSString的一样

```
//要用真机调试
(lldb) p/x $x0
(unsigned long) $3 = 0x00000001c00369e0
(lldb) po $x0
1804289383
```

> 我们确认了`NSString length`最后的实现会是调用`_CFStringGetLength2`，然后把self作为参数传递进来。


小知识：x0表示第一个通用寄存器，用来传递函数的第一个参数的，更多的汇编细节，参考我的这篇文章《[iOS汇编精讲](https://blog.csdn.net/hello_hwc/article/details/80028030)》


### `CFStringGetLength`

`CFStringGetLength`和`_CFStringGetLength2`的方法实现几乎一样，只是多了两个宏定义

```
/* This one is for CF
*/
CFIndex CFStringGetLength(CFStringRef str) {
    CF_OBJC_FUNCDISPATCHV(__kCFStringTypeID, CFIndex, (NSString *)str, length);

    __CFAssertIsString(str);
    return __CFStrLength(str);
}

/* This one is for NSCFString; it does not ObjC dispatch or assertion check
*/
CFIndex _CFStringGetLength2(CFStringRef str) {
    return __CFStrLength(str);
}
```

宏定义`CF_OBJC_FUNCDISPATCHV `会对str的类型进行检查，

- 如果不是`__kCFStringTypeID`（字符串类型），那么就直接向str发送消息`length`，走Runtime那一套逻辑。
- 如果是`__kCFStringTypeID`，那么直接调用`__CFStrLength`

比如定义一个类，实现了length方法：

```
@interface MYClass:NSObject

- (NSInteger)length;

@end

@implementation MYClass

- (NSInteger)length{
    return 10;
}

@end

```

然后，这些代码并不会crash

```
NSString * str = (NSString *)[[MYClass alloc] init];
NSLog(@"%ld",(long)CFStringGetLength((__bridge CFStringRef)str));
```

如果把MyClass替换成NSObject,会报错

> Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[NSObject length]: unrecognized selector sent to instance 0x1c40084d0'

----