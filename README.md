# CDBiCloudReadyDocumentsContainer
UIDocument based container with CRUD operations supposed to use with iCloud Documents

UIDocument CRUD container maintains connection to iCloud and make delegates calls on it's' state changed.
It also provide a list of documents stored on the cloud and updates it in real time.
UIDocument CRUD container also could create local documents and read, update, delete loacal and iCloud documents.
It also could move documents from a local directory to the cloud and vise versa.
CDBDocument resolves conflicts automatically based on the latest version.
CDBDocument could rename file of a document.
CDBDocument provides document file states and user friendly properties to check them.

[![CI Status](http://img.shields.io/travis/yocaminobien/CDBiCloudReadyDocumentsContainer.svg?style=flat)](https://travis-ci.org/yocaminobien/CDBiCloudReadyDocumentsContainer)
[![Version](https://img.shields.io/cocoapods/v/CDBiCloudReadyDocumentsContainer.svg?style=flat)](http://cocoapods.org/pods/CDBiCloudReadyDocumentsContainer)
[![License](https://img.shields.io/cocoapods/l/CDBiCloudReadyDocumentsContainer.svg?style=flat)](http://cocoapods.org/pods/CDBiCloudReadyDocumentsContainer)
[![Platform](https://img.shields.io/cocoapods/p/CDBiCloudReadyDocumentsContainer.svg?style=flat)](http://cocoapods.org/pods/CDBiCloudReadyDocumentsContainer)

##TODO

* Readme HOWTO
* Example project
* Implement move document logic, update rename by moving from document to container 

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

CDBiCloudReadyDocumentsContainer is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "CDBiCloudReadyDocumentsContainer"
```

## Author

yocaminobien, yocaminobien@gmail.com

## License

CDBiCloudReadyDocumentsContainer is available under the MIT license. See the LICENSE file for more info.
