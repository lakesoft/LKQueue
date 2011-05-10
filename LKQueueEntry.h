//
//  FBQueueEntry.h
//  FBQueue
//
//  Created by Hiroshi Hashiguchi on 11/04/23.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

// ** Do not change order **
typedef enum {
    FBQueueStateWating = 0,
    FBQueueStateProcessing,
    FBQueueStateInterrupting,
    FBQueueStateFinished,
} FBQueueState;

// ** Do not change order **
typedef enum {
    FBQueueResultUnfinished = 0,
    FBQueueResultSuccessful,
    FBQueueResultFailed,
    FBQueueResultInterrpted
} FBQueueResult;

@interface FBQueueEntry : NSObject {
    
    NSDictionary* info_;
    NSArray* resources_;

    FBQueueState state_;
    FBQueueResult result_;

    NSDate* timestamp_;

    id context_;
}

// persistent properties
@property (nonatomic, retain, readonly) NSDictionary* info;
@property (nonatomic, retain, readonly) NSArray* resources;
@property (nonatomic, assign, readonly) FBQueueState state;
@property (nonatomic, assign, readonly) FBQueueResult result;
@property (nonatomic, retain, readonly) NSDate* timestamp;

// volatile properties
@property (retain) id context;

@end
