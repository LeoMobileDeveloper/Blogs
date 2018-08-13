## AppDelegate

在iOS开发中，AppDelegate指的是[UIApplicationDelegate](https://docs.developer.apple.com/documentation/uikit/uiapplicationdelegate)，用来处理App层面的事件，包括生命周期变化，OpenURL，处理HandOff和Intent等。

每个iOS都有一个入口函数main，其中的一个参数就是AppDelegate：

```
int main(int argc, char *argv[])
{
    @autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([QTAppDelegate class]));
    }
}
```


## 痛点

由于AppDelegate是一个**单例**，所以通常写代码的方式：

1. import对应的业务类进来
2. 实现对应Delegate的方法，然后调用业务类

```
#import "TokenService.h"
....
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
    [TokenService update:deviceToken];
}

```

乍一看这也没什么问题，但是随着时间的推移：

- `didFinishLaunchingWithOptions`堆积了越来越多的代码，有些时候这些代码还有先后顺序，比如Crash收集代码就要最早初始化。
- 由于不同的模块负责处理不同的功能，比如路由模块处理OpenURL，Siri模块处理Intent....，结果就是这个文件import的类和模块越来越多，文件越来越臃肿。


日积月累：**这个文件耦合越来越严重，越来越难以迭代和维护**。

### 组件化

组件化是一个很热的概念，但并不是每个App都适合组件化，适不适合组件化要写的内容太多，以后有时间了再聊聊这方面。我们先来聊聊组件化需要翻过的几座大山：

**App层面的事件如何通知到各个组件**。这些事件包括应用内部的全局事件和系统层面的AppDelegate事件。

**组件之间如何相互调用**。通常有几种解决方案：

1. 每个组件暴露抽象的协议或者抽象类出来，由一个中介者去负责创建和协调。 
2. 通过路由URL来相互调用。
3. 暴露特定的类和方法出来，通过Target/Action的方式来调用。

**组件之间的页面跳转**。解决方案基本都是路由，通过URL来注册和跳转，路由还可以统一处理内跳和外跳。

可见，**如果你想要组件化，那么对AppDelegate解耦是必须解决的问题**。

## QTEventBus

AppDelegate解耦的核心：**如何让事件通知到每个模块？**。

如果仅仅通知到模块，模块内部还要自己处理分发，如果支持**事件可以直接通知到相关的类**就更好了。

这种一对多的消息通知关系，用总线设计模式可以完美解决，所以本文的解决方案是建立在[QTEventBus](https://github.com/LeoMobileDeveloper/QTEventBus)上的。

关于如何实现一个总线，参考我的上一篇文章：《[实现一个优雅的iOS消息总线](https://blog.csdn.net/Hello_Hwc/article/details/81023561)》

### 使用教程

安装：

```
pod QTEventBus/AppModule
```

**QTAppDelegate替代默认的AppDelegate，修改main.m:**

```
return UIApplicationMain(argc, argv, nil, NSStringFromClass([QTAppDelegate class]));
```

> 也可以继承QTAppDelegate实现一些自定义，但是记得要在方法里调用super。

**宏定义`QTAppModuleRegister`注册模块**

注意对应的类要实现协议`QTAppModule`

```
// 两个参数分别是类名和优先级
QTAppModuleRegister(PayService, QTAppEventPriorityDefault)
```

**响应事件**

```
@interface PayService()<QTAppModule>
@end
@implementation PayService

/// 每一次事件来的时候，EventBus调用这个方法来生成实例
+ (id<QTAppModule>)moduleInstance{
    return [[PayService alloc] init];
}

/// App启动
- (void)appDidFinishLuanch:(QTAppDidLaunchEvent *)event{
    NSLog(@"PayService: appDidFinishLuanch");
}

@end

```

也可以在具体的类中，直接监听：

```
// DemoViewController
[QTSub(self, QTAppLifeCircleEvent) next:^(QTAppLifeCircleEvent *event) {
     NSLog(@"%@",event.type);
}];
```


## 原理

### QTEventBus

QTEventBus是总线模式在Objective C中的实现，对AppDelegate的解耦是在它的基础上的扩展。

### 协议封装

对UIApplication进行协议封装，抽象出协议[QTAppModule](https://github.com/LeoMobileDeveloper/QTEventBus/blob/master/Sources/UIApplication/QTAppModule.h)。

```
@protocol QTAppModule <NSObject>
+ (id<QTAppModule>)moduleInstance;

@optional
// 对应application:didFinishLaunchingWithOptions:
- (void)appDidFinishLuanch:(QTAppDidLaunchEvent *)event;
- (void)appLifeCircleChanged:(QTAppLifeCircleEvent *)event;
...
@end
```

为什么要这么封装呢？原因有几点：

**[QTEventBus](https://github.com/LeoMobileDeveloper/QTEventBus)是基于类来注册的**。把方法参数封装成一个类，就可以通过以下的方式注册监听：

```
// 监听生App命周期变化
[QTSub(self, QTAppLifeCircleEvent) next:^(QTAppLifeCircleEvent *event) {
     NSLog(@"%@",event.type);
}];
```

**合并多个方法。** 举个例子，在注册远程推送token的时候，AppDelegate有两个方法

```
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
```

合并后

```
@interface QTAppDidRegisterRemoteNotificationEvent: QTAppEvent<QTEvent>
@property (copy  , nonatomic) NSData * deviceToken;
@property (strong, nonatomic) NSError * error;
@end

- (void)appDidRegisterRemoteNotification:(QTAppDidRegisterRemoteNotificationEvent *)event;

```

**隐藏UIApplicationDelegate细节。**对上隐藏UIApplication细节，便于做App内部扩展。

```
// 所有模块都已经初始化
- (void)appAllModuleInit:(QTAppAllModuleInitEvent *)event;
```

### 注册

AppDelegate有个特殊的地方，就是在App启动的时候初始化，那么如何告诉总线有哪些类注册了呢？

典型的解决方案有以下几种：

- plist静态注册
- load方法动态注册
- 基于`__attribute__`的clang语法，把注册信息写到mach-o文件里。

最后选择了第三种方式，主要考虑如下：

- load方法拖慢App启动速度，所以很多团队是禁用load方法的。
- plist静态注册不利于多团队协作

考虑事件的响应是有先后顺序的，所以在注册类的同时还要注册优先级，所以定义了一个结构体

```
struct QTAppModuleInfo{
    char * className;
    long priority;
};
```

然后用宏定义注册

```
#define QTAppModule(_class_,_priority_)\
__attribute__((used)) static struct QTAppModuleInfo QTAppModule##_class_ \
__attribute__ ((used, section ("__DATA,__QTEventBus"))) =\
{\
    .className = #_class_,\
    .priority = _priority_,\
};
```

`__attribute__ ((used, section ("__DATA,__QTEventBus")))`的作用是告诉编译器这个结构体会用到，麻烦写到`__DATA`段中的`__QTEventBus` section里。

然后，在加载二进制文件的时候，读取二进制文件里的注册信息

```
const struct mach_header_* header  = (void*)mhp;
unsigned long size = 0;
uintptr_t *data = (uintptr_t *)getsectiondata(header, "__DATA", "__QTEventBus",&size);
if (data && size > 0) {
    unsigned long count = size / sizeof(struct QTAppModuleInfo);
    struct QTAppModuleInfo *items = (struct QTAppModuleInfo*)data;
    for (int index = 0; index < count; index ++) {
        NSString * classStr = [NSString stringWithUTF8String:items[index].className];
        NSInteger priority = items[index].priority;
		 ...
    }
}
    
```

### AppDelegate封装

由于AppDelegate是一个单例，这里选择实现绝大部分核心方法，分别通知AppModule和EventBus。举例：

```
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    QTAppDidRegisterRemoteNotificationEvent * event = [[QTAppDidRegisterRemoteNotificationEvent alloc] init];
    event.deviceToken = deviceToken;
	    [[QTAppModuleManager shared] enumerateModulesUsingBlock:^(__unsafe_unretained Class<QTAppModule> module) {
        id<QTAppModule> instance = [module moduleInstance];
        if ([instance respondsToSelector:sel]) {
            [instance performSelector:sel withObject:event];
        }
    }];
    [[QTEventBus shared] dispatch:event];
}

```

由于有些方法只在特定版本生效，所以时间的封装要进行版本适配，比如3D touch是从iOS 9开始才有的

```
// 类定义
API_AVAILABLE(ios(9.0))
@interface QTAppPerformActionForShortcutItemEvent: QTAppEvent<QTEvent>

@end

// 协议中的方法
- (void)appPerformActionForShortcutItem:(QTAppPerformActionForShortcutItemEvent *)event API_AVAILABLE(ios(9.0));

```

还有一些特定方法是无法封装的，这时候通过让client继承的方式来自己扩展：

```
- (BOOL)application:(UIApplication *)application shouldAllowExtensionPointIdentifier:(UIApplicationExtensionPointIdentifier)extensionPointIdentifier;
```

### 宏定义

Objective C/C/C++开发中，宏定义是一个利器，可以缩减代码量和对外提供一些细节。比如宏`QTAppModule`用来对外提供注册的接口：

```
#define QTAppModule(_class_,_priority_)\
__attribute__((used)) static struct QTAppModuleInfo QTAppModule##_class_ \
__attribute__ ((used, section ("__DATA,__QTEventBus"))) =\
{\
    .className = #_class_,\
    .priority = _priority_,\
};

```

宏`__LIFE_CIRCLE_IMPLEMENT`用来缩减代码量

```
#define __LIFE_CIRCLE_IMPLEMENT(_name_) QTAppLifeCircleEvent * event = [[QTAppLifeCircleEvent alloc] init];\
    event.type = QTAppLifeCircleEvent._name_;\
    [self _sendEvent:event sel:@selector(appLifeCircleChanged:)];
    
- (void)applicationDidBecomeActive:(UIApplication *)application{
    __LIFE_CIRCLE_IMPLEMENT(didBecomeActive);
}

- (void)applicationWillResignActive:(UIApplication *)application{
    __LIFE_CIRCLE_IMPLEMENT(willResignActive);
}
```

## 总结

本文在QTEventBus的基础上，增加了UIApplication的解耦支持，不管是组件化还是非组件化的项目均可以接入。

代码链接：[QTEventBus](https://github.com/LeoMobileDeveloper/QTEventBus)。
