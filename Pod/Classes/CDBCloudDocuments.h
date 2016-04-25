

#if __has_feature(objc_modules)
    @import Foundation;
    @import UIKit;
#else
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
#endif


#import "CDBiCloudReadyConstants.h"
#import "CDBDocument.h"
#import <CDBKit/CDBKit.h>


@protocol CDBCloudDocumentsDelegate;


@interface CDBCloudDocuments : NSObject
<
CDBDocumentDelegate
>

/**
 @brief: Use this option to enable verbose logging
**/

@property (assign, nonatomic) BOOL verbose;
@property (assign, nonatomic, readonly) BOOL ubiquitosActive;
@property (assign, nonatomic) BOOL metadataQueryShouldStopAfterFinishGathering;


@property (copy, nonatomic, readonly, nullable) NSURL * currentDocumentsURL;

/**
 This is the URL where cloud documents container points (where cloud files stored)
 By default it points to cloud Documents directory
 App makes attempt to create this path if it doesn't exist
 **/

@property (copy, nonatomic, readonly, nullable) NSURL * ubiquityDocumentsURL;

/**
 This is the URL where local documents container points (where local files stored)
 By default it points to local Documents directory
 App makes attempt to create this path if it doesn't exist
 You could change it at any time you want
**/

@property (copy, nonatomic, nullable) NSURL * localDocumentsURL;

/**
 Contains all documents that present in container
**/

@property (strong, nonatomic, readonly, nullable) NSArray<NSURL *> * cloudDocumentURLs;
@property (strong, nonatomic, readonly, nullable) NSArray<NSString *> * cloudDocumentNames;

/**
 This is for cloudConnection only
**/
- (void)initiateUsingCloudPathComponent:(NSString * _Nullable)pathComponent;

/**
 This is for cloudConnection only
 **/

- (void)updateForUbiquityActive:(BOOL)active
      usingUbiquityContainerURL:(NSURL * _Nullable)containerURL;

/**
 Add delegate to notify changes
 **/

- (void)addDelegate:(id<CDBCloudDocumentsDelegate> _Nonnull)delegate;

/**
 Remove delegate
 **/

- (void)removeDelegate:(id<CDBCloudDocumentsDelegate> _Nonnull)delegate;


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

- (void)readContentOfDocumentAtURL:(NSURL *)URL
                        completion:(void(^)(NSData * data, NSError * error))completion;
/**
 Process block called only once for every single revision of the document with unique name
 if file modified date doesn't change processing block doesn't call
**/
- (void)processDocumentWithName:(NSString *)name
                          atURL:(NSURL *)URL
                processingBlock:(void(^) (NSData * documentData, NSError * error))processingBlock;

- (void)processStringsDocumentWithName:(NSString *)name
                                 atURL:(NSURL *)URL
               separationCharactersSet:(NSCharacterSet *)separators
                     onlyUniqueStrings:(BOOL)unique
                processingStringsBlock:(void(^) (NSArray * documentStrings, NSError * error))stringsProcessingBlock;

/**
 Delete document in localDocumentsURL directory (for local documents)
 Could delete both local and ubiquitous iCloud documents;
 Behaviour based on deleting a file and setting empty fileURL for a document
 It resolves issue with deleted document wich stored somewhere in a property
**/

- (void)deleteDocument:(CDBDocument * _Nonnull)document
            completion:(CDBErrorCompletion _Nonnull)completion;

- (void)copyDocument:(CDBDocument * _Nonnull)document
               toURL:(NSURL * _Nonnull)destinationURL
             replace:(BOOL)replace
          completion:(CDBErrorCompletion _Nonnull)completion;

- (void)moveDocument:(CDBDocument * _Nonnull)document
               toURL:(NSURL * _Nonnull)destinationURL
          completion:(CDBErrorCompletion _Nonnull)completion;
@end


@protocol CDBCloudDocumentsDelegate <NSObject>

@optional

- (void)didChangeCloudStateOfCDBCloudDocuments:(CDBCloudDocuments * _Nonnull)documents;

- (void)CDBCloudDocuments:(CDBCloudDocuments * _Nonnull)documents
   didChangeMetadataQuery:(NSMetadataQuery *)query;

- (void)CDBCloudDocuments:(CDBCloudDocuments * _Nonnull)documents
    didAutoresolveConflictInCDBDocument:(CDBDocument * _Nonnull)document;

- (void)CDBCloudDocuments:(CDBCloudDocuments * _Nonnull)documents
    didChangeUbiquitosDocumentAtURL:(NSURL * _Nullable)URL;
    
- (void)CDBCloudDocuments:(CDBCloudDocuments * _Nonnull)documents
    didRemoveUbiquitosDocumentAtURL:(NSURL * _Nullable)URL;

@end
