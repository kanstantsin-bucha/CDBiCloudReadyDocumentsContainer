

#import "CDBCloudConnection.h"


NSString * _Nonnull CDBCloudConnectionDidChangeState = @"CDBCloudConnectionDidChangeState";


@interface CDBCloudConnection ()

@property (assign, nonatomic, readwrite) CDBCloudState state;

@property (strong, nonatomic, readwrite) CDBCloudDocuments * documents;
@property (strong, nonatomic, readwrite) CDBCloudStore * store;

@property (copy, nonatomic) NSString * containerID;
@property (copy, nonatomic) NSString * documentsPathComponent;
@property (copy, nonatomic) NSString * storeName;
@property (strong, nonatomic) NSString * storeModelURL;



@property (strong, nonatomic, readonly) NSFileManager * fileManager;
@property (nonatomic, strong) NSURL * ubiquityContainerURL;
@property (strong, nonatomic) id ubiquityIdentityToken;

@end


@implementation CDBCloudConnection

#pragma mark - property -

- (NSFileManager *)fileManager {
    NSFileManager * result = [NSFileManager new];
    return result;
}

#pragma mark - lazy loading - 

- (CDBCloudDocuments *)documents {
    if (_documents == nil) {
        _documents = [CDBCloudDocuments new];
        [_documents initiateUsingCloudPathComponent:self.documentsPathComponent];
        [_documents updateForConnectionState:self.state];
    }
    return _documents;
}

- (CDBCloudStore *)store {
    if (_store == nil) {
        _store = [CDBCloudStore new];
        [_store initiateWithStoreName:self.storeName
                        storeModelURL:self.storeModelURL];
    }
    return _store;
}

#pragma mark - notifications -

- (void)subscribeToNotifications {
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(cloudContentAvailabilityChanged:)
                                                 name: NSUbiquityIdentityDidChangeNotification
                                               object: nil];
}


- (void)postNotificationUsingName:(NSString *)name {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self];
}

#pragma mark - life cycle -

+ (instancetype)sharedInstance {
    static CDBCloudConnection * _sharedInstance = nil;
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
                  documentsPathComponent:(NSString * _Nullable)pathComponent
                               storeName:(NSString * _Nullable)storeName
                           storeModelURL:(NSURL * _Nullable)storeModelURL {
    self.containerID = ID;
    self.documentsPathComponent = pathComponent;
    self.storeName = storeName;
    self.storeModelURL = storeModelURL;
    
    [self subscribeToNotifications];
    [self performCloudStateCheckWithCompletion:^{
        [self postNotificationUsingName:CDBCloudConnectionDidChangeState];
    }];
}

#pragma mark handle state changes

- (void)cloudContentAvailabilityChanged:(NSNotification *)notification {
    [self performCloudStateCheckWithCompletion:^{
        [_documents updateForConnectionState:self.state];
        [self postNotificationUsingName:CDBCloudConnectionDidChangeState];
    }];
}

- (void)performCloudStateCheckWithCompletion:(dispatch_block_t)completion {
    dispatch_async(dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSURL * ubiquityContainerURL = nil;
        id ubiquityIdentityToken = [self.fileManager ubiquityIdentityToken];
        if (ubiquityIdentityToken != nil) {
            ubiquityContainerURL = [self.fileManager URLForUbiquityContainerIdentifier:self.containerID];
        }
        dispatch_async(dispatch_get_main_queue (), ^(void) {
            BOOL cloudIsAvailable = ubiquityIdentityToken != nil;
            BOOL ubiquityContainerIsAvailable = ubiquityContainerURL != nil;
            
            CDBCloudState currentState;
            
            if (ubiquityContainerIsAvailable == NO) {
                currentState = CDBCloudAccessGranted;
            } else {
                currentState = CDBCloudUbiquitosConеtentAvailable;
            }
            
            if (cloudIsAvailable == NO) {
                currentState = CDBCloudAccessDenied;
            }
            
            self.ubiquityContainerURL = ubiquityContainerURL;
            self.ubiquityIdentityToken = ubiquityIdentityToken;
            self.state = currentState;
        });
    });
}

@end
