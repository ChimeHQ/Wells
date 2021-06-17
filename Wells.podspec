Pod::Spec.new do |s|
  s.name         = 'Wells'
  s.version      = '0.1.4'
  s.summary      = 'a lightweight diagnostics report submission system'

  s.homepage     = 'https://github.com/stacksift/Wells'
  s.license      = { :type => 'BSD-3-Clause', :file => 'LICENSE' }
  s.author       = { 'Stacksift' => 'support@stacksift.io' }
  s.social_media_url = 'https://twitter.com/stacksift'
  
  s.source        = { :git => 'https://github.com/stacksift/Wells.git', :tag => s.version }

  s.source_files  = 'Wells/**/*.swift'

  s.osx.deployment_target = '10.12'
  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '3.0'

  s.cocoapods_version = '>= 1.4.0'
  s.swift_version = '5.0'
end
