Pod::Spec.new do |s|
  s.name             = 'MediastreamPlatformSDKiOS'
  s.version          = '0.1.7'
  s.summary          = 'iOS solution for Mediastream Player'
  s.description      = <<-DESC
    iOS solution for Mediastream Player. Install and enjoy it.
  DESC
  s.homepage         = 'https://www.mediastre.am'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'cruiz666' => 'ruizcarlos1985@gmail.com' }
  s.swift_version    = '4.1.2'
  s.ios.deployment_target = '9.0'
  s.ios.vendored_frameworks = 'MediastreamPlatformSDK.framework'
  s.source           = { :http => 'https://s3.amazonaws.com/mediastream-platform-sdk-ios/sdk/MediastreamPlatformSDK.zip' }
  s.dependency 'GoogleAds-IMA-iOS-SDK', '~> 3.7'
end
