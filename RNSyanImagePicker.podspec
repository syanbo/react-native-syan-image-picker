require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name            = 'RNSyanImagePicker'
  s.version         = package['version']
  s.summary         = package['description']
  s.description     = package['description']
  s.homepage        = 'https://github.com/syanbo/react-native-syan-image-picker'
  s.license         = { :type => 'MIT', :file => 'LICENSE' }
  s.author          = { 'syan' => 'hanhun@163.com' }

  # RN 0.67.5 的最低部署目标是 iOS 11，TZImagePickerController 3.8.x 亦可满足。
  s.platform        = :ios, '11.0'

  # 必须限定在 ios/ 目录下。老版本写的是 "**/*.{h,m}"，那是从**包根**递归匹配 ——
  # 从 git 检出安装时会把 example/ios 下的 AppDelegate.m、main.m 一并卷进来，
  # 直接导致符号重复。
  s.source_files    = 'ios/**/*.{h,m}'
  # ios/tests 下是两个各自带 int main() 的命令行测试程序（见 ios/tests/run.sh）。
  # 不排除的话它们会被编进每个使用者的 pod target，App 链接时报 duplicate symbol _main。
  s.exclude_files   = 'ios/tests/**/*'
  s.requires_arc    = true

  s.source          = {
    :git => 'https://github.com/syanbo/react-native-syan-image-picker.git',
    :tag => "v#{s.version}"
  }

  s.frameworks      = 'Photos', 'AVFoundation', 'UIKit'

  # React-Core 才是 RN 0.60+ 的正确坐标；老版本依赖的 "React" 是已废弃的整体 pod。
  s.dependency 'React-Core'
  # 必须锁版本。不加约束的话，TZ 的任何一次大版本更新都会静默流入所有使用者。
  s.dependency 'TZImagePickerController', '~> 3.8.9'
end
