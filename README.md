
# react-native-syan-image-picker

[![npm](https://img.shields.io/npm/v/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/dm/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/dt/react-native-syan-image-picker.svg)](https://www.npmjs.com/package/react-native-syan-image-picker)
[![npm](https://img.shields.io/npm/l/react-native-syan-image-picker.svg)](https://github.com/syanbo/react-native-syan-image-picker/blob/master/LICENSE)

## 功能介绍

基于已有原生第三方框架封装的多图片选择组件，适用于 React Native App。

### 原生框架依赖
> * Android： [PictureSelector 2.2.0](https://github.com/LuckSiege/PictureSelector) - by [LuckSiege](https://github.com/LuckSiege)
> * iOS：[TZImagePickerController 2.0.0.4](https://github.com/banchichen/TZImagePickerController) - by [banchichen](https://github.com/banchichen)

### 功能特点
* 支持 iOS、Android 两端
* 支持单选、多选，类型包括图片、GIF
* 可自定义裁剪区域大小，支持圆形裁剪
* 可设置压缩质量
* 支持返回图片 base64 编码

## 运行截图

![](http://oy5rz3rfs.bkt.clouddn.com/github/syan_001.png?imageView/2/w/268)
![](http://oy5rz3rfs.bkt.clouddn.com/github/syan_002.png?imageView/2/w/268)
![](http://oy5rz3rfs.bkt.clouddn.com/github/syan_003.png?imageView/2/w/268)

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

- 项目目录->Info.plist->增加3项
    ```
    "Privacy - Camera Usage Description
    "Privacy - Location When In Use Usage Description"
    "Privacy - Photo Library Usage Description"
    ```
- 记得添加描述
    ```
    Privacy - Camera Usage Description 是否允许此App使用你的相机？
    Privacy - Photo Library Usage Description 是否允许此App访问你的媒体资料库？
    Privacy - Location When In Use Usage Description 我们需要通过您的地理位置信息获取您周边的相关数据
    ```

##### 3、中文适配：    
- 添加中文 PROJECT -> Info -> Localizations 点击"+"按钮，选择Chinese(Simplified)

#### Android

##### 1、在 `build.gradle` 中添加 `maven` 配置：
```gradle
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
  
##### 3、更新到 PictureSelector 2.2.0：
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

相关 Demo 见 [ImagePickerExample](https://github.com/syanbo/ImagePickerExample)。以下为入口文件，可参考使用方式的注释：

```javascript
// react-native-syan-image-picker/index.js
import {
    NativeModules,
    Dimensions,
} from 'react-native';

const { RNSyanImagePicker } = NativeModules;
const { width } = Dimensions.get('window');
/**
 * 默认参数
 */
const defaultOptions = {
    imageCount: 6,             // 最大选择图片数目，默认6
    isCamera: true,            // 是否允许用户在内部拍照，默认true
    isCrop: false,             // 是否允许裁剪，默认false, imageCount 为1才生效
    CropW: ~~(width * 0.6),    // 裁剪宽度，默认屏幕宽度60%
    CropH: ~~(width * 0.6),    // 裁剪高度，默认屏幕宽度60%
    isGif: false,              // 是否允许选择GIF，默认false，暂无回调GIF数据
    showCropCircle: false,     // 是否显示圆形裁剪区域，默认false
    circleCropRadius: width/2, // 圆形裁剪半径，默认屏幕宽度一半
    showCropFrame: true,       // 是否显示裁剪区域，默认true
    showCropGrid: false,       // 是否隐藏裁剪区域网格，默认false
    quality: 90,               // 压缩质量
    enableBase64: false,       // 是否返回base64编码，默认不返回
};

export default {
    /**
     * 以Callback形式调用
     * 1、相册参数暂时只支持默认参数中罗列的属性；
     * 2、回调形式：showImagePicker(options, (err, selectedPhotos) => {})
     *  1）选择图片成功，err为null，selectedPhotos为选中的图片数组
     *  2）取消时，err返回"取消"，selectedPhotos将为undefined
     *  按需判断各参数值，确保调用正常，示例使用方式：
     *      showImagePicker(options, (err, selectedPhotos) => {
     *          if (err) {
     *              // 取消选择
     *              return;
     *          }
     *          // 选择成功
     *      })
     *
     * @param {Object} options 相册参数
     * @param {Function} callback 成功，或失败回调
    */
    showImagePicker(options, callback) {
        const optionObj = {
            ...defaultOptions,
            ...options
        };
        RNSyanImagePicker.showImagePicker(optionObj, callback)
    },

    /**
     * 以Promise形式调用
     * 1、相册参数暂时只支持默认参数中罗列的属性；
     * 2、使用方式
     *  1）async/await
     *  handleSelectPhoto = async () => {
     *      try {
     *          const photos = await SYImagePicker.asyncShowImagePicker(options);
     *          // 选择成功
     *      } catch (err) {
     *          // 取消选择，err.message为"取消"
     *      }
     *  }
     *  2）promise.then形式
     *  handleSelectPhoto = () => {
     *      SYImagePicker.asyncShowImagePicker(options)
     *      .then(photos => {
     *          // 选择成功
     *      })
     *      .catch(err => {
     *          // 取消选择，err.message为"取消"
     *      })
     *  }
     * @param {Object} options 相册参数
     * @return {Promise} 返回一个Promise对象
    */
    asyncShowImagePicker(options) {
        const optionObj = {
          ...defaultOptions,
          ...options,
        };
        return RNSyanImagePicker.asyncShowImagePicker(optionObj);
    },

    /**
     * 打开相机支持裁剪参数
     * @param options
     * @param callback
     */
    openCamera(options, callback) {
        const optionObj = {
                ...defaultOptions,
            ...options
        };
        RNSyanImagePicker.openCamera(optionObj, callback)
    },

    /**
     * 清除缓存
     */
    deleteCache() {
        RNSyanImagePicker.deleteCache()
    }
};

```
## 帮助
加入 React-Native QQ群 397885169
## 非常感谢

[LuckSiege](https://github.com/LuckSiege/PictureSelector)

[banchichen](https://github.com/banchichen/TZImagePickerController)

[ljunb](https://github.com/ljunb)

## 捐助
随时欢迎！！☕️☕️☕️✨✨
