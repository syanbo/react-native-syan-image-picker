import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    /*
     * 刻意**不**整体忽略 example/ —— 它以前被忽略，导致 example 里的
     * `eslint .` 一个文件都匹配不到、直接以错误码退出，而 example/.eslintrc.js
     * 在 flat config 模式下又完全不生效。现在全仓库共用这一份配置。
     */
    ignores: [
      'lib/**',
      '**/node_modules/**',
      'example/ios/**',
      'example/android/**',
      'example-rn067/**',
    ],
  },
  ...tseslint.configs.recommended,
  {
    rules: {
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },
  {
    // babel / metro / jest / react-native.config 这些都是 CommonJS 配置文件，
    // require() 是它们唯一的写法，不该套用 TS 的 ESM 规则。
    files: ['**/*.js', '**/*.cjs'],
    rules: {
      '@typescript-eslint/no-require-imports': 'off',
    },
  },
);
