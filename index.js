import {
    NativeModules,
    Platform,
    Dimensions,
} from 'react-native';

const {RNSyanImagePicker} = NativeModules;

const {width, height} = Dimensions.get('window');

export default {
    showImagePicker(options, bc) {

        const optionObj = {
            imageCount: 1,
            isCamera: true,
            isCrop: false,
            CropW: ~~(width*0.6),
            CropH: ~~(width*0.6),
            isGif: false,
            showCropCircle: false,
            showCropFrame: true,
            showCropGrid: false,
            ...options
        }

        return RNSyanImagePicker.showImagePicker(optionObj, bc)


        // if (Platform.OS == 'android') {
        //
        //     const optionObj = {
        //         imageCount: 1,
        //         isCamera: true,
        //         isCrop: false,
        //         CropW: 100,
        //         CropH: 100,
        //         isGif: false,
        //         showCropCircle: false,
        //         showCropFrame: true,
        //         showCropGrid: false,
        //         ...options
        //     }
        //
        //     return RNSyanImagePicker.showImagePicker(optionObj)
        //
        // } else {
        //     let x = (width - CropWidth) / 2;
        //     let y = (height - CropHeight) / 2;
        //     return RNSyanImagePicker.show(count, Crop, x, y, CropWidth, CropHeight, SelectVideo).then((result) => {
        //         return result;
        //     });
        // }
    }
};
