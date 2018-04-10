
# react-native-syan-image-picker

[![npm](https://img.shields.io/npm/v/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/dm/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/dt/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/l/react-native-syan-image-picker.svg)](https://github.com/syanbo/react-native-syan-image-picker/blob/master/LICENSE)

## 功能介绍

基于已有原生第三方框架封装的多图片选择组件，适用于 React Native App。

### 原生框架依赖
* Android： [PictureSelector 2.2.2](https://github.com/LuckSiege/PictureSelector) - by [LuckSiege](https://github.com/LuckSiege)
* iOS：[TZImagePickerController 2.0.0.4](https://github.com/banchichen/TZImagePickerController) - by [banchichen](https://github.com/banchichen)

### 功能特点
* 支持 iOS、Android 两端
* 支持单选、多选
* 可自定义裁剪区域大小，支持圆形裁剪
* 可设置压缩质量
* 可设置是否返回图片 base64 编码
* 支持记录当前已选中的图片
* 支持删除指定下标的图片

### Live

![](http://oy5rz3rfs.bkt.clouddn.com/github/syan-01.gif)


## 安装使用

### 安装
```
// Step 1 基于 npm
npm install react-native-syan-image-picker --save

// 或是 yarn
yarn add react-native-syan-image-picker

// Step 2 执行 link
react-native link react-native-syan-image-picker

```

### 其他配置
#### iOS
##### 1、添加原生框架中所需的 `bundle` 文件：

- TARGETS -> Build Phases -> Copy Bundle Resources
点击"+"按钮，在弹出的窗口中点击“Add Other”按钮，选择
    ```
    node_modules/react-native-syan-image-picker/ios/TZImagePickerController/TZImagePickerController.bundle
    ```

##### 2、添加相册相关权限：

- 项目目录->Info.plist->增加

```
 Privacy - Camera Usage Description 是否允许此App使用你的相机进行拍照？
 Privacy - Photo Library Usage Description 请允许访问相册以选取照片
 Privacy - Photo Library Additions Usage Description 请允许访问相册以选取照片
 Privacy - Location When In Use Usage Description 我们需要通过您的地理位置信息获取您周边的相关数据
```

##### 3、中文适配：    
- 添加中文 PROJECT -> Info -> Localizations 点击"+"按钮，选择Chinese(Simplified)

#### Android

##### 1、在 `build.gradle` 中添加 `maven { url "https://jitpack.io" }` 和`Google` 配置：
```gradle
buildscript {
    repositories {
        jcenter()
        maven {
            url 'https://maven.google.com/'
            name 'Google'
        }
        google()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:2.2.3'

        // NOTE: Do not place your application dependencies here; they belong
        // in the individual module build.gradle files
    }
}
allprojects {
    repositories {
        mavenLocal()
        jcenter()
        maven { url "https://jitpack.io" }
        maven {
            // All of React Native (JS, Obj-C sources, Android binaries) is installed from npm
            url "$rootDir/../node_modules/react-native/android"
        }
    }
}
```

##### 2、在 `AndroidManifest.xml` 中添加权限：
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CAMERA" />
```

##### 3、更新到 PictureSelector 2.2.0 需要修改：
```gradle
// app/build.gradle

android {
    compileSdkVersion 26
    buildToolsVersion "26.0.3"
    ...
}
```
 
### 注意安装运行报错
1. 检查自动 link 是否成功 
2. 使用 Android Studio 查看 `MainApplication.java` 文件是否添加 `new RNSyanImagePickerPackage()`
3. 使用 Android Studio 打开项目检查 Gradle 是否同步完成
4. 可以运行 [ImagePickerExample](https://github.com/syanbo/ImagePickerExample) 该 Demo，测试 Android 7.0，6.0 拍照选图都为正常

## link失败手动添加
### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-syan-image-picker` and add `RNSyanImagePicker.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNSyanImagePicker.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

### Android

1. Open up `android/app/src/main/java/[...]/MainApplication.java`
  - Add `import com.reactlibrary.RNSyanImagePickerPackage;` to the imports at the top of the file
  - Add `new RNSyanImagePickerPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```gradle
  	include ':react-native-syan-image-picker'
  	project(':react-native-syan-image-picker').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-syan-image-picker/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```gradle
      compile project(':react-native-syan-image-picker')
  	```

## 运行示例

相关 Demo 见 [ImagePickerExample](https://github.com/syanbo/ImagePickerExample)。

## 配置参数说明
组件调用时，支持传入一个 `options` 对象，可设置的属性如下：

属性名              | 类型   | 是否可选 | 默认值      | 描述
----------------  | ------ | -------- | -----------  | -----------
imageCount         | int | 是      | 6  | 最大选择图片数目
isRecordSelected         | bool | 是      | false  | 记录当前已选中的图片
isCamera         | bool | 是      | true  | 是否允许用户在内部拍照
isCrop         | bool | 是      | false  | 是否允许裁剪，imageCount 为1才生效
CropW         | int | 是      | screenW * 0.6  | 裁剪宽度，默认屏幕宽度60%
CropH         | int | 是      | screenW * 0.6   | 裁剪高度，默认屏幕宽度60%
isGif         | bool | 是      | false  | 是否允许选择GIF，暂无回调GIF数据
showCropCircle         | bool | 是      | false  | 是否显示圆形裁剪区域
circleCropRadius         | float | 是      | screenW * 0.5  | 圆形裁剪半径，默认屏幕宽度一半
showCropFrame         | bool | 是      | true  | 是否显示裁剪区域
showCropGrid         | bool | 是      | false  | 是否隐藏裁剪区域网格
quality         | int | 是      | 90  | 压缩质量
enableBase64        | bool | 是      | false  | 是否返回base64编码，默认不返回

## 返回结果说明
以 `Callback` 形式调用时，返回的第一个参数为错误对象，第二个才是图片数组：

属性名              | 类型   | 描述
----------------  | ------ | -----------
error         | object | 取消拍照时不为 null，此时 `error.message` == '取消'
photos        | array | 选择的图片数组

而以 `Promise` 形式调用时，则直接返回图片数组，在 `catch` 中去处理取消选择的情况。

下面是每张图片对象所包含的属性：

属性名              | 类型   | 描述
----------------  | ------ | -----------
width         | int | 图片宽度
height        | int | 图片高度
uri           | string | 图片路径
original_uri  | string | 图片原始路径，仅 Android
type          | string | 文件类型，仅 Android，当前只返回 `image`
size          | int | 图片大小，单位为字节 `b`
base64        | string | 图片的 base64 编码，如果 `enableBase64` 设置 false，则不返回该属性

## 方法调用
### Callback
回调形式需调用 `showImagePicker` 方法：

```javascript
import SyanImagePicker from 'react-native-syan-image-picker';

SyanImagePicker.showImagePicker(options, (err, selectedPhotos) => {
  if (err) {
    // 取消选择
    return;
  }
  // 选择成功，渲染图片
  // ...
})
```
### Promise
非回调形式则使用 `asyncShowImagePicker` 方法：

```javascript
import SyanImagePicker from 'react-native-syan-image-picker';

// promise-then
SYImagePicker.asyncShowImagePicker(options)
  .then(photos => {
    // 选择成功
  })
  .catch(err => {
    // 取消选择，err.message为"取消"
  })

// async/await
handleSelectPhoto = async () => {
  try {
    const photos = await SYImagePicker.asyncShowImagePicker(options);
    // 选择成功
  } catch (err) {
    // 取消选择，err.message为"取消"
  }
}
```
### 移除选中图片
在 React Native 页面移除选中的图片后，需调用 `removePhotoAtIndex` 方法，来删除原生中保存的图片数组，确保下次进入图片选择时，已选中的图片保持一致：
```javascript
handleDeletePhoto = index => {
  const { selectedPhotos: oldPhotos } = this.state;
  const selectedPhotos = oldPhotos.filter((photo, photoIndex) => photoIndex !== index);
  // 更新原生图片数组
  SYImagePicker.removePhotoAtIndex(index);
  // 更新 RN 页面
  this.setState({ selectedPhotos });
}
```

### 移除全部选中图片

```javascript
STImagePicke.removeAllPhoto()
```

### 调用相机
相机功能调用 `openCamera` 方法，一样支持 Callback 和 Promise 两种形式，结果参数也保持一致。

### 删除缓存
```javascript
SYImagePicker.deleteCache();
```

## 帮助
加入 React-Native QQ群 397885169
## 非常感谢

[LuckSiege](https://github.com/LuckSiege/PictureSelector)

[banchichen](https://github.com/banchichen/TZImagePickerController)

[ljunb](https://github.com/ljunb)

## 捐赠
随时欢迎！！☕️☕️☕️✨✨




