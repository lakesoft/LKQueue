//
//  FBQueueTests.m
//  FBQueueTests
//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import <CommonCrypto/CommonDigest.h>

#import "FBQueueTests.h"
#import "FBQueue.h"
#import "FBQueueEntry.h"

#define QUEUE_NAME      @"Test Queue"
#define QUEUE_NAME2     @"Test Queue#2"

@implementation FBQueueTests

@synthesize queue;

- (void)setUp
{
    [super setUp];

    self.queue = [LKQueue queueWithName:QUEUE_NAME];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.

    [self.queue removeAllEntries];

    self.queue = nil;

    [super tearDown];
}

//------------
// utilities
//------------
#define TEST_ENTRY_MAX  10
- (void)_setupTestEntries
{
    for (int i=0; i < TEST_ENTRY_MAX; i++) {
        NSDictionary* info =
        [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"TEST-%d", i]
                                    forKey:[NSString stringWithFormat:@"TITLE-%d", i]];
        NSArray* res = [NSArray arrayWithObject:
                        [NSString stringWithFormat:@"VALUE-%d", i]];
        LKQueueEntry* entry =
        [self.queue addEntryWithInfo:info resources:res];
        
        STAssertNotNil(entry, nil);
    }

}

// *NOTE* must call this method after _setupTestEntries
// 0: processing
// 1: interrupted
// 2: finished(successful)
// 3: finished(failed)
// 4: finished(interrupted)
// 5-9: waiting 
- (void)_setupMultiState
{
    LKQueueEntry* entry;

    // 0: processing
    entry = [self.queue getEntryForProcessing];

    // 1: interrupted
    entry = [self.queue getEntryForProcessing];
    [self.queue interruptEntry:entry];

    // 2: finished(successful)
    entry = [self.queue getEntryForProcessing];
    [self.queue finishEntry:entry];    

    // 3: finished(failed)
    entry = [self.queue getEntryForProcessing];
    [self.queue failEntry:entry];
    
    // 4: finished(interrupted)
    entry = [self.queue getEntryForProcessing];
    [self.queue interruptEntry:entry];
    [self.queue finishEntry:entry];
}

//------------
// basic test
//------------

- (void)testInitialization
{
    STAssertEqualObjects(self.queue.name, QUEUE_NAME, nil);
    STAssertNotNil(self.queue.queueList, nil);
    STAssertEquals([self.queue.queueList count], (NSUInteger)0, nil);
}

- (void)testAddEntryWithData
{
    [self _setupTestEntries];
    STAssertEquals([self.queue count], (NSUInteger)TEST_ENTRY_MAX, nil);

    [self _setupTestEntries];
    STAssertEquals([self.queue count], (NSUInteger)TEST_ENTRY_MAX*2, nil);
}

- (void)testGetEntryForProcessing
{
    LKQueueEntry* entry;    

    entry = [self.queue getEntryForProcessing];
    STAssertNil(entry, nil);

    
    [self _setupTestEntries];
    for (int i=0; i < TEST_ENTRY_MAX; i++) {
        entry = [self.queue getEntryForProcessing];
        STAssertNotNil(entry, nil);
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", i]), nil);
        STAssertEquals(entry.state, FBQueueStateProcessing, nil);
        STAssertEquals([self.queue countOfWating], (NSUInteger)(TEST_ENTRY_MAX-i-1), nil);
    }
    entry = [self.queue getEntryForProcessing];
    STAssertNil(entry, nil);

    
    [self.queue removeAllEntries];
    [self _setupTestEntries];

    [self _setupMultiState];
    
    int i = 0;
    while ((entry = [self.queue getEntryForProcessing])) {
        STAssertEquals(entry.state, FBQueueStateProcessing, nil);
        i++;
    }
    STAssertEquals((int)i, (int)(TEST_ENTRY_MAX-5), nil);

}

- (void)testFinishEntry
{
    [self _setupTestEntries];
    
    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    [self.queue finishEntry:entry];
    
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, FBQueueResultSuccessful, nil);
}

