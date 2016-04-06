

#import "CDBDocumentsContainer.h"


#define VZiCloudDocumentsDirectoryPath @"Documents"


@interface CDBDocumentsContainer ()

@property (copy, nonatomic) NSString * containerID;
@property (copy, nonatomic) NSString * documentsDirectoryPath;
@property (copy, nonatomic) NSString * requestedFilesExtension;

@property (strong, nonatomic, readwrite) NSArray<CDBDocument *> * cloudDocuments;
@property (strong, nonatomic, readwrite) NSArray<NSString *> * cloudDocumentNames;
@property (assign, nonatomic, readwrite) CDBContaineriCloudState state;

@property (weak, nonatomic) id<CDBDocumentsContainerDelegate> delegate;

@property (copy, nonatomic, readonly) NSURL * ubiquityDocumentsDirectoryURL;

@property (strong, nonatomic) NSMetadataQuery * metadataQuery;
@property (strong, nonatomic, readonly) NSFileManager * fileManager;
@property (nonatomic, strong) NSURL * ubiquityContainer;

@property (assign, nonatomic, readonly, getter=isiCloudOperable) BOOL iCloudOperable;

@end


@implementation CDBDocumentsContainer
@synthesize localDocumentsURL = _localDocumentsURL;

#pragma mark - Life Cycle -

+ (instancetype)sharedInstance {
    static CDBDocumentsContainer * _sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        _sharedInstance = [[super allocWithZone:NULL] init];
    });
    return _sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [self sharedInstance];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)initiateUsingContainerIdentifier:(NSString * _Nullable)ID
                  documentsDirectoryPath:(NSString * _Nullable)path
                 requestedFilesExtension:(NSString * _Nullable)extension {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUbiquityIdentityDidChangeNotification:)
                                                 name:NSUbiquityIdentityDidChangeNotification
                                               object:nil];
    
    self.containerID = ID;
    self.documentsDirectoryPath = path;
    if (self.documentsDirectoryPath.length == 0) {
        self.documentsDirectoryPath = VZiCloudDocumentsDirectoryPath;
    }
    self.requestedFilesExtension = extension;
    if (extension.length == 0) {
        self.requestedFilesExtension = @"*";
    }
    
    [self performCloudStateCheckWithCompletion:nil];
}

#pragma mark - Notifications -

- (void)handleUbiquityIdentityDidChangeNotification:(NSNotification *)notification {
    [self performCloudStateCheckWithCompletion:nil];
}

- (void)handleMetadataQueryDidUpdateNotification:(NSNotification *)notification {
    [self.metadataQuery disableUpdates];
    [self updateFiles];
    [self logMetadataQueryNotification:notification];
    [self.metadataQuery enableUpdates];
}

- (void)handleMetadataQueryDidFinishGatheringNotification:(NSNotification *)notification {
    [self.metadataQuery disableUpdates];
    [self updateFiles];
    [self.metadataQuery enableUpdates];
}

#pragma mark - Protocols -

#pragma mark CDBDocumentDelegate

- (void)didAutoresolveConflictInCDBDocument:(CDBDocument *)document {
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(container: didAutoresolveConflictInCDBDocument:)]) {
            [wself.delegate container:wself
  didAutoresolveConflictInCDBDocument:document];
        }
    });
}

#pragma mark - Public -

- (void)performCloudStateCheckWithCompletion:(dispatch_block_t)completion {
    dispatch_async(dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        id cloudToken = [self.fileManager ubiquityIdentityToken];
        if (cloudToken != nil) {
            self.ubiquityContainer = [self.fileManager URLForUbiquityContainerIdentifier:self.containerID];
            [self ensureThatUbiquitousDocumentsDirectoryPresents];
        }
        dispatch_async(dispatch_get_main_queue (), ^(void) {
            
            BOOL cloudIsAvailable = cloudToken != nil;
            BOOL ubiquityContainerIsAvailable = self.ubiquityContainer != nil;
            
            CDBContaineriCloudState currentState;
            
            if (ubiquityContainerIsAvailable == NO) {
                currentState = CDBContaineriCloudAccessGranted;
            } else {
                currentState = CDBContaineriCloudUbiquitosContainerAvailable;
            }
            
            if (cloudIsAvailable == NO) {
                currentState = CDBContaineriCloudAccessDenied;
            }
            
            [self changeStateTo:currentState];
            if (completion != nil) {
                completion();
            }
        });
    });
}

