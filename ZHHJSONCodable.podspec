Pod::Spec.new do |s|
  s.name             = 'ZHHJSONCodable'
  s.version          = '1.0.0'
  s.summary          = '基于原生 Codable 的柔性 JSON 编解码库。'

  s.description      = <<-DESC
  ZHHJSONCodable 在原生 Codable 之上做柔性解码：脏后端 JSON 尽量解出模型，而不是整模失败。
  支持类型不匹配转换、缺字段回落初始值、key 映射、脏数组跳过、字符串套 JSON 解包等。
  DESC

  s.homepage         = 'https://github.com/yue5yueliang/ZHHJSONCodable'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '桃色三岁' => '136769890@qq.com' }
  s.source           = { :git => 'https://github.com/yue5yueliang/ZHHJSONCodable.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version    = '5.0'
  s.source_files     = 'ZHHJSONCodable/Classes/**/*'
  s.frameworks       = 'Foundation', 'UIKit'
end
