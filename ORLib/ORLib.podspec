Pod::Spec.new do |spec|
  spec.name         = "ORLib"
  spec.version      = "0.1.0"
  spec.summary      = "Library for OpenRemote iOS applications."
  spec.homepage     = "https://github.com/openremote/console-ios"
  spec.license      = "GNU Affero General Public License"

  spec.author       = { "OpenRemote" => "developers@openremote.io" }
  spec.platform     = :ios
  spec.platform     = :ios, "14.0"
  spec.source       = { :git => "https://github.com/openremote/console-ios.git", :tag => "#{spec.version}" }

  spec.source_files = 'ORLib/**/*.swift'

  spec.dependency "MaterialComponents/TextFields", "~> 124.2.0"
  spec.dependency "MaterialComponents/Buttons", "~> 124.2.0"
end