- (void)requestCloudAccess:(CDBiCloudAccessBlock)block {
    __weak typeof (self) wself = self;
    [self initiateSynchronizationWithCompletion:^(NSError * _Nullable error) {
        if (block == nil) {
            return;
        }
        block(wself.iCloudDocumentsDownloaded, wself.state, error);
    }];
}

- (void)addDelegate:(id<CDBDocumentsContainerDelegate> _Nonnull)delegate {
    self.delegate = delegate;
}

- (void)removeDelegate:(id<CDBDocumentsContainerDelegate> _Nonnull)delegate {
    if (self.delegate != delegate) {
        return;
    }
    self.delegate = nil;
}

- (void)makeDocument:(CDBDocument * _Nonnull)document
          ubiquitous:(BOOL)ubiquitous
          completion:(CDBiCloudCompletion _Nonnull)completion {
    if ([document isUbiquitous] == ubiquitous) {
        completion(nil);
        return;
    }
    
    void (^ handler)(BOOL success) = ^(BOOL success) {
        if (success == NO) {
            completion(document.iCloudDocumentNotOperableError);
            return;
        }
        
        [self makeClosedDocument:document
                      ubiquitous:ubiquitous
                      completion:completion];
    };
    
    if (document.isClosed) {
        handler(YES);
        return;
    }
    
    [document closeWithCompletionHandler:^(BOOL success) {
        handler(success);
    }];
}

- (CDBDocument *)localDocumentWithFileName:(NSString *)fileName
                                           error:(NSError *_Nullable __autoreleasing * _Nullable)error {
    if (fileName.length == 0) {
        *error = [self fileNameCouldNotBeEmptyError];
        return nil;
    }
    
    NSURL * fileURL = [self localDocumentFileURLUsingFileName:fileName];
    
    CDBDocument * result = [self documentWithAvailableFileURL:fileURL
                                                              error:error];
    return result;
}

- (CDBDocument *)ubiquitousDocumentWithFileName:(NSString *)fileName
                                                error:(NSError *_Nullable __autoreleasing * _Nullable)error; {
    if (fileName.length == 0) {
        *error = [self fileNameCouldNotBeEmptyError];
        return nil;
    }
    
    if (self.iCloudOperable == NO) {
        *error = [self iCloudNotAcceessableErrorUsingState:self.state];
        return nil;
    }
    
    NSURL * fileURL = [self ubiquityDocumentFileURLUsingFileName:fileName];
    
    CDBDocument * result = [self documentWithAvailableFileURL:fileURL
                                                              error:error];
    return result;
}

- (void)createClosedLocalDocumentUsingFileName:(NSString * _Nonnull)fileName
                               documentContent:(NSData * _Nullable)content
                                    completion:(CDBiCloudDocumentCompletion _Nonnull)completion {
    if (fileName.length == 0) {
        completion(nil, [self fileNameCouldNotBeEmptyError]);
        return;
    }
    
    NSURL * fileURL = [self localDocumentFileURLUsingFileName:fileName];
    
    CDBDocument * result = [[CDBDocument alloc] initWithFileURL:fileURL];
    result.contents = content;
    
    BOOL directory = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:result.fileURL.path
                                        isDirectory:&directory];
    
    if (directory) {
        completion (nil, [self fileNameCouldNotBeDirectoryError]);
        return;
    }
    
    UIDocumentSaveOperation operation = exist ? UIDocumentSaveForOverwriting
                                              : UIDocumentSaveForCreating;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [result saveToURL:result.fileURL
         forSaveOperation:operation
        completionHandler:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    completion(result, nil);
                    return;
                }
                completion(nil, [result iCloudDocumentNotOperableError]);
            });
        }];
    });
}

- (void)deleteDocument:(CDBDocument * _Nonnull)document
            completion:(CDBiCloudCompletion _Nonnull)completion {
    if (document.isUbiquitous && self.iCloudOperable == NO) {
        completion([self iCloudNotAcceessableErrorUsingState:self.state]);
        return;
    }
    
    void (^ handler)(BOOL success) = ^(BOOL success) {
        if (success == NO) {
            completion(document.iCloudDocumentNotOperableError);
            return;
        }
        [self deleteClosedDocument:document
                        completion:completion];
    };
    
    if (document.isClosed) {
        handler(YES);
        return;
    }
    
    [document closeWithCompletionHandler:^(BOOL success) {
        handler(success);
    }];
}

