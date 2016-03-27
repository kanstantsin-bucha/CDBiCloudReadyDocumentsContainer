#
# Be sure to run `pod lib lint CDBiCloudReadyDocumentsContainer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

@version = "0.0.3"

Pod::Spec.new do |s|
  s.name             = "CDBiCloudReadyDocumentsContainer"
  s.version          = @version
  s.summary          = "UIDocument CRUD container supposed to be used with iCloud Documents"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
    UIDocument CRUD container maintains connection to iCloud and make delegates calls on it's' state changed.
    It also provide a list of documents stored on the cloud and updates it in real time.
    UIDocument CRUD container also could create local documents and read, update, delete loacal and iCloud documents.
    It also could move documents from a local directory to the cloud and vise versa.
    CDBDocument resolves conflicts automatically based on the latest version.
    CDBDocument could rename file of a document.
    CDBDocument provides document file states and user friendly properties to check them.
                       DESC

  s.homepage         = "https://github.com/yocaminobien/CDBiCloudReadyDocumentsContainer"
  s.license          = 'MIT'
  s.author           = { "yocaminobien" => "yocaminobien@gmail.com" }
  s.source           = { :git => "https://github.com/yocaminobien/CDBiCloudReadyDocumentsContainer.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/yocaminobien'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
