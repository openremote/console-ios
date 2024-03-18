Pod::Spec.new do |spec|
  spec.name         = "ORLib"
  spec.version      = "0.0.1"
  spec.summary      = "Library for OpenRemote iOS applications."
  spec.homepage     = "https://github.com/openremote/console-ios"
  spec.license      = "GNU Affero General Public License"
  # spec.license      = { :type => "MIT", :file => "FILE_LICENSE" }


  spec.author             = { "Michael Rademaker" => "michael@openremote.io" }
  spec.platform     = :ios
  spec.platform     = :ios, "14.0"
  spec.source       = { :git => "https://github.com/openremote/console-ios.git", :tag => "#{spec.version}" }

  spec.source_files = 'ORLib/**/*.swift'

  spec.dependency "MaterialComponents/TextFields", "~> 124.2.0"
  spec.dependency "MaterialComponents/Buttons", "~> 124.2.0"
  spec.dependency "Popover", "~> 1.3.0"
end
