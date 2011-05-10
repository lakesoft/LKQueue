//
//  FBQueueEntry.h
//  FBQueue
//
//  Created by Hiroshi Hashiguchi on 11/04/21.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

//
// NOTE: Thread *not* safe
//

#import <Foundation/Foundation.h>
#import "FBQueueEntry.h"

@interface FBQueueEntryOperator : FBQueueEntry <NSCoding> {

    NSString* queueId_;
    NSString* entryId_;

}
@property (nonatomic, retain, readonly) NSString* queueId;
@property (nonatomic, retain, readonly) NSString* entryId;


// API
+ (FBQueueEntryOperator*)queueEntryWithQueueId:(NSString*)queueId info:(NSDictionary*)info resources:(NSArray*)resources;

- (BOOL)finish;
- (BOOL)fail;
- (BOOL)wait;
- (BOOL)process;
- (BOOL)interrupt;

- (BOOL)clean;  // remove persistant files


@end
