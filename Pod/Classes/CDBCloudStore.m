

#import "CDBCloudStore.h"
#import <Identify/Identify.h>


#define CDB_Store_Ubiqutos_URL_Postfix @".CDB.CDBCloudStore.store.ubiquitos.URL=NSURL"
#define CDB_Store_Current_State_Postfix @".CDB.CDBCloudStore.store.current.state=CDBCloudStoreState"
#define CDB_Store_Ubiqutos_Token_Postfix @".CDB.CDBCloudStore.store.ubiquitos.token=NSObject"
#define CDB_Store_SQLite_Files_Postfixes @[@"-shm", @"-wal"]
#define CDB_Store_Ubiquitos_Content_Local_Directory_Name @"CoreDataUbiquitySupport"


#ifdef DEBUG
    #define CDB_Store_Ubiquitos_Delay_For_Initiation_Sec 10
#else
    #define CDB_Store_Ubiquitos_Delay_For_Initiation_Sec 180
#endif


NSString * _Nonnull CDBCloudStoreWillChangeNotification = @"CDBCloudStoreWillChangeNotification";
NSString * _Nonnull CDBCloudStoreDidChangeNotification = @"CDBCloudStoreDidChangeNotification";


@interface CDBCloudStore ()



@property (strong, nonatomic, readwrite) NSURL * storeModelURL;
@property (strong, nonatomic, readwrite) NSString * storeName;
@property (strong, nonatomic, readwrite) NSManagedObjectModel * storeModel;

@property (assign, nonatomic, readwrite) BOOL localStoreDisabled;
@property (strong, nonatomic, readwrite) NSManagedObjectContext * localContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * localStore;
@property (strong, nonatomic) NSURL * localStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * localStoreCoordinator;

@property (assign, nonatomic, readwrite) BOOL ubiquitosStoreDisabled;
@property (strong, nonatomic, readwrite) NSManagedObjectContext * ubiquitosContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * ubiqutosStore;
@property (strong, nonatomic) NSURL * ubiquitosStoreURL;
@property (strong, nonatomic, readwrite) NSURL * ubiquitosTempStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * ubiquitosStoreCoordinator;

@end


BOOL CDBCheckStoreState(CDBCloudStoreState state, NSUInteger option) {
    BOOL result = (state & option) > 0;
    return result;
}

CDBCloudStoreState CDBAddStoreState(CDBCloudStoreState state, NSUInteger option) {
    CDBCloudStoreState result = state | option;
    return result;
}

CDBCloudStoreState CDBRemoveStoreState(CDBCloudStoreState state, NSUInteger option) {
    CDBCloudStoreState result = state & ~option;
    return result;
}


@implementation CDBCloudStore

@synthesize state = _state;


#pragma mark - property -

- (BOOL)ubiquitous {
    BOOL result = CDBCheckStoreState(self.state, CDBCloudStoreUbiquitosActive);
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

#pragma mark lazy loading

#pragma mark context

- (NSManagedObjectContext *)localContext {
    if (self.localStoreDisabled) {
        return nil;
    }
    
    if (_localContext == nil
        && self.localStoreCoordinator != nil) {
        _localContext =
            [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_localContext setPersistentStoreCoordinator:self.localStoreCoordinator];
    }
    return _localContext;
}

- (NSManagedObjectContext *)ubiquitosContext {
    if (self.ubiquitosStoreDisabled) {
        return nil;
    }
    
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
            [self notifyDelegateThatCoreDataStackCreatedForUbiquitos:NO];
        }
    }
    
    return _localStoreCoordinator;
}

