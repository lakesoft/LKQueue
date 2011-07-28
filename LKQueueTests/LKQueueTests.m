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
#import "LKQueueEntryLog.h"
#import "LKQueueManager.h"

#define QUEUE_NAME      @"Test Queue"
#define QUEUE_NAME2     @"Test Queue#2"
#define QUEUE_NAME3     @"Test Queue#3 (not existed)"

@implementation LKQueueTests

@synthesize queue;
@synthesize queue2;

- (void)setUp
{
    [super setUp];

    self.queue = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME];
    self.queue2 = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME2];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.

    [[LKQueueManager defaultManager] removeAllQueues];

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
        NSString* tagName = [NSString stringWithFormat:@"TAG-%d", i % 3];   // 0,1,2,0,1,2,0,1,2,0
        LKQueueEntry* entry =
        [self.queue addEntryWithInfo:info resources:res tagName:tagName];
        entry.context = [NSString stringWithFormat:@"CONTEXT-%d", i];
        
        STAssertNotNil(entry, nil);
    }

}

// *NOTE* must call this method after _setupTestEntries
// 0: processing
// 1: suspended
// 2: finished(successful)
// 3: finished(failed)
// 4: finished(suspended)
// 5-9: waiting 
- (void)_setupMultiState
{
    LKQueueEntry* entry;

    // 0: processing
    entry = [self.queue getEntryForProcessing];

    // 1: suspended
    entry = [self.queue getEntryForProcessing];
    [self.queue suspendEntry:entry];

    // 2: finished(successful)
    entry = [self.queue getEntryForProcessing];
    [self.queue finishEntry:entry];    

    // 3: finished(failed)
    entry = [self.queue getEntryForProcessing];
    [self.queue failEntry:entry];
    
    // 4: finished(suspended)
    entry = [self.queue getEntryForProcessing];
    [self.queue suspendEntry:entry];
    [self.queue finishEntry:entry];
}

//------------
// basic test
//------------

- (void)testInitialization
{
    NSString* path = [[LKQueueManager defaultManager] path];
    NSString* queueId = @"QUEUE-ID-0";
    LKQueue* queueCreated = [[LKQueue alloc] initWithId:queueId basePath:path];
    STAssertEqualObjects(queueCreated.queueId, queueId, nil);
    NSString* queuePath = [path stringByAppendingPathComponent:queueId];
    STAssertEqualObjects(queueCreated.path, queuePath, nil);
    [[LKQueueManager defaultManager] removeQueue:queueCreated];
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
        STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
        STAssertEquals([self.queue countOfEntryState:LKQueueEntryStateWating], (NSUInteger)(TEST_ENTRY_MAX-i-1), nil);
    }
    entry = [self.queue getEntryForProcessing];
    STAssertNil(entry, nil);

    
    [self.queue removeAllEntries];
    [self _setupTestEntries];

    [self _setupMultiState];
    
    int i = 0;
    while ((entry = [self.queue getEntryForProcessing])) {
        STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
        i++;
    }
    STAssertEquals((int)i, (int)(TEST_ENTRY_MAX-5), nil);

}

