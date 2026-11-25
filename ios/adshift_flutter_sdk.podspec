require 'json'
require 'yaml'

pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))
ios_sdk = JSON.parse(File.read(File.join(__dir__, '..', 'native_sdk.json')))['ios']

# The AdShift iOS SDK ships inside the plugin. Without it the pod cannot build,
# so fail here rather than with a missing-module error.
sdk_framework = 'adshift_flutter_sdk/Frameworks/AdshiftSDK.xcframework'
unless File.exist?(File.join(__dir__, sdk_framework, 'Info.plist'))
  message = "adshift_flutter_sdk: the AdShift iOS SDK #{ios_sdk['version']} is missing from " \
            "#{File.join(__dir__, 'adshift_flutter_sdk', 'Frameworks')}. " \
            'Run `flutter pub get` again to restore the package.'
  raise(defined?(Pod::Informative) ? Pod::Informative.new(message) : message)
end

Pod::Spec.new do |s|
  s.name             = 'adshift_flutter_sdk'
  s.version          = pubspec['version']
  s.summary          = 'AdShift SDK for Flutter'
  s.description      = pubspec['description']
  s.homepage         = pubspec['homepage']
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AdShift' => 'support@adshift.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'adshift_flutter_sdk/Sources/adshift_flutter_sdk/**/*.swift'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'

  s.dependency 'Flutter'

  s.vendored_frameworks = sdk_framework
  s.static_framework = true
  s.frameworks = 'Foundation', 'UIKit', 'StoreKit', 'AdSupport', 'AppTrackingTransparency'

  # A static framework brings no resources into the app, its privacy manifest
  # included; the resource bundle puts the manifest where Xcode's privacy report
  # finds it.
  s.resource_bundles = {
    'AdshiftSDK' => ["#{sdk_framework}/ios-arm64/AdshiftSDK.framework/PrivacyInfo.xcprivacy"]
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
