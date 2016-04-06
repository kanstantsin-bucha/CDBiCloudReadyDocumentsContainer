

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
 * if selected, connected but not active then cloud initial sync didn't finish yet and we use local store
 * when (set local storage: 0) appears we switch to ubiquitos store and set
 CDBCoreDataStoreUbiquitosActive to 1
 CDBCoreDataStoreUbiquitosInitiated to 1
 
 * if user removes cloud content we switch to local store, post notification and set
 CDBCoreDataStoreUbiquitosSelected to 0
 CDBCoreDataStoreUbiquitosInitiated to 0
 CDBCoreDataStoreUbiquitosActive to 0
 
 * if user log out from cloud we switch to local store while waiting for log in and set
 CDBCoreDataStoreUbiquitosConnected to 0
 CDBCoreDataStoreUbiquitosActive to 0
 **/

@property (assign, nonatomic, readonly) CDBCoreDataStoreState state;


@property (strong, nonatomic, readonly, nullable) NSURL * storeModelURL;
@property (strong, nonatomic, readonly, nullable) NSString * storeName;
@property (strong, nonatomic, readonly, nullable) NSManagedObjectModel * storeModel;


@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * localContext;
@property (strong, nonatomic, readonly, nullable) NSPersistentStore * localStore;
@property (strong, nonatomic, nullable) NSDictionary * localStoreOptions;
@property (strong, nonatomic, readonly, nullable) NSURL * localStoreURL;
@property (strong, nonatomic, readonly, nullable) NSPersistentStoreCoordinator * localStoreCoordinator;

@property (strong, nonatomic, readonly, nullable) NSManagedObjectContext * ubiquitosContext;
@property (strong, nonatomic, readonly, nullable) NSPersistentStore * ubiqutosStore;
@property (strong, nonatomic, nullable) NSDictionary * ubiquitosStoreOptions;
@property (strong, nonatomic, readonly, nullable) NSURL * ubiquitosStoreURL;
@property (strong, nonatomic, readonly, nullable) NSPersistentStoreCoordinator * ubiquitosStoreCoordinator;


+ (instancetype _Nullable)sharedInstance;

- (void)initiateWithStoreName:(NSString * _Nonnull)storeName
                storeModelURL:(NSURL * _Nonnull)modelURL;

- (void)selectUbiquitos:(BOOL)ubiquitos;



- (void)dismissLocalCoreDataStack;
- (void)dismissUbiquitosCoreDataStack;

- (void)mergeUbiquitousContentChangesUsing:(NSNotification * _Nullable)changeNotification;
- (void)replaceLocalStoreUsingUbiquitosOne;

/**
 * @brief
 * remove ubiquitos store and recreate it using cloud ubiquitos content
 * this method switch CDBCoreDataStore to local store automatically
 **/

- (void)rebuildUbiquitosStoreFromUbiquitousContenWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove all ubiquitos content from this device only
 * this method switch CDBCoreDataStore to local store automatically
 **/

- (void)removeLocalUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion;

/**
 * @brief
 * remove all ubiquitos content from the cloud and all devices
 * this method switch CDBCoreDataStore to local store automatically
 **/

- (void)removeAllUbiquitousContentWithCompletion:(CDBErrorCompletion _Nullable)completion;

- (NSPersistentStoreCoordinator * _Nullable)defaultStoreCoordinator;

@end


@protocol CDBCoreDataStoreDelegate <NSObject>

@optional

/**
 * @brief
 * called when store switching current context
 * called before store changes it's state
 * you could migrate you data from store to store there
 **/

- (void)CDBCoreDataStore:(CDBCoreDataStore * _Nullable)store
   switchingToUbiquitous:(BOOL)ubiquitous;

/**
 * @brief
 * called when store imported cloud changes
 * you could provide your custom logic there
 * after merging changes using [ mergeUbiquitousContentChangesUsing:] method 
 *
 * if this method not implemented in delegate store use
 * using [ mergeUbiquitousContentChangesUsing:] method automatically
 **/

- (void)CDBCoreDataStore:(CDBCoreDataStore * _Nullable)store
    didImportUbiquitousContentChanges:(NSNotification * _Nullable)changeNotification;


- (void)CDBCoreDataDidChangeStateOfStore:(CDBCoreDataStore * _Nullable)store;

/**
 * @brief
 * called when user remove (clear) all cloud data 
 * called before store changes it's state
 * you probably should migrate you cloud data to local on this call or lose it forever
 **/

- (void)CDBCoreDataDetectThatUserWillRemoveContentOfStore:(CDBCoreDataStore * _Nullable)store;

@end