- (void)testFinishEntry
{
    [self _setupTestEntries];
    
    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue finishEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultSuccessful, nil);

    STAssertFalse([self.queue finishEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultSuccessful, nil);

    STAssertFalse([self.queue failEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultSuccessful, nil);

    STAssertFalse([self.queue suspendEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultSuccessful, nil);

    entry = [self.queue getEntryForProcessing];
    [self.queue suspendEntry:entry];
    STAssertTrue([self.queue finishEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultSuspended, nil);
    
    entry = [self.queue getEntryForProcessing];
    [self.queue suspendEntry:entry];
    STAssertTrue([self.queue failEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultFailed, nil);
    
    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 finishEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueEntryResultUnfinished, nil);
}

- (void)testFailEntry
{
    [self _setupTestEntries];
    
    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue failEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultFailed, nil);

    STAssertFalse([self.queue failEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultFailed, nil);

    STAssertFalse([self.queue finishEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultFailed, nil);

    STAssertFalse([self.queue suspendEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals(entry.result, LKQueueEntryResultFailed, nil);

    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 failEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueEntryResultUnfinished, nil);
}

- (void)testWaitEntry
{
    [self _setupTestEntries];
    LKQueueEntry* entry;
    
    entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue waitEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateWating, nil);

    entry = [self.queue getEntryForProcessing];
    [self.queue suspendEntry:entry];
    STAssertTrue([self.queue waitEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateWating, nil);

    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 waitEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueEntryResultUnfinished, nil);
}

- (void)testInterruptEntry
{
    [self _setupTestEntries];

    LKQueueEntry* entry = [self.queue getEntryForProcessing];
    STAssertTrue([self.queue suspendEntry:entry], nil);    
    STAssertEquals(entry.state, LKQueueEntryStateSuspending, nil);
    STAssertEquals(entry.result, LKQueueEntryResultUnfinished, nil);

    // at other queue
    entry = [self.queue getEntryForProcessing];
    STAssertFalse([self.queue2 suspendEntry:entry], nil);
    STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueEntryResultUnfinished, nil);

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
    
    [self.queue removeFinishedEntry];
    
    STAssertEquals([self.queue count], (NSUInteger)(TEST_ENTRY_MAX-3), nil);
    STAssertEquals([self.queue countOfEntryState:LKQueueEntryStateWating], (NSUInteger)(TEST_ENTRY_MAX-5), nil);
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
    [self _setupMultiState];
    STAssertEquals([self.queue count], (NSUInteger)TEST_ENTRY_MAX, nil);
    STAssertEquals([self.queue countOfEntryState:LKQueueEntryStateWating], (NSUInteger)5, nil);
    STAssertEquals([self.queue countOfEntryState:LKQueueEntryStateProcessing], (NSUInteger)1, nil);
    STAssertEquals([self.queue countOfEntryState:LKQueueEntryStateSuspending], (NSUInteger)1, nil);
    STAssertEquals([self.queue countOfEntryState:LKQueueEntryStateFinished], (NSUInteger)3, nil);
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

- (void)testEntries
{
    [self _setupTestEntries];
    STAssertEquals([[self.queue entries] count], (NSUInteger)TEST_ENTRY_MAX, nil);
}

- (void)testTags
{
    // tagList
    NSArray* tagList = [self.queue tagNames];
    STAssertEquals([tagList count], (NSUInteger)0, nil);

    [self _setupTestEntries];
    [self _setupMultiState];
    // TAG-0: 0, 3, 6, 9
    // TAG-1: 1, 4, 7
    // TAG-2: 2, 5, 8

    tagList = [self.queue tagNames];
    for (int i=0; i < [tagList count]; i++) {
        NSString* tagName = [tagList objectAtIndex:i];
        STAssertEqualObjects(tagName, ([NSString stringWithFormat:@"TAG-%d", i%3]), nil);
    }
    
    // entriesForTagName
    int cnt[3] = {4, 3, 3};    
    for (int it=0; it < 3; it++) {
        NSArray* tags = [self.queue entriesForTagName:[NSString stringWithFormat:@"TAG-%d", it]];
        STAssertEquals([tags count], (NSUInteger)cnt[it], nil);
        for (int i=0; i < [tags count]; i++) {
            int idx = it + i*3;
            LKQueueEntry* entry = [tags objectAtIndex:i];
            STAssertEqualObjects(([entry.info objectForKey:
                                   [NSString stringWithFormat:@"TITLE-%d", idx]]),
                                 ([NSString stringWithFormat:@"TEST-%d", idx]), nil);
            STAssertEqualObjects(([entry.resources lastObject]),
                                 ([NSString stringWithFormat:@"VALUE-%d", idx]), nil);
        }
    }
    
    // countForTagName
    STAssertEquals([self.queue countForTagName:@"TAG-0"], (NSUInteger)4, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-1"], (NSUInteger)3, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-2"], (NSUInteger)3, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-3"], (NSUInteger)0, nil);
     
    // 0: processing               TAG-0
    // 1: suspended              TAG-1
    // 2: finished(successful)     TAG-2
    // 3: finished(failed)         TAG-0
    // 4: finished(suspended)    TAG-1
    // 5-9: waiting                TAG-2, TAG-0, TAG-1, TAG-2, TAG-0

    // (clearFinishedEntry) left: 0, 1, 5, 6, 7, 8, 9
    [self.queue removeFinishedEntry];
    STAssertEquals([self.queue countForTagName:@"TAG-0"], (NSUInteger)3, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-1"], (NSUInteger)2, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-2"], (NSUInteger)2, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-3"], (NSUInteger)0, nil);

    // (removeEntry) remove TAG-2
    LKQueueEntry* entry;
    entry = [self.queue entryAtIndex:5];
    [self.queue removeEntry:entry];
    entry = [self.queue entryAtIndex:2];
    [self.queue removeEntry:entry];
    STAssertEquals([self.queue countForTagName:@"TAG-0"], (NSUInteger)3, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-1"], (NSUInteger)2, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-2"], (NSUInteger)0, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-3"], (NSUInteger)0, nil);
    
    // (removeAllEntries)
    [self.queue removeAllEntries];
    STAssertEquals([self.queue countForTagName:@"TAG-0"], (NSUInteger)0, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-1"], (NSUInteger)0, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-2"], (NSUInteger)0, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-3"], (NSUInteger)0, nil);

}

- (void)testEntryForId
{
    // (1) on memory
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:TEST_ENTRY_MAX];
    for (int i=0; i < TEST_ENTRY_MAX; i++) {
        NSDictionary* info =
        [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"TEST-ID-%d", i]
                                    forKey:[NSString stringWithFormat:@"TITLE-ID-%d", i]];
        LKQueueEntry* entry = [self.queue addEntryWithInfo:info resources:nil tagName:nil];
        [array addObject:entry];
    }
    for (LKQueueEntry* entry in array) {
        LKQueueEntry* fetchedEntry = [self.queue entryForId:entry.entryId];
        STAssertEquals(fetchedEntry, entry, nil);
    }
    // (2) persistent => see testPersistent3
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
    [[LKQueueManager defaultManager] releaseCacheWithQueue:previous];
    
    [pool drain];

    // create new queue with same queue name
    self.queue = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME];
    
    STAssertTrue((previous != self.queue), nil);
    STAssertEquals([self.queue count], (NSUInteger)(TEST_ENTRY_MAX), nil);

    for (int i=0; i < [self.queue count]; i++) {
        LKQueueEntry* entry = [self.queue entryAtIndex:i];
        STAssertNotNil(entry, nil);
        switch (i) {
            case 0:
                // 0: processing -> wating (when resuming)
                STAssertEquals(entry.state, LKQueueEntryStateWating, nil);
                break;
            case 1:
                // 1: suspended
                STAssertEquals(entry.state, LKQueueEntryStateSuspending, nil);
                STAssertEquals(entry.result, LKQueueEntryResultUnfinished, nil);
                break;
            case 2:
                // 2: finished(successful)
                STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
                STAssertEquals(entry.result, LKQueueEntryResultSuccessful, nil);
                break;
            case 3:
                // 3: finished(failed)
                STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
                STAssertEquals(entry.result, LKQueueEntryResultFailed, nil);
                break;
            case 4:
                // 4: finished(suspended)
                STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
                STAssertEquals(entry.result, LKQueueEntryResultSuspended, nil);
                break;
            default:
                // 5-9: waiting 
                STAssertEquals(entry.state, LKQueueEntryStateWating, nil);
                break;
        }
        
        STAssertEqualObjects(([entry.info objectForKey:
                               [NSString stringWithFormat:@"TITLE-%d", i]]),
                             ([NSString stringWithFormat:@"TEST-%d", i]), nil);
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", i]), nil);
        STAssertNotNil(entry.created, nil);
        STAssertNotNil(entry.modified, nil);
        STAssertNil(entry.context, nil);
        i++;
    }
    
    // tag
    NSArray* tagList = [self.queue tagNames];
    for (int i=0; i < [tagList count]; i++) {
        NSString* tagName = [tagList objectAtIndex:i];
        STAssertEqualObjects(tagName, ([NSString stringWithFormat:@"TAG-%d", i%3]), nil);
    }
    STAssertEquals([self.queue countForTagName:@"TAG-0"], (NSUInteger)4, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-1"], (NSUInteger)3, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-2"], (NSUInteger)3, nil);
    STAssertEquals([self.queue countForTagName:@"TAG-3"], (NSUInteger)0, nil);
}

