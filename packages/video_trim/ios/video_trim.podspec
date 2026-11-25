Pod::Spec.new do |s|
  s.name             = 'video_trim'
  s.version          = '0.1.0'
  s.summary          = '동영상 한 구간 자르기'
  s.description      = 'AVAssetExportSession으로 동영상의 한 구간을 잘라 MP4로 만든다.'
  s.homepage         = 'https://github.com/thingjae85/jedoit'
  s.license          = { :type => 'Private' }
  s.author           = { 'jedoit' => 'jedoit' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks       = 'AVFoundation'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