- (void)testFailEntry
{
    [self _setupTestEntries];
    
    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    [self.queue failEntry:entry];
    
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, FBQueueResultFailed, nil);
}

- (void)testWaitEntry
{
    [self _setupTestEntries];
    LKQueueEntry* entry;
    
    entry = [self.queue getEntryForProcessing];
    [self.queue waitEntry:entry];
    STAssertEquals(entry.state, FBQueueStateWating, nil);

    entry = [self.queue getEntryForProcessing];
    [self.queue interruptEntry:entry];
    [self.queue waitEntry:entry];
    STAssertEquals(entry.state, FBQueueStateWating, nil);

}

- (void)testInterruptEntry
{
    [self _setupTestEntries];

    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    [self.queue interruptEntry:entry];
    
    STAssertEquals(entry.state, FBQueueStateInterrupting, nil);
}



- (void)testClearFinishedEntry
{
    [self _setupTestEntries];
    
    [self _setupMultiState];
    
    [self.queue clearFinishedEntry];
    
    STAssertEquals([self.queue count], (NSUInteger)(TEST_ENTRY_MAX-3), nil);
    STAssertEquals([self.queue countOfWating], (NSUInteger)(TEST_ENTRY_MAX-5), nil);
}

- (void)testRemoveAllEntries
{
    [self _setupTestEntries];
    [self.queue removeAllEntries];
    STAssertEquals(self.queue.count, (NSUInteger)0, nil);
    
}

- (void)testCount
{
    STAssertEquals([self.queue count], (NSUInteger)0, nil);
    [self _setupTestEntries];
    STAssertEquals([self.queue count], (NSUInteger)TEST_ENTRY_MAX, nil);

}

- (void)testQueueList
{
    STAssertNotNil([self.queue queueList], nil);
}

- (void)testPathForQueueId
{
    unsigned char result[16];
    const char* cString = [self.queue.name UTF8String];
    
    CC_MD5(cString, strlen(cString), result ); // This is the md5 call
    NSString* queueId = [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3], 
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ]; 
    STAssertEqualObjects(queueId, self.queue.queueId, nil);
}


//-------------------
// persistent test
//-------------------
- (void)testPersistent
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [self _setupTestEntries];

    [self _setupMultiState];
    
    // discard current queue
    LKQueue* previous = self.queue;
    self.queue = nil;
    [LKQueue releaseQueueWithName:QUEUE_NAME];
    
    [pool drain];

    // create new queue with same queue name
    self.queue = [LKQueue queueWithName:QUEUE_NAME];
    
    STAssertFalse((previous == self.queue), nil);
    STAssertEquals([self.queue count], (NSUInteger)(TEST_ENTRY_MAX), nil);

    int i=0;
    for (LKQueueEntry* entry in [self.queue queueList]) {
        STAssertNotNil(entry, nil);
        switch (i) {
            case 0:
                // 0: processing -> wating (when resuming)
                STAssertEquals(entry.state, FBQueueStateWating, nil);
                break;
            case 1:
                // 1: interrupted
                STAssertEquals(entry.state, FBQueueStateInterrupting, nil);
                STAssertEquals(entry.result, FBQueueResultUnfinished, nil);
                break;
            case 2:
                // 2: finished(successful)
                STAssertEquals(entry.state, FBQueueStateFinished, nil);
                STAssertEquals(entry.result, FBQueueResultSuccessful, nil);
                break;
            case 3:
                // 3: finished(failed)
                STAssertEquals(entry.state, FBQueueStateFinished, nil);
                STAssertEquals(entry.result, FBQueueResultFailed, nil);
                break;
            case 4:
                // 4: finished(interrupted)
                STAssertEquals(entry.state, FBQueueStateFinished, nil);
                STAssertEquals(entry.result, FBQueueResultInterrpted, nil);
                break;
            default:
                // 5-9: waiting 
                STAssertEquals(entry.state, FBQueueStateWating, nil);
                break;
        }
        
        STAssertEqualObjects(([entry.info objectForKey:
                               [NSString stringWithFormat:@"TITLE-%d", i]]),
                             ([NSString stringWithFormat:@"TEST-%d", i]), nil);
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", i]), nil);
        STAssertNotNil(entry.timestamp, nil);
        i++;
    }
    
}

