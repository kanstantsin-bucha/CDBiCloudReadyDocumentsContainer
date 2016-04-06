

#import "CDBCoreDataStore.h"


#define CDB_Store_Ubiqutos_URL_Postfix @".CDB.CDBCoreDataStore.store.ubiquitos.URL=NSURL"
#define CDB_Store_Current_State_Postfix @".CDB.CDBCoreDataStore.store.current.state=CDBCoreDataStoreState"
#define CDB_Store_Ubiqutos_Token_Postfix @".CDB.CDBCoreDataStore.store.ubiquitos.token=NSObject"


#ifdef DEBUG
    #define CDB_Store_Ubiquitos_Delay_For_Initiation_Sec 10
#else
    #define CDB_Store_Ubiquitos_Delay_For_Initiation_Sec 180
#endif


NSString * _Nonnull CDBCoreDataStoreWillChangeNotification = @"CDBCoreDataStoreWillChangeNotification";
NSString * _Nonnull CDBCoreDataStoreDidChangeNotification = @"CDBCoreDataStoreDidChangeNotification";


@interface CDBCoreDataStore ()

@property (strong, nonatomic, readonly) NSNotificationCenter * notificationCenter;

@property (strong, nonatomic, readwrite) NSURL * storeModelURL;
@property (strong, nonatomic, readwrite) NSString * storeName;
@property (strong, nonatomic, readwrite) NSManagedObjectModel * storeModel;

@property (strong, nonatomic, readwrite) NSManagedObjectContext * localContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * localStore;
@property (strong, nonatomic) NSURL * localStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * localStoreCoordinator;

@property (strong, nonatomic, readwrite) NSManagedObjectContext * ubiquitosContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * ubiqutosStore;
@property (strong, nonatomic) NSURL * ubiquitosStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * ubiquitosStoreCoordinator;

@property (strong, nonatomic, readonly) NSURL * localCoreDataUbiquitySupportDirectoryURL;

@end


BOOL CDBCheckStoreState(CDBCoreDataStoreState state, NSUInteger option) {
    BOOL result = (state & option) > 0;
    return result;
}

CDBCoreDataStoreState CDBAddStoreState(CDBCoreDataStoreState state, NSUInteger option) {
    CDBCoreDataStoreState result = state | option;
    return result;
}

CDBCoreDataStoreState CDBRemoveStoreState(CDBCoreDataStoreState state, NSUInteger option) {
    CDBCoreDataStoreState result = state & ~option;
    return result;
}


@implementation CDBCoreDataStore

@synthesize currentStoreState = _currentStoreState;


#pragma mark - property -

- (BOOL)ubiquitous {
    BOOL result = CDBCheckStoreState(self.currentStoreState, CDBCoreDataStoreUbiquitosActive);
    return result;
}

- (NSManagedObjectContext *)currentContext {
    NSManagedObjectContext * result = nil;
    
    if (self.ubiquitous) {
        result = self.ubiquitosContext;
    } else {
        result = self.localContext;
    }
    
    return result;
}

#pragma mark useability

- (NSNotificationCenter *)notificationCenter {
    NSNotificationCenter * result = [NSNotificationCenter defaultCenter];
    return result;
}

#pragma mark lazy loading

#pragma mark context

- (NSManagedObjectContext *)localContext {
    if (_localContext == nil
        && self.localStoreCoordinator != nil) {
        _localContext =
            [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_localContext setPersistentStoreCoordinator:self.localStoreCoordinator];
    }
    return _localContext;
}

- (NSManagedObjectContext *)ubiquitosContext {
    if (_ubiquitosContext == nil
        && self.ubiquitosStoreCoordinator != nil) {
        _ubiquitosContext =
            [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_ubiquitosContext setPersistentStoreCoordinator:self.ubiquitosStoreCoordinator];
    }
    return _ubiquitosContext;
}

#pragma mark store options

