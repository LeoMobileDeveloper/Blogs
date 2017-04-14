前言
--

> 工欲善其事，必先利其器

好像在哪听到一句话，"满级程序员不需要IDE，不需要自动补全，不需要静态语法检查"。对于这种言论，我只想说<font color="red">bullshit</font>。

IDE对于开发还是很重要的，而React Native开发官方推荐使用Atom＋Nuclide插件。本文会详细的介绍，如何配置好这个环境，并且以一个示例工程为例，<font color="orange">介绍如何利用这套环境进行开发，与运行，调试，断点</font>。

使用Nuclide你能够

 - 配合flow进行静态语法检查，自动补全
 - 方便的debug
 - 进行版本控制，方便diff
 - iOS模拟器Log

对了,<font color="orange">为了从零开始，我卸载了之前安装好的atom和对应的插件</font>

----------
Mac/Windows/Linux
-----------------
推荐还是用Mac开发React Native，因为iOS运行需要Mac的环境。而且，用Mac的话，也比较省心。

<font color="red">本文的所有流程，均以Mac为例</font>

----------

准备工作
----
本文默认读者已经安装好了React Native，如果没有安装好，可以按照[官网](https://facebook.github.io/react-native/docs/getting-started.html#content)的讲解安装，很简单，本文侧重IDE

注意，如果没有安装watchman 和Flow，建议安装

<font color="blue">安装watchman－自动监听文件内容变化，刷新数据</font>
```
brew install watchman
```
如果提示没有安装brew

```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
<font color="blue">安装flow－提供静态语法检查，自动补全</font>

```
brew install flow
```
<font color="blue">如果你之前安装了flow或者watchman,建议更新到最新版本</font>

```
brew upgrade watchman
brew upgrade flow
```

----------


安装Atom
------
[下载地址](https://atom.io/)
这个没什么难的，解压缩之后，把Atom从下载目录，拖到应用程序目录即可。
打开Atom，你看到的界面应该是这样的
<img src="http://img.blog.csdn.net/20160608102309975"  width="600">


----------

安装Nuclide
---------
这里，我们在Atom中，用图形化界面来安装。

点击菜单栏：<font color="blue">Atom->Preferences</font>,或者可以"Command+,"快捷打开

然后，在Install Packets的输入框中，输入nuclide，出现的第一个就是我们想要安装的，点击<font color="blue">install</font>
<img src="http://img.blog.csdn.net/20160608102754195" width="500">

默认安装nuclide之后，会安装一大堆的依赖包，安装完成后
<img src="http://img.blog.csdn.net/20160608103834149" width="500">
可以看到，红色部分是额外的Toolbar可以快捷打开一些选项，小的红色框里多了一个<font color="blue">nuclide</font>选项。

如果没有默认安装这些依赖包，可以选中,<font color="blue">Packages->Settings View->Manage Packets</font>
<img src="http://img.blog.csdn.net/20160608104302936" width="300">

然后，<font color="blue">搜索nuclide，再nuclide package上双击，进入设置</font>
<img src="http://img.blog.csdn.net/20160608104408360" width="400">

勾选<font color="blue">Install recommended packets on startup</font>
<img src="http://img.blog.csdn.net/20160608104750563" width="400">

<font color="blue">退出Atom，再打开，会发现自动安装这些依赖包</font>

----------

新建一个工程
------
 
```
react-native init Demo --verbose
```
然后，打开Atom，点击<font color="blue">Add project folder</font>
<img src="http://img.blog.csdn.net/20160608112958470" width="200">
再在右侧目录双击index.ios.js,你看到的应该是这样的界面
<img src="http://img.blog.csdn.net/20160608113148051" width="500">

----------

自动补全
----
我们在这一行上面，输入fun
```
class Demo extends Component {
```
会看到
<img src="http://img.blog.csdn.net/20160608113725310" width="300">
然后，会车，你就会发现自动生成了方法
```
function functionName() {

}
```
<font color="red">自动补全肯定没有XCode 或者Android Studio来的那么强力，不过有总比没有好对吧。</font>

----------

类型标注
----
将光标放到上文提到的`functionName`上，你会发现如图，就是出现了这个方法的类型
<img src="http://img.blog.csdn.net/20160608114140566" width="400">
这时候，点击出现的针头，那么这个类型标注就会一直显示在界面上
<img src="http://img.blog.csdn.net/20160608114300647" width="400">

----------
语法检查
----
我们在function里随便输入
```
function functionName() {
  a
}
```
然后，command+s保存文件，这时候，正常会出现如下检查错误
![这里写图片描述](http://img.blog.csdn.net/20160608114735482)

其中

 - 1，表示这一行有错误，点击那个红色的三角图标，你可以看到详细的错误描述
 - 2，表示整个工程的错误

点击2，你会看到错误和警告的列表
![这里写图片描述](http://img.blog.csdn.net/20160608114915963)

<font color="red">如果这里，没有检查出错误</font>

打开终端，cd到工程的根目录,例如我的

```
/Users/huangwenchen/Desktop/Demo
```
然后，用终端检查flow能否正常工作

```
Leo-2:Demo huangwenchen$ flow
```
如果出现错误

```
.flowconfig:97 Wrong version of Flow. The config specifies version ^0.25.0 but this is version 0.20.1
Leo-2:Demo huangwenchen$ brew update flow
```
证明你本地的flow版本和react native默认使用的flow版本不一致，通常，更新到最新版本即可

```
Leo-2:Demo huangwenchen$ brew upgrade flow
==> Upgrading 1 outdated package, with result:
flow 0.25.0
==> Upgrading flow
==> Downloading https://homebrew.bintray.com/bottles/flow-0.25.0.el_capitan.bottle.tar.gz
######################################################################## 100.0%
==> Pouring flow-0.25.0.el_capitan.bottle.tar.gz
==> Caveats
```

----------

跳转到方法或者类型定义
-----------
使用command+鼠标左键

----------

在Nuclide运行项目
----------
<font color="blue">第一步，运行react native packager</font>

点击 command + shift + p打开command palette（打开终端选项），然后输入

```
react native start
```
![这里写图片描述](http://img.blog.csdn.net/20160608125428714)

然后，选择
**Nuclide React Native :Start packager**
 
 <font color="red">如果，出现错误</font>
 
```
/Users/huangwenchen/Desktop/Demo/node_modules/react-native/local-cli/cli.js:123
class CreateSuppressingTerminalAdapter extends TerminalAdapter {
^^^^^
SyntaxError: Unexpected reserved word
    at exports.runInThisContext (vm.js:73:16)
    at Module._compile (module.js:443:25)
    at Object.Module._extensions..js (module.js:478:10)
    at Module.load (module.js:355:32)
    at Function.Module._load (module.js:310:12)
    at Function.Module.runMain (module.js:501:10)
    at startup (node.js:129:16)
    at node.js:814:3
```
说明你node的版本太低,运行以下命令更新

```
sudo npm cache clean -f
sudo npm install -g n
sudo n stable
```

<font color="blue">第二步，终端运行项目</font>
cd到项目目录，执行
```
$ react-native run-ios
$ react-native run-android
```

----------

在Nuclide中调试
-----------
 执行完上面一步后，你应该会看到这样的模拟器界面
 <img src="http://img.blog.csdn.net/20160608130658104" width="200">
 
 然后，在Nuclide中，点击 command + shift + p打开command palette（打开终端选项），输入react native debug
 
 <img src="http://img.blog.csdn.net/20160608130934376" width="500">
 
 接着，点击模拟器，Command+D，选择Enable Remote JS debugging
 <img src="http://img.blog.csdn.net/20160608131152231" width="200">
 这时候，你会看到，Nuclide中，加载了debug窗口
 <img src="http://img.blog.csdn.net/20160608131254521" width="600">

----------

添加断点
----
和很多IDE一样，在每一行左边左键可以添加断点了
![这里写图片描述](http://img.blog.csdn.net/20160608131823998)

同时，修改代码看看效果

```
function myLog() {
  console.log("adtad");
}
class Demo extends Component {
  render() {
    myLog();
      return (
      <View style={styles.container}>
        <Text style={styles.welcome}>
          Welcome to React Native!
        </Text>
        ......
```
保存，点击模拟器，Command＋R，会发现，停在了断点处
![这里写图片描述](http://img.blog.csdn.net/20160608132026812)

其它的都是JS的调试技巧了，这里不再赘述，后面写博客的时候，遇到了再说。

----------

Element Inspector
-----------------
像网页调试，你可以再浏览器里动态修改网页的HTML代码，在React Native中调试你也可以
Command + shift + p然后打开如下图
![这里写图片描述](http://img.blog.csdn.net/20160608132544470)
接着，你就会发现像HTML的Element Inspector出现了，你可以看到视图的布局和对应的属性

![这里写图片描述](http://img.blog.csdn.net/20160608132800737)


----------

总结
--

> Facebook出品的一般都容易安装，并且使用起来上手相对容易。本文更多的是对[英文文档](https://nuclide.io/docs/platforms/react-native/#debugging)的总结，以及列出了我在安装使用过程中遇到的一些坑，希望能有些帮助。


