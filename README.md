
# react-native-syan-image-picker

## Getting started

`$ npm install react-native-syan-image-picker --save`

### Mostly automatic installation

`$ react-native link react-native-syan-image-picker`

### Manual installation


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

#### Windows
[Read it! :D](https://github.com/ReactWindows/react-native)

1. In Visual Studio add the `RNSyanImagePicker.sln` in `node_modules/react-native-syan-image-picker/windows/RNSyanImagePicker.sln` folder to their solution, reference from their app.
2. Open up your `MainPage.cs` app
  - Add `using Com.Reactlibrary.RNSyanImagePicker;` to the usings at the top of the file
  - Add `new RNSyanImagePickerPackage()` to the `List<IReactPackage>` returned by the `Packages` method


## Usage
```javascript
import RNSyanImagePicker from 'react-native-syan-image-picker';

// TODO: What to do with the module?
RNSyanImagePicker;
```
  