- (NSDictionary *)localStoreOptions {
    if (_localStoreOptions == nil) {
        _localStoreOptions =  @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                NSInferMappingModelAutomaticallyOption: @YES,
                               };
    }
    return _localStoreOptions;
}

- (NSDictionary *)ubiquitosStoreOptions {
    if (_ubiquitosStoreOptions == nil && self.storeName != nil) {
        _ubiquitosStoreOptions =  @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                    NSInferMappingModelAutomaticallyOption: @YES,
                                    NSPersistentStoreUbiquitousContentNameKey: self.storeName,
                                   };
    }
    return _ubiquitosStoreOptions;
}

#pragma mark store coordinator

- (NSPersistentStoreCoordinator *)localStoreCoordinator {
    if (_localStoreCoordinator == nil
        && self.storeName != nil
        && self.storeModel != nil) {
        NSPersistentStoreCoordinator * storeCoordinator = [self defaultStoreCoordinator];
        
        NSError * error = nil;
        NSPersistentStore * store =
            [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                           configuration:nil
                                                     URL:self.localStoreURL
                                                 options:self.localStoreOptions
                                                   error:&error];
        if (error == nil) {
            _localStoreCoordinator = storeCoordinator;
            _localStore = store;
        }
    }
    
    return _localStoreCoordinator;
}

- (NSPersistentStoreCoordinator *)ubiquitosStoreCoordinator {
    if (_ubiquitosStoreCoordinator == nil
        && self.storeName != nil
        && self.storeModel != nil) {
        NSPersistentStoreCoordinator * storeCoordinator = [self defaultStoreCoordinator];
        
        NSError * error = nil;
        NSPersistentStore * store =
            [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                           configuration:nil
                                                     URL:self.ubiquitosStoreURL
                                                 options:self.ubiquitosStoreOptions
                                                   error:&error];
        if (error == nil) {
            _ubiquitosStoreCoordinator = storeCoordinator;
            _ubiqutosStore = store;
            [self registerToiCloudStoreNotifications];
            [self preventLockSwitchingToUbiquitosStore];
            CDBCoreDataStoreState state = self.currentStoreState;
            state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosConnected);
            [self changeStoreStateTo:state];
        }
    }
    
    return _ubiquitosStoreCoordinator;
}

- (NSManagedObjectModel *)storeModel {
    if (_storeModel == nil
        && self.storeModelURL != nil) {
        _storeModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:self.storeModelURL];
    }
    
    return _storeModel;
}

#pragma mark urls

- (NSURL *)localStoreURL {
    NSURL * result = [[self applicationDirectoryURLForPath:NSDocumentDirectory] URLByAppendingPathComponent:self.storeName];
    return result;
}

- (NSURL *)ubiquitosStoreURL {
    NSURL * result = [self loadUbiquitosStoreURLUsingStoreName:self.storeName];
    
    if (result == nil) {
        result = [[self applicationDirectoryURLForPath:NSLibraryDirectory] URLByAppendingPathComponent:self.storeName];
    }
    
    return result;
}

- (NSURL *)localCoreDataUbiquitySupportDirectoryURL {
    NSURL * result =
        [[self applicationDirectoryURLForPath:NSLibraryDirectory] URLByAppendingPathComponent:@"CoreDataUbiquitySupport"
                                                                                  isDirectory:YES];
    return result;
}

#pragma mark - life cycle -

+ (CDBCoreDataStore *)sharedInstance {
    static CDBCoreDataStore *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init];
    });
    
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)copyWithZone:(struct _NSZone *)zone {
    return self;
}

#pragma mark - notifications -

- (void)registerToiCloudStoreNotifications {
    [self.notificationCenter addObserver:self
                                selector:@selector(storesWillChange:)
                                    name:NSPersistentStoreCoordinatorStoresWillChangeNotification
                                  object:self.ubiquitosStoreCoordinator];
    
    [self.notificationCenter addObserver:self
                                selector:@selector(storesDidChange:)
                                    name:NSPersistentStoreCoordinatorStoresDidChangeNotification
                                  object:self.ubiquitosStoreCoordinator];
    
    [self.notificationCenter addObserver:self
                                selector:@selector(persistentStoreDidImportUbiquitousContentChanges:)
                                    name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                  object:self.ubiquitosStoreCoordinator];
}

