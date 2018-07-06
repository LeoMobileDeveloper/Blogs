## Crash Log

Crash Log的主要来源有两种：

1. Apple提供的，可以从用户设备中直接拷贝，或者从iTunes Connect（XCode）下载
2. 三方或者自研Framework统计，三方服务包括Fabric，Bugly等。

这篇文章讲到的Crash Log是Apple提供的。

## 获取

### 设备获取

USB连接设备，接着在XCode菜单栏依次选择：Window -> Devices And Simulators，接着选择View Device Logs

![Devices And Simulators](https://img-blog.csdn.net/20180706205307664?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

然后，等待XCode拷贝Crash Log，在右上角可以通过App的名字搜索，比如这里我搜索的是微信，可以右键导出Crash Log到本地来分析：

![Export](https://img-blog.csdn.net/20180706205318460?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

> 在查看Crash Log的时候，XCode会自动尝试Symboliate，至于什么是Symboliate会在本文后面讲解。

### XCode下载

在XCode菜单栏选择Window -> Organizer，切换到Crashes的Tab，选择版本后就可以自动下载对应版本的crash log：

![XCode](https://img-blog.csdn.net/20180706205328116?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

选择Open In Project，然后选择对应的项目，然后就是我们日常开发中熟悉的界面了：

![Project](https://img-blog.csdn.net/20180706205337161?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

## 分析

用于Demo的是一个微信的Crash Log：

- WeChat-2018-6-11-21-54.crash
- 设备信息：iPhone 7，iOS 12 beta1
- 版本信息：微信 6.6.7.32 (6.6.7)

### Header 

Crash Log的最开始是头部，这里包含了日志的元数据：

```
//crash log的唯一标识符
Incident Identifier: 4F85AD99-CF91-4240-BBC7-AEAFA51ED7FC 
//处理过的设备标识符，同一台设备的crash log是一样的
CrashReporter Key:   c84934ca1eae8ba4209ce4725a52492c77d05add
Hardware Model:      iPhone9,1
Process:             WeChat [31763]
Path:                /private/var/containers/Bundle/Application/11F1F5DE-2F68-4331-A107-FAADCED42A1F/WeChat.app/WeChat
Identifier:          com.tencent.xin
Version:             6.6.7.32 (6.6.7)
Code Type:           ARM-64 (Native)
Role:                Non UI
Parent Process:      launchd [1]
Coalition:           com.tencent.xin [12577]


Date/Time:           2018-06-11 21:54:07.2673 +0800
Launch Time:         2018-06-11 21:53:55.2690 +0800
OS Version:          iPhone OS 11.3 (15E216)
Baseband Version:    3.66.00
Report Version:      104
```

## Reason

接着是崩溃原因模块：

```
Exception Type:  EXC_CRASH (SIGKILL)
Exception Codes: 0x0000000000000000, 0x0000000000000000
Exception Note:  EXC_CORPSE_NOTIFY
Termination Reason: Namespace SPRINGBOARD, Code 0x8badf00d
Termination Description: SPRINGBOARD, scene-create watchdog transgression: com.tencent.xin exhausted CPU time allowance of 2.38 seconds |  | ProcessVisibility: Background | ProcessState: Running | WatchdogEvent: scene-create | WatchdogVisibility: Background | WatchdogCPUStatistics: ( | "Elapsed total CPU time (seconds): 23.520 (user 23.520, system 0.000), 100% CPU", | "Elapsed application CPU time (seconds): 5.151, 22% CPU" | )
Triggered by Thread:  0
```

**Exception Type**表示异常的类型：

```
Exception Type:  EXC_CRASH (SIGKILL)
```

在`<mach/exception_types.h>`我们可以找到这个`EXC_CRASH`的具体含义：**非正常的进程退出**。

```
#define EXC_CRASH		10	/* Abnormal process exit */
```

那么SIGKILL又代表什么意思呢？在头文件`<sys/signal.h>`中可以找到:

```
#define	SIGKILL	9	/* kill (cannot be caught or ignored) */
```


表示这个这是一个无法捕获也不能忽略的异常，所以系统决定杀掉这个进程。

**Exception Note**中的代码同样在`<mach/exception_types.h>`可以找到

```
#define EXC_CORPSE_NOTIFY	13	/* Abnormal process exited to corpse state */
```

**Termination Reason**提供的信息就更详细一些了

```
Termination Reason: Namespace SPRINGBOARD, Code 0x8badf00d
```

**0x8badf00d**是一个很常见的Code，表示App启动时间过长或者主线程卡住时间过长，导致系统的WatchDog杀掉了当前App。


### Thread

接下来就是各个线程的调用栈，崩溃的线程会被标记为crashed，比如主线程的调用栈如下：

```
Thread 0 name:  Dispatch queue: com.apple.main-thread
Thread 0 Crashed:
0   libobjc.A.dylib               	0x0000000184475da8 0x184464000 + 73128
1   libobjc.A.dylib               	0x0000000184475aa8 0x184464000 + 
...
7   WeChat                        	0x00000001031f64d4 0x100490000 + 47604948
8   WeChat                        	0x0000000102e74a5c 0x100490000 + 43928156
9   WeChat                        	0x0000000102e71a14 0x100490000 + 43915796
10  Foundation                    	0x0000000185c52d1c 0x185be5000 + 449820
...
16  WeChat                        	0x00000001029d0924 0x100490000 + 39061796
...
37  WeChat                        	0x00000001005d7e18 0x100490000 + 1343000
38  libdyld.dylib                 	0x0000000184c09fc0 0x184c09000 + 4032
```

可以看到这里的描述信息都是地址`0x0000000102e74a5c 0x100490000 + 43928156`，我们只有把它们转换成代码中的类/方法等信息才能够找到问题，这就是接下来要讲的。

### 寄存器

一堆的线程调用栈后，还可以看到Crash的时候寄存器状态：

```
Thread 0 crashed with ARM Thread State (64-bit):
    x0: 0x00000001b76acea0   x1: 0x000000018fbd3fbd   x2: 0x000000010cb17260   x3: 0x0000000000000001
    x4: 0x0000000000000000   x5: 0x0000000000000001   x6: 0x0000000000000020   x7: 0x0000000000000004
    x8: 0x0000000109a34380   x9: 0x0000000109a34310  x10: 0x0000000109a34311  x11: 0x0000000109a34318
   x12: 0x000000010c8e3cb0  x13: 0x0000000000000000  x14: 0x0000000000000000  x15: 0x000000018fbd49dd
   x16: 0x00000001b76acea0  x17: 0x0000000000000000  x18: 0x0000000000000000  x19: 0x000000018fbd3fbd
   x20: 0x0000000109a34318  x21: 0x0000000109a34388  x22: 0x00000001b766cfd0  x23: 0x0000000000000000
   x24: 0x00000001b76acea0  x25: 0x0000000000000000  x26: 0x00000001b766e000  x27: 0x00000000ffed8282
   x28: 0x0000000000000000   fp: 0x000000016f969e90   lr: 0x0000000184475aa8
    sp: 0x000000016f969e70   pc: 0x0000000184475da8 cpsr: 0x80000000
```

### 可执行文件

Crash Log的最后是可执行文件，在这里你可以看到当时加载的动态库。

```
Binary Images:
0x100490000 - 0x103cabfff WeChat arm64  <6499420763bf3621abf3f6218adc6354> /var/containers/Bundle/Application/11F1F5DE-2F68-4331-A107-FAADCED42A1F/WeChat.app/WeChat
0x104ce8000 - 0x104e1ffff MMCommon arm64  <85b8839214673db29e3b6a4eeaaacba7> /var/containers/Bundle/Application/11F1F5DE-2F68-4331-A107-FAADCED42A1F/WeChat.app/Frameworks/MMCommon.framework/MMCommon
0x104e68000 - 0x104ea3fff dyld arm64  <06dc98224ae03573bf72c78810c81a78> /usr/lib/dyld
0x104efc000 - 0x1051bbfff TXLiteAVSDK_Smart_No_VOD arm64  <94b2ab6b3c863923b321327155770286> /var/containers/Bundle/Application/11F1F5DE-2F68-4331-A107-FAADCED42A1F/WeChat.app/Frameworks/TXLiteAVSDK_Smart_No_VOD.framework/TXLiteAVSDK_Smart_No_VOD
0x1055e4000 - 0x10572ffff WCDB arm64  <c1b1509046923a93b29755fe25526e00> /var/containers/Bundle/Application/11F1F5DE-2F68-4331-A107-FAADCED42A1F/WeChat.app/Frameworks/WCDB.framework/WCDB
0x10587c000 - 0x105c7bfff MultiMedia arm64  <b456f7d1d8ba3eadb83d84d9e9eed783> /var/containers/Bundle/Application/11F1F5DE-2F68-4331-A107-FAADCED42A1F/WeChat.app/Frameworks/MultiMedia.framework/MultiMedia
0x105f8c000 - 0x106147fff QMapKit arm64  <682efa309eed33ce894bd1383988e38a> /var/containers/Bundle/Application/11F1F5DE-2F68-4331-A107-FAADCED42A1F/WeChat.app/Frameworks/QMapKit.framework/QMapKit
...
```


## Symbolication

刚刚我们拿到的crash log的函数栈：

```
...
7   WeChat                        	0x00000001031f64d4 0x100490000 + 47604948
8   WeChat                        	0x0000000102e74a5c 0x100490000 + 43928156
9   WeChat                        	0x0000000102e71a14 0x100490000 + 43915796
```

可以看到，**这些地址其实并没有给我们提供什么有用的信息，我们需要把它们转换为类/函数才能找到问题，这个过程就叫做Symbolication（符号化）**。

符号化你需要一样东西：Debug Symbol文件，也就是我们常说的dsym文件。

机器指令通常会对应你源文件中的一行代码，在编译的时候，编译器会生成这个映射关系的信息。根据build setting中的`DEBUG_INFORMATION_FORMAT`设置，这些信息有可能会存在二进制文件或者dsym文件里。

> 注意，crash log中的二进制文件会有一个唯一的uuid，dsym文件也有一个唯一的uuid，这两个文件的uuid对应到一起才能够进行符号化。


**如果你在上传到App Store的时候，选择了上传dsym文件，那么从XCode中看到的崩溃日志是自动符号化的**。

### BitCode

当项目开启BitCode的时候，编译器并不会生成机器码，而会生成一种中间代码叫做bitcode。当上传到App Store的时候，这个bitCode才会编译成机器吗。

![这里写图片描述](https://img-blog.csdn.net/2018070620545357?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

那么，问题就来了，最后的编译过程是你不可控的，那么如何获得dsym文件呢？

答案是Apple会生成这个dsym文件，你可以从XCode或者iTunesConnect下载。

从XCode中下载：Window -> Orginizer -> Archives -> 选择构建版本 -> Download dSYMs

![这里写图片描述](https://img-blog.csdn.net/20180706205417150?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

从iTunes Connect下载

![这里写图片描述](https://img-blog.csdn.net/20180706205402637?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)



### 手动符号化

#### uuid

在crash log中，可以看到image（可执行文件）对应的uuid，

![这里写图片描述](https://img-blog.csdn.net/20180706205434820?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L0hlbGxvX0h3Yw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

也可以用`grep`快速查找uuid

```
$ grep --after-context=1000 "Binary Images:" <Path to Crash Report> | grep <Binary Name>
```

接着，我们查看dsym的uuid：

```
xcrun dwarfdump --uuid <Path to dSYM file>
```

> 只有两个uuid对应起来，才能符号化成功。

#### XCode 

XCode会自动尝试符号化Crash Log（需要文件以.crash结尾）

1. USB连接设备
2. 打开XCode，菜单栏点Device -> Window
3. 选择一个设备
4. 点View Device Logs
5. 然后把你的crash log，拖动到左侧部分
6. XCode会自动符号化

XCode能自动符号化需要能够找到如下文件：

- 崩溃的可执行文件和dsym文件
- 所有用到的framework的dsym文件
- OS版本相关的符号（这个在USB连接的时候，XCode会自动把这些符号拷贝到设备中）

#### atos

atos是一个命令行工具，可以用来符号化单个地址，命令格式如下：

```
atos -arch <Binary Architecture> -o <Path to dSYM file>/Contents/Resources/DWARF/<binary image name> -l <load address> <address to symbolicate>

```

举例:

```
$ atos -arch arm64 -o TheElements.app.dSYM/Contents/Resources/DWARF/TheElements -l 0x1000e4000 0x00000001000effdc
-[AtomicElementViewController myTransitionDidStop:finished:context:]
```

#### symbolicatecrash

symbolicatecrash是XCode内置的符号化整个Crash Log的工具

```
cd /Applications/Xcode.app/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/Resources
./symbolicatecrash ~/Desktop/1.crash ~/Desktop/1.dSYM > ~/Desktop/result.crash
```

如果报错

```
Error: "DEVELOPER_DIR" is not defined at ./symbolicatecrash line 60
```

可以引入环境变量来解决这个问题

```
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

```

## lldb

假设有一个这样的crashlog栈

```
Exception Type: EXC_BAD_ACCESS (SIGSEGV)
...
0   libobjc.A.dylib 0x00007fff6011713c objc_release + 28
1   RideSharingApp 0x00000001000022ea @objc LoginViewController.__ivar_destroyer + 42
```

通过调用栈，我们知道是在LoginViewController的ivar被释放的时候导致crash，而LoginViewController有很多个属性，释放哪一个导致crash的呢？

我们可以通过lldb，查看汇编代码来寻找一些蛛丝马迹：

首先，打开终端，导入crashlog工具

```
LeodeMacbook:Desktop Leo$ lldb
(lldb) command script import lldb.macosx.crashlog
"crashlog" and "save_crashlog" command installed, use the "--help" option for detailed help
"malloc_info", "ptr_refs", "cstr_refs", "find_variable", and "objc_refs" commands have been installed, use the "--help" options on these commands for detailed help.
```

接着，我们就可以用这个脚本提供的一系列命令了

载入Crash log

```
crashlog /Users/…/RideSharingApp-2018-05-24-1.crash
...
Thread[0] EXC_BAD_ACCESS (SIGSEGV) (0x000007fdd5e70700)
[ 0] 0x00007fff6011713c libobjc.A.dylib objc_release + 28
[ 1] 0x00000001000022ea RideSharingApp @objc LoginViewController.__ivar_destroyer + 42
[ 2] 0x00007fff6011ed66 libobjc.A.dylib object_cxxDestructFromClass + 127
[ 3] 0x00007fff60117276 libobjc.A.dylib objc_destructInstance + 76
[ 4] 0x00007fff60117218 libobjc.A.dylib object_dispose + 22
[ 5] 0x0000000100002493 RideSharingApp Initialize (main.swift:33)
[ 6] 0x0000000100001e75 RideSharingApp main (main.swift:37)
[ 7] 0x00007fff610a2ee1 libdyld.dylib start + 1
```

然后，查看汇编代码：

```
(lldb) disassemble -a 0x00000001000022ea
RideSharingApp`@objc LoginViewController.__ivar_destroyer:
0x1000022c0 <+0>: pushq %rbp
0x1000022c1 <+1>: movq %rsp, %rbp
0x1000022c4 <+4>: pushq %rbp
0x1000022c4 <+4>: pushq %rbx
0x1000022c5 <+5>: pushq %rax
0x1000022c6 <+6>: movq %rdi, %rbx 
0x1000022c9 <+9>: movq 0x551e40(%rip), %rax      ; direct field offset for LoginViewController.userName
0x1000022d0 <+16>: movq 0x10(%rbx,%rax), %rdi
0x1000022d5 <+21>: callq 0x1004adc90             ; swift_unknownRelease
0x1000022da <+26>: movq 0x551e37(%rip), %rax     ; direct field offset for LoginViewController.database
0x1000022e1 <+33>: movq (%rbx,%rax), %rdi
0x1000022e5 <+37>: callq 0x1004bf9e6             ; symbol stub for: objc_release
0x1000022ea <+42>: movq 0x551e2f(%rip), %rax     ; direct field offset for LoginViewController.views
0x1000022f1 <+49>: movq (%rbx,%rax), %rdi
0x1000022f5 <+53>: addq $0x8, %rsp
0x1000022f9 <+57>: popq %rbx
0x1000022fa <+58>: popq %rbp
0x1000022fb <+59>: jmp 0x1004adec0               ; swift_bridgeObjectRelease
```

我们看到，这一行的地址就是我们crash的符号地址：

```
0x1000022ea <+42>: movq 0x551e2f(%rip), %rax     ; direct field offset for LoginViewController.views
```

但是PC寄存器始终保存下一条执行的指令，所以实际crash的应该是上一条指令

```
0x1000022da <+26>: movq 0x551e37(%rip), %rax     ; direct field offset for LoginViewController.database
0x1000022e1 <+33>: movq (%rbx,%rax), %rdi
0x1000022e5 <+37>: callq 0x1004bf9e6             ; symbol stub for: objc_release
```

通过汇编代码后面的注释不难看出，问题出在属性`database`上。

## 常见的Code和Debug技巧

### EXC\_BAD\_ACCESS/SIGSEGV/SIGBUS 

这三个都是内存访问错误，比如数组越界，访问一个已经释放的OC对象，尝试往readonly地址写入等等。这种错误通常会在Exception的Subtype找到错误地址的一些详细信息。

调试的时候需要观察调用栈的上下文：

1. 如果在上下文中看到了`objc_msgSend`和`objc_release`，往往是尝试对一个已经释放的Objective C对象发送消息，可以用Zombies来调试。
2. 多线程也有可能是导致内存问题的原因，这时候可以打开Address Sanitizer，让它帮助你找到多线程的Data Race。

### EXC\_CRASH/SIGABRT

这两个Code表示进程异常的退出，最常见的是一些没有被处理Objective C/C++异常。

App Extensions如果初始化的时候占用时间太多，被watchdog杀掉了，那么也会出现这种Code 。

### EXC\_BREAKPOINT/SIGTRAP

和进程异常退出类似，但是这种异常在尝试告诉调试器发生了这种异常，如果当前没有调试器依附，那么则会导致进程被杀掉。

> 可以通过`__builtin_trap()`在代码里手动出发这种异常。

这种Crash在iOS底层的框架中经常出现，最常见的是GCD，比如dispatch_group

```
Crashed: com.apple.main-thread
0  libdispatch.dylib              0x18316fae4 dispatch_group_leave$VARIANT$mp + 76
2  libdispatch.dylib              0x18316cb24 _dispatch_call_block_and_release + 24
```

Swfit代码在以下情况，也会出现这这种异常：

- 给一个非可选值类型赋值nil
- 失败的强制类型转换

### Killed [SIGKILL]

进程被系统强制杀掉了，通常在**Termination Reason**可以找到被强杀的原因：

- 0x8badf00d 表示watch dog超时，通常是主线程卡住或者启动时间超过20s。

## 资料

- [WWDC：Understanding Crashes and Crash Logs](https://developer.apple.com/videos/play/wwdc2018/414/)
- [Understanding and Analyzing Application Crash Reports](https://developer.apple.com/library/archive/technotes/tn2151/_index.html)