- (void)testPersistent2
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [self _setupTestEntries];

    for (int i=0; i < [self.queue count]; i++) {
        LKQueueEntry* entry = [self.queue entryAtIndex:i];
        for (int j=0; j < 3; j++) {
            LKQueueEntryLog* log =
                [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeInformation
                 title:[NSString stringWithFormat:@"LOG-%02-%02", i+1, j+1]
                                                detail:[NSString stringWithFormat:@"DETAIL-%02-%02\n", i+1, j+1]];
            [entry addQueueEntryLog:log];
        }
        i++;
    }

    // discard current queue
    LKQueue* preivous = self.queue;
    self.queue = nil;
    [[LKQueueManager defaultManager] releaseCacheWithQueue:preivous];
    
    [pool drain];
    
    // create new queue with same queue name
    self.queue = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME];

    for (int i=0; i < [self.queue count]; i++) {
        LKQueueEntry* entry = [self.queue entryAtIndex:i];
        for (int j=0; j < 3; j++) {
            LKQueueEntryLog* log = [entry.logs objectAtIndex:j];
            NSString* title = [NSString stringWithFormat:@"LOG-%02-%02", i+1, j+1];
            NSString* detail = [NSString stringWithFormat:@"DETAIL-%02-%02\n", i+1, j+1];
            STAssertTrue([log.title isEqualToString:title], nil);
            STAssertTrue([log.detail isEqualToString:detail], nil);
        }
        i++;
    }
}

