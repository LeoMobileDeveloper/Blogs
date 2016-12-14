```
export LC_ALL=zh_CN.GB2312;
export LANG=zh_CN.GB2312
buildConfig="Release" //这里是build模式
projectName=`find . -name *.xcodeproj | awk -F "[/.]" '{print $(NF-1)}'`
projectDir=`pwd`
wwwIPADir=~/Desktop/$projectName-IPA
isWorkSpace=true
echo "~~~~~~~~~~~~~~~~~~~开始编译~~~~~~~~~~~~~~~~~~~"
if [ -d "$wwwIPADir" ]; then
echo $wwwIPADir
echo "文件目录存在"
else
echo "文件目录不存在"
mkdir -pv $wwwIPADir
echo "创建${wwwIPADir}目录成功"
fi
cd $projectDir
rm -rf ./build
buildAppToDir=$projectDir/build
infoPlist="$projectName/Info.plist"
bundleVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $infoPlist`
bundleIdentifier=`/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" $infoPlist`
bundleBuildVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $infoPlist`

if $isWorkSpace ; then  #是否用CocoaPod
echo  "开始编译workspace...."
xcodebuild  -workspace $projectName.xcworkspace -scheme $projectName  -configuration $buildConfig clean build SYMROOT=$buildAppToDir
else
echo  "开始编译target...."
xcodebuild  -target  $projectName  -configuration $buildConfig clean build SYMROOT=$buildAppToDir
fi

if test $? -eq 0
then
echo "~~~~~~~~~~~~~~~~~~~编译成功~~~~~~~~~~~~~~~~~~~"
else
echo "~~~~~~~~~~~~~~~~~~~编译失败~~~~~~~~~~~~~~~~~~~"
exit 1
fi

ipaName=`echo $projectName | tr "[:upper:]" "[:lower:]"` #将项目名转小写
findFolderName=`find . -name "$buildConfig-*" -type d |xargs basename` #查找目录
appDir=$buildAppToDir/$findFolderName/  #app所在路径
echo "开始打包$projectName.app成$projectName.ipa....."
xcrun -sdk iphoneos PackageApplication -v $appDir/$projectName.app -o $appDir/$ipaName.ipa

if [ -f "$appDir/$ipaName.ipa" ]
then
echo "打包$ipaName.ipa成功."
else
echo "打包$ipaName.ipa失败."
exit 1
fi

path=$wwwIPADir/$projectName$(date +%Y%m%d%H%M%S).ipa
cp -f -p $appDir/$ipaName.ipa $path   #拷贝ipa文件
echo "复制$ipaName.ipa到${wwwIPADir}成功"
echo "~~~~~~~~~~~~~~~~~~~结束编译，处理成功~~~~~~~~~~~~~~~~~~~"

```