- (NSPersistentStoreCoordinator *)ubiquitosStoreCoordinator {
    if (_ubiquitosStoreCoordinator == nil
        && self.storeName != nil
        && self.storeModel != nil) {
//        NSURL * ubiquitosStoreURL = [[NSFileManager new] URLForUbiquityContainerIdentifier:nil];
//        if (ubiquitosStoreURL != nil) {
            NSPersistentStoreCoordinator * storeCoordinator = [self defaultStoreCoordinator];
            
            NSError * error = nil;
            NSPersistentStore * store =
            [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                           configuration:nil
                                                     URL:self.ubiquitosTempStoreURL
                                                 options:self.ubiquitosStoreOptions
                                                   error:&error];
            if (error == nil) {
                _ubiquitosStoreCoordinator = storeCoordinator;
                _ubiqutosStore = store;
                [self subscribeToUbiquitosStoreNotifications];
                [self preventLockSwitchingToUbiquitosStore];
                [self notifyDelegateThatCoreDataStackCreatedForUbiquitos:YES];
            }
//        }
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
    return result;
}

- (NSURL *)ubiquitosTempStoreURL {
    NSURL * result = [[self applicationDirectoryURLForPath:NSLibraryDirectory] URLByAppendingPathComponent:self.storeName];;
    return result;
}

#pragma mark - life cycle -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - notifications -

- (void)subscribeToUbiquitosStoreNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storesWillChange:)
                                                 name:NSPersistentStoreCoordinatorStoresWillChangeNotification
                                               object:self.ubiquitosStoreCoordinator];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storesDidChange:)
                                                 name:NSPersistentStoreCoordinatorStoresDidChangeNotification
                                               object:self.ubiquitosStoreCoordinator];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(persistentStoreDidImportUbiquitousContentChanges:)
                                                 name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                               object:self.ubiquitosStoreCoordinator];
}

- (void)unsubscribeFromUbiquitosStoreNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)postNotificationUsingName:(NSString *)name {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self];
}

#pragma mark - public -

- (void)initiateWithStoreName:(NSString * _Nonnull)storeName
                storeModelURL:(NSURL * _Nonnull)modelURL {
    self.storeModelURL = modelURL;
    self.storeName = storeName;
    
    
    [self postNotificationUsingName:CDBCloudStoreWillChangeNotification];
    CDBCloudStoreState state = [self loadStoreStateForStoreName:self.storeName];
    [self changeStoreStateTo:state];
    [self postNotificationUsingName:CDBCloudStoreDidChangeNotification];
}

- (void)selectUbiquitos:(BOOL)ubiquitos {
    CDBCloudStoreState state = self.state;
    if (ubiquitos) {
        state = CDBAddStoreState(state, CDBCloudStoreUbiquitosSelected);
    } else {
        state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosSelected);
    }
    [self changeStoreStateTo:state];
}

- (void)replaceLocalStoreUsingUbiquitosOneWithCompletion:(CDBErrorCompletion _Nullable)completion {
    [self dismissAndDisableLocalCoreDataStack];
    
    [self removeCoreDataStoreAtURL:self.localStoreURL
                        completion:^(NSError * _Nullable deletionError) {
        NSMutableDictionary * migrationOptions = [self.localStoreOptions mutableCopy];
        migrationOptions[NSPersistentStoreRemoveUbiquitousMetadataOption] = @YES;

        NSError * error = nil;
        [self.ubiquitosStoreCoordinator migratePersistentStore:self.ubiqutosStore
                                                         toURL:self.localStoreURL
                                                       options:migrationOptions
                                                      withType:NSSQLiteStoreType
                                                         error:&error];
        [self enableLocalCoreDataStack];
        if (completion != nil) {
            completion(error);
        }
    }];
}

- (void)dismissAndDisableLocalCoreDataStack {
    [_localContext performBlockAndWait:^{
        [_localContext save:nil];
    }];
    
    self.localStoreDisabled = YES;

    _localContext = nil;
    _localStore = nil;
    _localStoreCoordinator = nil;
}

- (void)enableLocalCoreDataStack {
    self.localStoreDisabled = NO;
}

