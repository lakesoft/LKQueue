//
//  LKQueue.h
//  LKQueue
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
#import "LKQueueEntry.h"

@class LKQueueEntry;
@interface LKQueue : NSObject {
 
    NSString* queueId_;
    NSString* name_;
    NSMutableArray* list_;      // <LKQueueEntryOperator>
    
    NSString* path_;
}
@property (nonatomic, retain, readonly) NSString* queueId;
@property (nonatomic, copy  , readonly) NSString* name;
@property (nonatomic, retain, readonly) NSString* path;

// API
+ (LKQueue*)queueWithName:(NSString*)name;
+ (void)releaseQueueWithName:(NSString*)name;

- (LKQueueEntry*)addEntryWithInfo:(NSDictionary*)info resources:(NSArray*)resources;
- (LKQueueEntry*)getEntryForProcessing;

- (BOOL)finishEntry:(LKQueueEntry*)entry;
- (BOOL)failEntry:(LKQueueEntry*)entry;
- (BOOL)waitEntry:(LKQueueEntry*)entry;
- (BOOL)interruptEntry:(LKQueueEntry*)entry;

- (void)clearFinishedEntry; 
- (void)removeAllEntries;

- (NSUInteger)count;
- (NSUInteger)countOfWating;
- (NSArray*)queueList;

+ (NSString*)pathForQueueId:(NSString*)queueId;

@end