#pragma mark - Private -

#pragma mark Safe working with files

- (void)deleteClosedDocument:(CDBDocument * _Nonnull)document
                  completion:(CDBiCloudCompletion _Nonnull)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        __block NSError * error = nil;
        
        void (^accessor)(NSURL *) = ^(NSURL * newURL1) {
            [self.fileManager removeItemAtURL:newURL1
                                        error:&error];
            if (error == nil) {
                [document presentedItemDidMoveToURL:[NSURL new]];
            }
        };

        // we need this error because coordinator makes variable nil and we lose result of a file operation
        NSError * coordinationError = nil;
        NSFileCoordinator * fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:document];
        [fileCoordinator coordinateWritingItemAtURL:document.fileURL
                                            options:NSFileCoordinatorWritingForDeleting
                                              error:&error
                                         byAccessor:accessor];
        
        NSError * valuableError = (error != nil) ? error
                                                 : coordinationError;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(valuableError);
        });
    });
}

- (void)makeClosedDocument:(CDBDocument * _Nonnull)document
                ubiquitous:(BOOL)ubiquitous
                completion:(CDBiCloudCompletion _Nonnull)completion {
    if (self.iCloudOperable == NO) {
        if (completion != nil) {
            completion([self iCloudNotAcceessableErrorUsingState:self.state]);
        }
        return;
    }
    
    NSURL * ubiquitosURL = [self ubiquityDocumentFileURLUsingFileName:document.fileName];
    NSURL * localURL = [self localDocumentFileURLUsingFileName:document.fileName];
    NSURL * destinationURL = ubiquitous ? ubiquitosURL
                                        : localURL;
    void (^accessor)(NSURL *, NSURL *) = ^(NSURL * newReadingURL, NSURL * newWritingURL) {
        NSError * error = nil;
        BOOL result = [self.fileManager setUbiquitous:ubiquitous
                                            itemAtURL:newReadingURL
                                       destinationURL:newWritingURL
                                                error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result) {
                [document presentedItemDidMoveToURL:newWritingURL];
            }
            
            if (completion != nil) {
                completion(error);
            }
        });
    };
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError * coordinationError = nil;
        NSFileCoordinator * fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:document];
        [fileCoordinator coordinateWritingItemAtURL:document.fileURL
                                            options:NSFileCoordinatorWritingForMoving
                                   writingItemAtURL:destinationURL
                                            options:NSFileCoordinatorWritingForReplacing
                                              error:&coordinationError
                                         byAccessor:accessor];
    });
}

- (CDBDocument *)documentWithAvailableFileURL:(NSURL *)fileURL
                                              error:(NSError *__autoreleasing *)error {
    BOOL directory = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:fileURL.path
                                        isDirectory:&directory];
    if (exist == NO || directory) {
        *error = [self directoryUnacceptableURLErrorUsingURL:fileURL];
        return nil;
    }
    
    CDBDocument * result = [[CDBDocument alloc] initWithFileURL:fileURL];
    return result;
}

#pragma mark Synchronize documents

- (void)initiateSynchronizationWithCompletion:(CDBiCloudCompletion)completion {
    if (self.state >= CDBContaineriCloudRequestingInfo) {
        if (completion != nil) {
            completion(nil);
        }
    }
    
    if (self.state < CDBContaineriCloudUbiquitosContainerAvailable) {
        [self performCloudStateCheckWithCompletion:^{
            [self startSynchronizationWithCompletion:completion];
        }];
        return;
    }
    
    [self startSynchronizationWithCompletion:completion];
}

