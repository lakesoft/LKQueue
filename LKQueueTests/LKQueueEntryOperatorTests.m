//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FBQueueEntryOperatorTests.h"
#import "FBQueueEntryOperator.h"
#import "FBQueue.h"

#define QUEUE_NAME  @"Test Queue"

@implementation FBQueueEntryOperatorTests

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
    STAssertEquals(entry.state, FBQueueStateWating, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);
    STAssertEqualObjects([entry.info objectForKey:@"TITLE"], @"TEST", nil);
    STAssertEqualObjects([entry.resources lastObject], @"VALUE", nil);
    STAssertNotNil(entry.timestamp, nil);
    STAssertTrue([entry.timestamp compare:date]==NSOrderedDescending, nil);
    
    NSFileManager* fileMananger = [NSFileManager defaultManager];
    NSString* resPath = [entry performSelector:@selector(_resourcesFilePath)];
    BOOL exisited = [fileMananger fileExistsAtPath:resPath];
    STAssertTrue(exisited, @"%@ does not exists.", resPath);

    entry.context = @"CONTEXT";
    STAssertEqualObjects(entry.context, @"CONTEXT", nil);
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

    STAssertTrue(result, @"Invalid cleanup result", nil);
    STAssertFalse(exisited, @"%@ does exists.", resPath);
}

- (void)testWatingState
{
    LKQueueEntryOperator* entry = nil;
    BOOL ret;

    // waiting -> waiting[x]
    entry = [self _waitingEntry];
    ret = [entry wait];
    STAssertFalse(ret, @"waiting->waiting[x]");
    STAssertEquals(entry.state, FBQueueStateWating, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);

    // wating -> processing[o]
    entry = [self _waitingEntry];
    ret = [entry process];
    STAssertTrue(ret, @"waiting->processing[o]");
    STAssertEquals(entry.state, FBQueueStateProcessing, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);

    // waiting -> finished(successful)[x]
    entry = [self _waitingEntry];
    ret = [entry finish];
    STAssertFalse(ret, @"wating -> finished(successful)[x]");
    STAssertEquals(entry.state, FBQueueStateWating, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);
    
    // wating -> finished(failed)[x]
    entry = [self _waitingEntry];
    ret = [entry fail];
    STAssertFalse(ret, @"wating -> finished(failed)[x]");
    STAssertEquals(entry.state, FBQueueStateWating, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);

    // waiting -> interrupted[x]
    entry = [self _waitingEntry];
    ret = [entry interrupt];
    STAssertFalse(ret, @"waiting->intterrupted[x]");
    STAssertEquals(entry.state, FBQueueStateWating, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);
    
}

- (void)testProcessingState
{
    LKQueueEntryOperator* entry = nil;
    BOOL ret;
    
    // processing -> waiting[o]
    entry = [self _processingEntry];
    ret = [entry wait];
    STAssertTrue(ret, @"processing->waiting[o]");
    STAssertEquals(entry.state, FBQueueStateWating, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);
    
    // processing -> processing[x]
    entry = [self _processingEntry];
    ret = [entry process];
    STAssertFalse(ret, @"processing->processing[x]");
    STAssertEquals(entry.state, FBQueueStateProcessing, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);
    
    // processing -> finished(successful)[o]
    entry = [self _processingEntry];
    ret = [entry finish];
    STAssertTrue(ret, @"processing->finished(successful)[o]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, FBQueueResultSuccessful, nil);
    
    // processing -> finished(failed)[o]
    entry = [self _processingEntry];
    ret = [entry fail];
    STAssertTrue(ret, @"processing->finished(failed)[o]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, FBQueueResultFailed, nil);

    // processing -> interrupted[o]
    entry = [self _processingEntry];
    ret = [entry interrupt];
    STAssertTrue(ret, @"processing->interrupted[o]");
    STAssertEquals(entry.state, FBQueueStateInterrupting, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);    
}

- (void)testFinishedState
{
    LKQueueEntryOperator* entry = nil;
    BOOL ret;
    FBQueueResult result;
    
    // finshed -> waiting[x]
    entry = [self _finishedEntry];
    result = entry.result;
    ret = [entry wait];
    STAssertFalse(ret, @"finished->wating[x]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);

    // finshed -> processing[x]
    entry = [self _finishedEntry];
    result = entry.result;
    ret = [entry process];
    STAssertFalse(ret, @"finished->processing[x]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);
    
    // finshed -> finished(successful)[x]
    entry = [self _finishedEntry];
    result = entry.result;
    ret = [entry finish];
    STAssertFalse(ret, @"finished->finished(successful)[x]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);
    
    // finshed -> failed(failed)[x]
    entry = [self _finishedEntry];
    result = entry.result;
    ret = [entry fail];
    STAssertFalse(ret, @"finished->failed(failed)[x]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);
    
    // finshed -> interrupted[x]
    entry = [self _finishedEntry];
    result = entry.result;
    ret = [entry interrupt];
    STAssertFalse(ret, @"finished->interrupted[x]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, result, nil);    
}


- (void)testInterruptingState
{
    LKQueueEntryOperator* entry = nil;
    BOOL ret;
    
    // interrupted -> waiting[o]
    entry = [self _interruptedEntry];
    ret = [entry wait];
    STAssertTrue(ret, @"interrupted->wating[o]");
    STAssertEquals(entry.state, FBQueueStateWating, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);    
    
    // interrupted -> processing[x]
    entry = [self _interruptedEntry];
    ret = [entry process];
    STAssertFalse(ret, @"interrupted->processing[x]");
    STAssertEquals(entry.state, FBQueueStateInterrupting, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);    
    
    // interrupted -> finished(failed)[o]
    entry = [self _interruptedEntry];
    ret = [entry fail];
    STAssertTrue(ret, @"interrupted->failed[o]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, FBQueueResultFailed, nil);    
    
    // interrupted -> finished(successful)[o]
    entry = [self _interruptedEntry];
    ret = [entry finish];
    STAssertTrue(ret, @"interrupted->finished(sccessful)[o]");
    STAssertEquals(entry.state, FBQueueStateFinished, nil);
    STAssertEquals(entry.result, FBQueueResultInterrpted, nil);    
    
    // interrupted -> interrupted[x]
    entry = [self _interruptedEntry];
    ret = [entry interrupt];
    STAssertFalse(ret, @"interrupted->interrupted[x]");
    STAssertEquals(entry.state, FBQueueStateInterrupting, nil);
    STAssertEquals(entry.result, FBQueueResultUnfinished, nil);    
    
}

//
// NOTE: the persistent test runs in FBQueueTest.

@end
