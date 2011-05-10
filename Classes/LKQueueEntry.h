//
//  LKQueueEntry.h
//  LKQueue
//
//  Created by Hiroshi Hashiguchi on 11/04/23.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

// ** Do not change order **
typedef enum {
    LKQueueStateWating = 0,
    LKQueueStateProcessing,
    LKQueueStateInterrupting,
    LKQueueStateFinished,
} LKQueueState;

// ** Do not change order **
typedef enum {
    LKQueueResultUnfinished = 0,
    LKQueueResultSuccessful,
    LKQueueResultFailed,
    LKQueueResultInterrpted
} LKQueueResult;

@interface LKQueueEntry : NSObject {
    
    NSDictionary* info_;
    NSArray* resources_;

    LKQueueState state_;
    LKQueueResult result_;

    NSDate* timestamp_;

    id context_;
}

// persistent properties
@property (nonatomic, retain, readonly) NSDictionary* info;
@property (nonatomic, retain, readonly) NSArray* resources;
@property (nonatomic, assign, readonly) LKQueueState state;
@property (nonatomic, assign, readonly) LKQueueResult result;
@property (nonatomic, retain, readonly) NSDate* timestamp;

// volatile properties
@property (retain) id context;

@end
