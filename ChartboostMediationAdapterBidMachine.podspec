Pod::Spec.new do |spec|
  spec.name        = 'ChartboostMediationAdapterBidMachine'
  spec.version     = '5.4.0.0.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-bidmachine'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Chartboost Mediation iOS SDK BidMachine adapter.'
  spec.description = 'BidMachine Adapters for mediating through Chartboost Mediation. Supported ad formats: banner, interstitial, rewarded.'

  # Source
  spec.module_name  = 'ChartboostMediationAdapterBidMachine'
  spec.source       = { :git => 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-bidmachine.git', :tag => spec.version }
  spec.source_files = 'Source/**/*.{swift}'
  spec.resource_bundles = { 'ChartboostMediationAdapterBidMachine' => ['PrivacyInfo.xcprivacy'] }

  # Minimum supported versions
  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '15.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'UIKit']

  # Dependencies
  spec.dependency 'ChartboostMediationSDK', '~> 5.0'
  spec.dependency 'BidMachine', '~> 4.0.0'

  spec.static_framework = true
end
