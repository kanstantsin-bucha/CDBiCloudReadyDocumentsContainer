

@class CDBDocument;


@protocol CDBDocumentDelegate <NSObject>

@optional
- (void)didAutoresolveConflictInCDBDocument:(CDBDocument * _Nonnull)document;

- (void)CDBDocumentDirectory:(CDBDocument * _Nonnull)document
       didChangeSubitemAtURL:(NSURL *)URL;

@end


#import "CDBDocumentsContainer.h"
#import "CDBDocument.h"
#import "CDBCoreDataStore.h"
#import "CDBiCloudReadyConstants.h"