- (void)unregisterFromiCloudStoreNotifications {
    [self.notificationCenter removeObserver:self];
}

- (void)postNotificationUsingName:(NSString *)name {
    [self.notificationCenter postNotificationName:name
                                           object:self];
}

#pragma mark - public -

- (void)initiateWithStoreName:(NSString * _Nonnull)storeName
                storeModelURL:(NSURL * _Nonnull)modelURL {
    self.storeModelURL = modelURL;
    self.storeName = storeName;
    
    
    [self postNotificationUsingName:CDBCoreDataStoreWillChangeNotification];
    [self loadStoreStateForStoreName:self.storeName];
    [self postNotificationUsingName:CDBCoreDataStoreDidChangeNotification];
}

- (void)selectUbiquitos:(BOOL)ubiquitos {
    CDBCoreDataStoreState state = self.currentStoreState;
    if (ubiquitos) {
        state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosSelected);
    } else {
        state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosSelected);
    }
    [self changeStoreStateTo:state];
}

- (void)replaceLocalStoreUsingUbiquitosOne {
    NSMutableDictionary * destinationOptions = [self.localStoreOptions mutableCopy];
    destinationOptions[NSPersistentStoreRemoveUbiquitousMetadataOption] = @YES;
    
    
    
    NSPersistentStoreCoordinator * replacementCoordinator = [self defaultStoreCoordinator];
    
    NSError * error = nil;
    
    [self.localStoreCoordinator removePersistentStore:self.localStore
                                                error:&error];
    self.localStoreCoordinator = nil;
    
    if (error != nil) {
        
    }
    
    [replacementCoordinator replacePersistentStoreAtURL:self.localStoreURL
                                     destinationOptions:destinationOptions
                             withPersistentStoreFromURL:self.ubiquitosStoreURL
                                          sourceOptions:self.ubiquitosStoreOptions
                                              storeType:NSSQLiteStoreType
                                                  error:&error];
    
    
    if (error != nil) {
        
    }
}

- (void)dismissLocalCoreDataStack {
    self.localContext = nil;
    self.localStore = nil;
    self.localStoreCoordinator = nil;
}

- (void)dismissUbiquitosCoreDataStack {
    self.ubiquitosContext = nil;
    self.ubiqutosStore = nil;
    self.ubiquitosStoreCoordinator = nil;
    
    CDBCoreDataStoreState state = [self loadCurrentStoreStateUsingStoreName:self.storeName];
    
    state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosConnected);
    state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosActive);
    
    [self changeStoreStateTo:state];
}

- (void)mergeUbiquitousContentChangesUsing:(NSNotification *)changeNotification {
    NSManagedObjectContext * context = self.ubiquitosContext;
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:changeNotification];
    }];
}

- (void)removeLocalUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.localCoreDataUbiquitySupportDirectoryURL.path] == NO) {
        return;
    }
    
    __block NSError * error = nil;
    void (^ accessor)(NSURL * writingURL)  = ^(NSURL* writingURL) {
        [[NSFileManager new] removeItemAtURL:writingURL
                                       error:&error];
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self dismissUbiquitosCoreDataStack];
        });
        
        NSFileCoordinator * fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        
        [fileCoordinator coordinateWritingItemAtURL:self.localCoreDataUbiquitySupportDirectoryURL
                                            options:NSFileCoordinatorWritingForDeleting
                                              error:nil
                                         byAccessor:accessor];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion != nil) {
                completion(error);
            }
        });
    });
}

