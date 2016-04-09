//
//  Identify.h
//  Identify
//

#import <Foundation/Foundation.h>

/**
 * The `Identify` class provides methods for generating compact, unique ids.
 *
 * Ids are encoded as urlsafe base64 (letters, numbers, underscores, dashes),
 * any `=` padding is stripped off, and they are given a single character 
 * prefix.
 */
@interface Identify : NSObject

/**--------------------------------------------------------------------
 * @name Class Methods
 * ---------------------------------------------------------------------
 */

/** 
 * Generate a new, unique, id. 
 *
 * This method uses `CFUUID` to create new ids. The encoded result is 23 
 * characters long.
 *
 * @return a unique id
 */
+ (NSString *)makeId;

/**
 * Generate a compact id for this device.
 *
 * This method uses the `advertisingIdentifier` from `ASIdentifierManager`. The
 * encoded result is 23 characters long. It is usually consistend unless the 
 * device is reset.
 *
 * @return a unique id for this device
 */
+ (NSString *)deviceId;

/**
 * Hash together several ids to synthesize a new id.
 *
 * This method concatenates the ids together into a sha1 hash. The encoded
 * result is 28 characters long.
 *
 * @param ident any number of string ids
 * @param ... terminate `ident` sequence with `nil`
 *
 * @return a synthetic id
 */
+ (NSString *)synthesizeId:(NSString *)ident, ...NS_REQUIRES_NIL_TERMINATION;

@end