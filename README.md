
# react-native-syan-image-picker

[![npm](https://img.shields.io/npm/v/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/dm/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/dt/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/l/react-native-syan-image-picker.svg)](https://github.com/syanbo/react-native-syan-image-picker/blob/master/LICENSE)

## 功能介绍

基于已有原生第三方框架封装的多图片选择组件，适用于 React Native App。

### 原生框架依赖
* Android： [PictureSelector 2.2.0](https://github.com/LuckSiege/PictureSelector) - by [LuckSiege](https://github.com/LuckSiege)
* iOS：[TZImagePickerController 2.0.0.4](https://github.com/banchichen/TZImagePickerController) - by [banchichen](https://github.com/banchichen)

### 功能特点
* 支持 iOS、Android 两端
* 支持单选、多选
* 可自定义裁剪区域大小，支持圆形裁剪
* 可设置压缩质量
* 支持返回图片 base64 编码

## 运行截图
![](http://oy5rz3rfs.bkt.clouddn.com/2018-03-31-syan.gif)

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
2. 使用 Android Studio 查看 `MainApplication