- (void)startSynchronizationWithCompletion:(CDBiCloudCompletion)completion {
    if (self.state < CDBContaineriCloudUbiquitosContainerAvailable) {
        if (completion != nil) {
            completion([self iCloudNotAcceessableErrorUsingState:self.state]);
        }
        return;
    }
    
    [self.metadataQuery setSearchScopes:@[NSMetadataQueryUbiquitousDocumentsScope]];
    [self.metadataQuery setPredicate:[self requestedFilesMetadataPredicate]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMetadataQueryDidUpdateNotification:)
                                                     name:NSMetadataQueryDidUpdateNotification
                                                   object:self.metadataQuery];
        
        [[NSNotificationCenter defaultCenter]  addObserver:self
                                                  selector:@selector(handleMetadataQueryDidFinishGatheringNotification:)
                                                      name:NSMetadataQueryDidFinishGatheringNotification
                                                    object:self.metadataQuery];
        
        BOOL startedQuery = [self.metadataQuery startQuery];
        if (startedQuery == NO) {
            NSLog(@"[CDBiCloudReadyDocumentsContainer] Failed to start metadata query");
        } else {
            [self changeStateTo:CDBContaineriCloudRequestingInfo];
        }
        
        if (completion != nil) {
            completion(nil);
        }
    });
}

- (void)updateFiles {
    __block CDBContaineriCloudState state = CDBContaineriCloudCurrent;
    
    NSMutableArray * documents = [NSMutableArray array];
    NSMutableArray * documentNames = [NSMutableArray array];
    
    [self.metadataQuery enumerateResultsUsingBlock:^(NSMetadataItem * item, NSUInteger idx, BOOL *stop) {
        NSURL * fileURL = [item valueForAttribute:NSMetadataItemURLKey];
        NSString * fileName = [item valueForAttribute:NSMetadataItemFSNameKey];
        
        CDBDocument * document = [CDBDocument documentWithFileURL:fileURL
                                                         delegate:self];
        
        [documents addObject:document];
        [documentNames addObject:document.localizedName];
        
        switch (document.fileState) {
            case CDBFileUbiquitousMetadataOnly: {
                state = CDBContaineriCloudMetadata;
                [self startDownloadingDocumentWithURL:fileURL
                                              andName:fileName];
            } break;
                
            case CDBFileUbiquitousDownloaded: {
                if (state == CDBContaineriCloudCurrent) {
                    state = CDBContaineriCloudDownloaded;
                }
            } break;
                
            case CDBFileUbiquitousCurrent: {
                
            } break;
                
            default:
                break;
        }
    }];
    
    self.cloudDocuments = [documents copy];
    self.cloudDocumentNames = [documentNames copy];
    
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(iCloudDocumentsDidChangeForContainer:)]) {
            [wself.delegate iCloudDocumentsDidChangeForContainer:wself];
        }
    });
    
    [self changeStateTo:state];
}

- (void)dissmissSynchronization {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_metadataQuery stopQuery];
    _metadataQuery = nil;
}

- (void)startDownloadingDocumentWithURL:(NSURL *)fileURL
                                andName:(NSString *)name {
    NSError *error;
    BOOL downloading = [self.fileManager startDownloadingUbiquitousItemAtURL:fileURL
                                                                       error:&error];
    if (downloading == NO){
        NSLog(@"[CDBiCloudReadyDocumentsContainer] Ubiquitous item with name %@ \
              \nfailed to start downloading with error: %@", name, error);
    }
}

#pragma mark Handle state changes

- (void)changeStateTo:(CDBContaineriCloudState)state {
    if (self.state == state) {
        return;
    }
    
    NSLog(@"[CDBiCloudReadyDocumentsContainer] Changed state to %@",
          StringFromCDBContaineriCloudState(state));
    
    self.state = state;
    switch (state) {
        case CDBContaineriCloudAccessGranted: {
            [self dissmissSynchronization];
        } break;
        
        case CDBContaineriCloudAccessDenied: {
            [self dissmissSynchronization];
            [self showDeniedAccessAlert];
        } break;
        
        case CDBContaineriCloudUbiquitosContainerAvailable: {
            
        } break;
        
        case CDBContaineriCloudRequestingInfo: {

        } break;
        
        case CDBContaineriCloudMetadata: {
        } break;
        
        case CDBContaineriCloudDownloaded: {
            
        } break;
        
        case CDBContaineriCloudCurrent: {
            
        } break;
            
        default:
            break;
    }
    
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(container:iCloudStatedidChangeTo:)]) {
            [wself.delegate container:wself iCloudStatedidChangeTo:state];
        }
    });
}

#pragma mark Show Unavailable Alert

- (void)showDeniedAccessAlert {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:LSCDB(iCloud Unavailable)
                                                     message:LSCDB(Make sure that you are signed into a valid iCloud account and documents are Enabled)
                                                    delegate:nil
                                           cancelButtonTitle:LSCDB(OK)
                                           otherButtonTitles:nil];
    [alert show];
}

