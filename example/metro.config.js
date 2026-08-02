const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const pkg = require('../package.json');

const root = path.resolve(__dirname, '..');

/** peerDependencies 必须只保留一份实例，否则会出现"两个 React"。 */
const peerModules = Object.keys(pkg.peerDependencies ?? {});

const escapeForRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Metro 配置要点（RN 库最常踩坑的地方）：
 *
 * 1. `watchFolders` 加上仓库根目录，改动库源码能触发热重载。
 * 2. `blockList` 屏蔽根目录 node_modules 下的 react / react-native ——
 *    不屏蔽的话会同时加载两份副本，典型报错是
 *    "Invariant Violation: Tried to register two views with the same name"，
 *    或者 hooks 直接失效。
 * 3. `extraNodeModules` 把库名指向仓库根目录；根 package.json 的
 *    `"react-native": "src/index.ts"` 字段会让 Metro 直接加载 TS 源码，
 *    因此不需要先 build。
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = {
  watchFolders: [root],

  resolver: {
    blockList: peerModules.map(
      (name) =>
        new RegExp(
          `^${escapeForRegExp(path.join(root, 'node_modules', name))}\\/.*$`,
        ),
    ),

    extraNodeModules: {
      [pkg.name]: root,
      ...Object.fromEntries(
        peerModules.map((name) => [
          name,
          path.join(__dirname, 'node_modules', name),
        ]),
      ),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
