const path = require('path');

/**
 * RN CLI 6（RN 0.6x 宿主）只给带 .xcodeproj 的库生成 iOS 链接配置，本库只有 podspec，会被跳过。
 * 这里给 CLI 6 一个 project 占位（它不检查文件是否存在）并显式指定 podspec。
 * CLI 7 起直接按 podspec 识别，且校验不认这两个字段，所以只对 CLI 6 及以下生效。
 */
function hostIosCliMajor() {
  try {
    const pkgPath = require.resolve('@react-native-community/cli-platform-ios/package.json', {
      paths: [process.cwd()],
    });
    return parseInt(require(pkgPath).version, 10);
  } catch (e) {
    return Infinity;
  }
}

module.exports = {
  dependency: {
    platforms: hostIosCliMajor() < 7
      ? {
        ios: {
          project: 'ios/RNSyanImagePicker.xcodeproj',
          podspecPath: path.join(__dirname, 'RNSyanImagePicker.podspec'),
        },
      }
      : {},
  },
};
