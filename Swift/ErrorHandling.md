## 前言
任何代码都会发生错误，这些错误有些是可以补救的，有些则只能让程序崩溃。良好的错误处理能够让你的代码健壮性提高，提高程序的稳定性。


## Objective C

### **返回nil**
如果出错了，就返回空是Objective C中的一种常见的处理方式。因为在Objective C中，向nil发送消息是安全的。比如：

```
- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    //如果初始化失败，会返回nil
    return self;
}
```

### 断言
断言指定了我们方法的上下文，如果断言不满足，则在Debug环境下会直接crash。

比如：AFNetworking中的[af_resume](https://github.com/AFNetworking/AFNetworking/blob/master/AFNetworking/AFURLSessionManager.m#L419)方法

```
- (void)af_resume {
    NSAssert([self respondsToSelector:@selector(state)], @"Does not respond to state");
    NSURLSessionTaskState state = [self state];
    [self af_resume];
    
    if (state != NSURLSessionTaskStateRunning) {
        [[NSNotificationCenter defaultCenter] postNotificationName:AFNSURLSessionTaskDidResumeNotification object:self];
    }
}
```
### **返回状态码**
返回状态码和全局错误信息往往是在一起使用的。这种错误的处理方式常见于用Objective C来封装C的代码，或者纯C的方法。比如sqlite中的错误处理：

```
int result = sqlite3_open(dbPath,&_db );
if(result != SQLITE_OK) {//如果出错
   
}
```
又比如，Data写入到文件

```
BOOL succeed = [currentData writeToFile:path atomically:YES];
```

### **NSError**
> <font color="red">**NSError是Cocoa中推荐的错误处理方式**</font>。
> 使用NSError来处理错误的例子遍布整个CocoaTouch框架。
比如：NSFileManager

```
NSFileManager * fm  = [NSFileManager defaultManager];
NSError * error;
[fm removeItemAtPath:path error:&error];
```

又比如，NSURLSession通过NSError来传递错误信息

```
[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
}];
```
一个NSError包括了错误的详细信息：主要有以下几个信息

- code 错误的状态码
- domain 错误的域
- userInfo 错误的详细信息

比如，常见的NSURLErrorDomain，也就是网络请求失败：

```
    NSURLErrorCancelled = -999,
    NSURLErrorBadURL = -1000,
    NSURLErrorTimedOut = -1001,
    NSURLErrorUnsupportedURL = -1002,
    NSURLErrorCannotFindHost = -1003,
    //....
```

### **NSException**
NSException是类似其他语言中的异常，你可以通过try-catch等方式捕获异常

```
@try {
    //Code that can potentially throw an exception
} @catch (NSException *exception) {
    //Handle an exception thrown in the @try block
} @finally {
    //Code that gets executed whether or not an exception is thrown
}
```
当然，你也可以自己抛出一个异常：

```
[NSException raise:@"ExceptionName" format:@"Contents"];
```

> - <font color="red">在Objective C中，通常只有当程序出错，无法继续执行的时候，我们才会主动抛出一个异常。
> - Objective C的异常处理的效率很低，通常不用来做错误处理,而且Objective C也没有类似的throw关键字来表明一个方法会抛出异常，编码起来很难判断是否需要try-cathe。</font>

----
## Swift中的错误处理
> Swift provides first-class support for throwing, catching, propagating, and manipulating recoverable errors at runtime.

Swift提供了一套完整的错误抛出-捕获-处理机制。Swift采用`Error`协议来表示错误类型，通过do-try-catch的方式来处理可能会抛出异常的代码。


### Optional

可选值表示一个值要么有值，要么是nil。在Swift中，Optional是用enum写的，

```
public enum Optional<Wrapped> : ExpressibleByNilLiteral {
    case none
    case some(Wrapped)
	 //...
}
```

当发生错误的时候，返回一个可选值是常见的处理方式。但是，这种方式的有一个很明显的缺点：

> 调用者不清楚为什么失败，也就不好进行相关的处理。

### **Error协议与throws**

`Error`是一个空的协议，用来表示错误类型。`NSError`和`CFError`都遵循了这个协议。

throws关键字表明这个方法会抛出错误，方法调用者需要处理错误。

在Swfit中，枚举是一个特别适合用来处理Error的数据类型。我们首先定义一个类Person表示人

```
enum Sex{
    case male
    case female
}
class Person{
    let sex:Sex
    var money:CGFloat
    init(sex:Sex ,money:CGFloat) {
        self.sex = sex
        self.money = money
    }
}
```
Person可以结婚，结婚的时候会发生一些错误，比如钱不够，比如性别不对，用枚举来表示。

```
enum MarryError : Error{
    case lackMoney
    case wrongSex
}
```
然后，方法的实现如下：

```
extension Person{
    func marry(with another: Person) throws -> Bool{
        guard self.sex != another.sex else{
            throw MarryError.wrongSex
        }
        guard self.money + another.money > 100000 else {
            throw MarryError.lackMoney
        }
        return true
    }
}

```

对于一个带有throws关键字的函数，调用的时候有两种方式选择：

- **使用 do-try-catch 代码块**

```

let tom = Person(sex: .male, money: 100000)
let jack = Person(sex: .male, money: 100000)
do{
    try tom.marry(with: jack)
}catch MarryError.wrongSex {
    print("Two Person have same sex")
}catch MarryError.lackMoney{
    print("Oh, they do not have enough moeny")
}catch let error{
    print(error)
}
```
当然，如果不需要区分每一个Error，也可以这么调用。

```
do{
    try tom.marry(with: jack)
}catch let error{
    print(error)
}
```

- **使用 try?，对于有返回值的throws函数，使用try?会把结果转换为可选值。**

```
let tom = Person(sex: .male, money: 100000)
let jack = Person(sex: .male, money: 100000)

if let result = try? tom.marry(with: jack){//成功

}else{
    print("Error happen")
}
```
### **defer关键字**
defer关键字用来处理类似Ojective C中@try-@catch-@finally中，@finally的作用。
比如，我们打开文件，如果抛出错误的话，我们总希望关闭这个文件句柄。

```
func contents(of filePath:String) throws -> String{
    let file = open(filePath,O_RDWR)
    defer {
        close(file)
    }
    //...
}
```

> defer代码块的内容在退出作用域之前会被执行

关于defer，有两点需要注意

- 多个defer会按照逆序的方式执行。
- 当你的程序遇到严重错误，比如fatalError,或者强制解析nil，或者segfaults的时候，defer的代码块并不会执行。

### **rethrow**
rethrow关键字在高阶函数中比较常见，所谓高阶函数，就是一个函数的参数或者返回值是函数类型。

最常见的比如，`Sequence`协议`map`方法。

```
let array = [1,2,3]
let result = array.map{$0 * 2}
```

由于map函数传入的是一个闭包，这个闭包可能会抛出错误。由参数抛出的错误最后会向上传递给map函数。

比如：

```
enum MapError : Error{
    case invalid
}
func customMapper(input:Int) throws -> Int{
    if input < 10{
        throw MapError.invalid
    }
    return input + 1
}
let array = [1,2,3]
let result = array.map(customMapper)
```
> 这样是编译不通过的。

调用的时候需要：按照上文提到的throws关键字的路子来

```
do {
    let result = try array.map(customMapper)
} catch let error{
    
}
```

所以，这就是rethrows关键字的精髓所在

> rethrows 关键字表示当参数闭包标记为throws的时候，函数本身为throws。如果参数闭包不会抛出错误，则函数也不会。

通过这个关键字，你不必每次都进行try-catch

### Result类型
我们知道，一个函数执行要么成功，要么失败。成功的时候我们希望返回数据，失败的时候我们希望得到错误信息，这就是Result类型，一个典型的Result类型如下：

```
enum Result<T>{
    case success(T)
    case failure(error:Error)
}
```
通过Result类型，不再需要可选值或者do-try-catch来包裹你的代码。

我们用Result类型对上述marry函数进行重写：

```
extension Person{
    func marry(with another: Person)  -> Result<Bool>{
        guard self.sex != another.sex else{
            return .failure(error: MarryError.wrongSex)
        }
        guard self.money + another.money > 100000 else {
            return .failure(error: MarryError.lackMoney)
        }
        return .success(true)
    }
}

```
然后，这么调用

```
let tom = Person(sex: .male, money: 100000)
let jack = Person(sex: .male, money: 100000)
let result = tom.marry(with: jack)
switch result {
	case let .success(value):
  	  	print(value)
	case let .failure(error):
   	 	print(error)
}
```

#### **Result链**

Swift中有可选链，来处理多个可选值的连续调用。同样的，我们也可以为Result类型来添加链式调用：

- 如果上一个调用结果是.success, 则继续调用下一个
- 如果上一个调用结果是.failure, 则传递failure给下一个

我们可以用extension来实现

```
extension Result{
    func flatMap<V>(transform:(T) throws -> (V)) rethrows -> Result<V>{
        switch self {
        case let .failure(error):
            return .failure(error: error)
        
        case let .success(data):
            return .success(try transform(data))
        }
    }
}
```

于是，你就可以这么调用了

```
resut.flatMap({//转换1}).flatMap(//转换2)...
```
一旦失败，中间有一次flatMap转换失败，则之后的转换逻辑都不会执行


> 进阶：Result类型在Swift版本的Promise中大行其道，可以参见[PromiseKit](https://github.com/mxcl/PromiseKit/blob/master/Sources/Promise.swift)的源码，promise让异步处理变得优雅。

### **assert/precondition**

在本文最初的的地方降到了Objective C的断言，同样Swift也有断言支持。在Swfit中，断言是一个函数：

```
func assert(_ condition: @autoclosure () -> Bool, 
			  _ message: @autoclosure () -> String = default, 
			       file: StaticString = #file, 
			       line: UInt = #line)
```

断言仅在Debug模式下进行检查，帮助开发者发现代码中的问题。

如果需要在Relase模式下也进行检查，则使用`precondition `

```
func precondition(_ condition: @autoclosure () -> Bool, 
			  _ message: @autoclosure () -> String = default, 
			       file: StaticString = #file, 
			       line: UInt = #line)
```

### **桥接到Objective C**

对于如下使用NSError来处理错误的的Objective 方法

```
//NSFileManager
- (BOOL)removeItemAtURL:(NSURL *)URL error:(NSError * _Nullable *)error;
```

在Swift中会被自动的转换成

```
func removeItem(at URL: URL) throws
```

但是，纯Swfit的Error桥接的Objective C的时候，会有一些问题。因为NSError需要 `domain`和`code`等详细信息。

我们可以让Swift的Error实现CustomNSError协议，来提供这些需要的信息。

```
enum MarryError : Error{
    case lackMoney
    case wrongSex
}
extension MarryError : CustomNSError{
    static let errorDomain = "com.person.marryError"
    var erroCode:Int{
        switch self {
        case .lackMoney:
            return -100001
        case .wrongSex:
            return -100002
        }
    }
    var errorUserInfo:[String:Any]{
        return [:]
    }
}
```
相关的，还有两个协议`LocalizedError`和`RecoverableError`
