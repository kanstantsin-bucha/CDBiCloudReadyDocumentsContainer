#
# Be sure to run `pod lib lint CDBiCloudReadyDocumentsContainer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

@version = "1.0.5"

Pod::Spec.new do |s|
  s.name             = "CDBiCloudReadyDocumentsContainer"
  s.version          = @version
  s.summary          = "DEPRECATED USE CDBiCloudKit POD"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
   DEPRECATED USE CDBiCloudKit Instead
   DESC

  s.homepage         = "https://github.com/truebucha/CDBiCloudReadyDocumentsContainer"
  s.license          = 'MIT'
  s.author           = { "truebucha" => "truebucha@gmail.com" }
  s.source           = { :git => "https://github.com/truebucha/CDBiCloudReadyDocumentsContainer.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/truebucha'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.frameworks = 'UIKit', 'CoreData'
  s.dependency 'CDBKit', '~> 0.0'
  s.dependency 'CDBUUID', '~> 1.0.0'
  s.deprecated = false
end
