//
//  LKQueueTests.m
//  LKQueueTests
//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import <CommonCrypto/CommonDigest.h>

#import "LKQueueTests.h"
#import "LKQueue.h"
#import "LKQueueEntry.h"

#define QUEUE_NAME      @"Test Queue"
#define QUEUE_NAME2     @"Test Queue#2"

@implementation LKQueueTests

@synthesize queue;
@synthesize queue2;

- (void)setUp
{
    [super setUp];

    self.queue = [LKQueue queueWithName:QUEUE_NAME];
    self.queue2 = [LKQueue queueWithName:QUEUE_NAME2];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.

    [self.queue removeAllEntries];
    [self.queue2 removeAllEntries];

    self.queue = nil;
    self.queue2 = nil;

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
        STAssertEquals(entry.state, LKQueueStateProcessing, nil);
        STAssertEquals([self.queue countOfWating], (NSUInteger)(TEST_ENTRY_MAX-i-1), nil);
    }
    entry = [self.queue getEntryForProcessing];
    STAssertNil(entry, nil);

    
    [self.queue removeAllEntries];
    [self _setupTestEntries];

    [self _setupMultiState];
    
    int i = 0;
    while ((entry = [self.queue getEntryForProcessing])) {
        STAssertEquals(entry.state, LKQueueStateProcessing, nil);
        i++;
    }
    STAssertEquals((int)i, (int)(TEST_ENTRY_MAX-5), nil);

}

