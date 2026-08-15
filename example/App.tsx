/**
 * react-native-syan-image-picker 示例。
 *
 * 覆盖公开方法，并刻意演示两条最容易被误用的约定：
 *  - 取消是正常结果（`cancelled`），不是异常
 *  - 库不持有选中态，"记住上次选择"靠把 assets 传回去
 *
 * 「验收」一节补齐发版门闩要用的入口：预览、keepOriginal、关闭 loading + 进度、GIF。
 *
 * @format
 */

import React, {useCallback, useState} from 'react';
import {
  Image,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import {
  addProgressListener,
  captureImage,
  captureVideo,
  clearCache,
  isSyanError,
  openPreview,
  pickImage,
  pickVideo,
  type ImageAsset,
  type PickResult,
  type VideoAsset,
} from 'react-native-syan-image-picker';

type AnyAsset = ImageAsset | VideoAsset;

const isVideo = (asset: AnyAsset): asset is VideoAsset =>
  typeof (asset as VideoAsset).coverUri === 'string';

export default function App() {
  const [assets, setAssets] = useState<AnyAsset[]>([]);
  const [status, setStatus] = useState('准备就绪');

  /** 统一处理结果：取消不是错误，只有真正的异常才进 catch。 */
  const run = useCallback(
    async <T extends AnyAsset>(
      label: string,
      action: () => Promise<PickResult<T>>,
    ) => {
      try {
        setStatus(`${label}…`);
        const result = await action();

        if (result.cancelled) {
          setStatus(`${label}：用户取消（注意这不是异常）`);
          return;
        }

        setAssets(result.assets);
        setStatus(`${label}：选中 ${result.assets.length} 项`);
      } catch (error) {
        if (isSyanError(error)) {
          setStatus(`${label} 失败 [${error.code}]：${error.message}`);
        } else {
          setStatus(`${label} 失败：${String(error)}`);
        }
      }
    },
    [],
  );

  const imageAssets = assets.filter((a): a is ImageAsset => !isVideo(a));

  /** 预览界面一展示就 resolve，不等用户关闭。 */
  const previewLast = useCallback(async () => {
    if (assets.length === 0) {
      setStatus('预览：没有可预览的结果');
      return;
    }
    try {
      setStatus('预览…');
      await openPreview(assets, {index: assets.length > 1 ? 1 : 0});
      setStatus(`预览：已打开（${assets.length} 项，不等关闭）`);
    } catch (error) {
      if (isSyanError(error)) {
        setStatus(`预览 失败 [${error.code}]：${error.message}`);
      } else {
        setStatus(`预览 失败：${String(error)}`);
      }
    }
  }, [assets]);

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>syan-image-picker 示例</Text>
        <Text style={styles.status}>{status}</Text>

        <Section title="相册">
          <Button
            label="选图（最多 9 张）"
            onPress={() => run('选图', () => pickImage({maxCount: 9}))}
          />
          <Button
            label="单选 + 裁剪 300×300"
            onPress={() =>
              run('裁剪', () =>
                pickImage({maxCount: 1, crop: {width: 300, height: 300}}),
              )
            }
          />
          <Button
            label="单选 + 圆形裁剪"
            onPress={() =>
              run('圆形裁剪', () =>
                pickImage({
                  maxCount: 1,
                  crop: {width: 300, height: 300, shape: 'circle'},
                }),
              )
            }
          />
          <Button
            label="选图并返回 base64"
            onPress={() =>
              run('base64', () =>
                pickImage({maxCount: 3, includeBase64: true}),
              )
            }
          />
          <Button
            label="不压缩"
            onPress={() =>
              run('原图', () => pickImage({maxCount: 3, compress: false}))
            }
          />
          <Button
            label="选视频"
            onPress={() => run('选视频', () => pickVideo({maxCount: 1}))}
          />
        </Section>

        <Section title="相机">
          <Button label="拍照" onPress={() => run('拍照', () => captureImage())} />
          <Button
            label="拍照 + 裁剪"
            onPress={() =>
              run('拍照裁剪', () =>
                captureImage({crop: {width: 300, height: 300}}),
              )
            }
          />
          <Button
            label="录像（10 秒）"
            onPress={() => run('录像', () => captureVideo({recordDuration: 10}))}
          />
        </Section>

        <Section title="选中态回填（库自身不持有状态）">
          <Button
            label={`带上次选择再打开（${imageAssets.length} 项）`}
            disabled={imageAssets.length === 0}
            onPress={() =>
              run('回填', () =>
                pickImage({maxCount: 9, selectedAssets: imageAssets}),
              )
            }
          />
        </Section>

        <Section title="验收">
          <Button
            label={`预览上次结果（${assets.length} 项）`}
            disabled={assets.length === 0}
            onPress={previewLast}
          />
          <Button
            label="选图 + keepOriginal"
            onPress={() =>
              run('keepOriginal', () =>
                pickImage({maxCount: 9, keepOriginal: true}),
              )
            }
          />
          <Button
            label="选图 + 关闭 loading（看进度）"
            onPress={() =>
              run('无 HUD', async () => {
                const sub = addProgressListener(
                  ({phase, completed, total}) => {
                    setStatus(`处理中 ${phase} ${completed}/${total}`);
                  },
                );
                try {
                  return await pickImage({maxCount: 9, showLoading: false});
                } finally {
                  sub.remove();
                }
              })
            }
          />
          <Button
            label="选图 + 允许 GIF"
            onPress={() =>
              run('GIF', () => pickImage({maxCount: 9, allowGif: true}))
            }
          />
        </Section>

        <Section title="缓存">
          <Text style={styles.hint}>处理中请勿点清空缓存</Text>
          <Button
            label="清空缓存"
            onPress={async () => {
              await clearCache();
              setStatus('缓存已清空');
            }}
          />
          <Button label="清空结果列表" onPress={() => setAssets([])} />
        </Section>

        <Text style={styles.sectionTitle}>结果（{assets.length}）</Text>
        <View style={styles.grid}>
          {assets.map((asset, index) => (
            <View key={`${asset.uri}-${index}`} style={styles.cell}>
              <Image
                source={{uri: isVideo(asset) ? asset.coverUri : asset.uri}}
                style={styles.thumb}
              />
              <Text style={styles.meta} numberOfLines={3}>
                {asset.width}×{asset.height}
                {'\n'}
                {(asset.size / 1024).toFixed(0)} KB
                {isVideo(asset) ? `\n${(asset.duration / 1000).toFixed(1)}s` : ''}
                {!isVideo(asset) && asset.originalUri ? '\n有 originalUri' : ''}
              </Text>
            </View>
          ))}
        </View>

        {assets.length > 0 && (
          <Text style={styles.raw}>{JSON.stringify(assets[0], replacer, 2)}</Text>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

/** base64 太长，打印时截断，否则整屏都是它。 */
const replacer = (key: string, value: unknown) =>
  key === 'base64' && typeof value === 'string'
    ? `<${value.length} 字符已省略>`
    : value;

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

function Button({
  label,
  onPress,
  disabled,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
}) {
  return (
    <TouchableOpacity
      style={[styles.button, disabled ? styles.buttonDisabled : null]}
      onPress={onPress}
      disabled={disabled}>
      <Text style={styles.buttonText}>{label}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1, backgroundColor: '#fff'},
  content: {padding: 16, paddingBottom: 48},
  title: {fontSize: 20, fontWeight: '600', marginBottom: 8},
  status: {
    fontSize: 13,
    color: '#444',
    backgroundColor: '#f2f2f5',
    padding: 10,
    borderRadius: 6,
    marginBottom: 16,
  },
  section: {marginBottom: 20},
  sectionTitle: {
    fontSize: 15,
    fontWeight: '600',
    marginBottom: 8,
    marginTop: 8,
  },
  button: {
    backgroundColor: '#2f6feb',
    paddingVertical: 11,
    paddingHorizontal: 14,
    borderRadius: 6,
    marginBottom: 8,
  },
  buttonDisabled: {backgroundColor: '#b8c4d9'},
  buttonText: {color: '#fff', fontSize: 14, textAlign: 'center'},
  hint: {fontSize: 12, color: '#a33', marginBottom: 8},
  grid: {flexDirection: 'row', flexWrap: 'wrap', gap: 8},
  cell: {width: 96},
  thumb: {width: 96, height: 96, borderRadius: 4, backgroundColor: '#eee'},
  meta: {fontSize: 10, color: '#666', marginTop: 4},
  raw: {
    fontSize: 10,
    fontFamily: 'Courier',
    color: '#333',
    backgroundColor: '#f7f7f9',
    padding: 8,
    borderRadius: 4,
    marginTop: 16,
  },
});
