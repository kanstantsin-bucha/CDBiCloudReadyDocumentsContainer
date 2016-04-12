
#if __has_feature(objc_modules)
    @import Foundation;
    @import UIKit;
#else
    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
#endif


#import <CDBKit/CDBKit.h>
#import "CDBiCloudReadyConstants.h"
#import "CDBCloudDocuments.h"
#import "CDBCloudStore.h"


extern NSString * _Nonnull CDBCloudConnectionDidChangeState;


@interface CDBCloudConnection : NSObject

/**
 Contains connection state
 **/

@property (assign, nonatomic, readonly) CDBCloudState state;

@property (strong, nonatomic, readonly, nullable) NSURL * ubiquityContainerURL;
@property (strong, nonatomic, readonly, nullable) id ubiquityIdentityToken;

@property (strong, nonatomic, readonly, nullable) CDBCloudDocuments * documents;
@property (strong, nonatomic, readonly, nullable) CDBCloudStore * store;

+ (instancetype _Nullable)sharedInstance;

- (void)initiateUsingContainerIdentifier:(NSString * _Nullable)ID
                  documentsPathComponent:(NSString * _Nullable)pathComponent
                               storeName:(NSString * _Nullable)storeName
                           storeModelURL:(NSURL * _Nullable)storeModelURL;
             

@end