- (void)dismissAndDisableUbiquitosCoreDataStack {
    [_ubiquitosContext performBlockAndWait:^{
        [_ubiquitosContext save:nil];
    }];

    self.ubiquitosStoreDisabled = YES;
    
    [self unsubscribeFromUbiquitosStoreNotifications];
    
    _ubiquitosContext = nil;
    _ubiqutosStore = nil;
    _ubiquitosStoreCoordinator = nil;
}

- (void)enableUbiquitosCoreDataStack {
    self.ubiquitosStoreDisabled = NO;
    [self initiateUbiquitosConnection];
}

- (void)mergeUbiquitousContentChanges:(NSNotification *)changeNotification
                         usingContext:(NSManagedObjectContext *)context {
    if (context == nil) {
        return;
    }
    
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:changeNotification];
    }];
    
    [self saveContext:context];
}

- (void)rebuildUbiquitosStoreFromUbiquitousContenWithCompletion:(CDBErrorCompletion _Nullable)completion {
    NSDictionary * options = self.ubiquitosStoreOptions;
    
    [self dismissAndDisableUbiquitosCoreDataStack];
    
    NSMutableDictionary * rebuildOptions = [options mutableCopy];
    rebuildOptions[NSPersistentStoreRebuildFromUbiquitousContentOption] = @(YES);
    self.ubiquitosStoreOptions = [rebuildOptions copy];
    
    [self enableUbiquitosCoreDataStack];
    [self touch:self.ubiquitosStoreCoordinator];
    
    self.ubiquitosStoreOptions = options;
    
    if (completion != nil) {
        completion(nil);
    }
}

- (void)removeLocalUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion {
    
    NSURL * firstPossibleDirectory =
        [[self applicationDirectoryURLForPath:NSDocumentDirectory]
            URLByAppendingPathComponent:CDB_Store_Ubiquitos_Content_Local_Directory_Name
                            isDirectory:YES];
    NSURL * secondPossibleDirectory =
        [[self applicationDirectoryURLForPath:NSLibraryDirectory]
            URLByAppendingPathComponent:CDB_Store_Ubiquitos_Content_Local_Directory_Name
                            isDirectory:YES];
    
    [self dismissAndDisableUbiquitosCoreDataStack];
    
    [self coordinatedRemoveItemsAtURLs:@[firstPossibleDirectory, secondPossibleDirectory]
                            completion:^(NSError * _Nullable error) {
        [self enableUbiquitosCoreDataStack];
        
        if (completion != nil) {
            completion(error);
        }
    }];
}

- (void)removeAllUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion {
    [self dismissAndDisableUbiquitosCoreDataStack];
      
    NSError * error = nil;
    
    [NSPersistentStoreCoordinator removeUbiquitousContentAndPersistentStoreAtURL:self.ubiquitosStoreURL
                                                                         options:self.ubiquitosStoreOptions
                                                                           error:&error];
    [self enableUbiquitosCoreDataStack];
    
    if (completion != nil) {
        completion(error);
    }
}

- (void)removeCoreDataStoreAtURL:(NSURL *)URL
                      completion:(CDBErrorCompletion)completion {
    if (URL.path.length == 0) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    NSMutableArray * URLsToRemove = [NSMutableArray array];
    [URLsToRemove addObject:URL];
    
    NSString * storeName = URL.lastPathComponent;
    NSURL * containingDirectoryURL = [URL URLByDeletingLastPathComponent];
    
    for (NSString * postfix in CDB_Store_SQLite_Files_Postfixes) {
        NSString * fileName = [storeName stringByAppendingString:postfix];
        NSURL * URLToDelete = [containingDirectoryURL URLByAppendingPathComponent:fileName];
        if (URLToDelete == nil) {
            continue;
        }
        [URLsToRemove addObject:URLToDelete];
    }
    
    [self coordinatedRemoveItemsAtURLs:URLsToRemove
                            completion:completion];
}

#pragma mark - private -

#pragma mark store state changing

