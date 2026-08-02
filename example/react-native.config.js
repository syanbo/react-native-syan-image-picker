const path = require('path');
const pkg = require('../package.json');

/**
 * 让原生自动链接指向仓库根目录的**本地源码**，而不是 npm 上已发布的包。
 *
 * 老仓库的 example 依赖的是已发布的 `react-native-syan-image-picker@^0.5.3` ——
 * 也就是说改了库代码，example 根本跑不到，等于没有验证回路。
 */
module.exports = {
  dependencies: {
    [pkg.name]: {
      root: path.join(__dirname, '..'),
    },
  },
};