- (void)removeAllUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion {
    CDBCoreDataStoreState state = [self loadCurrentStoreStateUsingStoreName:self.storeName];
    
    state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosSelected);
    state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosConnected);
    state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosActive);
    
    [self changeStoreStateTo:state];
    
    [self dismissUbiquitosCoreDataStack];
    
    NSError * error = nil;
    
    [NSPersistentStoreCoordinator removeUbiquitousContentAndPersistentStoreAtURL:self.ubiquitosStoreURL
                                                                         options:self.ubiquitosStoreOptions
                                                                           error:&error];
    
    if (completion != nil) {
        completion(error);
    }
}

#pragma mark - private -

#pragma mark store state changing

- (void)loadStoreStateForStoreName:(NSString *)name {
    if (name.length == 0) {
        return;
    }
    
    // check if cloud user changed and make app use local store if cloud not initiated yet
    CDBCoreDataStoreState state = [self loadCurrentStoreStateUsingStoreName:self.storeName];
    
    // definately we not connected and not active yet
    state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosConnected);
    state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosActive);
    
    if (state & CDBCoreDataStoreUbiquitosInitiated) {
        id token = [self currentUbiquitosStoreToken];
        id initiatedOne = [self loadUbiquitosStoreTokenUsingStoreName:self.storeName];
        if ([token isEqual:initiatedOne] == NO) {
            state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosInitiated);
            state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosActive);
        }
    }
    
    [self changeStoreStateTo:state];
}

- (void)changeStoreStateTo:(CDBCoreDataStoreState)state {
    if (self.currentStoreState == state) {
        return;
    }
    
    BOOL shouldPostDidChangeNotification = NO;
    
    
    if (CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosSelected) == NO) {
        state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosActive);
    }

    if (CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosSelected)
        && CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosConnected)
        && CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosInitiated)) {
        state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosActive);
    }
    
    if (CDBCheckStoreState(self.currentStoreState, CDBCoreDataStoreUbiquitosActive)
        && (CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosActive) == NO)) {
        [self postNotificationUsingName:CDBCoreDataStoreWillChangeNotification];
        
        [self notifyDelegateThatStoreSwitchingToUbiquitous:NO];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if ((CDBCheckStoreState(self.currentStoreState, CDBCoreDataStoreUbiquitosActive) == NO)
        && CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosActive)) {
        [self postNotificationUsingName:CDBCoreDataStoreWillChangeNotification];
        
        [self storeSystemProvidedUbiquitosStoreURL];
        
        [self notifyDelegateThatStoreSwitchingToUbiquitous:YES];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if (CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosSelected)
        && (CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosConnected) == NO)) {
        // make store initiate cloud connection if not connected yet
        dispatch_async(dispatch_get_main_queue(), ^{
            [self touch:self.ubiquitosStoreCoordinator];
        });
    }

    _currentStoreState = state;
    [self saveCurrentStoreState:state
                 usingStoreName:self.storeName];
    
    if (shouldPostDidChangeNotification) {
         dispatch_async(dispatch_get_main_queue(), ^{
             [self postNotificationUsingName:CDBCoreDataStoreDidChangeNotification];
         });
    }
    
    [self notifyDelegateThatStoreDidChangeState];
}

#pragma mark delegate method calls

- (void)notifyDelegateThatStoreSwitchingToUbiquitous:(BOOL)ubiquitous {
    if ([self.delegate respondsToSelector:@selector(CDBCoreDataStore:switchingToUbiquitous:)]) {
        [self.delegate CDBCoreDataStore:self
                  switchingToUbiquitous:ubiquitous];
    }
}

- (void)notifyDelegateThatStoreDidChangeState {
    if ([self.delegate respondsToSelector:@selector(CDBCoreDataDidChangeStateOfStore:)]) {
        [self.delegate CDBCoreDataDidChangeStateOfStore:self];
    }
}

- (void)notifyDelegateThatUserWillRemoveContentOfStore {
    if ([self.delegate respondsToSelector:@selector(CDBCoreDataDetectThatUserWillRemoveContentOfStore:)]) {
        [self.delegate CDBCoreDataDetectThatUserWillRemoveContentOfStore:self];
    }
}