- (CDBCloudStoreState)loadStoreStateForStoreName:(NSString *)name {
    if (name.length == 0) {
        return 0;
    }
    
    // check if cloud user changed and make app use local store if cloud not initiated yet
    CDBCloudStoreState result = [self loadCurrentStoreStateUsingStoreName:self.storeName];
    
    // definately we are not active yet
    result = CDBRemoveStoreState(result, CDBCloudStoreUbiquitosActive);
    
    if (result & CDBCloudStoreUbiquitosInitiated) {
        id token = [self currentUbiquitosStoreToken];
        id initiatedOne = [self loadUbiquitosStoreTokenUsingStoreName:self.storeName];
        if ([token isEqual:initiatedOne] == NO) {
            result = CDBRemoveStoreState(result, CDBCloudStoreUbiquitosInitiated);
            result = CDBRemoveStoreState(result, CDBCloudStoreUbiquitosActive);
        }
    }
    
    return result;
}

- (void)changeStoreStateTo:(CDBCloudStoreState)incomingState {
    if (self.state == incomingState) {
        return;
    }
    
    BOOL shouldPostDidChangeNotification = NO;
    
    if (CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosSelected) == NO) {
        incomingState = CDBRemoveStoreState(incomingState, CDBCloudStoreUbiquitosActive);
    }

    if (CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosSelected)
        && CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosInitiated)) {
        incomingState = CDBAddStoreState(incomingState, CDBCloudStoreUbiquitosActive);
    }
    
    if (CDBCheckStoreState(self.state, CDBCloudStoreUbiquitosActive)
        && (CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosActive) == NO)) {
        [self postNotificationUsingName:CDBCloudStoreWillChangeNotification];
        
        [self notifyDelegateThatStoreSwitchingToUbiquitous:NO];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if ((CDBCheckStoreState(self.state, CDBCloudStoreUbiquitosActive) == NO)
        && CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosActive)) {
        [self postNotificationUsingName:CDBCloudStoreWillChangeNotification];
        
        [self storeSystemProvidedUbiquitosStoreData];
        
        [self notifyDelegateThatStoreSwitchingToUbiquitous:YES];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if (CDBCheckStoreState(incomingState, CDBCloudStoreUbiquitosSelected)
        && _ubiquitosStoreCoordinator == nil) {
        [self initiateUbiquitosConnection];
    }

    _state = incomingState;
    [self saveCurrentStoreState:_state
                 usingStoreName:self.storeName];
    
    if (shouldPostDidChangeNotification) {
        __weak typeof (self) wself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself postNotificationUsingName:CDBCloudStoreDidChangeNotification];
        });
    }
    
    [self notifyDelegateThatStoreDidChangeState];
}

- (void)initiateUbiquitosConnection {
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself touch:self.ubiquitosStoreCoordinator];
    });
}

#pragma mark delegate method calls

- (void)notifyDelegateThatStoreSwitchingToUbiquitous:(BOOL)ubiquitous {
    if ([self.delegate respondsToSelector:@selector(CDBCloudStore:switchingToUbiquitous:)]) {
        [self.delegate CDBCloudStore:self
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

- (void)notifyDelegateThatCoreDataStackCreatedForUbiquitos:(BOOL)ubiquitos {
    if ([self.delegate respondsToSelector:@selector(CDBCloudStore:didCreateCoreDataStackThatUbiquitous:)]) {
        [self.delegate CDBCloudStore:self didCreateCoreDataStackThatUbiquitous:ubiquitos];
    }
}

#pragma mark context 

- (void)saveContext:(NSManagedObjectContext *)context {
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

- (void)resetContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        [context reset];
    }];
}

#pragma mark prevent cloud lock when losed store changed InitialImportCompleted notification

- (void)preventLockSwitchingToUbiquitosStore {
    __weak typeof (self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(CDB_Store_Ubiquitos_Delay_For_Initiation_Sec * NSEC_PER_SEC)),
                                 dispatch_get_main_queue(), ^{
        CDBCloudStoreState state = wself.state;
        if (CDBCheckStoreState(state, CDBCloudStoreUbiquitosSelected)
            && _ubiquitosStoreCoordinator != nil) {
            state = CDBAddStoreState(state, CDBCloudStoreUbiquitosInitiated);
            [wself changeStoreStateTo:state];
        }
    });
}

