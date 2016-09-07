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

    [[LKQueueManager defaultManager] removeAllQueues];
    self.queue1 = nil;
    self.queue2 = nil;
    self.queue3 = nil;
}

- (void)_createQueues
{
    LKQueueManager* queueManager = [LKQueueManager defaultManager];
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
    
    XCTAssertNotNil(self.queue1);
    BOOL isDirectory = NO;
    BOOL result1 = [fileManager fileExistsAtPath:self.queue1.path isDirectory:&isDirectory];
    XCTAssertTrue(result1);
    XCTAssertTrue(isDirectory);

    XCTAssertNotNil(self.queue2);
    BOOL result2 = [fileManager fileExistsAtPath:self.queue2.path isDirectory:&isDirectory];
    XCTAssertTrue(result2);
    XCTAssertTrue(isDirectory);
    
    XCTAssertNotNil(self.queue3);
    BOOL result3 = [fileManager fileExistsAtPath:self.queue3.path isDirectory:&isDirectory];
    XCTAssertTrue(result3);    
    XCTAssertTrue(isDirectory);

}

- (void)testQueues
{
    LKQueueManager* queueManager = [LKQueueManager defaultManager];
    NSDictionary* queues = [queueManager queues];
    XCTAssertEqual([queues count], (NSUInteger)0);

    // add queues
    [self _createQueues];
    
    queues = [queueManager queues];
    XCTAssertEqual([queues count], (NSUInteger)3);
    
    NSString* name = [queues objectForKey:self.queue1.queueId];
    XCTAssertEqualObjects(name, QUEUE_NAME1);

    NSString* name2 = [queues objectForKey:self.queue2.queueId];
    XCTAssertEqualObjects(name2, QUEUE_NAME2);

    NSString* name3 = [queues objectForKey:self.queue3.queueId];
    XCTAssertEqualObjects(name3, QUEUE_NAME3);


    // remove queue2
    [queueManager removeQueue:self.queue2];
    queues = [queueManager queues];
    XCTAssertEqual([queues count], (NSUInteger)2);

    LKQueue* queue21 = [queueManager queueWithName:QUEUE_NAME1];
    XCTAssertEqual(queue21, queue1);
    NSString* name21 = [queues objectForKey:self.queue1.queueId];
    XCTAssertEqualObjects(name21, QUEUE_NAME1);
    
    LKQueue* queue23 = [queueManager queueWithName:QUEUE_NAME3];
    XCTAssertEqual(queue23, queue3);
    NSString* name23 = [queues objectForKey:self.queue3.queueId];
    XCTAssertEqualObjects(name23, QUEUE_NAME3);

}

- (void)testRemoveQueue
{
    [self _createQueues];

    LKQueueManager* queueManager = [LKQueueManager defaultManager];
    [queueManager removeQueue:self.queue2];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
   
    BOOL isDirectory = NO;
    BOOL result1 = [fileManager fileExistsAtPath:self.queue1.path isDirectory:&isDirectory];
    XCTAssertTrue(result1);
    XCTAssertTrue(isDirectory);

    BOOL result2 = [fileManager fileExistsAtPath:self.queue2.path isDirectory:&isDirectory];
    XCTAssertFalse(result2);
    XCTAssertTrue(isDirectory);
    
    BOOL result3 = [fileManager fileExistsAtPath:self.queue3.path isDirectory:&isDirectory];
    XCTAssertTrue(result3);    
    XCTAssertTrue(isDirectory);
}

- (void)testRemoveAll
{
    [self _createQueues];

    LKQueueManager* queueManager = [LKQueueManager defaultManager];
    BOOL result = [queueManager removeAllQueues];
    XCTAssertTrue(result);
    NSDictionary* queues = [queueManager queues];
    XCTAssertEqual([queues count], (NSUInteger)0);

    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = nil;
    NSArray* files = [fileManager contentsOfDirectoryAtPath:[queueManager path]
                                                      error:&error];
    XCTAssertEqual([files count], (NSUInteger)1);  // only *.plist
}

- (void)testReleaseCache
{
    [self _createQueues];
    
    SEL sel = @selector(queueCache);

    LKQueueManager* queueManager = [LKQueueManager defaultManager];
    NSDictionary* caches1 = [queueManager performSelector:sel];
    XCTAssertEqual([caches1 count], (NSUInteger)3);

    [queueManager releaseCacheWithQueue:self.queue2];
    NSDictionary* caches2 = [queueManager performSelector:sel];
    XCTAssertEqual([caches2 count], (NSUInteger)2);
    
    [queueManager removeAllQueues];
    NSDictionary* caches3 = [queueManager performSelector:sel];
    XCTAssertEqual([caches3 count], (NSUInteger)0);
}

- (void)testPersistent
{
    // TODO:try to confirm queueList persistent
}

- (void)testDefaultPath
{
    LKQueueManager* queueManager = [LKQueueManager defaultManager];
    NSString* queuePath = [LKQueueManager defaultPath];
    XCTAssertEqualObjects(queueManager.path, queuePath);
}

- (void)testCustomPath
{
    [self _createQueues];
    
    NSString* queuePath =  [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                 NSUserDomainMask, YES) lastObject]
                            stringByAppendingPathComponent:@"CustomPath"];
    LKQueueManager* queueManager = [[LKQueueManager alloc] initWithPath:queuePath];
    XCTAssertEqualObjects(queueManager.path, queuePath);

    LKQueueManager* defaultQueueManager = [LKQueueManager defaultManager];
    XCTAssertTrue((queueManager!=defaultQueueManager));
    
    LKQueue* queue21 = [queueManager queueWithName:QUEUE_NAME1];
    LKQueue* queue22 = [queueManager queueWithName:QUEUE_NAME2];
    LKQueue* queue23 = [queueManager queueWithName:QUEUE_NAME3];    
    
    XCTAssertTrue((queue21.queueId!=self.queue1.queueId));
    XCTAssertTrue((queue22.queueId!=self.queue2.queueId));
    XCTAssertTrue((queue23.queueId!=self.queue3.queueId));
    
    
    [queueManager removeAllQueues];
}

@end
