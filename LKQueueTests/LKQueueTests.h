//
//  LKQueueTests.h
//  LKQueueTests
//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@class LKQueue;
@interface LKQueueTests : SenTestCase {
@private
}

@property (nonatomic, retain) LKQueue* queue;
@property (nonatomic, retain) LKQueue* queue2;
@property (nonatomic, retain) NSString* calledNotificationName;

@end
