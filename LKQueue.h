//
//  FBQueue.h
//  FBQueue
//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

//
// state diagram
//
//                                                finish
//           +-----------+ process +------------+  /fail +-----------+ clear
// [start]-->|   wating  |-------->| processing |------->| finished  |------>[x]
//           |           |<--------|            |   +--->|           |
//           +-----------+ wait    +------------+   |    +-----------+
//              |                         |         |
//              |                         |interrupt|
//              | wait +------------+     |         |
//              +<-----|interrupting|<----+         |
//                     |            |---------------+
//                     +------------+     finish/fail
//
//

#import <Foundation/Foundation.h>
#import "FBQueueEntry.h"

@class FBQueueEntry;
@interface FBQueue : NSObject {
 
    NSString* queueId_;
    NSString* name_;
    NSMutableArray* list_;      // <FBQueueEntryOperator>
    
    NSString* path_;
}
@property (nonatomic, retain, readonly) NSString* queueId;
@property (nonatomic, copy  , readonly) NSString* name;
@property (nonatomic, retain, readonly) NSString* path;

// API
+ (FBQueue*)queueWithName:(NSString*)name;
+ (void)releaseQueueWithName:(NSString*)name;

- (FBQueueEntry*)addEntryWithInfo:(NSDictionary*)info resources:(NSArray*)resources;
- (FBQueueEntry*)getEntryForProcessing;

- (BOOL)finishEntry:(FBQueueEntry*)entry;
- (BOOL)failEntry:(FBQueueEntry*)entry;
- (BOOL)waitEntry:(FBQueueEntry*)entry;
- (BOOL)interruptEntry:(FBQueueEntry*)entry;

- (void)clearFinishedEntry; 
- (void)removeAllEntries;

- (NSUInteger)count;
- (NSUInteger)countOfWating;
- (NSArray*)queueList;

+ (NSString*)pathForQueueId:(NSString*)queueId;

@end
