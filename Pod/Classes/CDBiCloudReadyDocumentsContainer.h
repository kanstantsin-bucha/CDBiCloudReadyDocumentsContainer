

@class CDBDocument;


@protocol CDBDocumentDelegate <NSObject>

- (void)didAutoresolveConflictInCDBDocument:(CDBDocument * _Nonnull)document;

@end


#import "CDBDocumentsContainer.h"
#import "CDBDocument.h"



