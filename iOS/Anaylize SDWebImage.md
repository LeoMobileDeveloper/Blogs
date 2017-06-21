这个源码解析系列的文章

* [AsnycDispalyKit](http://blog.csdn.net/hello_hwc/article/details/51383470)
* [SDWebImage](http://blog.csdn.net/hello_hwc/article/details/51404322)
* [Mantle](http://blog.csdn.net/hello_hwc/article/details/51548128)
* [Alamofire](http://blog.csdn.net/hello_hwc/article/details/72853786)


----------

前言
--
SDWebImage是iOS开发中十分流行的库，大多数的开发者在下载图片或者加载网络图片并且本地缓存的时候，都会用这个框架。这个框架相对来说，源代码还是比较少的。本文会详细的讲解这些类的架构关系和原理。

本文会先介绍<font color="#0f83d1">类的整体架构关系</font>，先有一个宏观的认识。然后讲解<font color="#0f83d1">`sd_setImageWithURL`的加载逻辑</font>，因为这是SDWebImage最核心的，也是很多面试会问到的。接下来会介绍<font color="#0f83d1">Image的解码</font>，然后讲解<font color="#0f83d1">缓存处理</font>。最后再讲解<font color="#0f83d1">API设计方式</font>,以及其他我认为有用的。


----------

整体架构关系
--------
按照分组方式，可以分为几组

### 定义通用宏和方法 

 - <font color="#1ba0cc">SDWebImageCompat</font>, 宏定义和C语言的一些工具方法
 - <font color="#1ba0cc"> SDWebImageOperation</font>，定义通用的Operation协议，主要就是一个方法，cancel。从而在cancel的时候，可以面向协议编程。
 
 
### 下载

 - <font color="#1ba0cc">SDWebImageDownloader</font> 实际的下载功能和配置提供者，使用了<font color="orange">单例</font>的设计模式
 - <font color="#1ba0cc">SDWebImageDownloaderOperation</font>，继承自`NSOperation`，是一个<font color="orange">异步</font>的`NSOperation`,封装了`NSURLConnection`进行实际的下载任务

### 缓存处理

 - <font color="#1ba0cc">AutoPurgeCache</font>,NSCache的子类，用于<font color="orange">内存cache</font>，会在收到内存警告的时候，自动清空
 - <font color="#1ba0cc">SDImageCache</font>，实际处理<font color="orange">内存cache</font>和<font color="orange">磁盘cache</font>

### 功能类 

 - <font color="#1ba0cc">SDWebImageManager</font>,宏观的从整体上管理整个框架的类
 -  <font color="#1ba0cc">SDWebImageDecoder</font>，图片的解码类，后面会详细的讲解如何解码的
 -  <font color="#1ba0cc">SDWebImagePrefetcher</font>，图片的预加载管理

### Category

 - 类别用来为UIView和UIImageView等"添加"属性来存储必要的信息，同时暴露出接口，进行实际的操作。

<font color="orange">
Tips：

 1. 用类别来提供接口往往是最方便的，因为用户只需要import这个文件，就可以像使用原生SDK那样去开发，不需要修改原有的什么代码
 2. 面向对象开发有一个原则是－单一功能原则，所以不管是在开发一个Lib或者开发App的时候，尽量保证各个模块之前功能单一，这样会降低耦合。

</font>


----------
sd_setImageWithURL的加载逻辑
----------

### 1. 取消当前正在加载的图片

```
  [self sd_cancelCurrentImageLoad];

```

这个方法的实际调用源代码如下，其中key是`UIImageViewImageLoad`

<font color="orange">
Tips：operationDictionary是通过Runtime为UIView"添加"的属性，不懂的同学可以看看我这篇[文章](http://blog.csdn.net/Hello_Hwc/article/details/49756487)
</font>

```
- (void)sd_cancelImageLoadOperationWithKey:(NSString *)key {
	 //用一个字典来存储当前的加载operation
    NSMutableDictionary *operationDictionary = [self operationDictionary];
    id operations = [operationDictionary objectForKey:key];
    //两种类型，帧类型的的gif是多个operation，静态图是一个operaiton
    if (operations) {
        if ([operations isKindOfClass:[NSArray class]]) {
            for (id <SDWebImageOperation> operation in operations) {
                if (operation) {
                    [operation cancel];
                }
            }
        } else if ([operations conformsToProtocol:@protocol(SDWebImageOperation)]){
            //这里属于面向协议编程，不关心具体的类，只关心遵守某个协议
            [(id<SDWebImageOperation>) operations cancel];
        }
        //删除对应的key
        [operationDictionary removeObjectForKey:key];
    }
}
```


----------


### 2. 如果有PlaceHolder，设置placeHolder

```
   if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            self.image = placeholder;
        });
    }
```
这里的dispatch_main_async_safe是一个宏定义，会检查调用是否在主线程上，如果在主线程就直接调用，后台线程会用gcd切换到主线程

```
#define dispatch_main_async_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }
```

----------
### 3. 根据SDImageCache来查缓存，看看是否有图片
查看缓存的是这个方法

```
operation.cacheOperation = [self.imageCache queryDiskCacheForKey:key done:^(UIImage *image, SDImageCacheType cacheType) {//异步返回查询的结果}

```

这块感觉代码优点难懂，其实这是执行了一个方法`queryDiskCacheForKey:key`，返回一个`NSOperation`,之所以这样，是因为从磁盘或者内存查询的过程是异步的，后面可能需要cancel，所以这样做。

我们再看看`queryDiskCacheForKey:key`这个方法是怎么实现的？

```
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(SDWebImageQueryCompletedBlock)doneBlock {
	//输入检查，这里省略掉
    //先检查磁盘缓存
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        doneBlock(image, SDImageCacheTypeMemory);
        return nil;
    }
    //检查磁盘缓存
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{//切换到io队列上，进行磁盘操作
            //省略中间检查代码
            //回归到主线程行，进行doneBlock操作
            dispatch_async(dispatch_get_main_queue(), ^{
                doneBlock(diskImage, SDImageCacheTypeDisk);
            });
        }
    });
    return operation;
}
```

----------


### 4. 创建下载任务

```
id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadImageWithURL:url options:options progress:progressBlock completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
 //这里是下载完成后的回调，没什么要讲解的，简单来说就是image下载成功，就wself.image = image;[wself setNeedsLayout];,下载失败仍然显示placeHolder。然后调用completion block回调。
        }];
//记录下来当前的下载，方便后面取消
[self sd_setImageLoadOperation:operation forKey:@"UIImageViewImageLoad"];
```
接下来，我们来看看实际的下载operation是什么样子的
也就是这个方法

[-(id<SDWebImageOperation>)downloadImageWithURL:options:progress:completed:](https://github.com/rs/SDWebImage/blob/master/SDWebImage/SDWebImageDownloader.m)


----------


####  3.1,由于有各种各样的block回调，例如下载进度的回调，完成的回调，所以需要一个数据结构来存储这些回调 

所以，这个方法中，首先调用以下方法来存储回调

```
[self addProgressCallback:progressBlock completedBlock:completedBlock forURL:url createCallback:^{
//...
}
```
其中，用来存储回调的数据结构是一个NSMutableDictionary,其中<font color="orange">key是图片的url，value是回调的数组</font>
举个例子，存储后应该是这样的，

```
@{
        @"http://iamgeurl":[
                            @{
                                @"progress":progressBlock1,
                                @"completed":completedBlock1,
                            },
                            @{
                                @"progress":progressBlock2,
                                @"completed":completedBlock2,
                              },
                           ],
            //其他
}
```

Tips：注意，对于同一个URL，在第二次调用`addProgressCallback:progressBlock`用的时候，并不会执行createCallback，也就是说，<font color="orange">保证一个URL在多次下载的时候，只进行多次回调，而不会进行多次网络请求</font>

<font color="1ba0cc">如果是我，可能更愿意用一个对象来存储这些block回调，觉得这个数据结构有点复杂，很难维护</font>


----------


#### 3.2,对于同一个url，在第一次调用sd_setImage的时候进行，创建网络请求`SDWebImageDownloaderOperation`。

创建的方法是这个 

```
[[wself.operationClass alloc] initWithRequest:request
                                      options:options
                                     progress:^(NSInteger receivedSize, NSInteger expectedSize){//Progress 回调}
                                     completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished){//Completion回调}
                                     cancelled:^{//Cancel 回调}
                                      
```
在看看Progress回调

```
 //Block中强引用sself（weakself）,保证在执行结束前不会被释放
 SDWebImageDownloader *sself = wself; 
 //如果weakself已经为nil，此时已经释放了，所以直接放回
 if (!sself) return;
 //用__block来修饰callbacksForURL，保证在能在block中修改这个变量
 __block NSArray *callbacksForURL;
 //在队列`barrierQueue`里同步捕获callBack
 dispatch_sync(sself.barrierQueue, ^{
     callbacksForURL = [sself.URLCallbacks[url] copy];
 });
 for (NSDictionary *callbacks in callbacksForURL) {
//异步切换到主线程上进行回调
   dispatch_async(dispatch_get_main_queue(), ^{
         SDWebImageDownloaderProgressBlock callback = callbacks[kProgressCallbackKey];
         if (callback) callback(receivedSize, expectedSize);
     });
 }
```
completion回调和progress类似，不再赘述。
再看看cancel block的处理

```
SDWebImageDownloader *sself = wself;
if (!sself) return;
//阻碍barrierQueue,
dispatch_barrier_async(sself.barrierQueue, ^{
    [sself.URLCallbacks removeObjectForKey:url];
});
```
Tips:这里为什么要用`dispatch_barrier_async`呢？因为

```
_barrierQueue = dispatch_queue_create("com.hackemist.SDWebImageDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);

```
_barrierQueue是个并行队列，意味着队列上的任务可以并行执行。用`dispatch_barrier_async`来保证后续提交的block等待当前的`dispatch_barrier_async`block执行完毕后再执行。

Tips：

 1. 用这么多GCD是为了保证线程安全
 
再简单提一下`dispatch_barrier_async` 的用法

> Calls to this function always return immediately after the block has been submitted and never wait for the block to be invoked. When the barrier block reaches the front of a private concurrent queue, it is not executed immediately. Instead, the queue waits until its currently executing blocks finish executing. At that point, the barrier block executes by itself. Any blocks submitted after the barrier block are not executed until the barrier block completes.

----------
#### 4. 下载图片完成后，根据需要图片解码和处理图片格式，回调给Imageview</font>

```
 UIImage *image = [UIImage sd_imageWithData:self.imageData];
            NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
            image = [self scaledImageForKey:key image:image];
            
            // Do not force decoding animated GIFs
            if (!image.images) {
                if (self.shouldDecompressImages) {
                    image = [UIImage decodedImageWithImage:image];
                }
            }

```
----------

总结下整个调用过程
---------

 1. 取消上一次调用
 2. 设置placeHolder
 3. 保存回调block
 4. cache查询是否已经下载过了，先检查内存，后检查磁盘
 5. 利用NSURLConnection来下载图片，根据需要解码，回调给imageview，存储到缓存


----------
线程管理
-----
整个SDWebImage一共有四个队列

 - Main queue,主队列，在这个队列上进行UIKit对象的更新，发送notification
 - barrierQueue，并行队列，在这个队列上统一处理3-1中的数据回调，为了保证线程安全，一致使用`dispatch_barrier_sync`
 - ioQueue，用在图片的磁盘操作
 - downloadQueue（NSOperationQueue），用来全局的管理下载的任务


----------

图片解码
----

传统的UIImage进行解码都是在主线程上进行的，比如

```
UIImage * image = [UIImage imageNamed:@"123.jpg"]
self.imageView.image = image;
```
在这个时候，图片其实并没有解码。而是，当图片实际需要显示到屏幕上的时候，CPU才会进行解码，绘制成纹理什么的，交给GPU渲染。这其实是很占用主线程CPU时间的，而众所周知，<font color="blue">主线程的时间真的很宝贵</font>

现在，我们看看SDWebImage是如何在后台进行解码的
代码来自于这个原文件[SDWebImageDecoder](https://github.com/rs/SDWebImage/blob/master/SDWebImage/SDWebImageDecoder.m)

```
+ (UIImage *)decodedImageWithImage:(UIImage *)image {
    if (image == nil) { 
        return nil;
    }
    
    @autoreleasepool{
        //Gif不用解码，直接返回
        if (image.images != nil) {
            return image;
        }
        CGImageRef imageRef = image.CGImage
        ;
        CGImageAlphaInfo alpha = CGImageGetAlphaInfo(imageRef);
        BOOL anyAlpha = (alpha == kCGImageAlphaFirst ||
                         alpha == kCGImageAlphaLast ||
                         alpha == kCGImageAlphaPremultipliedFirst ||
                         alpha == kCGImageAlphaPremultipliedLast);
        if (anyAlpha) {
        //有Alpha通道，直接返回
            return image;
        }
        //获得Color Space
        CGColorSpaceModel imageColorSpaceModel = CGColorSpaceGetModel(CGImageGetColorSpace(imageRef));
        CGColorSpaceRef colorspaceRef = CGImageGetColorSpace(imageRef);
        
        BOOL unsupportedColorSpace = (imageColorSpaceModel == kCGColorSpaceModelUnknown ||
                                      imageColorSpaceModel == kCGColorSpaceModelMonochrome ||
                                      imageColorSpaceModel == kCGColorSpaceModelCMYK ||
                                      imageColorSpaceModel == kCGColorSpaceModelIndexed);
        if (unsupportedColorSpace) {
            colorspaceRef = CGColorSpaceCreateDeviceRGB();
        }
        
        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);
        NSUInteger bytesPerPixel = 4;
        NSUInteger bytesPerRow = bytesPerPixel * width;
        NSUInteger bitsPerComponent = 8;
		//创建bitmapContext
        CGContextRef context = CGBitmapContextCreate(NULL,
                                                     width,
                                                     height,
                                                     bitsPerComponent,
                                                     bytesPerRow,
                                                     colorspaceRef,
                                                     kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast);
        
        // 绘制Image到Context中，强制解码
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGImageRef imageRefWithoutAlpha = CGBitmapContextCreateImage(context);
        UIImage *imageWithoutAlpha = [UIImage imageWithCGImage:imageRefWithoutAlpha
                                                         scale:image.scale
                                                   orientation:image.imageOrientation];
        
        if (unsupportedColorSpace) {
            CGColorSpaceRelease(colorspaceRef);
        }
        
        CGContextRelease(context);
        CGImageRelease(imageRefWithoutAlpha);
        
        return imageWithoutAlpha;
    }
}
```

----------

缓存处理
----
整个缓存处理的类都在[SDImageCache](https://github.com/rs/SDWebImage/blob/master/SDWebImage/SDImageCache.m)文件中，其中缓存又包括两个方面，

 - 内存缓存
 - 磁盘缓存

其中，内存缓存采用了`NSCache`的子类`AutoPurgeCache`，

AutoPurgeCache
只是对NSCache添加了在收到内存警告通知`UIApplicationDidReceiveMemoryWarningNotification`的时候自动`removeAllObjects`

<font color="red">再看看磁盘缓存是如何做的？</font>
磁盘缓存是基于<font color="orange">文件系统</font>的,也就是说图片是以普通文件的方式存储到沙盒里的。

<font color="blue">缓存的目录是啥？</font>
默认的缓存目录是

```
Lbirary/Caches/default/com.hackemist.SDWebImageCache.default/
```
<font color="orange">缓存的文件名称是对缓存的key求md5</font>

<font color="blue">何时自动清除过期图片？</font>
在App关闭的时候

```
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(cleanDisk)
                                             name:UIApplicationWillTerminateNotification
                                           object:nil];

```
>清除的逻辑很简单，获取文件的modify时间，然后比较下过期时间，如果过期了就删除。当磁盘缓存超过阈值后，根据最后访问的时间排序，删除最老的访问图片。

<font color="blue">存储成什么格式？</font>
见SDImageCache中，

```
//获取Alpha信息
int alphaInfo = CGImageGetAlphaInfo(image.CGImage);
BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                  alphaInfo == kCGImageAlphaNoneSkipFirst ||
                  alphaInfo == kCGImageAlphaNoneSkipLast);
BOOL imageIsPng = hasAlpha;

//如果又imageData，并且有png的前8个字节，根据NSData前8个字节来检查是否是png
if ([imageData length] >= [kPNGSignatureData length]) {
    imageIsPng = ImageDataHasPNGPreffix(imageData);
}
//如果是Png，存储成png
if (imageIsPng) {
    data = UIImagePNGRepresentation(image);
}
else {
//否则存储称jpg
    data = UIImageJPEGRepresentation(image, (CGFloat)1.0);
}
```

----------

deprecated一个API
---------------
只需要在方法后面，添加`__deprecated_msg`例如

```
+ (NSString *)contentTypeForImageData:(NSData *)data __deprecated_msg("Use `sd_contentTypeForImageData:`");

```


----------


条件编译
----
这个在之前AsyncDisplayKit解析的文章里也提到过，这里再提一次

```
#if TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
//代码
#endif
```
又比如

```
#if TARGET_OS_IOS 
//代码for iOS
#else
//代码for osx
#endif
```
就是条件编译，根据条件是否满足来让编译器编译这段代码。

<font color="orange">
Tips：根据条件编译，可以为不同的版本的iOS做一些适配
</font>

----------
如何实现Gif动图？
----------
本质上，使用这个iOS SDK提供的方法

```
//传入一个Image数组，和动画的时间
animatedImage = [UIImage animatedImageWithImages:images duration:duration];
```
那么，如何解析Gif图片呢？
原理也比较简单，源代码在[UIImage+GIF.m](https://github.com/rs/SDWebImage/blob/master/SDWebImage/UIImage+GIF.m)中。利用[CGImageSource](https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CGImageSource/)的一系列方法依次提取每一帧的图片和每一帧的图片间隔，然后用上文提到的API来实现Gif


Tips：在ARC开启的时候，Foundation对象（CF开头）和CoreGraphics对象(CG开头）的一些对象仍然需要手动管理，例如

```
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
//利用完毕
    CGImageRelease(image);

```
----------
获取图片的格式
-------
原文件[NSData+ImageContentType.m](https://github.com/rs/SDWebImage/blob/master/SDWebImage/NSData+ImageContentType.m)	,代码不难，不做讲解了

```
+ (NSString *)sd_contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
        case 0x52:
            // R as RIFF for WEBP
            if ([data length] < 12) {
                return nil;
            }

            NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                return @"image/webp";
            }

            return nil;
    }
    return nil;
}

```


----------

预下载
---
原文件[SDWebImagePrefetcher.m](https://github.com/rs/SDWebImage/blob/master/SDWebImage/SDWebImagePrefetcher.m)

可以看到，由于类的功能划分非常清楚，所以`SDWebImagePrefetcher` 的实现文件很简单，本质上只是<font color="orange">用单例的设计模式，并且这个类保存了SDWebImageManager对象来进行的实际下载操作</font>

----------
设计方式的一点理解
--------

 - 整个框架的处理核心是`SDWebImageManager`类，而为了让使用者在使用的时候<font color="red">不必实例化这个类的一个对象</font>，整个类采用了单利的设计模式。

 - 用block的方式，处理复杂的异步回调。用block的方式，在这里是要比代理来的简单直接的。如果用代理，那么上文讲解的sd_setImageWithURL的过程，将会有复杂的代理回调方法

 -  每个线程处理自己的独立任务。上文提到了，这个库一共有四个Queue

 - 面向协议编程。这个在`SDWebImageOperation`协议的体现上十分明显。

```
@protocol SDWebImageOperation <NSObject>

- (void)cancel;

@end
```
在使用的时候，只需关注协议的本身就可以了

```
if ([operations conformsToProtocol:@protocol(SDWebImageOperation)]){
     [(id<SDWebImageOperation>) operations cancel];
 }
```

 - 用Category的方式提供接口,例如UIImageView+WebCache等，这样能最大程度的降低使用者的使用难度。

 - <font color="orange">单一功能原则</font>,这个在上文提到了，每个类or文件负责单一的功能，方便独立测试和维护
最好的例子就是

```
UIImage+GIF.h
UIImage+MultiFormat
UIImageView+HighlightedWebCache.h
UIImageView+WebCache.h
```

 - 线程安全的保证。很明显，SDWebImage不能强求用户在某一个线程上调用，然后自己切换回主线程。所以你会看到类似这样的代码来保证线程安全

```
@synchronized (self) {}
```

```
dispatch_barrier_sync(sself.barrierQueue, ^{
   callbacksForURL = [sself.URLCallbacks[url] copy];
	if (finished) {
    	[sself.URLCallbacks removeObjectForKey:url];
	}
});
```
----------
总结
---
SDWebImage相对来说源代码没有那么多，建议有时间的同学自己好好研究下源代码。对图片的基础知识巩固，各种线程的处理方式，类的架构和API设计等都很有帮助。


                                         
