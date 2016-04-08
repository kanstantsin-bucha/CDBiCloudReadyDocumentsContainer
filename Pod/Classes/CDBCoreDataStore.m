

#import "CDBCoreDataStore.h"


#define CDB_Store_Ubiqutos_URL_Postfix @".CDB.CDBCoreDataStore.store.ubiquitos.URL=NSURL"
#define CDB_Store_Current_State_Postfix @".CDB.CDBCoreDataStore.store.current.state=CDBCoreDataStoreState"
#define CDB_Store_Ubiqutos_Token_Postfix @".CDB.CDBCoreDataStore.store.ubiquitos.token=NSObject"
#define CDB_Store_SQLite_Files_Postfixes @[@"-shm", @"-wal"]
#define CDB_Store_Ubiquitos_Content_Local_Directory_Name @"CoreDataUbiquitySupport"


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

@property (assign, nonatomic, readwrite) BOOL localStoreDisabled;
@property (strong, nonatomic, readwrite) NSManagedObjectContext * localContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * localStore;
@property (strong, nonatomic) NSURL * localStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * localStoreCoordinator;

@property (assign, nonatomic, readwrite) BOOL ubiquitosStoreDisabled;
@property (strong, nonatomic, readwrite) NSManagedObjectContext * ubiquitosContext;
@property (strong, nonatomic, readwrite) NSPersistentStore * ubiqutosStore;
@property (strong, nonatomic) NSURL * ubiquitosStoreURL;
@property (strong, nonatomic, readwrite) NSPersistentStoreCoordinator * ubiquitosStoreCoordinator;

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

@synthesize state = _state;


#pragma mark - property -

- (BOOL)ubiquitous {
    BOOL result = CDBCheckStoreState(self.state, CDBCoreDataStoreUbiquitosActive);
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
            [self subscribeToUbiquitosStoreNotifications];
            [self preventLockSwitchingToUbiquitosStore];
            [self notifyDelegateThatCoreDataStackCreatedForUbiquitos:YES];
            CDBCoreDataStoreState state = self.state;
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

- (void)subscribeToUbiquitosStoreNotifications {
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

- (void)unsubscribeFromUbiquitosStoreNotifications {
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
    CDBCoreDataStoreState state = self.state;
    if (ubiquitos) {
        state = CDBAddStoreState(state, CDBCoreDataStoreUbiquitosSelected);
    } else {
        state = CDBRemoveStoreState(state, CDBCoreDataStoreUbiquitosSelected);
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
    self.localStoreDisabled = YES;

    _localContext = nil;
    _localStore = nil;
    _localStoreCoordinator = nil;
}

- (void)enableLocalCoreDataStack {
    self.localStoreDisabled = NO;
}

- (void)dismissAndDisableUbiquitosCoreDataStack {
    self.ubiquitosStoreDisabled = YES;
    
    [self unsubscribeFromUbiquitosStoreNotifications];
    
    _ubiquitosContext = nil;
    _ubiqutosStore = nil;
    _ubiquitosStoreCoordinator = nil;
}

- (void)enableUbiquitosCoreDataStack {
    self.ubiquitosStoreDisabled = NO;
}

- (void)mergeUbiquitousContentChangesUsing:(NSNotification *)changeNotification {
    NSManagedObjectContext * context = self.ubiquitosContext;
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:changeNotification];
    }];
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

- (void)changeStoreStateTo:(CDBCoreDataStoreState)incomingState {
    if (self.state == incomingState) {
        return;
    }
    
    BOOL shouldPostDidChangeNotification = NO;
    
    
    if (CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosSelected) == NO) {
        incomingState = CDBRemoveStoreState(incomingState, CDBCoreDataStoreUbiquitosActive);
    }

    if (CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosSelected)
        && CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosConnected)
        && CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosInitiated)) {
        incomingState = CDBAddStoreState(incomingState, CDBCoreDataStoreUbiquitosActive);
    }
    
    if (CDBCheckStoreState(self.state, CDBCoreDataStoreUbiquitosActive)
        && (CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosActive) == NO)) {
        [self postNotificationUsingName:CDBCoreDataStoreWillChangeNotification];
        
        [self notifyDelegateThatStoreSwitchingToUbiquitous:NO];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if ((CDBCheckStoreState(self.state, CDBCoreDataStoreUbiquitosActive) == NO)
        && CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosActive)) {
        [self postNotificationUsingName:CDBCoreDataStoreWillChangeNotification];
        
        [self storeSystemProvidedUbiquitosStoreData];
        
        [self notifyDelegateThatStoreSwitchingToUbiquitous:YES];
        
        shouldPostDidChangeNotification = YES;
    }
    
    if (CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosSelected)
        && (CDBCheckStoreState(incomingState, CDBCoreDataStoreUbiquitosConnected) == NO)) {
        // make store initiate cloud connection if not connected yet
        dispatch_async(dispatch_get_main_queue(), ^{
            [self touch:self.ubiquitosStoreCoordinator];
        });
    }

    _state = incomingState;
    [self saveCurrentStoreState:_state
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

- (void)notifyDelegateThatCoreDataStackCreatedForUbiquitos:(BOOL)ubiquitos {
    if ([self.delegate respondsToSelector:@selector(CDBCoreDataStore:didCreateCoreDataStackThatUbiquitous:)]) {
        [self.delegate CDBCoreDataStore:self didCreateCoreDataStackThatUbiquitous:ubiquitos];
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
        CDBCoreDataStoreState state = self.state;
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
    
    CDBCoreDataStoreState state = self.state;
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
    
    CDBCoreDataStoreState state = self.state;
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

@end
