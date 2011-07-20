//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LKQueueEntryOperatorTests.h"
#import "LKQueueEntryOperator.h"
#import "LKQueueEntryLog.h"
#import "LKQueue.h"

#define QUEUE_NAME  @"Test Queue"

@implementation LKQueueEntryOperatorTests

@synthesize queue;

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    self.queue = [LKQueue queueWithName:QUEUE_NAME];
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
    [self.queue removeAllEntries];
    self.queue = nil;
}

//-----------
// Utilities
//-----------
- (LKQueueEntryOperator*)_waitingEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueueId:self.queue.queueId info:nil resources:nil];
    return entry;
}
- (LKQueueEntryOperator*)_processingEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueueId:self.queue.queueId info:nil resources:nil];
    [entry process];
    return entry;
}
- (LKQueueEntryOperator*)_finishedEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueueId:self.queue.queueId info:nil resources:nil];
    [entry process];
    [entry finish];
    return entry;
}
- (LKQueueEntryOperator*)_failedEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueueId:self.queue.queueId info:nil resources:nil];
    [entry process];
    [entry fail];
    return entry;
}
- (LKQueueEntryOperator*)_interruptedEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueueId:self.queue.queueId info:nil resources:nil];
    [entry process];
    [entry interrupt];
    return entry;
}

