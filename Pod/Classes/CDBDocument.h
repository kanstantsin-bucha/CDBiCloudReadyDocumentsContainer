
#if __has_feature(objc_modules)
    @import Foundation;
    @import UIKit;
#else
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
#endif


#import "CDBiCloudReadyDocumentsContainer.h"


@protocol CDBDocumentDelegate;


@interface CDBDocument : UIDocument

@property (strong, nonatomic, nullable) NSData * contents;
@property (assign, nonatomic) CDBFileState fileState;
@property (copy, nonatomic, readonly, nonnull) NSString * localizedDocumentState;
@property (copy, nonatomic, readonly, nonnull) NSString * fileName;
@property (weak, nonatomic, nullable) id<CDBDocumentDelegate> delegate;

/**
 Returns YES if it is iCloud document
 **/
@property (assign, nonatomic, readonly, getter=isUbiquitous) BOOL ubiquitous;

/**
 Returns YES if document is closed
 Be aware. SDK rarely calls handler of [ closeWithCompletionHandler:] or
                                       [ openWithCompletionHandler:]
 if document already closed (opened)
 It is unpredictable behaviour and you better just check state before use it
**/
@property (assign, nonatomic, readonly, getter=isClosed) BOOL closed;

/**
 Returns YES for deleted documents
 Behaviour based on empty fileURL (CBDDocumentsContainer set it for deleted documents)
**/
@property (assign, nonatomic, readonly, getter=isDeleted) BOOL deleted;


- (instancetype _Nullable)initWithFileURL:(NSURL * _Nonnull)url
                                 delegate:(id<CDBDocumentDelegate> _Nullable)delegate NS_DESIGNATED_INITIALIZER __TVOS_PROHIBITED;

/**
 Rename document file to fileName
 Fails if file with fileName already exist
**/
- (void)renameFileUsingFileName:(NSString * _Nonnull)fileName
                     completion:(CDBiCloudCompletion _Nonnull)completion;

- (NSError * _Nonnull)iCloudDocumentNotOperableError;

@end


@protocol CDBDocumentDelegate <NSObject>

- (void)didAutoresolveConflictInCDBDocument:(CDBDocument * _Nonnull)document;

@end
