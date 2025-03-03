Pod::Spec.new do |spec|
  spec.name          = "ORLib"
  spec.version       = "0.3.0"
  spec.summary       = "Library for OpenRemote iOS applications."
  spec.homepage      = "https://github.com/openremote/console-ios"
  spec.license       = { :type => 'AGPL-3.0' }

  spec.author        = { "OpenRemote" => "developers@openremote.io", :file => 'LICENSE.txt' }
  spec.platform      = :ios, "14.0"
  spec.swift_version = '5.0'

  spec.source        = { :git => "https://github.com/openremote/console-ios.git", :tag => "#{spec.version}" }
  spec.source_files  = 'ORLib/**/*.swift'
  spec.exclude_files = '**/Tests/*'
  spec.dependency 'ESPProvision', '3.0.2'
end
