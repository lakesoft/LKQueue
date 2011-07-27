//
//  LKQueueManagerTests.m
//  LKQueue
//
//  Created by Hashiguchi Hiroshi on 11/07/27.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "LKQueueManagerTests.h"
#import "LKQueueManager.h"
#import "LKQueue.h"

#define QUEUE_NAME1      @"Manager Test Queue#1"
#define QUEUE_NAME2      @"Manager Test Queue#2"
#define QUEUE_NAME3      @"Manager Test Queue#3"


@implementation LKQueueManagerTests
@synthesize queue1, queue2, queue3;

- (void)setUp
{
    [super setUp];

}

- (void)tearDown
{
    [super tearDown];

    [[LKQueueManager sharedManager] removeAllQueues];
    self.queue1 = nil;
    self.queue2 = nil;
    self.queue3 = nil;
}

- (void)_createQueues
{
    LKQueueManager* queueManager = [LKQueueManager sharedManager];
    self.queue1 = [queueManager queueWithName:QUEUE_NAME1];
    self.queue2 = [queueManager queueWithName:QUEUE_NAME2];
    self.queue3 = [queueManager queueWithName:QUEUE_NAME3];    
}


//------------
// basic test
//------------
- (void)testCreate
{
    NSFileManager* fileManager = [NSFileManager defaultManager];

    [self _createQueues];
    
    STAssertNotNil(self.queue1, nil);
    BOOL isDirectory = NO;
    BOOL result1 = [fileManager fileExistsAtPath:self.queue1.path isDirectory:&isDirectory];
    STAssertTrue(result1, nil);
    STAssertTrue(isDirectory, nil);

    STAssertNotNil(self.queue2, nil);
    BOOL result2 = [fileManager fileExistsAtPath:self.queue2.path isDirectory:&isDirectory];
    STAssertTrue(result2, nil);
    STAssertTrue(isDirectory, nil);
    
    STAssertNotNil(self.queue3, nil);
    BOOL result3 = [fileManager fileExistsAtPath:self.queue3.path isDirectory:&isDirectory];
    STAssertTrue(result3, nil);    
    STAssertTrue(isDirectory, nil);

}

- (void)testQueues
{
    LKQueueManager* queueManager = [LKQueueManager sharedManager];
    NSDictionary* queues = [queueManager queues];
    STAssertEquals([queues count], (NSUInteger)0, nil);

    // add queues
    [self _createQueues];
    
    queues = [queueManager queues];
    STAssertEquals([queues count], (NSUInteger)3, nil);
    
    NSString* name = [queues objectForKey:self.queue1.queueId];
    STAssertEqualObjects(name, QUEUE_NAME1, nil);

    NSString* name2 = [queues objectForKey:self.queue2.queueId];
    STAssertEqualObjects(name2, QUEUE_NAME2, nil);

    NSString* name3 = [queues objectForKey:self.queue3.queueId];
    STAssertEqualObjects(name3, QUEUE_NAME3, nil);


    // remove queue2
    [queueManager removeQueue:self.queue2];
    queues = [queueManager queues];
    STAssertEquals([queues count], (NSUInteger)2, nil);

    LKQueue* queue21 = [queueManager queueWithName:QUEUE_NAME1];
    STAssertEquals(queue21, queue1, nil);
    NSString* name21 = [queues objectForKey:self.queue1.queueId];
    STAssertEqualObjects(name21, QUEUE_NAME1, nil);
    
    LKQueue* queue23 = [queueManager queueWithName:QUEUE_NAME3];
    STAssertEquals(queue23, queue3, nil);
    NSString* name23 = [queues objectForKey:self.queue3.queueId];
    STAssertEqualObjects(name23, QUEUE_NAME3, nil);

}

- (void)testRemoveQueue
{
    [self _createQueues];

    LKQueueManager* queueManager = [LKQueueManager sharedManager];
    [queueManager removeQueue:self.queue2];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
   
    BOOL isDirectory = NO;
    BOOL result1 = [fileManager fileExistsAtPath:self.queue1.path isDirectory:&isDirectory];
    STAssertTrue(result1, nil);
    STAssertTrue(isDirectory, nil);

    BOOL result2 = [fileManager fileExistsAtPath:self.queue2.path isDirectory:&isDirectory];
    STAssertFalse(result2, nil);
    STAssertTrue(isDirectory, nil);
    
    BOOL result3 = [fileManager fileExistsAtPath:self.queue3.path isDirectory:&isDirectory];
    STAssertTrue(result3, nil);    
    STAssertTrue(isDirectory, nil);
}

- (void)testRemoveAll
{
    [self _createQueues];

    LKQueueManager* queueManager = [LKQueueManager sharedManager];
    BOOL result = [queueManager removeAllQueues];
    STAssertTrue(result, nil);
    NSDictionary* queues = [queueManager queues];
    STAssertEquals([queues count], (NSUInteger)0, nil);

    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = nil;
    NSArray* files = [fileManager contentsOfDirectoryAtPath:[queueManager path]
                                                      error:&error];
    NSLog(@"files: %@", files); //TODO
    STAssertEquals([files count], (NSUInteger)1, nil);  // only *.plist
}

- (void)testReleaseCache
{
    [self _createQueues];
    
    SEL sel = @selector(queueCache);

    LKQueueManager* queueManager = [LKQueueManager sharedManager];
    NSDictionary* caches1 = [queueManager performSelector:sel];
    STAssertEquals([caches1 count], (NSUInteger)3, nil);

    [queueManager releaseCacheWithQueue:self.queue2];
    NSDictionary* caches2 = [queueManager performSelector:sel];
    STAssertEquals([caches2 count], (NSUInteger)2, nil);
    
    [queueManager removeAllQueues];
    NSDictionary* caches3 = [queueManager performSelector:sel];
    STAssertEquals([caches3 count], (NSUInteger)0, nil);
}

- (void)testPersistent
{
    // try to confirm queueList persistent
}

@end