- (void)testPersistent3
{
    // testEntryForId (2) persistent
    NSMutableArray* entryIds = [NSMutableArray arrayWithCapacity:TEST_ENTRY_MAX];
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    for (int i=0; i < TEST_ENTRY_MAX; i++) {
        NSDictionary* info =
        [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"TEST-ID-%d", i]
                                    forKey:[NSString stringWithFormat:@"TITLE-ID-%d", i]];
        LKQueueEntry* entry = [self.queue addEntryWithInfo:info resources:nil tagName:nil];
        [entryIds addObject:entry.entryId];
    }
    
    [[LKQueueManager defaultManager] releaseCacheWithQueue:self.queue];
    self.queue = nil;
    [pool drain];
    
    // create new queue with same queue name
    self.queue = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME];
    
    int i=0;
    for (NSString* entryId in entryIds) {
        LKQueueEntry* entry = [self.queue entryForId:entryId];
        STAssertEqualObjects(([entry.info objectForKey:
                               [NSString stringWithFormat:@"TITLE-ID-%d", i]]),
                             ([NSString stringWithFormat:@"TEST-ID-%d", i]), nil);
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
    LKQueue* queue1b = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME];
    STAssertEquals(queue1b, self.queue, nil);
    
    
    // [2] diferent name    
    for (int i=0; i < TEST_ENTRY_MAX; i++) {
        NSDictionary* info =
        [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"TEST2-%d", i]
                                    forKey:[NSString stringWithFormat:@"TITLE2-%d", i]];
        NSArray* res =
            [NSArray arrayWithObject:[NSString stringWithFormat:@"VALUE2-%d", i]];
        [self.queue2 addEntryWithInfo:info resources:res tagName:nil];
    }
    
    STAssertEquals([self.queue count], (NSUInteger)(TEST_ENTRY_MAX), nil);
    for (int i=0; i < [self.queue count]; i++) {
        LKQueueEntry* entry = [self.queue entryAtIndex:i];
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE-%d", i]), nil);
        i++;
    }


    STAssertEquals([self.queue2 count], (NSUInteger)(TEST_ENTRY_MAX), nil);
    for (int j=0; j < [self.queue2 count]; j++) {
        LKQueueEntry* entry = [self.queue2 entryAtIndex:j];
        STAssertEqualObjects(([entry.resources lastObject]),
                             ([NSString stringWithFormat:@"VALUE2-%d", j]), nil);
        j++;
    }
    [self.queue2 removeAllEntries];
    [[LKQueueManager defaultManager] releaseCacheWithQueue:self.queue2];
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
    STAssertEquals(entry2.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals(entry2.result, LKQueueEntryResultUnfinished, nil);
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

                [self.queue addEntryWithInfo:info resources:res tagName:nil];
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
            NSLog(@"countOfWating: %d", [self.queue countOfEntryState:LKQueueEntryStateWating]);
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
