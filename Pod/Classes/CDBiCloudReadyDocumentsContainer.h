
#ifndef LSCDB

// localization
#define LSCDB(x) NSLocalizedString(@#x, nil)

#endif /* LSCDB */


#ifndef CDBiCloudReadyDocumentsContainer_h
#define CDBiCloudReadyDocumentsContainer_h

typedef NS_ENUM(NSUInteger, CDBContaineriCloudState) {
    CDBContaineriCloudStateUndefined = 0,
    CDBContaineriCloudAccessDenied = 1,
    CDBContaineriCloudAccessGranted = 2,
    CDBContaineriCloudRequestingInfo = 3, // Connection established, loading documents list
    CDBContaineriCloudMetadata = 4, // Some of documents has only metadata
    CDBContaineriCloudDownloaded = 5, // All documents downloaded but some of them has previous versions
    CDBContaineriCloudCurrent = 6 // All documents in a local store has the most current state
};

#define StringFromCDBContaineriCloudState(enum) (([@[\
@"ContainerStateUndefined",\
@"ContainerAccessDenied",\
@"ContainerAccessGranted",\
@"ContainerRequestingInfo",\
@"ContainerMetadata",\
@"ContainerDownloaded",\
@"ContainerCurrent",\
] objectAtIndex:(enum)]))


typedef NS_ENUM(NSUInteger, CDBFileState) {
    CDBFileStateUndefined = 0,
    CDBFileLocal = 1,
    CDBFileUbiquitousMetadataOnly = 1, // it has metadata only
    CDBFileUbiquitousDownloaded = 2, // it downloaded to a local store
    CDBFileUbiquitousCurrent = 3 // it downloaded and has the most current state
};

#define StringFromCDBFileState(enum) (([@[\
@"CDBFileStateUndefined",\
@"CDBFileLocal",\
@"CDBFileUbiquitousMetadataOnly",\
@"CDBFileUbiquitousDownloaded",\
@"CDBFileUbiquitousCurrent",\
] objectAtIndex:(enum)]))


@class CDBDocument;


typedef void (^CDBiCloudAccessBlock) (BOOL allDownloaded, CDBContaineriCloudState state);
typedef void (^CDBiCloudCompletion) (NSError * _Nullable error);
typedef void (^CDBiCloudDocumentCompletion) (CDBDocument * _Nullable document, NSError * _Nullable error);

#endif /* CDBiCloudReadyDocumentsContainer_h */

#import "CDBDocumentsContainer.h"
#import "CDBDocument.h"
