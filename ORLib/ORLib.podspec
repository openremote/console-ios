Pod::Spec.new do |spec|
  spec.name         = "ORLib"
  spec.version      = "0.2.0"
  spec.summary      = "Library for OpenRemote iOS applications."
  spec.homepage     = "https://github.com/openremote/console-ios"
  spec.license      = { :type => 'AGPL-3.0', :file => 'LICENSE.txt' }

  spec.author       = { "OpenRemote" => "developers@openremote.io" }
  spec.platform     = :ios, "14.0"
  spec.swift_version = '5.0'

  spec.source       = { :git => "https://github.com/openremote/console-ios.git", :tag => "#{spec.version}" }
  spec.source_files = 'ORLib/**/*.swift'

  # Define test targets
  spec.test_spec do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    test_spec.resources = ['Tests/Fixtures/**/*']
  end
end
