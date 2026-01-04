Pod::Spec.new do |s|
  s.name             = 'adshift_flutter_sdk'
  s.version          = '1.0.0'
  s.summary          = 'AdShift SDK Flutter Plugin - Mobile Attribution & Analytics'
  s.description      = <<-DESC
    AdShift SDK Flutter Plugin enables mobile attribution, in-app event tracking,
    SKAdNetwork 4.0+ integration, deep linking, and GDPR/TCF 2.2 compliance.
  DESC
  s.homepage         = 'https://adshift.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AdShift' => 'support@adshift.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'

  s.dependency 'Flutter'
  
  # Native AdShift iOS SDK from CocoaPods
  s.dependency 'AdshiftSDK', '~> 1.0'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }

  s.resource_bundles = {'adshift_flutter_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