#pragma mark Directory checking

- (void)ensureThatUbiquitousDocumentsDirectoryPresents {
    [self synchronousEnsureThatDirectoryPresentsAtURL:self.ubiquityDocumentsDirectoryURL
                                            comletion:^(NSError *error) {
        if (error == nil) {
            return;
        }
        NSLog(@"[CDBiCloudReadyDocumentsContainer] could not resolve ubiquituos documents directory URL %@\
              \n failed with error: %@",
              self.ubiquityDocumentsDirectoryURL, error);
        NSLog(@"[CDBiCloudReadyDocumentsContainer] ubiquituos documents directory resolved to default path");
        self.documentsDirectoryPath = VZiCloudDocumentsDirectoryPath;
        [self synchronousEnsureThatDirectoryPresentsAtURL:self.ubiquityDocumentsDirectoryURL
                                                comletion:^(NSError *error) {
            if (error == nil) {
                return;
            }
            NSLog(@"[CDBiCloudReadyDocumentsContainer] unpredicable error \
                  \ncould not resolve default ubiquituos documents directory URL %@\
                  \n failed with error: %@",
                  self.ubiquityDocumentsDirectoryURL, error);
        }];
    }];
}

- (void)synchronousEnsureThatDirectoryPresentsAtURL:(NSURL *)URL
                                          comletion:(CDBiCloudCompletion)completion {
    if (URL == nil) {
        if (completion != nil) {
            completion([self directoryUnacceptableURLErrorUsingURL:URL]);
        }
        return;
    }
    
    NSError * error = nil;
    
    NSString * directoryPath = [URL path];
    BOOL isDirectory = NO;
    BOOL exist = [self.fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory];
    
    if (exist == NO) {
        [self.fileManager createDirectoryAtURL:URL
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
        if (completion != nil) {
            completion(error);
        }
        return;
    }
    
    if (isDirectory) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    [self.fileManager removeItemAtPath:directoryPath
                                 error:&error];
    if (error != nil) {
        if (completion != nil) {
            completion(error);
        }
        return;
    }
    
    [self.fileManager createDirectoryAtURL:URL
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    if (completion != nil) {
        completion(error);
    }
}


#pragma mark Ubiquitios URL

- (NSURL *)ubiquityDocumentFileURLUsingFileName:(NSString *)fileName {
    
    NSURL * result = [self.ubiquityDocumentsDirectoryURL URLByAppendingPathComponent:fileName
                                                                         isDirectory:NO];
    return result;
}

- (NSURL *)localDocumentFileURLUsingFileName:(NSString *)fileName {
    NSURL * result = [self.localDocumentsURL URLByAppendingPathComponent:fileName
                                                             isDirectory:NO];
    return result;
}

#pragma mark Logging

- (void)logMetadataQueryNotification:(NSNotification *)notification {
    if (self.verbose == NO) {
        return;
    }
    
    [notification.userInfo enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull change, NSArray *  _Nonnull metadataItems, BOOL * _Nonnull stop) {
        if (metadataItems.count == 0) {
            return;
        }
        NSLog(@"Change %@: ==============================\r", change);
        for (NSMetadataItem *metadataItem in metadataItems) {
            if ([metadataItem isKindOfClass:[NSMetadataItem class]] == NO) {
                continue;
            }
            
            [self logMetadataItem:metadataItem];
        }
    }];
}

- (void)logMetadataItem:(NSMetadataItem *)item {
    NSNumber *isUbiquitous = [item valueForAttribute:NSMetadataItemIsUbiquitousKey];
    NSNumber *hasUnresolvedConflicts = [item valueForAttribute:NSMetadataUbiquitousItemHasUnresolvedConflictsKey];
    NSString *isDownloaded = [item valueForAttribute:NSMetadataUbiquitousItemDownloadingStatusKey];
    NSNumber *isDownloading = [item valueForAttribute:NSMetadataUbiquitousItemIsDownloadingKey];
    NSNumber *isUploaded = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadedKey];
    NSNumber *isUploading = [item valueForAttribute:NSMetadataUbiquitousItemIsUploadingKey];
    NSNumber *percentDownloaded = [item valueForAttribute:NSMetadataUbiquitousItemPercentDownloadedKey];
    NSNumber *percentUploaded = [item valueForAttribute:NSMetadataUbiquitousItemPercentUploadedKey];
    NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
    
    BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[url path]];
    
    NSLog(@"documentExists:%i - %@\
          \r isUbiquitous:%@ hasUnresolvedConflicts:%@\
          \r isDownloaded:%@ isDownloading:%@ isUploaded:%@ isUploading:%@\
          \r %%downloaded:%@ %%uploaded:%@",
            documentExists, url,
            isUbiquitous,
            hasUnresolvedConflicts,
            isDownloaded,
            isDownloading,
            isUploaded,
            isUploading,
            percentDownloaded,
            percentUploaded);
}


