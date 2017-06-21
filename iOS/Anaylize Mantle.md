
一些有深度的博客我会同步到自己的Github上

- [LeoMobileDeveloper](https://github.com/LeoMobileDeveloper)

这个源码解析系列的文章

* [AsnycDispalyKit](http://blog.csdn.net/hello_hwc/article/details/51383470)
* [SDWebImage](http://blog.csdn.net/hello_hwc/article/details/51404322)
* [Mantle](http://blog.csdn.net/hello_hwc/article/details/51548128)
* [Alamofire](http://blog.csdn.net/hello_hwc/article/details/72853786)

----------
前言
--
iOS开发中，不管是哪种设计模式，Model层都是不可或缺的。而Model层的第三方库常用的库有以下几个

 - [JSONModel](https://github.com/icanzilb/JSONModel)
 - [Mantle](https://github.com/Mantle/Mantle)
 - [MJExtension](https://github.com/CoderMJLee/MJExtension)

JSON data到对象的转换原理都差不多，一般的顺序如下



 - <font color="orange">根据Runtime，动态的获取属性的类型和属性的名字，（如果需要，做一次Json的key的Mapping</font>
 - <font color="orange">创建对应的对象实例</font>
 - <font color="orange">根据KVC（NSKeyValueCoding协议）来为属性设置值</font>


Mantle就是这样的一个库，个人比较喜欢Mantle,而且在**Github**的**Star**也是提到的几个库中最多的。Mantle除了提供<font color="red">JSON和对象的相互转化</font>，继承自MTLModel的对象还自动实现了

 - `NSCopying`
 - `NSCoding`
 - `isEqual`
 - `hash`

等几个工具方法。

----------
本文的讲解顺序
-------
首先会讲解几个Runtime的基础知识，不理解这个，也就没办法掌握这几个JSON到Model转化的原理

 1. 介绍<font color="orange">Runtime</font>如何获取某一个类的全部属性的名字
 2. 介绍<font color="orange">Runtime</font>如何动态获取属性的类型


然后，会讲解Mantle本身

 1. 类的组织架构关系
 2. JSON到对象的处理流程（对象到JSON的过程类似）
 4. NSValueTransformer
 4. 如何自动实现NSCoding，NSCopying，hash等方法
 5. 异常处理
 6. 其他认为有用的，例如编译选项等


<font color="red">本文会很长，希望读者看完后能有些许收获，如果发现有任何地方有问题，欢迎指正，我会及时修改。</font>

----------

利用Runtime动态获取类的属性
-----------------
首先，写两个类

```
@interface Base : NSObject
@property (copy,nonatomic)NSString * baseProperty;
@end

@interface Demo : Base
@property (nonatomic,strong)NSDate * createAt;
@property (nonatomic,copy)NSString * name;
@property (nonatomic,assign)CGFloat count;
@end
```
然后, 写一个方法来Log Property

```
-(void)logAllPropertys{
    uint count;
    objc_property_t * propertys = class_copyPropertyList(Demo.class,&count);
    @try {
        for (int i = 0; i < count ; i++) {
            objc_property_t  property = propertys[i];
            NSLog(@"%@",@(property_getName(property)));
        }
    }@finally {
        free(propertys);
    }
}
```
执行这个方法的Log

```
2016-05-26 22:51:48.996 LearnMantle[4670:165290] createAt
2016-05-26 22:51:49.001 LearnMantle[4670:165290] name
2016-05-26 22:51:49.001 LearnMantle[4670:165290] count
```
不难发现`class_copyPropertyList`仅仅是获取了当前类的属性列表，并没有获取基类的属性对象。所以对上述方法进行修改

```
-(void)logAllPropertys{
    Class cls = Demo.class;
    while (![cls isEqual:NSObject.class]) {
        uint count;
        objc_property_t * propertys;
        @try {
            propertys = class_copyPropertyList(cls,&count);
            cls = cls.superclass;
            for (int i = 0; i < count ; i++) {
                objc_property_t  property = propertys[i];
                NSLog(@"%@",@(property_getName(property)));
            }
        }@finally {
            free(propertys);
        }
    }
}
```
这里又个Tips：
<font color="orange">
class_copyPropertyList返回一个数组，这个数字必须要手动释放，所以用Try-Catch-Finally包裹起来。</font>后面会介绍，Mantle如何用更简洁的方式来实现。

----------
利用Runtime来获取属性的attributes
-----------------
关键方法`property_getAttributes`，返回个一个C类型的字符串。
我们先声明一个这样的属性

```
@property (nonatomic,readonly,copy)id name;

```
然后，打印出它的attributes信息

```
    NSLog(@"%@",@(property_getAttributes(class_getProperty(self.class,@"name".UTF8String))));

```
可以看到Log是

```
2016-05-28 10:09:10.476 LearnMantle[731:17207] T@,R,C,N,V_name
```
这里的Attributes字符串是编码后的字符串，分为三个部分

 1. `T@,T`表示开头，后面跟着属性的类型，`@`表示`id`类型
 2. `Vname`，`V`表示中间部分的结束，后面跟`ivar`名字,自动合成呢的情况下前面加下划线
 3. 中间`R,C,N`用逗号隔开，表示属性的描述，`R`表示`readonly`，`C`表示`Copy`，`N`表示`Nonatomic`
 
Mantle和ReactiveCocoa都是采用了[extobjc](https://github.com/Mantle/Mantle/tree/master/Mantle/extobjc)这个OC的Runtime工具类将属性的详细信息提取到一个结构体里的，原理都是一样的。提取完成的结构体是[mtl_propertyAttributes](https://github.com/Mantle/Mantle/blob/master/Mantle/extobjc/EXTRuntimeExtensions.h)

----------
Matnle的类的组织架构
------------

按照文件的方式，

* [MTLJSONAdapter.h](https://github.com/Mantle/Mantle/blob/master/Mantle/MTLJSONAdapter.h),定义了协议`MTLJSONSerializing`和适配器类`MTLJSONAdapter`,这两个协议/类定义了接口来实现<font color="orange">JSON-MTLModel</font>的转换。

* [MTLModel.h](https://github.com/Mantle/Mantle/blob/master/Mantle/MTLModel.h)，定义了协议MTLModel和基类MTLModel，基类MTLModel实现了`isEqual`,`NSCopying`和`hash`几个方法。


* [MTLModel+NSCoding.h](https://github.com/Mantle/Mantle/blob/master/Mantle/MTLModel%2BNSCoding.h),MTLModel的类别，让其支持NSCoding协议



* [MTLValueTransformer.h](https://github.com/Mantle/Mantle/blob/master/Mantle/MTLValueTransformer.h)，`NSValueTransformer`的子类，定义了将一个value转变成另一个value的接口。例如，返回的一个`2020-01-01T15:33:30`字符串，利用转换block转换成`NSDate`


* 其它的都是工具类，提供工具方法，不全列出来了。

----------
JSON->对象的处理过程
-------------
以下面代码调用为例（为了看起来不那么臃肿，省略不必要的代码）

```
Demo * demo = [MTLJSONAdapter modelOfClass:[Demo class] fromJSONDictionary:json error:&error];

```
看看这个方法的具体实现，就知道分为两个大的过程

```
+ (id)modelOfClass:(Class)modelClass fromJSONDictionary:(NSDictionary *)JSONDictionary error:(NSError **)error {
    //1.根据modelClass初始化一个adapter
	MTLJSONAdapter *adapter = [[self alloc] initWithModelClass:modelClass];
    //2.adapter解析实际的JSON数据
	return [adapter modelFromJSONDictionary:JSONDictionary error:error];
}

```
现在看看整个第一大步，[initWithModelClass](https://github.com/Mantle/Mantle/blob/master/Mantle/MTLJSONAdapter.m)，Mantle做了什么，

<font color="red">1.1，断言检查，并保存modelClass</font>

```
	NSParameterAssert(modelClass != nil);
	NSParameterAssert([modelClass conformsToProtocol:@protocol(MTLJSONSerializing)]);
	//...
	_modelClass = modelClass;
```

<font color="red">1.2,获取所有的属性名字，获取MTLJSONSerialing中`JSONKeyPathsByPropertyKey`方法提供的属性名字->JSON key的映射，并进行合法性检查</font>


```
    //属性名－>JSON key的映射
    JSONKeyPathsByPropertyKey = [modelClass JSONKeyPathsByPropertyKey];
    //所有的属性集合
	NSSet *propertyKeys = [self.modelClass propertyKeys];
    //每一个属性进行检查
	for (NSString *mappedPropertyKey in _JSONKeyPathsByPropertyKey) {
	    //检查属性名－>JSON Key映射的属性名是否合法
		if (![propertyKeys containsObject:mappedPropertyKey]) {
			NSAssert(NO, @"%@ is not a property of %@.", mappedPropertyKey, modelClass);
			return nil;
		}
        //获取对应的JSON key
		id value = _JSONKeyPathsByPropertyKey[mappedPropertyKey];
        //如果是Array（支持JSON key是Array）
		if ([value isKindOfClass:NSArray.class]) {
		    //Array中的每一个Key必须是String类型
			for (NSString *keyPath in value) {
				if ([keyPath isKindOfClass:NSString.class]) continue;

				NSAssert(NO, @"%@ must either map to a JSON key path or a JSON array of key paths, got: %@.", mappedPropertyKey, value);
				return nil;
			}
		} else if (![value isKindOfClass:NSString.class]) {
		    //检查JSON key是否时Array类型
			NSAssert(NO, @"%@ must either map to a JSON key path or a JSON array of key paths, got: %@.",mappedPropertyKey, value);
			return nil;
		}
	}
```
<font color="red">1.3 获取所有的NSValueTransformer,来方便做值转换（例如：服务器JSON返回的是2015-10-01T13:15:15,转换成NSDate）</font>

```
	_valueTransformersByPropertyKey = [self.class valueTransformersForModelClass:modelClass];

```

用过Mantle的都知道，mantle利用"属性名+JSONTransformer"的方法名字来提供NSValueTransformer,
这里Mantle用了一些Runtime稍微高级点的东西，所以这个方法我会详细讲解

```
+ (NSDictionary *)valueTransformersForModelClass:(Class)modelClass {
    //...
	for (NSString *key in [modelClass propertyKeys]) {//对每一个key检查NSValueTransformer
	    //根据属性名字＋JSONTransformer来合成一个Selector
		SEL selector = MTLSelectorWithKeyPattern(key, "JSONTransformer");
		if ([modelClass respondsToSelector:selector]) {//如果提供了Transformer方法
		    //获取IMP指针，也就是实际方法的执行体
			IMP imp = [modelClass methodForSelector:selector];
			//OC方法转换为C方法的时候，前两个参数是_cmd,和SEL，所以，这里做一个强制转化，方便下一行执行
			NSValueTransformer * (*function)(id, SEL) = (__typeof__(function))imp;
			//获取transformer，保存到Dictionary
			NSValueTransformer *transformer = function(modelClass, selector);
			if (transformer != nil) result[key] = transformer;
			continue;
		}
		//检查是否通过协议方法JSONTransformerForKey来提供NSValueTransformer
		if ([modelClass respondsToSelector:@selector(JSONTransformerForKey:)]) {
			//...
		}
		//把一个属性的类型，关键字，属性名字提取到一个结构体中
		objc_property_t property = class_getProperty(modelClass, key.UTF8String);
		if (property == NULL) continue;
		mtl_propertyAttributes *attributes = mtl_copyPropertyAttributes(property);
		@onExit {
			free(attributes);
		};
		NSValueTransformer *transformer = nil;
		//如果某一个属性是id类型
		if (*(attributes->type) == *(@encode(id))) {
		    //获得该属性的实际类名
			Class propertyClass = attributes->objectClass;
			if (propertyClass != nil) {
			    //获取该类名型提供的NSValueTransformer,即类是否提供了keyJSONTransformer方法
				transformer = [self transformerForModelPropertiesOfClass:propertyClass];
			}
			//如果该类型也是一个MTLModel，并且实现了MTLJSONSerializing，获取该对象的NSValueTransformer,也就是保证了在MTLModel的一个属性也是一个MTLModel的时候能够正常工作
			if (nil == transformer && [propertyClass conformsToProtocol:@protocol(MTLJSONSerializing)]) {
				transformer = [self dictionaryTransformerWithModelClass:propertyClass];
			}
		    //如果仍然没有获取到transformer，验证对于modalClass是否可转换
			if (transformer == nil) transformer = [NSValueTransformer mtl_validatingTransformerForClass:propertyClass ?: NSObject.class];
		} else {
		//不是ID类型，则是值类型的transformer
			transformer = [self transformerForModelPropertiesOfObjCType:attributes->type] ?: [NSValueTransformer mtl_validatingTransformerForClass:NSValue.class];
		}

		if (transformer != nil) result[key] = transformer;
	}

	return result;
}
```
再看看第二大步，Adapter如何解析JSON
即这个方法

```
- (id)modelFromJSONDictionary:(NSDictionary *)JSONDictionary error:(NSError **)error {
//...
}
```
2.1，检查是否实现了聚类方式解析JSON，例如解析这样的JSON

```
[
	{
		"key1":"value1",
		"key2":"value2"
	},
	{
		"key3":"value3",
		"key4":"value4"

	}
]
```
对应代码块

```
if ([self.modelClass respondsToSelector:@selector(classForParsingJSONDictionary:)]) {
	//...
}
```

2.2，对于每一个Property的名字，即propertyKey，获取对应的JSON key。根据JSON key 来获取对应的值，主要掉用[mtl_valueForJSONKeyPath:success:error:](https://github.com/Mantle/Mantle/blob/master/Mantle/NSDictionary%2BMTLJSONKeyPath.m)

这个方法很简单，比如对应json的keyPath是person.name.first
先分解成person,name,first,然后一层一层的获取json[person][name][first],只不过Mantle在解析的时候，用了个for循环，来给用户反馈，到底错误在哪里。个人感觉用以下两个KVC的方法更简洁一点

```
//验证是否可用KVC
- validateValue:forKeyPath:error:
//用KVC来获取值
- valueForKeyPath:
```

2.3，对于2.2种，获取到的值，利用1.3的NSValueTransformer进行转换，这里只知道NSValueTransformer能够把一个值转换成另一个值就行了，后面会详细讲解如何转换的。

<font color="orange">
Tips:
这里要提到的是，Mantle采用了条件编译方式来处理异常，即debug模式下会抛出异常给开发者，但是release模式下，不会崩溃

```
#if DEBUG
	@throw ex;
#else
	//...			
#endif
```
</font>

2.4 根据以上三步得到的值字典，对每一个key利用KVC进行设置值，KVC设置值之前，调用

```
[obj validateValue:&validatedValue forKey:key error:error]
```
来验证是否可以KVC


----------
NSValueTransformer
------------------
[官方文档](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSValueTransformer_Class/)

>NSValueTranformer是一个抽象的基类，利用Cocoa Bindings技术来进行值的相互转换

既然是一个抽象基类，那么使用的时候要继承这个基类，然后实现必要的方法，从而才能进行相应的值转换。

例如,实现一个简单的NSDate<->NSString转换的Transformer

```
@interface LHValueTransformer : NSValueTransformer

@end

@implementation LHValueTransformer

+(BOOL)allowsReverseTransformation{
    return YES;
}
+(Class)transformedValueClass{
    return [NSString class];
}
-(NSDateFormatter *)dateFormatter{
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return formatter;
}
-(id)transformedValue:(id)value{
    NSAssert([value isKindOfClass:[NSDate class]], @"Should a NSDate value");
    
    return [[self dateFormatter] stringFromDate:value];
}
-(id)reverseTransformedValue:(id)value{
    NSAssert([value isKindOfClass:[NSString class]], @"Should be a NSString value");
    return [[self dateFormatter] dateFromString:value];
}
@end
```
然后，这样掉用

```
    NSValueTransformer * trans = [[LHValueTransformer alloc] init];
    
    NSDate * date = [NSDate date];
    NSString * str = [trans transformedValue:date];
    NSDate * date2 = [trans reverseTransformedValue:str];
```

>MTLValueTransformer就是这样的一个子类，只不过它提供了正反两个转换的block作为接口。

----------
isEqual，NSCopying，hash
-------------------
实现NSCopying和hash很简单，就是基类根据Runtime动态的获取所有的属性，然后对应的进行操作就可以了

```

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
	MTLModel *copy = [[self.class allocWithZone:zone] init];
	[copy setValuesForKeysWithDictionary:self.dictionaryValue];
	return copy;
}

#pragma mark NSObject

- (NSString *)description {
	NSDictionary *permanentProperties = [self dictionaryWithValuesForKeys:self.class.permanentPropertyKeys.allObjects];

	return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, permanentProperties];
}

- (NSUInteger)hash {
	NSUInteger value = 0;
    //每个value取hash值
	for (NSString *key in self.class.permanentPropertyKeys) {
		value ^= [[self valueForKey:key] hash];
	}

	return value;
}

- (BOOL)isEqual:(MTLModel *)model {
	if (self == model) return YES;
	if (![model isMemberOfClass:self.class]) return NO;

	for (NSString *key in self.class.permanentPropertyKeys) {
		id selfValue = [self valueForKey:key];
		id modelValue = [model valueForKey:key];
        //每一个value取isEqual
		BOOL valuesEqual = ((selfValue == nil && modelValue == nil) || [selfValue isEqual:modelValue]);
		if (!valuesEqual) return NO;
	}

	return YES;
}
```
----------

NSCoding
--------
NSCoding的支持有些复杂，源代码[MTLModel+NSCoding.m](https://github.com/Mantle/Mantle/blob/master/Mantle/MTLModel%2BNSCoding.m)

对于`initWithCoder:`
1. 根据Runtime，获取所有的属性名字
2. 对于每一个属性，检查是否响应`decodeWithCoder:modelVersion:`,也就是说，支持属性也是MTLModel对象，如果是，则调用`decodeWithCoder:modelVersion:`解析这个MTLModel
3. 如果不是MTLModel子类，则调用`decodeObjectForKey`来解析，这里的key就是属性的名字

encodeWithCoder类似，不做讲解

----------

异常处理
----

Mantle中，有一些

```
@try{}
@catch{}
@finally{}
```

并且在catch模块中

```
#if DEBUG
	@throw ex;
#else
    //其它处理
#endif

```
这样能够方便调试错误，并且在运行时的时候不崩溃。

同时，你还能看到这样的代码

```
mtl_propertyAttributes *attributes = mtl_copyPropertyAttributes(property);
@onExit {
	free(attributes);
};
```
这里的`@onExit`是一个宏定义，保证代码在在当前域返回（return，break，异常）始终能执行到。其实本质就是把代码放到了finally里

----------

\__attribute__
--------------

\__attribute__机制能够为方法，变量，类型增加额外的属性。

<font color="red">增加的额外属性，能够让编译器进行额外的检查，从而提供额外的提示</font>
比如

```
@property (nonatomic, strong, readonly) id<MTLJSONSerializing> model __attribute__((unavailable("Replaced by -modelFromJSONDictionary:error:")));

+ (NSArray *)JSONArrayFromModels:(NSArray *)models __attribute__((deprecated("Replaced by +JSONArrayFromModels:error:"))) NS_SWIFT_UNAVAILABLE("Replaced by +JSONArrayFromModels:error:");
```
就分别提示model当前不可用unavailable，和`JSONArrayFromModels`方法被`deprecated`

<font color="red">后面有时间了，系统的整理下所有的\__attribute__,今天很晚了，先这样吧</font>

----------