#pragma mark context 

- (void)saveContext {
    NSManagedObjectContext * context = self.currentContext ;
    [context performBlockAndWait:^{
        NSError * error = nil;
        
        if ([context hasChanges]) {
            [context save:&error];
            
            if (error != nil) {
                // perform error handling
                NSLog(@"%@", [error localizedDescription]);
            }
        }
    }];
}

#pragma mark prevent cloud lock when losed store changed InitialImportCompleted notification

- (void)preventLockSwitchingToUbiquitosStore {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(CDB_Store_Ubiquitos_Delay_For_Initiation_Sec * NSEC_PER_SEC)),
                                 dispatch_get_main_queue(), ^{
        CDBCoreDataStoreState state = self.currentStoreState;
        if (CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosSelected)
            && CDBCheckStoreState(state, CDBCoreDataStoreUbiquitosConnected)) {
            state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosInitiated);
            [self changeStoreStateTo:state];
        }
    });
}

#pragma mark iCloud store changes handling

- (void)persistentStoreDidImportUbiquitousContentChanges:(NSNotification *)changeNotification {
    if ([self.delegate respondsToSelector:@selector(CDBCoreDataStore:didImportUbiquitousContentChanges:)]) {
        [self.delegate CDBCoreDataStore:self
         didImportUbiquitousContentChanges:changeNotification];
    } else {
        [self mergeUbiquitousContentChangesUsing:changeNotification];
    }
    
    [self postNotificationUsingName:CDBCoreDataStoreDidChangeNotification];
}

- (void)storesWillChange:(NSNotification *)notification {
    NSPersistentStoreUbiquitousTransitionType transitionType =
        [self transitionTypeFromNotification:notification];
    
    CDBCoreDataStoreState state = self.currentStoreState;
    switch (transitionType) {
        case NSPersistentStoreUbiquitousTransitionTypeAccountAdded: {
        }   break;
        
        case NSPersistentStoreUbiquitousTransitionTypeAccountRemoved: {
            state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosConnected);
            state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosActive);
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeContentRemoved: {
            [self notifyDelegateThatUserWillRemoveContentOfStore];
            state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosConnected);
            state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosSelected);
            state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosActive);
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeInitialImportCompleted: {
        }   break;
            
        default:
            break;
    }
    
    [self changeStoreStateTo:state];
}

- (void)storesDidChange:(NSNotification *)notification {
    NSPersistentStoreUbiquitousTransitionType transitionType =
        [self transitionTypeFromNotification:notification];
    
    CDBCoreDataStoreState state = self.currentStoreState;
    switch (transitionType) {
        case NSPersistentStoreUbiquitousTransitionTypeAccountAdded: {
            state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosActive);
            state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosConnected); //????
        }   break;
        
        case NSPersistentStoreUbiquitousTransitionTypeAccountRemoved: {
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeContentRemoved: {
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeInitialImportCompleted: {
            state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosInitiated);
        }   break;
            
        default:
            break;
    }
    
    [self changeStoreStateTo:state];
}

- (NSPersistentStoreUbiquitousTransitionType)transitionTypeFromNotification:(NSNotification *)notification {
    NSNumber * transition = notification.userInfo[@"NSPersistentStoreUbiquitousTransitionTypeKey"];
    NSPersistentStoreUbiquitousTransitionType result =
    (NSPersistentStoreUbiquitousTransitionType)transition.unsignedIntegerValue;
    return result;
}

#pragma mark directory urls

- (NSURL *)applicationDirectoryURLForPath:(NSSearchPathDirectory)pathDirectory {
    NSURL * result =
        [[[NSFileManager defaultManager] URLsForDirectory:pathDirectory inDomains:NSUserDomainMask] lastObject];
    return result;
}

#pragma mark store to user defaults 

#pragma mark CDB.CDBCoreDataStore.store.ubiquitos.URL=NSURL