- (void)testFinishEntry
{
    [self _setupTestEntries];
    
    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue finishEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultSuccessful, nil);

    STAssertFalse([self.queue finishEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultSuccessful, nil);

    STAssertFalse([self.queue failEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultSuccessful, nil);

    STAssertFalse([self.queue interruptEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultSuccessful, nil);

    entry = [self.queue getEntryForProcessing];
    [self.queue interruptEntry:entry];
    STAssertTrue([self.queue finishEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultInterrpted, nil);
    
    entry = [self.queue getEntryForProcessing];
    [self.queue interruptEntry:entry];
    STAssertTrue([self.queue failEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultFailed, nil);
    
    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 finishEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
}

- (void)testFailEntry
{
    [self _setupTestEntries];
    
    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue failEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultFailed, nil);

    STAssertFalse([self.queue failEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultFailed, nil);

    STAssertFalse([self.queue finishEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultFailed, nil);

    STAssertFalse([self.queue interruptEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultFailed, nil);

    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 failEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
}

- (void)testWaitEntry
{
    [self _setupTestEntries];
    LKQueueEntry* entry;
    
    entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue waitEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateWating, nil);

    entry = [self.queue getEntryForProcessing];
    [self.queue interruptEntry:entry];
    STAssertTrue([self.queue waitEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateWating, nil);

    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 waitEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
}

- (void)testInterruptEntry
{
    [self _setupTestEntries];

    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue interruptEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueStateInterrupting, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);

    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 interruptEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);

}

- (void)testRemoveEntry
{
    [self _setupTestEntries];    
    [self _setupMultiState];

    LKQueueEntry* entry;
    NSUInteger count = TEST_ENTRY_MAX;

    entry = [self.queue entryAtIndex:0];
    STAssertFalse([self.queue removeEntry:entry], nil);
    STAssertEquals([self.queue count], count, nil);

    count--;
    entry = [self.queue entryAtIndex:1];
    STAssertTrue([self.queue removeEntry:entry], nil);
    STAssertEquals([self.queue count], count, nil);

    count--;
    entry = [self.queue entryAtIndex:1];
    STAssertTrue([self.queue removeEntry:entry], nil);
    STAssertEquals([self.queue count], count, nil);

    count--;
    entry = [self.queue entryAtIndex:1];
    STAssertTrue([self.queue removeEntry:entry], nil);
    STAssertEquals([self.queue count], count, nil);

    count--;
    entry = [self.queue entryAtIndex:1];
    STAssertTrue([self.queue removeEntry:entry], nil);
    STAssertEquals([self.queue count], count, nil);

    
    STAssertFalse([self.queue removeEntry:nil], nil);
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

- (void)testQueueAtIndex
{
    [self _setupTestEntries];
    
    for (int index=0; index < TEST_ENTRY_MAX; index++) {
        NSString* key = [NSString stringWithFormat:@"TITLE-%d", index];
        NSString* value = [NSString stringWithFormat:@"TEST-%d", index];
        LKQueueEntry* entry = [self.queue entryAtIndex:index];
        STAssertEqualObjects(([entry.info objectForKey:key]), value, nil);
    }
    LKQueueEntry* entry;
    entry = [self.queue entryAtIndex:-1];
    STAssertNil(entry, nil);
    entry = [self.queue entryAtIndex:TEST_ENTRY_MAX];
    STAssertNil(entry, nil);
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
                STAssertEquals(entry.state, LKQueueStateWating, nil);
                break;
            case 1:
                // 1: interrupted
                STAssertEquals(entry.state, LKQueueStateInterrupting, nil);
                STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
                break;
            case 2:
                // 2: finished(successful)
                STAssertEquals(entry.state, LKQueueStateFinished, nil);
                STAssertEquals(entry.result, LKQueueResultSuccessful, nil);
                break;
            case 3:
                // 3: finished(failed)
                STAssertEquals(entry.state, LKQueueStateFinished, nil);
                STAssertEquals(entry.result, LKQueueResultFailed, nil);
                break;
            case 4:
                // 4: finished(interrupted)
                STAssertEquals(entry.state, LKQueueStateFinished, nil);
                STAssertEquals(entry.result, LKQueueResultInterrpted, nil);
                break;
            default:
                // 5-9: waiting 
                STAssertEquals(entry.state, LKQueueStateWating, nil);
                break;
        }
        
        STAssertEqualObjects(([entry.info objectForKey:
                               [NSString stringWithFormat:@"TITLE-%d", i]]),
                             ([NSString stringWithFormat:@"TEST-%d", i]), nil);
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", i]), nil);
        STAssertNotNil(entry.created, nil);
        STAssertNotNil(entry.modified, nil);
        i++;
    }
    
}

//-------------------
// multi queues test
//-------------------

- (void)testMultiQueues
{
    [self _setupTestEntries];

    // [1] same name
    LKQueue* queue1b = [LKQueue queueWithName:QUEUE_NAME];
    STAssertEquals(queue1b, self.queue, nil);
    
    
    // [2] diferent name    
    for (int i=0; i < TEST_ENTRY_MAX; i++) {
        NSDictionary* info =
        [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"TEST2-%d", i]
                                    forKey:[NSString stringWithFormat:@"TITLE2-%d", i]];
        NSArray* res =
            [NSArray arrayWithObject:[NSString stringWithFormat:@"VALUE2-%d", i]];
        [self.queue2 addEntryWithInfo:info resources:res];
    }
    
    int i = 0;
    STAssertEquals([self.queue count], (NSUInteger)(TEST_ENTRY_MAX), nil);
    for (LKQueueEntry* entry in [self.queue queueList]) {
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", i]), nil);
        i++;
    }


    int j = 0;
    STAssertEquals([self.queue2 count], (NSUInteger)(TEST_ENTRY_MAX), nil);
    for (LKQueueEntry* entry in [self.queue2 queueList]) {
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE2-%d", j]), nil);
        j++;
    }
    [self.queue2 removeAllEntries];
    [LKQueue releaseQueueWithName:QUEUE_NAME2];
}

// move queue entries
- (void)testMultiQueues2
{
    [self _setupTestEntries];

    LKQueueEntry* entry = [self.queue getEntryForProcessing];   // [0]
    [self.queue finishEntry:entry];
    STAssertFalse([self.queue addEntry:entry], nil);

    STAssertTrue([self.queue2 addEntry:entry], nil);
    LKQueueEntry* entry2 = [self.queue2 getEntryForProcessing];      // [1]
    STAssertEquals(entry2.state, LKQueueStateProcessing, nil);
    STAssertEquals(entry2.result, LKQueueResultUnfinished, nil);
    STAssertFalse(entry == entry2, nil);
    STAssertEqualObjects(([entry.resources lastObject]),
                         ([entry2.resources lastObject]), nil);
    STAssertTrue(([entry.resources lastObject] != [entry2.resources lastObject]), nil);
    STAssertTrue(([entry2.created compare:entry.created] == NSOrderedDescending), nil);
    STAssertTrue(([entry2.modified compare:entry.modified] == NSOrderedDescending), nil);
    STAssertEqualObjects(([entry2.info objectForKey:@"TITLE-0"]),
                         @"TEST-0", nil);
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