#pragma mark iCloud store changes handling

- (void)persistentStoreDidImportUbiquitousContentChanges:(NSNotification *)changeNotification {
    __weak typeof (self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([wself.delegate respondsToSelector:@selector(CDBCloudStore:didImportUbiquitousContentChanges:)]) {
            [wself.delegate CDBCloudStore:wself
        didImportUbiquitousContentChanges:changeNotification];
        } else {
            [wself mergeUbiquitousContentChanges:changeNotification
                                    usingContext:wself.ubiquitosContext];
        }
        
        [wself postNotificationUsingName:CDBCloudStoreDidChangeNotification];
    });
}

- (void)storesWillChange:(NSNotification *)notification {
    if ([NSThread isMainThread]) {
        [self handleStoresWillChange:notification];
        return;
    }
    __weak typeof (self) wself = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [wself handleStoresWillChange:notification];
    });
}

- (void)handleStoresWillChange:(NSNotification *)notification {
    
    NSPersistentStoreUbiquitousTransitionType transitionType =
        [self transitionTypeFromNotification:notification];
    
    CDBCloudStoreState state = self.state;
    switch (transitionType) {
        case NSPersistentStoreUbiquitousTransitionTypeAccountAdded: {
        }   break;
        
        case NSPersistentStoreUbiquitousTransitionTypeAccountRemoved: {
            state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosActive);
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeContentRemoved: {
            [self notifyDelegateThatUserWillRemoveContentOfStore];
            state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosSelected);
            state = CDBRemoveStoreState(state, CDBCloudStoreUbiquitosActive);
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeInitialImportCompleted: {
        }   break;
            
        default:
            break;
    }
    
    [self changeStoreStateTo:state];
    
    [self saveContext:self.currentContext];
    [self resetContext:self.currentContext];
}

- (void)storesDidChange:(NSNotification *)notification {
    if ([NSThread isMainThread]) {
        [self handleStoresDidChange:notification];
        return;
    }
    __weak typeof (self) wself = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [wself handleStoresDidChange:notification];
    });
}

