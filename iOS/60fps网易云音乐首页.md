## 前言
网易云音乐是一款很优秀的音乐软件，我也是它的忠实用户。最近在研究如何更好的开发TableView，接着我写了一个Model驱动的小框架 - [MDTable](https://github.com/LeoMobileDeveloper/MDTable)。为了去验证框架的可用性，我选择了网易云音乐的首页来作为Demo，语言是Swift 3。

本文的内容包括：

- 实现网易云音乐首页的思路
- 建立一个轻量级的`UITableViewController`（不到100行）
- 性能瓶颈原因以分析及如何优化到接近60fps

> Note：本文并没有用Reveal去分析网易云音乐iOS客户端的原始UI布局，所以实现方式肯定和原始App有出入。另外，本文仅代表个人观点，与雇主没有任何关系。

最后效果如下

<img src="https://raw.githubusercontent.com/LeoMobileDeveloper/React-Native-Files/master/Demo.gif" width="300">


---

## 容器
整体上分析来看，网易云音乐的首页是一个异构的滚动视图。由上至下依次是：

- Banner - 轮播
- Menu - 三个入口
- 6个分类，推荐歌单，独家放送，推荐MV，精选专栏，主播电台，最新音乐。每一个分类的UI布局都不一样。

并且这些布局都不是动态的，所谓动态的就是向淘宝京东首页那种，做不同的活动，首页可以按照不同的方式去显示内容，而不需要从App Store下载新的版本。

基于这些，有两种实现方式：

> 用单纯的UIScrollView作为容器，其他的内容作为SubView添加到ScrollView中，但要手动控制每一个视图进入屏幕和消失的事件，来进行图片的懒加载。采用这种方式可以选择天猫开源的[LazyScrollView](https://github.com/alibaba/LazyScrollView)
> 
> 用UITableView作为容器，其他的每一行内容都是一个Cell。

本文选择了后者，原因也很简单：我是为了评估[MDTable](https://github.com/LeoMobileDeveloper/MDTable)，而[MDTable](https://github.com/LeoMobileDeveloper/MDTable)是一个基于TableView的框架。

---
## Banner

网易云音乐Banner的最上面是一个轮播图，效果如下

<img src="http://img.blog.csdn.net/20170725163559492?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="320">

可以看到视图大致分为两部分：

- ScrollView - 容器
- ItemView - 轮播的具体内容
	- ImageView - 背景图
	- Label - 标签，就是图中的广告部分。

轮播图有很多种实现方式，这里我选择了之前写的[ParallexBanner](https://github.com/LeoMobileDeveloper/MDTable/blob/master/MDTableExample/ParallexBanner.swift)。

这是一个支持视差效果的Banner，所谓视差效果，就是类似这种：

<img src="http://img.blog.csdn.net/20160728110416509" width="300">

ParallexBanner原理我在[这篇博客](http://blog.csdn.net/hello_hwc/article/details/52057035)里有详细介绍，这里就不浪费篇幅了。

另外，那个标签Label也很容易实现，只要用一个左边是圆角的UILabel即可，这里写了个方便的扩展

```
extension UIView {
    func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }
}
```
---
## Menu

Menu的目标效果如下：

<img src="http://img.blog.csdn.net/20170725163612191?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="300">

中间的“每日歌曲推荐”这个选项有点意思，因为中间的文字是会随着日期变的。实现起来也很简单，图片留白，中间放一个Lable即可。

这是最后我选择的布局方式：

<img src="http://img.blog.csdn.net/20170725185654043?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="200">

侧面看起来：

<img src="http://img.blog.csdn.net/20170725185703729?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="200">

也就是说，SubView是这样子的：

- UIImageView - 红色背景圆圈
- UILabel - 标题（每日歌曲推荐）
- UIImageView - 图标（日历图标）
- UILabel - 日期时间（25）

Note: 这里先不管按下态，按下态在下文统一讲解。

---
## Cells
我们先从UI效果入手，一共有六种异构的Cell。

<img src="http://img.blog.csdn.net/20170726105621998?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast">

<img src="http://img.blog.csdn.net/20170726105632845?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast">

第一个冒出来的想法是Cell中放置CollectionView，CollectiionViewLayout也很简单，采用系统提供的FlowLayout即可。

图个省事，每一个CollectionViewCell我都采用Xib的方式，用AutoLayout布局的。

<img src="http://img.blog.csdn.net/20170726111709955?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="300">

然后，每一个TableViewCell的子类如下：

```
 //初始化
 override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
    let flowLayout = UICollectionViewFlowLayout()
    flowLayout.itemSize = CGSize(width: xxx, height: xxx)
    collectionView = UICollectionView(frame: contentView.bounds, collectionViewLayout: flowLayout)
    contentView.addSubview(collectionView)
    let nib = UINib(nibName: "xxx", bundle: Bundle.main)
    collectionView.register(nib, forCellWithReuseIdentifier: "cell")
}
```

用CollectionView写的第一个版本[在这里](https://github.com/LeoMobileDeveloper/MDTable/tree/d873ec3ecd3201abc00d1712737b9263ddbaccd9)。 感兴趣的同学可以下载下来看看，进入界面后滚动，能够明显的感到掉帧，具体的优化过程在后文。

### 蒙版

像这样的一个视图，需要在图像上展示白色的图标和文字，这就引入了一个问题：

> 如果展示文字的区域的背景图也是白色的怎么办？

<img src="http://img.blog.csdn.net/20170726121259385?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="200">

答案是在图片上面盖一层半透明的渐变蒙版：

<img src="http://img.blog.csdn.net/20170726121309472?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="230">


---
## 按下态

所谓按下态就是当你的手指放到一个视图上，UI会有一些变化告诉用户。比如网易云音乐的按下态是图片上加上一个半透明的遮罩：

<img src="http://img.blog.csdn.net/20170727162804365?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="200">

实践的过程中发现，视图有如下特点：

- 支持点击手势
- 支持长按手势
- 手指接触后一小段时间（0.1秒）左右才会显示按下态，直接点击并不会出现一瞬间的半透明遮罩
- 按下态触发后，上下移动并不会造成TableView滚动

<img src="http://img.blog.csdn.net/20170727164610745?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast" width="200">

看来想要实现这种效果，不是简单的重写`touchBegan`之类的方法就能实现了。

最后，我选择了三种手势，分别用来处理点击，长按和按下态，源代码[AvatarItemView](https://github.com/LeoMobileDeveloper/MDTable/blob/master/MDTableExample/AvatarItemView.swift)。点击和长按没什么好说的，主要讲解下按态：

按下态采用一个Lazy的CoverView：

```
lazy var highLightCoverView: UIView = {
    let view = UIView().added(to: self)
    view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    return view
}()
```

按下由一个长按手势触发：

```
highLightGesture = UILongPressGestureRecognizer(...)
highLightGesture.delegate = self
highLightGesture.minimumPressDuration = 0.1
//手势
func handleHight(_ sender: UILongPressGestureRecognizer){
    switch sender.state {
    case .began,.changed:
        let location = sender.location(in: self)
        let touchInside = self.bounds.contains(location)
        avatarImageView.highLightCoverView.isHidden = !touchInside
    default:
        avatarImageView.highLightCoverView.isHidden = true
    }
}
```

同时，为了防止两个长按手势冲突，实现手势代理方法，和保证按下态的时候TableView不滚动：

```
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    if otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self){
        return false
    }
    if gestureRecognizer == longPresssGesture {
        return false
    }
    return true
}
```

---
## Controller

开发MDTable的目的就是获得一个更轻量级的TableView。事实上，在Controller里，我只用15行代码就实现了这个样一个复杂的TableView。

```
 DispatchQueue.global(qos: .userInteractive).async {//准备MDTable的数据
    let menuSection = MenuSection.mockSection
    let recommendSection = RecommendSection.mockSection
    let exclusiveSection = ExclusiveSection.mockSection
    let mvSection = NMMVSection.mockSection
    let columnistSection = NeteaseColumnlistSection.mockSection
    let channelSection = ChannelSection.mockSection
    let latestMusicSection = LatestMusicSection.mockSection
    self.sections = [menuSection,recommendSection,exclusiveSection,mvSection,columnistSection,channelSection,latestMusicSection]
    DispatchQueue.main.async {//绑定数据
        self.tableView.manager = TableManager(sections: self.sections)
        self.tableView.tableFooterView = footer
    }
}
```
以主播电台为例，对应Controller中的这一行

```
let channelSection = ChannelSection.mockSection
```

ChannelSection是MDTable提供的基础类型Section的子类：表示主播电台这个TableView Section，对应MVVM设计模式中的ViewModel角色

```
class ChannelSection: Section, SortableSection{
    static var mockSection:ChannelSection{
        get{
            let channelTitleRow = NMColumnTitleRow(title: "主播电台")
            let channelRow = NMChannelRow(channels: channels)
            let channelSection = ChannelSection(rows: [channelTitleRow,channelRow])
            return channelSection
        }
    }
}
```

其中，NMChannelRow是ReactiveRow的子类，对应MVVM设计模式中的ViewModel角色

```
class NMChannelRow:ReactiveRow {
    var channels:[NMChannel] //Models
    var isDirty = true
    init(channels:[NMChannel]){
        self.channels = channels
        super.init()
        //行高相关信息
        self.rowHeight = NMChannelConst.itemHeight * 2.0 
        self.reuseIdentifier = "NMChannelRow"
        self.shouldHighlight = false
        self.initalType = .code(className: NMChannelCell.self)
    }
}
```
接着，我们再来看看NMChannelCell，也就是View的角色

```
class NMChannelCell: MDTableViewCell {
    weak var row:NMChannelRow?    
    override func render(with row: RowConvertable) {
    	 //重写render方法，把ViewModel绑定到View
        guard let _row = row as? NMChannelRow else {
            return;
        }
        self.row = _row
        if _row.isDirty{
            _row.isDirty = false
            reloadData()
        }
    }
}
```
---
## 排序
因为是模型驱动的TableView，只要修改模型的顺序即可。这里定义了一个协议，表示一个Section支持可排序：

```
protocol SortableSection {
    var sortTitle: String {get set} //排序的标题
    var sequence: Int {get set} // 顺序
    var defaultSequeue:Int {get} //默认顺序
    var identifier: String {get} //唯一id
}
```
接着，我们只需要在点击排序的时候，对Section进行过滤即可

```
let sortableSections = sections.filter { $0 is SortableSection }.map{$0 as! SortableSection}
let sortController = NeteaseCloudMusicSortController(sections: sortableSections)
let navController = BaseNavigationController(rootViewController: sortController)
present(navController, animated: true, completion: nil)
```

---
## 性能优化

到这里，我用MDTable很容易的就实现了网易云音乐的首页。但是卡顿的首页不是我想要的（事实上网易云音乐在5s上上下滚动能够感受到明显的卡顿），于是就开始了漫长的性能优化之路。如果你对卡顿分析好无头绪，建议先读读ibireme的这篇文章：《[iOS 保持界面流畅的技巧](http://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/)》。

### 分析卡顿

> 分析卡顿一般会从CPU和GPU两个方面入手，相信我除非你的UI层次特别复杂，比如大量的阴影遮罩之类的，一般来说GPU都不是卡顿的瓶颈。

卡顿的原因一般有三个：

- UI对象的创建，属性修改
- 布局
- 渲染

iOS设备是每秒60帧，也就是说一帧从"CPU计算->GPU渲染->显示"只有16.7ms。
一般来说，当你在滚动的时候，发现CPU持续占用超过50ms，肉眼就能明显的感觉到掉帧，肉眼很难分别出60fps和59fps。

首先分析CPU，使用工具Time Profiler：

<img src="http://img.blog.csdn.net/20170727183414235?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast">

### 图片解码

图片解码是一个常见的优化点，原因是

> 当你创建一个UIImage的时候，默认发生实际的解码，只有当图片要被显示到屏幕上的时候，才会发生实际的解码，解码是在CPU上进行了。

由于Demo是采用`UIImage(named:"")`，并不会后台解码，于是写了个异步设置的方法

```
func asyncSetImage(_ image:UIImage){
    DispatchQueue.global(qos: .userInteractive).async {
        let decodeImage = image.decodedImage()
        DispatchQueue.main.async {
            self.image = decodeImage
        }
    }
}
```

> 解码的原理也很简单，提前把图片绘制到一个CGContext中，再从Context获取图片，这样能够强制图片解码。通常三方库（KingFisher,SDWebImage）都自带后台解码。

### XIB

这是我用CollectionView实现第一个版本时候的截图：

<img src="http://img.blog.csdn.net/20170727184036353?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast">

可以清楚的看到，初始化xib占用了11ms。原理也很简单，直接从代码创建和读文件创建，肯定读文件要慢很多，

于是，第一个优化点就是

> **删除xib文件，用代码手动写。**

### AutoLayout

AutoLayout是一种很方便的技术，通过添加约束我们可以实现各种复杂的布局。但是同样，它也是很昂贵的，CPU在布局的时候需要进行不少计算。眼神阅读：[Auto Layout Performance on iOS](http://floriankugler.com/2013/04/22/auto-layout-performance-on-ios/)。

所以，这个优化点很容易想到：

> **用手动Layout代替AutoLayout**。其实优化AutoLayout对本文的场景带来的性能提升并不大，因为我们的视图较少，并且层级简单。但是写Demo的时候，我不想再引入一套DSL进行AutoLayout，手动Layout代码还清楚一些。

### reload

接着我发现，每次滚动的时候时候都调用collectionView.reload()是一件很蠢的事情，因为数据没改变，那么UI也不会改变，reload()只会带来额外的性能开销，于是给Row增加了一个isDirty属性，只有isDirty为true的时候，才reload。

```
if _row.isDirty{
    _row.isDirty = false
    reloadData()
}
```

> 经过这个处理，在第一次滚动到底部的时候会掉帧，之后再也不会掉帧了。原因也很简单，我们的所有Cell都是异构的，第一次滚动到底部后，都已经加载到内存里，所以不再有额外的创建对象和Layout的开销。

### 轻量级的View

CollectionView是一个昂贵的视图，它有各种的代理方法，并且需要根据`UICollectionViewLayout`动态的计算出每一个Cell的大小和位置。考虑到我们的布局比较简单，于是全部改写成简单的UIView，布局代码在视图的LayoutSubViews中写。


### 预计算Layout
我们继续用TimeProfile进行分析：

<img src="http://img.blog.csdn.net/20170728104507559?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast">

可以看到LayoutSubviews竟然占用了11ms，双击这一行，看看是什么代码占用了这么多时间：

<img src="http://img.blog.csdn.net/20170728104733226?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvSGVsbG9fSHdj/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast">

可以看到，`sizeToFit`应该就是罪魁祸首了，因为让Label去自适应大小是需要额外的CPU计算。

> 文本的大小计算是很损耗性能的，如果你的App中用到了大量的富文本（类似微博），那么基于CoreText打造一个异步的绘制引擎是一个不错的优化点，当然直接用[YYText](https://github.com/ibireme/YYText)也可以。

### 预加载 & Runloop

到这里，继续用Time Profiler分析发现主线程的CPU占用几乎都在main函数里了。我们来分析，在Cell显示到屏幕上CPU都干了什么：

- 创建Cell的实例
- 对Cell的实例和Model进行绑定，换句话说就是调整UI控件的属性
- 根据内容进行重新布局

这些任务有一个特点：**必须在主线程上进行**。

任务不能调度到后台，那么只能从两个方面入手了：

- 预加载。对模版Cell进行提前创建，并且放入内存缓存。这样显示到屏幕的时候，就不再需要重新创建Cell的对象了。
- 任务拆分。将大的任务拆分成小的任务，一次执行一个，这样瞬时CPU占用就不会很高。

先来分析预加载，什么时候预加载呢？一次预加载几个Cell呢？

> 这里采用监听主线程Runloop的方式进行加载，监听`beforeWaiting`和`exit`两个事件，这时候去执行一些任务。

核心代码`TaskDispatcher`类：每一个Runloop中，`TaskDispatcher `只执行一个任务

```
let mainRunloop = RunLoop.main.getCFRunLoop()
let activities = CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue
observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                                  activities,
                                                  true,
                                                  Int.max) { (observer, activity) in
    self.executeTask()
}
let runLoopMode = (mode == .common) ? CFRunLoopMode.commonModes : CFRunLoopMode.defaultMode
CFRunLoopAddObserver(mainRunloop, observer, runLoopMode)
```

TaskDispatcher有两个模式

```
enum TaskExecuteMode {
    case `default` //用来预加载cell，滚动的时候停止预加载
    case common //用来对大任务进行拆分
}
```

于是，预加载变成了这样子：

```
TaskDispatcher.default.add(row.reuseIdentifier, {
  	//预加载Cell
})
```

在CellForRow中，首先检查预加载缓存，如果有，直接返回缓存数据。

### 任务拆分
在对每一行reloadData的时候，我们需要调整6个subView的属性，对其进行Layout。我们可以利用之前写的TaskDispatcher对六个任务进行拆分：

```
for i in 0..<row.musics.count{
    TaskDispatcher.common.add("Music\(i)") {
        let style:MusicCollectionCellStyle = i == 0 ? .slogen : .normal;
        let music = row.musics[i]
        let itemView = self.itemViews[i]
        itemView.config(music, style: style)
    }
}
```


---
## 总结

> 性能分析就是一句话：能放到后台的就放到后台，不能放到后台的要么预加载，要么拆分。另外还有一个Facebook出品的三方库非常推荐：[Texture](https://github.com/TextureGroup/Texture)，这个是一个异步显示框架，会省去很多事。

感兴趣的同学可以下载Demo工程跑跑看

- [MDTable](https://github.com/LeoMobileDeveloper/MDTable)

