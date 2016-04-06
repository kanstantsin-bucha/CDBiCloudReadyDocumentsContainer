

#ifndef LSCDB

// localization
#define LSCDB(x) NSLocalizedString(@#x, nil)

#endif /* LSCDB */


#ifndef CDBiCloudReadyDocumentsContainer_h
#define CDBiCloudReadyDocumentsContainer_h

typedef NS_OPTIONS(NSUInteger, CDBCoreDataStoreState) {
    CDBCoreDataStoreUbiquitosSelected = 1 << 0, // 1 - selected store is ubiquitos / 0 - local
    CDBCoreDataStoreUbiquitosConnected = 1 << 1, // 1 - ubiquitos store connected / 0 - disconnected
    CDBCoreDataStoreUbiquitosActive = 1 << 2, // 1 - current store is ubiquitos / 0 - local
    CDBCoreDataStoreUbiquitosInitiated = 1 << 3 // 1 - ubiquitos initiated / 0 - waiting for initialization
};


typedef NS_ENUM(NSUInteger, CDBContaineriCloudState) {
    CDBContaineriCloudStateUndefined = 0,
    CDBContaineriCloudAccessDenied = 1,
    CDBContaineriCloudAccessGranted = 2,
    CDBContaineriCloudUbiquitosContainerAvailable = 3, // Connection established
    CDBContaineriCloudRequestingInfo = 4, // Loading documents list
    CDBContaineriCloudMetadata = 5, // Some of documents has only metadata
    CDBContaineriCloudDownloaded = 6, // All documents downloaded but some of them has previous versions
    CDBContaineriCloudCurrent = 7 // All documents in a local store has the most current state
};

#define StringFromCDBContaineriCloudState(enum) (([@[\
@"ContainerStateUndefined",\
@"ContainerAccessDenied",\
@"ContainerAccessGranted",\
@"CDBContaineriCloudUbiquitosContainerAvailable",\
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


typedef void (^CDBiCloudAccessBlock) (BOOL allDownloaded, CDBContaineriCloudState state, NSError * _Nullable error);
typedef void (^CDBiCloudCompletion) (NSError * _Nullable error);
typedef void (^CDBiCloudDocumentCompletion) (CDBDocument * _Nullable document, NSError * _Nullable error);

#endif /* CDBiCloudReadyDocumentsContainer_h */