- (NSString *)ubiquitosStoreURLKeyUsingStoreName:(NSString *)storeName {
    NSString * result = [storeName stringByAppendingString:CDB_Store_Ubiqutos_URL_Postfix];
    return result;
}

- (void)saveUbiquitosStoreURL:(NSURL *)storeURL
               usingStoreName:(NSString *)storeName {
    if (storeName.length == 0
        || storeURL == nil) {
        return;
    }
    
    NSString * key = [self ubiquitosStoreURLKeyUsingStoreName:storeName];
    
    [[NSUserDefaults standardUserDefaults] setURL:storeURL
                                           forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSURL *)loadUbiquitosStoreURLUsingStoreName:(NSString *)storeName {
    NSString * key = [self ubiquitosStoreURLKeyUsingStoreName:storeName];
    
    NSURL * result = [[NSUserDefaults standardUserDefaults] URLForKey:key];
    return result;
}

#pragma mark CDB.CDBCoreDataStore.store.current.state=CDBCoreDataStoreState

- (NSString *)currentStoreTypeKeyUsingStoreName:(NSString *)storeName {
    NSString * result = [storeName stringByAppendingString:CDB_Store_Current_State_Postfix];
    return result;
}

- (void)saveCurrentStoreState:(CDBCoreDataStoreState)storeState
               usingStoreName:(NSString *)storeName {
    if (storeName.length == 0) {
        return;
    }
    
    NSString * key = [self currentStoreTypeKeyUsingStoreName:storeName];
    
    [[NSUserDefaults standardUserDefaults] setInteger:storeState
                                               forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CDBCoreDataStoreState)loadCurrentStoreStateUsingStoreName:(NSString *)storeName {
    NSString * key = [self currentStoreTypeKeyUsingStoreName:storeName];
    
    CDBCoreDataStoreState result = (CDBCoreDataStoreState)[[NSUserDefaults standardUserDefaults] integerForKey:key];
    return result;
}

#pragma mark CDB.CDBCoreDataStore.store.ubiquitos.token=NSObject

- (NSString *)ubiquitosStoreTokenKeyUsingStoreName:(NSString *)storeName {
    NSString * result = [storeName stringByAppendingString:CDB_Store_Ubiqutos_Token_Postfix];
    return result;
}

- (void)saveUbiquitosStoreToken:(id<NSObject, NSCoding, NSCopying>)storeToken
               usingStoreName:(NSString *)storeName {
    if (storeName.length == 0
        || storeToken == nil) {
        return;
    }
    
    NSString * key = [self ubiquitosStoreTokenKeyUsingStoreName:storeName];
    
    [[NSUserDefaults standardUserDefaults] setObject:storeToken
                                              forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id<NSObject, NSCoding, NSCopying>)loadUbiquitosStoreTokenUsingStoreName:(NSString *)storeName {
    NSString * key = [self ubiquitosStoreTokenKeyUsingStoreName:storeName];
    
    id<NSObject, NSCoding, NSCopying> result = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return result;
}

#pragma mark ubiquitos url store

- (void)storeSystemProvidedUbiquitosStoreURL {
    NSURL * URL = self.ubiqutosStore.URL;
    [self saveUbiquitosStoreURL:URL
                 usingStoreName:self.storeName];
}

#pragma mark store coordinator

- (NSPersistentStoreCoordinator *)defaultStoreCoordinator {
    if (self.storeModel == nil) {
        return nil;
    }
    
    NSPersistentStoreCoordinator * result =
        [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.storeModel];
    return result;
}

#pragma mark touch

- (void)touch:(NSObject *)object {
    [object isKindOfClass:[object class]];
}

- (id<NSObject,NSCopying,NSCoding>)currentUbiquitosStoreToken {
    NSFileManager * fileManager = [NSFileManager defaultManager];
    id<NSObject,NSCopying,NSCoding> result = fileManager.ubiquityIdentityToken;
    return result;
}

@end
