/**
 * Author   : Syan
 * Date     : 2020/5/31
 * Project [ RNPlayground ] Coded on WebStorm.
 */

import React, {Component} from 'react';
import {
  StyleSheet,
  Text,
  View,
  Image,
  ScrollView,
  TouchableOpacity,
  Dimensions,
  PermissionsAndroid,
} from 'react-native';

import SYImagePicker from 'react-native-syan-image-picker';

const {width} = Dimensions.get('window');

export default class App extends Component<{}> {
  constructor(props) {
    super(props);
    this.state = {
      photos: [],
    };
  }

  requestPermission = async () => {
    try {
      const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
          {
            title: '申请读写手机存储权限',
            message:
                '一个很牛逼的应用想借用你的摄像头，' +
                '然后你就可以拍出酷炫的皂片啦。',
            buttonNeutral: '等会再问我',
            buttonNegative: '不行',
            buttonPositive: '好吧',
          },
      );
      if (granted === PermissionsAndroid.RESULTS.GRANTED) {
        console.log('现在你获得摄像头权限了');
      } else {
        console.log('用户并不给你');
      }
    } catch (err) {
      console.warn(err);
    }
  };

  handleOpenImagePicker = () => {
    SYImagePicker.showImagePicker(
        {
          imageCount: 1,
          isRecordSelected: true,
          isCrop: true,
          showCropCircle: true,
          quality: 90,
          compress: true,
          enableBase64: false,
        },
        (err, photos) => {
          console.log('开启', err, photos);
          if (!err) {
            this.setState({
              photos,
            });
          } else {
            console.log(err);
          }
        },
    );
  };

  /**
   * 使用方式sync/await
   * 相册参数暂时只支持默认参数中罗列的属性；
   * @returns {Promise<void>}
   */
  handleAsyncSelectPhoto = async () => {
    // SYImagePicker.removeAllPhoto()
    try {
      const photos = await SYImagePicker.asyncShowImagePicker({
        // allowPickingOriginalPhoto: true,
        imageCount: 8,
        showSelectedIndex: false,
        isGif: true,
        enableBase64: true,
      });
      console.log('关闭', photos);
      // 选择成功
      this.setState({
        photos: [...this.state.photos, ...photos],
      });
    } catch (err) {
      console.log(err);
      // 取消选择，err.message为"取消"
    }
  };

  handlePromiseSelectPhoto = () => {
    SYImagePicker.asyncShowImagePicker({imageCount: 3})
        .then(photos => {
          console.log(photos);
          const arr = photos.map(v => {
            return v;
          });
          // 选择成功
          this.setState({
            photos: [...this.state.photos, ...arr],
          });
        })
        .catch(err => {
          // 取消选择，err.message为"取消"
        });
  };

  handleLaunchCamera = async () => {
    await this.requestPermission();
    SYImagePicker.openCamera(
        {isCrop: true, showCropCircle: true, showCropFrame: false},
        (err, photos) => {
          console.log(err, photos);
          if (!err) {
            this.setState({
              photos: [...this.state.photos, ...photos],
            });
          }
        },
    );
  };

  handleDeleteCache = () => {
    SYImagePicker.deleteCache();
  };

  handleOpenVideoPicker = () => {
    SYImagePicker.openVideoPicker(
        {allowPickingMultipleVideo: true},
        (err, res) => {
          console.log(err, res);
          if (!err) {
            let photos = [...this.state.photos];
            res.map(v => {
              photos.push({...v, uri: v.coverUri});
            });
            this.setState({
              photos,
            });
          }
        },
    );
  };

  render() {
    const {photos} = this.state;
    return (
        <View style={styles.container}>
          <View style={styles.scroll}>
            <Button title={'拍照'} onPress={this.handleLaunchCamera} />
            <Button title={'开启压缩'} onPress={this.handleOpenImagePicker} />
            <Button title={'关闭压缩'} onPress={this.handleAsyncSelectPhoto} />
            <Button
                title={'选择照片(Promise)带base64'}
                onPress={this.handlePromiseSelectPhoto}
            />
            <Button title={'缓存清除'} onPress={this.handleDeleteCache} />
            <Button title={'选择视频'} onPress={this.handleOpenVideoPicker} />
          </View>
          <ScrollView style={{flex: 1}} contentContainerStyle={styles.scroll}>
            {photos.map((photo, index) => {
              let source = {uri: photo.uri};
              if (photo.enableBase64) {
                source = {uri: photo.base64};
              }
              return (
                  <Image
                      key={`image-${index}`}
                      style={styles.image}
                      source={source}
                      resizeMode={'contain'}
                  />
              );
            })}
          </ScrollView>
        </View>
    );
  }
}

const Button = ({title, onPress}) => {
  return (
      <TouchableOpacity style={styles.btn} onPress={onPress}>
        <Text style={{color: '#fff', fontSize: 16}}>{title}</Text>
      </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5FCFF',
    paddingTop: 40,
  },
  btn: {
    backgroundColor: '#FDA549',
    justifyContent: 'center',
    alignItems: 'center',
    height: 44,
    paddingHorizontal: 12,
    margin: 5,
    borderRadius: 22,
  },
  scroll: {
    padding: 5,
    flexWrap: 'wrap',
    flexDirection: 'row',
  },
  image: {
    margin: 10,
    width: (width - 80) / 3,
    height: (width - 80) / 3,
    backgroundColor: '#F0F0F0',
  },
});