//-------------------
// multi queues test
//-------------------

- (void)testMultiQueues
{
    LKQueue* queue2;
    [self _setupTestEntries];

    // [1] same name
    queue2 = [LKQueue queueWithName:QUEUE_NAME];
    STAssertEquals(queue2, self.queue, nil);
    
    
    // [2] diferent name    
    queue2 = [LKQueue queueWithName:QUEUE_NAME2];

    for (int i=0; i < TEST_ENTRY_MAX; i++) {
        NSDictionary* info =
        [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"TEST-%d", i]
                                    forKey:[NSString stringWithFormat:@"TITLE-%d", i]];
        NSArray* res =
            [NSArray arrayWithObject:[NSString stringWithFormat:@"VALUE-%d", i]];
        [queue2 addEntryWithInfo:info resources:res];
    }
    
    int i = 0;
    STAssertEquals([self.queue count], (NSUInteger)(TEST_ENTRY_MAX), nil);
    for (LKQueueEntry* entry in [self.queue queueList]) {
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", i]), nil);
        i++;
    }


    int j = 0;
    STAssertEquals([queue2 count], (NSUInteger)(TEST_ENTRY_MAX), nil);
    for (LKQueueEntry* entry in [queue2 queueList]) {
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", j]), nil);
        j++;
    }
    [queue2 removeAllEntries];
    [LKQueue releaseQueueWithName:QUEUE_NAME2];
}

//------------------
// thread safe test
//------------------

#define PRODUCER_MAX    10
#define CONSUMER_MAX    10

#define ENTRY_MAX       30

static int allCount_;
- (void)_addCount:(int)count
{
    @synchronized (self) {
        allCount_ = allCount_ + count;
    }
}

- (void)testMultiThread
{
    allCount_ = 0;

    dispatch_queue_t producer_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t producer_group = dispatch_group_create();

    for (int i=0; i < PRODUCER_MAX; i++) {

        dispatch_group_async(producer_group, producer_queue, ^{
            for (int j=0; j < ENTRY_MAX; j++) {
                NSDictionary* info =
                    [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"TEST-%d-%02d", i, j]
                                            forKey:[NSString stringWithFormat:@"TITLE-%d-%02d", i, j]];

                NSArray* res = [NSArray arrayWithObject:
                                [NSString stringWithFormat:@"VALUE-%d-%02d", i, j]];

                [self.queue addEntryWithInfo:info resources:res];
            }
        });
    }
    [NSThread sleepForTimeInterval:1.0];

    dispatch_queue_t consumer_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t consumer_group = dispatch_group_create();
    
    for (int i=0; i < CONSUMER_MAX; i++) {
        dispatch_group_async(consumer_group, consumer_queue, ^{
            int count = 0;
            while (1) {
                LKQueueEntry* entry = [self.queue getEntryForProcessing];
                if (entry) {
                    [self.queue finishEntry:entry];
                    count++;
                } else {
                    break;
                }
                [NSThread sleepForTimeInterval:0.1];
            }
            [self _addCount:count];
        });
    }

    while (1) {
        if (dispatch_group_wait(consumer_group, DISPATCH_TIME_NOW)) {
            NSLog(@"countOfWating: %d", [self.queue countOfWating]);
            [NSThread sleepForTimeInterval:1.0];
        } else {
            break;
        }
    }

    dispatch_release(producer_group);
    dispatch_release(consumer_group);
    
    STAssertEquals(allCount_, (int)(PRODUCER_MAX*ENTRY_MAX), nil);
}

@end
