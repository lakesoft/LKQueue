//
//  LKQueueTests.h
//  LKQueueTests
//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <XCTest/XCTest.h>

@class LKQueue;
@interface LKQueueTests : XCTestCase {
@private
}

@property (nonatomic, strong) LKQueue* queue;
@property (nonatomic, strong) LKQueue* queue2;
@property (nonatomic, strong) NSString* calledNotificationName;

@end
