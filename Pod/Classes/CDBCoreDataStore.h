

#if __has_feature(objc_modules)
    @import Foundation;
    @import UIKit;
    @import CoreData;
#else
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
    #import <CoreData/CoreData.h>
#endif


#import "CDBiCloudReadyDocumentsContainer.h"


extern NSString * _Nonnull CDBCoreDataStoreWillChangeNotification;
extern NSString * _Nonnull CDBCoreDataStoreDidChangeNotification;


@protocol CDBCoreDataStoreDelegate;


BOOL CDBCheckStoreState(CDBCoreDataStoreState state, NSUInteger option);


@interface CDBCoreDataStore : NSObject

@property (assign, nonatomic, readonly) BOOL ubiquitous;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * currentContext;
@property (weak, nonatomic, nullable) id<CDBCoreDataStoreDelegate> delegate;

/**
 * @brief
 * if selected but not active then cloud initial sync didn't finish yet and we use local store
 * when (set local storage: 0) appears we switch to ubiquitos store and set
 CDBCoreDataStoreUbiquitosActive to 1
 CDBCoreDataStoreUbiquitosInitiated to 1
 
 * if user removes cloud content we switch to local store, post notification and set
 CDBCoreDataStoreUbiquitosSelected to 0
 CDBCoreDataStoreUbiquitosInitiated to 0
 CDBCoreDataStoreUbiquitosActive to 0
 
 * if user log out from cloud we switch to local store while waiting for log in and set
 CDBCoreDataStoreUbiquitosActive to 0
 **/

@property (assign, nonatomic, readonly) CDBCoreDataStoreState state;


@property (strong, nonatomic, readonly, nullable) NSURL * storeModelURL;
@property (strong, nonatomic, readonly, nullable) NSString * storeName;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectModel * storeModel;

@property (assign, nonatomic, readonly) BOOL localStoreDisabled;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * localContext;
@property (strong, nonatomic, readonly, nullable) NSPersistentStore * localStore;
@property (strong, nonatomic, nullable) NSDictionary * localStoreOptions;
@property (strong, nonatomic, readonly, nullable) NSURL * localStoreURL;
@property (strong, nonatomic, readonly, nullable) NSPersistentStoreCoordinator * localStoreCoordinator;

@property (assign, nonatomic, readonly) BOOL ubiquitosStoreDisabled;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * ubiquitosContext;
@property (strong, nonatomic, readonly, nullable) NSPersistentStore * ubiqutosStore;
@property (strong, nonatomic, nullable) NSDictionary * ubiquitosStoreOptions;
@property (strong, nonatomic, readonly, nullable) NSURL * ubiquitosStoreURL;
@property (strong, nonatomic, readonly, nullable) NSPersistentStoreCoordinator * ubiquitosStoreCoordinator;


+ (instancetype _Nullable)sharedInstance;

- (void)initiateWithStoreName:(NSString * _Nonnull)storeName
                storeModelURL:(NSURL * _Nonnull)modelURL;

- (void)selectUbiquitos:(BOOL)ubiquitos;

- (void)dismissAndDisableLocalCoreDataStack;
- (void)enableLocalCoreDataStack;

- (void)dismissAndDisableUbiquitosCoreDataStack;
- (void)enableUbiquitosCoreDataStack;

- (void)mergeUbiquitousContentChanges:(NSNotification * _Nullable)changeNotification
                         usingContext:(NSManagedObjectContext * _Nonnull)context;

/**
 * @brief
 * remove local store and migrate ubiquitos to it's place
 * this method dissmiss local store during execution
 * if removing fails it try to populate local store with ubiquitos content
 **/

- (void)replaceLocalStoreUsingUbiquitosOneWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove ubiquitos store and recreate it using cloud ubiquitos content
 * this method restart ubiquitos store using rebuild option
 * so be aware of stright coping this store option - use ubiquitosStoreOptions instead
 **/

- (void)rebuildUbiquitosStoreFromUbiquitousContenWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove all ubiquitos content from this device only
 * note that it returns last happend error only
 * this method dissmiss ubiquitos store during execution
 **/

- (void)removeLocalUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove all ubiquitos content from the cloud and all devices
 * this method dissmiss ubiquitos store during execution
 **/

- (void)removeAllUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove store at URL and it's cach files too
 * store should be closed (it should have no connected store coordinators)
 **/

- (void)removeCoreDataStoreAtURL:(NSURL * _Nonnull)URL
                      completion:(CDBErrorCompletion _Nullable)completion;

- (NSPersistentStoreCoordinator * _Nullable)defaultStoreCoordinator;

#pragma mark deduplication helpers

+ (void)performRemovingDublicatesForEntity:(NSEntityDescription * _Nonnull)entity
                         uniquePropertyKey:(NSString * _Nonnull)uniquePropertyKey
                              timestampKey:(NSString * _Nonnull)timestampKey
                              usingContext:(NSManagedObjectContext * _Nonnull)context
                                     error:(NSError * _Nullable * _Nullable)error;

+ (void)performBatchPopulationForEntity:(NSEntityDescription * _Nonnull)entity
                usingPropertiesToUpdate:(NSDictionary * _Nonnull)propertiesToUpdate
                              predicate:(NSPredicate * _Nonnull)predicate
                              inContext:(NSManagedObjectContext * _Nonnull)context;

+ (void)performBatchUIDsPopulationForEntity:(NSEntityDescription * _Nonnull)entity
                     usingUniquePropertyKey:(NSString * _Nonnull)uniquePropertyKey
                                  batchSize:(NSUInteger)batchSize
                                  inContext:(NSManagedObjectContext * _Nonnull)context;

+ (NSDate * _Nonnull)generateTimestamp;
+ (NSString * _Nonnull)generateEntityUID;

@end


@protocol CDBCoreDataStoreDelegate <NSObject>

@optional

/**
 * @brief
 * called when store switching current context
 * called before store changes it's state
 * you could migrate you data from store to store there
 * please don't change store state inside this methods
 **/

- (void)CDBCoreDataStore:(CDBCoreDataStore * _Nullable)store
   switchingToUbiquitous:(BOOL)ubiquitous;

/**
 * @brief
 * called when store imported cloud changes
 * you could provide your custom logic there
 * after merging changes using [ mergeUbiquitousContentChanges: usingContext:] method
 *
 * if this method not implemented in delegate store use
 * using [ mergeUbiquitousContentChangesUsing:] method automatically
 **/

- (void)CDBCoreDataStore:(CDBCoreDataStore * _Nullable)store
    didImportUbiquitousContentChanges:(NSNotification * _Nullable)changeNotification;

/**
 * @brief
 * called when store created core data stack (storeCoordinator, store)
 * called before store changes it's state
 * usually it happends when app request context or on selecting different store
 *
 * you could perform some core data tasks with store here before it data comes to UI
 **/

- (void)CDBCoreDataStore:(CDBCoreDataStore * _Nullable)store
didCreateCoreDataStackThatUbiquitous:(BOOL)ubiquitos;


- (void)CDBCoreDataDidChangeStateOfStore:(CDBCoreDataStore * _Nullable)store;

/**
 * @brief
 * called when user remove (clear) all cloud data 
 * store changes to local automatically after delegate call
 * called before store changes it's state
 * you probably should migrate you cloud data to local on this call or lose it forever
 **/

- (void)CDBCoreDataDetectThatUserWillRemoveContentOfStore:(CDBCoreDataStore * _Nullable)store;

@end