#pragma mark - Property -

#pragma mark Getter

- (NSURL *)ubiquityDocumentsURL {
    NSURL * result = self.ubiquityDocumentsDirectoryURL;
    return result;
}

- (NSURL *)ubiquityDocumentsDirectoryURL {
    NSURL * result =
        [self.ubiquityContainer URLByAppendingPathComponent:self.documentsDirectoryPath
                                                isDirectory:YES];
    return result;
}

- (BOOL)isiCloudDocumentsDownloaded {
    BOOL result = self.state == CDBContaineriCloudDownloaded
                  || self.state == CDBContaineriCloudCurrent;
    return result;
}

- (BOOL)isiCloudOperable {
    BOOL result = (self.state != CDBContaineriCloudAccessGranted
                && self.state != CDBContaineriCloudAccessDenied
                && self.state != CDBContaineriCloudStateUndefined);
    return result;
}

- (NSFileManager *)fileManager {
    NSFileManager * result = [NSFileManager new];
    return result;
}

- (NSPredicate *)requestedFilesMetadataPredicate {
    NSString * format = [NSString stringWithFormat:@"%%K.pathExtension LIKE '%@'", self.requestedFilesExtension];
    NSPredicate * result = [NSPredicate predicateWithFormat:format, NSMetadataItemFSNameKey];
    return result;
}

- (NSError *)iCloudNotAcceessableErrorUsingState:(CDBContaineriCloudState)state {
    NSString * errorDescription = [NSString stringWithFormat:@"iCloud not acceessable with current state: %@",
                                   StringFromCDBContaineriCloudState(state)];
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:0
                                       userInfo:userInfo];
    return result;
}

- (NSError *)fileNameCouldNotBeEmptyError {
    NSString * errorDescription = @"Could not process empty file name";
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:1
                                       userInfo:userInfo];
    return result;
}

- (NSError *)fileNameCouldNotBeDirectoryError {
    NSString * errorDescription = @"Could not process file name that represents directory";
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:1
                                       userInfo:userInfo];
    return result;
}

- (NSError *)directoryUnacceptableURLErrorUsingURL:(NSURL *)URL {
    NSString * errorDescription = [NSString stringWithFormat:@"Could not handle nil or empty URL: %@", URL];
    NSDictionary * userInfo = @{NSLocalizedDescriptionKey: errorDescription};
    NSError * result = [NSError errorWithDomain:NSStringFromClass([self class])
                                           code:2
                                       userInfo:userInfo];
    return result;
}

#pragma mark Setter

- (void)setLocalDocumentsURL:(NSURL *)localDocumentsURL {
    if ([_localDocumentsURL.path isEqualToString:localDocumentsURL.path]) {
        return;
    }
    
    [self synchronousEnsureThatDirectoryPresentsAtURL:localDocumentsURL
                                            comletion:^(NSError *error) {
         if (error != nil) {
             NSLog(@"[CDBiCloudReadyDocumentsContainer] could not resolve local documents URL %@\
                    \n failed with error: %@",
                    localDocumentsURL, error);
         } else {
             _localDocumentsURL = localDocumentsURL;
         }
    }];
}

#pragma mark Lazy loading

- (NSURL *)localDocumentsURL {
    if (_localDocumentsURL == nil) {
        NSArray * URLs = [self.fileManager URLsForDirectory:NSDocumentDirectory
                                                  inDomains:NSUserDomainMask];
        _localDocumentsURL = [URLs lastObject];
    }
    return _localDocumentsURL;
}

- (NSMetadataQuery *)metadataQuery {
    if (_metadataQuery == nil) {
        _metadataQuery = [NSMetadataQuery new];
    }
    return _metadataQuery;
}

@end