//-----------
// Test case
//-----------
- (void)testInitialization
{
    NSDictionary* info = nil;
    NSArray* res = nil;
    LKQueueEntryOperator* entry = nil;

    info = [NSDictionary dictionaryWithObject:@"TEST" forKey:@"TITLE"];
    res = [NSArray arrayWithObject:@"VALUE"];

    NSDate* date = [NSDate date];
    entry = [LKQueueEntryOperator queueEntryWithQueueId:self.queue.queueId info:info resources:res];

    STAssertEquals(entry.queueId, self.queue.queueId, nil);
    STAssertEquals(entry.state, LKQueueStateWating, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEqualObjects([entry.info objectForKey:@"TITLE"], @"TEST", nil);
    STAssertEqualObjects([entry.resources lastObject], @"VALUE", nil);
    STAssertNotNil(entry.created, nil);
    STAssertTrue([entry.created compare:date]==NSOrderedDescending, nil);
    STAssertTrue([entry.created isEqualToDate:entry.modified], nil);
    
    NSFileManager* fileMananger = [NSFileManager defaultManager];
    NSString* resPath = [entry performSelector:@selector(_resourcesFilePath)];
    BOOL exisited = [fileMananger fileExistsAtPath:resPath];
    STAssertTrue(exisited, @"%@ does not exists.", resPath);

    STAssertEquals((int)[entry.logs count], 0, nil);    
}

- (void)testClean
{
    NSDictionary* info = nil;
    NSArray* res = nil;
    LKQueueEntryOperator* entry = nil;
    
    info = [NSDictionary dictionaryWithObject:@"TEST" forKey:@"TITLE"];
    res = [NSArray arrayWithObject:@"VALUE"];
    entry = [LKQueueEntryOperator queueEntryWithQueueId:self.queue.queueId info:info resources:res];
    BOOL result = [entry clean];

    NSFileManager* fileMananger = [NSFileManager defaultManager];
    NSString* resPath = [entry performSelector:@selector(_resourcesFilePath)];
    BOOL exisited = [fileMananger fileExistsAtPath:resPath];
    NSString* logPath = [entry performSelector:@selector(_logsFilePath)];
    BOOL exisited2 = [fileMananger fileExistsAtPath:logPath];

    STAssertTrue(result, @"Invalid cleanup result", nil);
    STAssertFalse(exisited, @"%@ does exists.", resPath);
    STAssertFalse(exisited2, @"%@ does exists.", logPath);
}

- (void)testWatingState
{
    LKQueueEntryOperator* entry = nil;
    NSDate* modified;
    BOOL ret;

    // waiting -> waiting[x]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry wait];
    STAssertFalse(ret, @"waiting->waiting[x]");
    STAssertEquals(entry.state, LKQueueStateWating, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);

    // wating -> processing[o]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry process];
    STAssertTrue(ret, @"waiting->processing[o]");
    STAssertEquals(entry.state, LKQueueStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);

    // waiting -> finished(successful)[x]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry finish];
    STAssertFalse(ret, @"wating -> finished(successful)[x]");
    STAssertEquals(entry.state, LKQueueStateWating, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // wating -> finished(failed)[x]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry fail];
    STAssertFalse(ret, @"wating -> finished(failed)[x]");
    STAssertEquals(entry.state, LKQueueStateWating, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);

    // waiting -> interrupted[x]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry interrupt];
    STAssertFalse(ret, @"waiting->intterrupted[x]");
    STAssertEquals(entry.state, LKQueueStateWating, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
}

- (void)testProcessingState
{
    LKQueueEntryOperator* entry = nil;
    NSDate* modified;
    BOOL ret;
    
    // processing -> waiting[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry wait];
    STAssertTrue(ret, @"processing->waiting[o]");
    STAssertEquals(entry.state, LKQueueStateWating, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // processing -> processing[x]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry process];
    STAssertFalse(ret, @"processing->processing[x]");
    STAssertEquals(entry.state, LKQueueStateProcessing, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // processing -> finished(successful)[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry finish];
    STAssertTrue(ret, @"processing->finished(successful)[o]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultSuccessful, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // processing -> finished(failed)[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry fail];
    STAssertTrue(ret, @"processing->finished(failed)[o]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultFailed, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);

    // processing -> interrupted[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry interrupt];
    STAssertTrue(ret, @"processing->interrupted[o]");
    STAssertEquals(entry.state, LKQueueStateInterrupting, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);    
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
}

- (void)testFinishedState
{
    LKQueueEntryOperator* entry = nil;
    NSDate* modified;
    BOOL ret;
    LKQueueResult result;
    
    // finshed -> waiting[x]
    entry = [self _finishedEntry];
    result = entry.result;
    modified = entry.modified;
    ret = [entry wait];
    STAssertFalse(ret, @"finished->wating[x]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);

    // finshed -> processing[x]
    entry = [self _finishedEntry];
    result = entry.result;
    modified = entry.modified;
    ret = [entry process];
    STAssertFalse(ret, @"finished->processing[x]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // finshed -> finished(successful)[x]
    entry = [self _finishedEntry];
    result = entry.result;
    modified = entry.modified;
    ret = [entry finish];
    STAssertFalse(ret, @"finished->finished(successful)[x]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // finshed -> failed(failed)[x]
    entry = [self _finishedEntry];
    result = entry.result;
    modified = entry.modified;
    ret = [entry fail];
    STAssertFalse(ret, @"finished->failed(failed)[x]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // finshed -> interrupted[x]
    entry = [self _finishedEntry];
    result = entry.result;
    modified = entry.modified;
    ret = [entry interrupt];
    STAssertFalse(ret, @"finished->interrupted[x]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);    
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
}


- (void)testInterruptingState
{
    LKQueueEntryOperator* entry = nil;
    NSDate* modified;
    BOOL ret;
    
    // interrupted -> waiting[o]
    entry = [self _interruptedEntry];
    modified = entry.modified;
    ret = [entry wait];
    STAssertTrue(ret, @"interrupted->wating[o]");
    STAssertEquals(entry.state, LKQueueStateWating, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);    
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // interrupted -> processing[x]
    entry = [self _interruptedEntry];
    modified = entry.modified;
    ret = [entry process];
    STAssertFalse(ret, @"interrupted->processing[x]");
    STAssertEquals(entry.state, LKQueueStateInterrupting, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);    
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // interrupted -> finished(failed)[o]
    entry = [self _interruptedEntry];
    modified = entry.modified;
    ret = [entry fail];
    STAssertTrue(ret, @"interrupted->failed[o]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultFailed, nil);    
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // interrupted -> finished(successful)[o]
    entry = [self _interruptedEntry];
    modified = entry.modified;
    ret = [entry finish];
    STAssertTrue(ret, @"interrupted->finished(sccessful)[o]");
    STAssertEquals(entry.state, LKQueueStateFinished, nil);
    STAssertEquals(entry.result, LKQueueResultInterrpted, nil);    
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // interrupted -> interrupted[x]
    entry = [self _interruptedEntry];
    modified = entry.modified;
    ret = [entry interrupt];
    STAssertFalse(ret, @"interrupted->interrupted[x]");
    STAssertEquals(entry.state, LKQueueStateInterrupting, nil);
    STAssertEquals(entry.result, LKQueueResultUnfinished, nil);    
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
}

//
// NOTE: the persistent test runs in LKQueueTest.


- (void)testCanRemove
{
    LKQueueEntryOperator* entry = nil;
    BOOL canRemove;

    entry = [self _waitingEntry];
    canRemove = entry.canRemove;
    STAssertTrue(canRemove, nil);

    entry = [self _processingEntry];
    canRemove = entry.canRemove;
    STAssertFalse(canRemove, nil);

    entry = [self _finishedEntry];
    canRemove = entry.canRemove;
    STAssertTrue(canRemove, nil);
    
    entry = [self _failedEntry];
    canRemove = entry.canRemove;
    STAssertTrue(canRemove, nil);
    
    entry = [self _interruptedEntry];
    canRemove = entry.canRemove;
    STAssertTrue(canRemove, nil);
}


- (void)testAddQueueEntryLog
{
    LKQueueEntryLog* log;
    
    LKQueueEntry* entry1 = [self _waitingEntry];
    for (int i=0; i < 3; i++) {
        log = [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeInformation
                            title:[NSString stringWithFormat:@"LOG-A-%02", i+1]
                            detail:[NSString stringWithFormat:@"DETAIL-A-%02\n", i+1]];
        [entry1 addQueueEntryLog:log];
    }

    LKQueueEntry*entry2 = [self _waitingEntry];
    for (int i=0; i < 6; i++) {
        log = [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeInformation
                               title:[NSString stringWithFormat:@"LOG-B-%02", i+1]
                              detail:[NSString stringWithFormat:@"DETAIL-B-%02\n", i+1]];
        [entry2 addQueueEntryLog:log];
    }

    STAssertEquals((int)[entry1.logs count], 3, nil);
    STAssertEquals((int)[entry2.logs count], 6, nil);
    
    for (int i=0; i < 3; i++) {
        log = [entry1.logs objectAtIndex:i];
        NSString* title = [NSString stringWithFormat:@"LOG-A-%02", i+1];
        NSString* detail = [NSString stringWithFormat:@"DETAIL-A-%02\n", i+1];
        STAssertTrue([log.title isEqualToString:title], nil);
        STAssertTrue([log.detail isEqualToString:detail], nil);
    }

    for (int i=0; i < 6; i++) {
        log = [entry2.logs objectAtIndex:i];
        NSString* title = [NSString stringWithFormat:@"LOG-B-%02", i+1];
        NSString* detail = [NSString stringWithFormat:@"DETAIL-B-%02\n", i+1];
        STAssertTrue([log.title isEqualToString:title], nil);
        STAssertTrue([log.detail isEqualToString:detail], nil);
    }
}

@end
