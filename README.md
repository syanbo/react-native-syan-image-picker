
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

## 运行示例

[ImagePickerExample](https://github.com/syanbo/ImagePickerExample)

```
import ImagePicker from 'react-native-syan-image-picker'

  /**
   * 默认参数
   */
  const options = {
      imageCount: 6,             // 最大选择图片数目，默认6
      isCamera: true,            // 是否允许用户在内部拍照，默认true
      isCrop: false,             // 是否允许裁剪，默认false
      CropW: ~~(width * 0.6),    // 裁剪宽度，默认屏幕宽度60%
      CropH: ~~(width * 0.6),    // 裁剪高度，默认屏幕宽度60%
      isGif: false,              // 是否允许选择GIF，默认false，暂无回调GIF数据
      showCropCircle: false,     // 是否显示圆形裁剪区域，默认false
      circleCropRadius: width/2  // 圆形裁剪半径，默认屏幕宽度一半
      showCropFrame: true,       // 是否显示裁剪区域，默认true
      showCropGrid: false        // 是否隐藏裁剪区域网格，默认false
  };

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

```

## 非常感谢

[LuckSiege](https://github.com/LuckSiege/PictureSelector)

[banchichen](https://github.com/banchichen/TZImagePickerController)

[ljunb](https://github.com/ljunb)