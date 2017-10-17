
# react-native-syan-image-picker

## 功能介绍

 多图片选择器

 Android 基于 [PictureSelector 2.0](https://github.com/LuckSiege/PictureSelector)

 iOS 基于 [TZImagePickerController 1.9.0](https://github.com/banchichen/TZImagePickerController)


## 安装使用

`$ npm install react-native-syan-image-picker --save`

`$ react-native link react-native-syan-image-picker`

### iOS

- TARGETS -> Build Phases -> Link Binary -> Copy Bundle Resources
点击"+"按钮，在弹出的窗口中点击“Add Other”按钮，选择
    ```
    node_modules/react-native-syan-image-picker/ios/TZImagePickerController/TZImagePickerController.bundle
    ```

- 项目目录->Info.plist->增加3项
    ```
    "Privacy - Camera Usage Description
    "Privacy - Location When In Use Usage Description"
    "Privacy - Photo Library Usage Description"
    ```

### Android

- android 下build.gradle文件添加
    ```
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


## link失败手动添加
#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-syan-image-picker` and add `RNSyanImagePicker.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNSyanImagePicker.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<



#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.RNSyanImagePickerPackage;` to the imports at the top of the file
  - Add `new RNSyanImagePickerPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-syan-image-picker'
  	project(':react-native-syan-image-picker').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-syan-image-picker/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-syan-image-picker')
  	```

  