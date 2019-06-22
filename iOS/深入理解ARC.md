## 前言
本文的ARC特指Objective C的ARC，并不会讲解其他语言。另外，本文涉及到的原理部分较多，适合有一定经验的开发者。

-----
## 什么是ARC？

ARC的全称Auto Reference Counting. 也就是自动引用计数。那么，为什么要有ARC呢？

我们从C语言开始。使用C语言编程的时候，如果要在堆上分配一块内存，代码如下

```
//分配内存（malloc/calloc均可）
int * array = calloc(10, sizeof (int));

//释放内存
free(array);
```

C是面向过程的语言（Procedural programming），这种内存的管理方式简单直接。但是，对于面向对象编程，这种手动的分配释放毫无疑问会大大的增加代码的复杂度。

于是，OOP的语言引入了各种各样的内存管理方法，比如Java的垃圾回收和Objective C的引用计数。关于垃圾回收和饮用计数的对比，可以参见Brad Larson的[这个SO回答](http://stackoverflow.com/a/7894809/3940672)。

> Objective C的引用计数理解起来很容易，当一个对象被持有的时候计数加一，不再被持有的时候引用计数减一，当引用计数为零的时候，说明这个对象已经无用了，则将其释放。
> 
> 引用计数分为两种：
> 
> - 手动引用计数（MRC）
> - 自动引用计数（ARC）

在iOS开发早期，编写代码是采用MRC的

```
// MRC代码
NSObject * obj = [[NSObject alloc] init]; //引用计数为1
//不需要的时候
[obj release] //引用计数减1
//持有这个对象
[obj retain] //引用计数加1
//放到AutoReleasePool
[obj autorelease]//在auto release pool释放的时候，引用计数减1
```

虽说这种方式提供了面向对象的内存管理接口，但是开发者不得不花大量的时间在内存管理上，并且容易出现内存泄漏或者release一个已被释放的对象，导致crash。

再后来，Apple对iOS/Mac OS开发引入了ARC。使用ARC，开发者不再需要手动的`retain/release/autorelease`. 编译器会自动插入对应的代码，再结合Objective C的runtime，实现自动引用计数。

比如如下ARC代码：

```
NSObject * obj;
{
	obj = [[NSObject alloc] init]; //引用计数为1
}
NSLog(@"%@",obj);
```

等同于如下MRC代码

```
NSObject * obj;
{
	obj = [[NSObject alloc] init]; //引用计数为1
	[obj relrease]
}
NSLog(@"%@",obj);
```

在Objective C中，有三种类型是ARC适用的：

- block
- objective 对象，id, Class, NSError*等
- 由__attribute__((NSObject))标记的类型。

像`double *`,`CFStringRef`等不是ARC适用的，仍然需要手动管理内存。

> Tips： 以CF开头的（Core Foundation）的对象往往需要手动管理内存。

----

## 属性所有权

最后，我们在看看ARC中常见的所有权关键字，

- `assign`对应关键字`__unsafe_unretained`, 顾名思义，就是指向的对象被释放的时候，仍然指向之前的地址，容易引起野指针。
- `copy`对应关键字`__strong`,只不过在赋值的时候，调用`copy`方法。
- `retain `对应`__strong `
- `strong `对应`__strong`
- `unsafe_unretained `对应`__unsafe_unretained `
- `weak `对应`__weak `。

其中，`__weak`和`__strong`是本文要讲解的核心内容。

-----
## ARC的内部实现

ARC背后的引用计数主要依赖于这三个方法：

- `retain` 增加引用计数
- `release` 降低引用计数，引用计数为0的时候，释放对象。
- `autorelease` 在当前的auto release pool结束后，降低引用计数。

在Cocoa Touch中，`NSObject`协议中定义了这三个方法，由于Cocoa Touch中，绝大部分类都继承自`NSObject`（`NSObject`类本身实现了`NSObject`协议），所以可以“免费”获得`NSObject`提供的运行时和ARC管理方法，这就是为什么适用OC开发iOS的时候，你的类要继承自`NSObject`。

既然ARC是引用计数，那么对应一个对象，内存中必然会有一个地方来存储这个对象的引用计数。iOS的Runtime是开源的，在[这里](https://opensource.apple.com/tarballs/objc4/objc4-706.tar.gz)可以下载到全部的代码，我们通过源代码一探究竟。

我们从**retain**入手,

```
- (id)retain {
    return ((id)self)->rootRetain();
}
inline id objc_object::rootRetain()
{
    if (isTaggedPointer()) return (id)this;
    return sidetable_retain();
}
```
所以说，本质上retain就是调用`sidetable_retain`，再看看`sitetable_retain`的实现：

```
id objc_object::sidetable_retain()
{
    //获取table
    SideTable& table = SideTables()[this];
    //加锁
    table.lock();
    //获取引用计数
    size_t& refcntStorage = table.refcnts[this];
    if (! (refcntStorage & SIDE_TABLE_RC_PINNED)) {
    	 //增加引用计数
        refcntStorage += SIDE_TABLE_RC_ONE;
    }
    //解锁
    table.unlock();
    return (id)this;
}

```
到这里，retain如何实现就很清楚了，通过`SideTable`这个数据结构来存储引用计数。我们看看这个数据结构的实现：

```
typedef objc::DenseMap<DisguisedPtr<objc_object>,size_t,true> RefcountMap;
struct SideTable {
    spinlock_t slock;
    RefcountMap refcnts;
    weak_table_t weak_table;
	 //省略其他实现...
};
```
可以看到，这个数据结构就是存储了一个自旋锁，一个引用计数map。这个引用计数的map以对象的地址作为key，引用计数作为value。到这里，引用计数的底层实现我们就很清楚了。

> 存在全局的map，这个map以地址作为key，引用计数的值作为value。

再来看看**release**的实现：

```
    SideTable& table = SideTables()[this];
    bool do_dealloc = false;
    table.lock();
    //找到对应地址的
    RefcountMap::iterator it = table.refcnts.find(this);
    if (it == table.refcnts.end()) { //找不到的话，执行dellloc
        do_dealloc = true;
        table.refcnts[this] = SIDE_TABLE_DEALLOCATING;
    } else if (it->second < SIDE_TABLE_DEALLOCATING) {//引用计数小于阈值，dealloc
        do_dealloc = true;
        it->second |= SIDE_TABLE_DEALLOCATING;
    } else if (! (it->second & SIDE_TABLE_RC_PINNED)) {
    //引用计数减去1
        it->second -= SIDE_TABLE_RC_ONE;
    }
    table.unlock();
    if (do_dealloc  &&  performDealloc) {
        //执行dealloc
        ((void(*)(objc_object *, SEL))objc_msgSend)(this, SEL_dealloc);
    }
    return do_dealloc;
```

> release的到这里也比较清楚了：查找map，对引用计数减1，如果引用计数小于阈值，则调用`SEL_dealloc`


----
## Autorelease pool
上文提到了，autorelease方法的作用是把对象放到autorelease pool中，到pool drain的时候，会释放池中的对象。举个例子

先新建一个自定义类CustomObject

- ARC的规则下，`alloc/init/new/copy/mutableCopy`开头的方法返回的对象**不是**autorelease对象

```
@interface CustomObject: NSObject
@end

@implementation CustomObject

//这个方法返回autorelease对象
+ (instancetype)object{
    return [[CustomObject alloc] init];
}

- (void)dealloc{
    NSLog(@"CustomObject Dealloc");
}

@end

```

先确定[CustomObject object]返回的对象是autorelease的：

```
   __weak CustomObject * weakRef;
    {
        CustomObject * temp = [CustomObject object];
        weakRef = temp;
    }
    NSLog(@"%@",weakRef);
```

看到的log是

```
2019-06-22 23:59:33.328198+0800 Demo[82431:5549926] <CustomObject: 0x6000005a3e50>
2019-06-22 23:59:33.330740+0800 Demo[82431:5549926] CustomObject Dealloc
```

这是因为`[CustomObject object]`返回的是一个autorelease对象，在作用域(大括号)结束后，并不会立刻被释放，所以在NSLog处还能看到对象的地址。

感兴趣的同学可以把`[CustomObject object]`替换成`[[CustomObject alloc] init]`，会发现作用域结束后立刻释放。

假如我们用autorelease包裹后：

```
    __weak CustomObject * weakRef;
    @autoreleasepool {
        CustomObject * temp = [CustomObject object];
        weakRef = temp;
    }
    NSLog(@"%@",weakRef);
```

会看到dealloc方法先调用，：

```
2019-06-23 00:02:30.946948+0800 Demo[82465:5551793] CustomObject Dealloc
2019-06-23 00:02:30.947106+0800 Demo[82465:5551793] (null)
```


> 可以看到，放到自动释放池的对象是在超出自动释放池作用域后立即释放的。事实上在iOS 程序启动之后，主线程会启动一个Runloop，这个Runloop在每一次循环是被自动释放池包裹的，在合适的时候对池子进行清空。


对于Cocoa框架来说，提供了两种方式来把对象显式的放入AutoReleasePool.

- NSAutoreleasePool(只能在MRC下使用)
- `@autoreleasepool {}代码块`(ARC和MRC下均可以使用)

那么AutoRelease pool又是如何实现的呢？

我们先从`autorelease`方法源码入手

```
//autorelease方法
- (id)autorelease {
    return ((id)self)->rootAutorelease();
}

//rootAutorelease 方法
inline id objc_object::rootAutorelease()
{
    if (isTaggedPointer()) return (id)this;
    
    //检查是否可以优化
    if (prepareOptimizedReturn(ReturnAtPlus1)) return (id)this;
    //放到auto release pool中。
    return rootAutorelease2();
}

// rootAutorelease2
id objc_object::rootAutorelease2()
{
    assert(!isTaggedPointer());
    return AutoreleasePoolPage::autorelease((id)this);
}

```
可以看到，把一个对象放到auto release pool中，是调用了`AutoreleasePoolPage::autorelease`这个方法。

我们继续查看对应的实现：

```
public: static inline id autorelease(id obj)
    {
        assert(obj);
        assert(!obj->isTaggedPointer());
        id *dest __unused = autoreleaseFast(obj);
        assert(!dest  ||  dest == EMPTY_POOL_PLACEHOLDER  ||  *dest == obj);
        return obj;
    }

static inline id *autoreleaseFast(id obj)
    {
        AutoreleasePoolPage *page = hotPage();
        if (page && !page->full()) {
            return page->add(obj);
        } else if (page) {
            return autoreleaseFullPage(obj, page);
        } else {
            return autoreleaseNoPage(obj);
        }
    }
id *add(id obj)
    {
        assert(!full());
        unprotect();
        id *ret = next;  // faster than `return next-1` because of aliasing
        *next++ = obj;
        protect();
        return ret;
    }
```
到这里，`autorelease`方法的实现就比较清楚了，

> autorelease方法会把对象存储到`AutoreleasePoolPage`的链表里。等到auto release pool被释放的时候，把链表内存储的对象删除。所以，AutoreleasePoolPage就是自动释放池的内部实现。

----
## `__weak与__strong`

用过block的同学一定写过类似的代码：

```
__weak typeSelf(self) weakSelf = self;

[object fetchSomeFromRemote:^{
	__strong typeSelf(weakSelf) strongSelf = weakSelf;
	//从这里开始用strongSelf
}];
```

那么，为什么要这么用呢？原因是：

- block会捕获外部变量，用`weakSelf`保证self不会被block被捕获，防止引起循环引用或者不必要的额外生命周期。
- 用strongSelf则保证在block的执行过程中，对象不会被释放掉。

首先`__strong`和`__weak`都是关键字，是给编译器理解的。为了理解其原理，我们需要查看它们编译后的代码，使用XCode，我们可以容易的获得一个文件的汇编代码。

比如，对于`Test.m`文件，当源代码如下时：

```
 #import "Test.h"

 @implementation Test

- (void)testFunction{
    {
        __strong NSObject * temp = [[NSObject alloc] init];
    }
}

@end

```

转换后的汇编代码如下：

```
Ltmp3:
	.loc	2 15 37 prologue_end    ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:37
	ldr		x9, [x9]
	ldr		x1, [x8]
	mov	 x0, x9
	bl	_objc_msgSend
	adrp	x8, L_OBJC_SELECTOR_REFERENCES_.2@PAGE
	add	x8, x8, L_OBJC_SELECTOR_REFERENCES_.2@PAGEOFF
	.loc	2 15 36 is_stmt 0       ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:36
	ldr		x1, [x8]
	.loc	2 15 36 discriminator 1 ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:36
	bl	_objc_msgSend
	mov	x8, #0
	add	x9, sp, #8              ; =8
	.loc	2 15 29                 ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:29
	str	x0, [sp, #8]
Ltmp4:
	.loc	2 16 5 is_stmt 1        ; /Users/hl/Desktop/OCTest/OCTest/Test.m:16:5
	mov	 x0, x9
	mov	 x1, x8
	bl	_objc_storeStrong
	.loc	2 17 1                  ; /Users/hl/Desktop/OCTest/OCTest/Test.m:17:1
	ldp	x29, x30, [sp, #32]     ; 8-byte Folded Reload
	add	sp, sp, #48             ; =48
	ret
Ltmp5:
```

即使你不懂汇编，也能很轻易的获取到调用顺序如下

```
_objc_msgSend // alloc
_objc_msgSend // init
_objc_storeStrong // 强引用
```

在结合Runtime的源码，我们看看最关键的objc_storeStrong的实现

```
void objc_storeStrong(id *location, id obj)
{
    id prev = *location;
    if (obj == prev) {
        return;
    }
    objc_retain(obj);
    *location = obj;
    objc_release(prev);
}

id objc_retain(id obj) { return [obj retain]; }
void objc_release(id obj) { [obj release]; }
```

我们再来看看`__weak`. 将Test.m修改成为如下代码，同样我们分析其汇编实现

```
	.loc	2 15 35 prologue_end    ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:35
	ldr		x9, [x9]
	ldr		x1, [x8]
	mov	 x0, x9
	bl	_objc_msgSend
	adrp	x8, L_OBJC_SELECTOR_REFERENCES_.2@PAGE
	add	x8, x8, L_OBJC_SELECTOR_REFERENCES_.2@PAGEOFF
	.loc	2 15 34 is_stmt 0       ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:34
	ldr		x1, [x8]
	.loc	2 15 34 discriminator 1 ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:34
	bl	_objc_msgSend
	add	x8, sp, #24             ; =24
	.loc	2 15 27                 ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:27
	mov	 x1, x0
	.loc	2 15 27 discriminator 2 ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:27
	str	x0, [sp, #16]           ; 8-byte Folded Spill
	mov	 x0, x8
	bl	_objc_initWeak
	.loc	2 15 27                 ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:27
	ldr	x1, [sp, #16]           ; 8-byte Folded Reload
	.loc	2 15 27 discriminator 3 ; /Users/hl/Desktop/OCTest/OCTest/Test.m:15:27
	str	x0, [sp, #8]            ; 8-byte Folded Spill
	mov	 x0, x1
	bl	_objc_release
	add	x8, sp, #24  
	Ltmp4:
	.loc	2 16 5 is_stmt 1        ; /Users/hl/Desktop/OCTest/OCTest/Test.m:16:5
	mov	 x0, x8
	bl	_objc_destroyWeak
	.loc	2 17 1                  ; /Users/hl/Desktop/OCTest/OCTest/Test.m:17:1
	ldp	x29, x30, [sp, #48]     ; 8-byte Folded Reload
	add	sp, sp, #64             ; =64
	ret
```

可以看到，`__weak`本身实现的核心就是以下两个方法

- `_objc_initWeak`
- `_objc_destroyWeak`

我们通过Runtime的源码分析这两个方法的实现：

```
id objc_initWeak(id *location, id newObj)
{
    //省略....
    return storeWeak<false/*old*/, true/*new*/, true/*crash*/>
        (location, (objc_object*)newObj);
}
void objc_destroyWeak(id *location)
{
    (void)storeWeak<true/*old*/, false/*new*/, false/*crash*/>
        (location, nil);
}
```
所以，本质上都是调用了`storeWeak`函数，这个函数内容较多，主要做了以下事情

- 获取存储weak对象的map，这个map的key是对象的地址，value是`weak`引用的地址。
- 当对象被释放的时候，根据对象的地址可以找到对应的`weak`引用的地址，将其置为nil即可。

这就是在`weak`背后的黑魔法。

----
## 总结

这篇文章属于想到哪里写到哪里的类型，后边有时间了在继续总结ARC的东西吧。