- (void)handleStoresDidChange:(NSNotification *)notification {
    NSPersistentStoreUbiquitousTransitionType transitionType =
        [self transitionTypeFromNotification:notification];
    
    CDBCloudStoreState state = self.state;
    switch (transitionType) {
        case NSPersistentStoreUbiquitousTransitionTypeAccountAdded: {
            state = [self loadStoreStateForStoreName:self.storeName];
        }   break;
        
        case NSPersistentStoreUbiquitousTransitionTypeAccountRemoved: {
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeContentRemoved: {
        }   break;
            
        case NSPersistentStoreUbiquitousTransitionTypeInitialImportCompleted: {
            state = CDBAddStoreState(state, CDBCloudStoreUbiquitosInitiated);
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

#pragma mark CDB.CDBCloudStore.store.ubiquitos.URL=NSURL

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

#pragma mark CDB.CDBCloudStore.store.current.state=CDBCloudStoreState

- (NSString *)currentStoreTypeKeyUsingStoreName:(NSString *)storeName {
    NSString * result = [storeName stringByAppendingString:CDB_Store_Current_State_Postfix];
    return result;
}

- (void)saveCurrentStoreState:(CDBCloudStoreState)storeState
               usingStoreName:(NSString *)storeName {
    if (storeName.length == 0) {
        return;
    }
    
    NSString * key = [self currentStoreTypeKeyUsingStoreName:storeName];
    
    [[NSUserDefaults standardUserDefaults] setInteger:storeState
                                               forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CDBCloudStoreState)loadCurrentStoreStateUsingStoreName:(NSString *)storeName {
    NSString * key = [self currentStoreTypeKeyUsingStoreName:storeName];
    
    CDBCloudStoreState result = (CDBCloudStoreState)[[NSUserDefaults standardUserDefaults] integerForKey:key];
    return result;
}

#pragma mark CDB.CDBCloudStore.store.ubiquitos.token=NSObject

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

- (void)storeSystemProvidedUbiquitosStoreData {
    NSURL * URL = self.ubiqutosStore.URL;
    [self saveUbiquitosStoreURL:URL
                 usingStoreName:self.storeName];
    id<NSObject,NSCopying,NSCoding> storeToken = [self currentUbiquitosStoreToken];
    [self saveUbiquitosStoreToken:storeToken
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

#pragma mark - files

- (void)coordinatedRemoveItemAtURL:(NSURL *)URL
                        completion:(CDBErrorCompletion)completion {
    __block NSError * error = nil;
    void (^ accessor)(NSURL * writingURL) = ^(NSURL* writingURL) {
        [[NSFileManager new] removeItemAtURL:writingURL
                                       error:&error];
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSFileCoordinator * fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        
        [fileCoordinator coordinateWritingItemAtURL:URL
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

/**
 * @brief:
 * note that we return last happend error only
**/

- (void)coordinatedRemoveItemsAtURLs:(NSArray *)URLs
                          completion:(CDBErrorCompletion)completion {
    NSMutableArray * URLsToRemove = [NSMutableArray array];
    for (NSURL * URL in URLs) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:URL.path] == NO) {
            continue;
        }
        [URLsToRemove addObject:URL];
    }
    
    if (URLsToRemove.count == 0) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    
    __block NSUInteger counter = URLsToRemove.count;
    __block NSError * removeError = nil;
    
    for (NSURL * URL in URLsToRemove) {
        [self coordinatedRemoveItemAtURL:URL
                              completion:^(NSError * _Nullable error) {
            if (error != nil) {
                removeError = error;
            }

            counter -= 1;

            if (counter == 0) {
                if (completion != nil) {
                    completion(removeError);
                }
            }
        }];
    }
}

#pragma mark - class -

#pragma mark duplicates handling

+ (void)performRemovingDublicatesForEntity:(NSEntityDescription *)entity
                         uniquePropertyKey:(NSString *)uniquePropertyKey
                              timestampKey:(NSString *)timestampKey
                              usingContext:(NSManagedObjectContext *)context
                                     error:(NSError **)error {
    
    NSArray * valuesWithDupes = [self valuesWithDublicatesForEntity:entity
                                                  uniquePropertyKey:uniquePropertyKey
                                                       usingContext:context
                                                              error:error];
    
    
    if (*error != nil) {
        RLogCDB(YES, @"failed to fetch values with dupes for unique key - %@, entity %@",
                uniquePropertyKey, entity.name);
        return;
    }
    
    RLogCDB(YES, @"found %ld not uniqued keys for entity %@",
            (unsigned long) valuesWithDupes.count, entity.name);
    
    [self resolveDuplicatesForEntity:entity
                   uniquePropertyKey:uniquePropertyKey
                        timestampKey:timestampKey
           usingValuesWithDublicates:valuesWithDupes
                             context:context
                               error:error];
    
    if (*error != nil) {
        RLogCDB(YES, @"failed to resolve dupes for unique key - %@, timestamp key - %@, entity %@",
                uniquePropertyKey, timestampKey, entity.name);
        return;
    }
    
    [context performBlockAndWait:^{
        [context save:error];
        [context reset];
    }];
}

+ (NSArray *)valuesWithDublicatesForEntity:(NSEntityDescription *)entity
                         uniquePropertyKey:(NSString *)uniquePropertyKey
                              usingContext:(NSManagedObjectContext *)context
                                     error:(NSError **)error {
    if (entity == nil
        || uniquePropertyKey.length == 0
        || context == nil) {
        return nil;
    }
    
    //    NSExpression * keyPathExpression = [NSExpression expressionForKeyPath:uniquePropertyKey];
    //    NSExpression * countExpression = [NSExpression expressionForFunction:@"count:" arguments:@[keyPathExpression]];
    NSExpression *countExpression = [NSExpression expressionWithFormat:@"count:(%K)", uniquePropertyKey];
    NSExpressionDescription * countExpressionDescription = [[NSExpressionDescription alloc] init];
    [countExpressionDescription setName:@"count"];
    [countExpressionDescription setExpression:countExpression];
    [countExpressionDescription setExpressionResultType:NSInteger64AttributeType];
    NSAttributeDescription * uniqueAttribute = [[entity attributesByName] objectForKey:uniquePropertyKey];
    
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    [request setPropertiesToFetch:@[uniqueAttribute, countExpressionDescription]];
    [request setPropertiesToGroupBy:@[uniqueAttribute]];
    [request setResultType:NSDictionaryResultType];
    
    NSArray * fetchedDictionaries = [context executeFetchRequest:request
                                                           error:error];
    
    NSMutableArray * result = [NSMutableArray array];
    for (NSDictionary * dict in fetchedDictionaries) {
        NSNumber * count = dict[@"count"];
        if ([count integerValue] > 1) {
            [result addObject:dict[uniquePropertyKey]];
        }
    }
    
    return [result copy];
}

+ (void)resolveDuplicatesForEntity:(NSEntityDescription *)entity
                 uniquePropertyKey:(NSString *)uniquePropertyKey
                      timestampKey:(NSString *)timestampKey
         usingValuesWithDublicates:(NSArray *)valuesWithDupes
                           context:(NSManagedObjectContext * _Nullable)context
                             error:(NSError **)error {
    
    NSFetchRequest * dupeRequest = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    [dupeRequest setIncludesPendingChanges:NO];
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"%K IN (%@)", uniquePropertyKey, valuesWithDupes];
    [dupeRequest setPredicate:predicate];
    NSSortDescriptor * uniquePropertySorted = [NSSortDescriptor sortDescriptorWithKey:uniquePropertyKey
                                                                            ascending:YES];
    [dupeRequest setSortDescriptors:@[uniquePropertySorted]];
    
    NSArray * fetchedDupes = [context executeFetchRequest:dupeRequest
                                                    error:error];
    
    if (*error != nil) {
        return;
    }
    
    NSUInteger removedDupesCount = 0;
    
    NSManagedObject * prevObject = nil;
    for (NSManagedObject * duplicate in fetchedDupes) {
        if (prevObject != nil) {
            NSString * prevObjectUniqueValue = [prevObject valueForKey:uniquePropertyKey];
            NSString * duplicateUniqueValue = [duplicate valueForKey:uniquePropertyKey];
            if ([duplicateUniqueValue isEqualToString:prevObjectUniqueValue]) {
                NSString * prevObjectTimestamp = [prevObject valueForKey:timestampKey];
                NSString * duplicateTimestamp = [duplicate valueForKey:timestampKey];
                if ([duplicateTimestamp compare:prevObjectTimestamp] == NSOrderedAscending) {
                    [context deleteObject:duplicate];
                } else {
                    [context deleteObject:prevObject];
                    prevObject = duplicate;
                }
                removedDupesCount++;
            } else {
                prevObject = duplicate;
            }
        } else {
            prevObject = duplicate;
        }
    }
    RLogCDB(YES, @"delete %ld dupes for unique key - %@, using newer timestamp logic at key - %@, entity %@",
            (unsigned long)removedDupesCount, uniquePropertyKey, timestampKey, entity.name);
}

+ (void)performBatchPopulationForEntity:(NSEntityDescription *)entity
                usingPropertiesToUpdate:(NSDictionary *)propertiesToUpdate
                              predicate:(NSPredicate *)predicate
                              inContext:(NSManagedObjectContext *)context {
    if (entity == nil
        || context == nil
        || propertiesToUpdate == nil) {
        return;
    }
    
    RLogCDB(YES, @"update entity %@ with %@", entity.name, propertiesToUpdate);
    
    NSBatchUpdateRequest * request = [[NSBatchUpdateRequest alloc] initWithEntity:entity];
    request.predicate = [NSPredicate predicateWithFormat:@"uid = nil"];
    request.propertiesToUpdate = propertiesToUpdate;
    request.resultType = NSUpdatedObjectsCountResultType;
    
    NSError * error = nil;
    NSBatchUpdateResult * result = (NSBatchUpdateResult *)[context executeRequest:request
                                                                            error:&error];
    if (error != nil) {
        RLogCDB(YES, @" failed update entity %@ with %@", entity.name, error);
        return;
    }
    
    RLogCDB(YES, @"%@ entities updated entity %@", result.result, entity.name);
}

+ (void)performBatchUIDsPopulationForEntity:(NSEntityDescription *)entity
                     usingUniquePropertyKey:(NSString *)uniquePropertyKey
                                  batchSize:(NSUInteger)batchSize
                                  inContext:(NSManagedObjectContext *)context {
    if (entity == nil
        || context == nil
        || uniquePropertyKey.length == 0) {
        return;
    }
    
    if (batchSize == 0) {
        batchSize = 1000;
    }
    
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    request.predicate = [NSPredicate predicateWithFormat:@"%K = nil", uniquePropertyKey];
    request.fetchBatchSize = batchSize;
    
    NSError * error = nil;
    NSArray<NSManagedObject *> * results = [context executeFetchRequest:request
                                                                  error:&error];
    
    if (error != nil) {
        RLogCDB(YES, @" failed fetch empty UID objects for entity %@ at unique key - %@ - with %@",
                entity.name, uniquePropertyKey, error);
        return;
    }
    
    NSUInteger currentIndex = 0;
    
    while (error == nil
           && currentIndex < results.count) {
        NSUInteger maxAvailableLenght = results.count - currentIndex;
        NSUInteger length = maxAvailableLenght < batchSize ? maxAvailableLenght
                                                           : batchSize;
        NSRange currentBatchRange = NSMakeRange(currentIndex, length);
        if (NSMaxRange(currentBatchRange) <= results.count) {
            @autoreleasepool {
                NSArray * batch = [results subarrayWithRange:currentBatchRange];
                [self populateUIDsOfManagedObjects:batch
                            usingUniquePropertyKey:(NSString * _Nullable)uniquePropertyKey
                                         inContext:context
                                             error:&error];
            }
        }
        
        currentIndex = NSMaxRange(currentBatchRange);
    }
    
    if (error != nil) {
        RLogCDB(YES, @" failed update UIDs for entity %@  at unique key - %@ - with %@",
                entity.name, uniquePropertyKey, error);
        return;
    }
    
    RLogCDB(YES, @"%lu UIDs created at unique key - %@ - for entity %@",
            (unsigned long)results.count, uniquePropertyKey, entity.name);
}

+ (void)populateUIDsOfManagedObjects:(NSArray<NSManagedObject *> *)mananagedObjects
              usingUniquePropertyKey:(NSString *)uniquePropertyKey
                           inContext:(NSManagedObjectContext *)context
                               error:(NSError **)error {
    for (NSManagedObject * object in mananagedObjects) {
        [object setValue:[self generateEntityUID]
                  forKey:uniquePropertyKey];
    }
    [context performBlockAndWait:^{
        [context save:error];
        [context reset];
    }];
}

+ (NSDate *)generateTimestamp {
    NSDate * result = [NSDate date];
    return result;
}

+ (NSString *)generateEntityUID {
    NSString * result = [Identify makeId];
    return result;
}

@end
