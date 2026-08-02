const path = require('path');

const pkg = require('../package.json');

/**
 * Jest **不读 Metro 配置**，所以 metro.config.js 里的 extraNodeModules 映射对它无效。
 * 示例工程又没有把本库声明为依赖（它靠自动链接消费仓库根目录的源码），
 * 因此必须在这里显式告诉 Jest 去哪里找 —— 否则 `npm --prefix example test`
 * 会直接报 "Cannot find module 'react-native-syan-image-picker'"。
 */
module.exports = {
  preset: '@react-native/jest-preset',
  moduleNameMapper: {
    [`^${pkg.name}$`]: path.resolve(__dirname, '..', 'src', 'index.ts'),
  },
  // 库源码在 example/node_modules 之外，默认不会被 babel 处理，这里放行。
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?)/)',
  ],
};
