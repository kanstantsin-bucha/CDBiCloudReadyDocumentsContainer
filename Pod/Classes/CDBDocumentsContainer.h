

#if __has_feature(objc_modules)
    @import Foundation;
    @import UIKit;
#else
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
#endif


#import "CDBiCloudReadyDocumentsContainer.h"
#import "CDBiCloudReadyConstants.h"
#import <CDBKit/CDBKit.h>


@protocol CDBDocumentsContainerDelegate;


@interface CDBDocumentsContainer : NSObject
<
CDBDocumentDelegate
>

/**
 @brief: Use this option to enable verbose logging
**/

@property (assign, nonatomic) BOOL verbose;

/**
 This is the URL where local documents container points (where local files stored)
 By default it points to local Documents directory
 App makes attempt to create this path if it doesn't exist
 You could change it at any time you want
**/

@property (copy, nonatomic, nullable) NSURL * localDocumentsURL;

/**
 This is the URL where cloud documents container points (where cloud files stored)
 By default it points to cloud Documents directory
 App makes attempt to create this path if it doesn't exist
 **/

@property (copy, nonatomic, readonly, nullable) NSURL * ubiquityDocumentsURL;

/**
 Contains state of container container
**/

@property (assign, nonatomic, readonly) CDBContaineriCloudState state;

/**
 Contains all documents that present in container
**/

@property (assign, nonatomic, readonly, getter=isiCloudDocumentsDownloaded) BOOL iCloudDocumentsDownloaded;
@property (strong, nonatomic, readonly, nonnull) NSArray<CDBDocument *> * cloudDocuments;
@property (strong, nonatomic, readonly, nonnull) NSArray<NSString *> * cloudDocumentNames;

+ (instancetype _Nullable)sharedInstance;

/**
 Call it before use entitled
 path - documentsDirectoryPath inside container
 extension - filter iCloud documents by extension before they will be provided by a container
 Could provide nil for both arguments
**/

- (void)initiateUsingContainerIdentifier:(NSString * _Nullable)ID
                  documentsDirectoryPath:(NSString * _Nullable)path
                 requestedFilesExtension:(NSString * _Nullable)extension;

/**
 Do your things with iCloud inside this block
 First call of this block makes CDBDocumentsContainer start synchronization of ubiquitos container files
 So if you don't want wait while loading occures call it right after initiateUsingContainerIdentifier: method
 
 It returns allDownloaded only for CDBContaineriCloudDownloaded or CDBContaineriCloudCurrent state
 That means iCloud documents are ready to roll
 
 @example
 
 [self requestCloudAccess:^(BOOL allDownloaded, VZiCloudState state){
     if (allDownloaded) {
         Do your job there
     }
 }];
 **/

- (void)requestCloudAccess:(CDBiCloudAccessBlock _Nullable)block;

/**
 Checks icloud state without starting synchronization
 Usually you don't need to call it becase initiateUsingContainerIdentifier: handle it for you
 **/

- (void)performCloudStateCheckWithCompletion:(dispatch_block_t _Nullable)completion;

/**
 Add delegate to notify changes
 **/

- (void)addDelegate:(id<CDBDocumentsContainerDelegate> _Nonnull)delegate;

/**
 Remove delegate
 **/

- (void)removeDelegate:(id<CDBDocumentsContainerDelegate> _Nonnull)delegate;


/**
 To move document to the cloud, use YES, otherwise NO
**/

- (void)makeDocument:(CDBDocument * _Nonnull)document
          ubiquitous:(BOOL)ubiquitous
          completion:(CDBErrorCompletion _Nonnull)completion;

/**
 Get document from local documents using file name
 Return nil if no file with such name exists or if it is a directory
 Local documents directory is defined by localDocumentsURL property
**/

- (CDBDocument * _Nullable)localDocumentWithFileName:(NSString * _Nonnull)fileName
                                               error:(NSError *_Nullable __autoreleasing * _Nullable)error;

/**
 Get document from iCloud documents using file name
 Return nil if no file with such name exists or if it is a directory
 iCloud documents directory is defined by documentsDirectoryPath variable passed on initalization
 **/

- (CDBDocument * _Nullable)ubiquitousDocumentWithFileName:(NSString * _Nonnull)fileName
                                                    error:(NSError *_Nullable __autoreleasing * _Nullable)error;

/**
 Create document in localDocumentsURL directory using file name and content
 Be aware - by defaullt it owerrides any existing document with such name
 If you aren't shure use localDocumentWithFileName: to check if any exist
**/

- (void)createClosedLocalDocumentUsingFileName:(NSString * _Nonnull)fileName
                               documentContent:(NSData * _Nullable)content
                                    completion:(CDBiCloudDocumentCompletion _Nonnull)completion;

/**
 Delete document in localDocumentsURL directory (for local documents)
 Could delete both local and ubiquitous iCloud documents;
 Behaviour based on deleting a file and setting empty fileURL for a document
 It resolves issue with deleted document wich stored somewhere in a property
**/

- (void)deleteDocument:(CDBDocument * _Nonnull)document
            completion:(CDBErrorCompletion _Nonnull)completion;
@end


@protocol CDBDocumentsContainerDelegate <NSObject>

@optional

- (void)container:(CDBDocumentsContainer * _Nonnull)container
    iCloudStatedidChangeTo:(CDBContaineriCloudState)state;
- (void)iCloudDocumentsDidChangeForContainer:(CDBDocumentsContainer * _Nonnull)container;
- (void)container:(CDBDocumentsContainer * _Nonnull)container
    didAutoresolveConflictInCDBDocument:(CDBDocument * _Nonnull)document;

@end
