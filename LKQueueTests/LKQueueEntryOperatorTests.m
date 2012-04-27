//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


//
// NOTE: the persistent test runs in LKQueueTest.
//

#import "LKQueueEntryOperatorTests.h"
#import "LKQueueEntryOperator.h"
#import "LKQueue.h"
#import "LKQueueManager.h"

#define QUEUE_NAME  @"Test Queue"

@implementation LKQueueEntryOperatorTests

@synthesize queue;

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    self.queue = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME];
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
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueue:self.queue info:@"INFO" tagId:nil];
    return entry;
}
- (LKQueueEntryOperator*)_processingEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueue:self.queue info:@"INFO" tagId:nil];
    [entry process];
    return entry;
}
- (LKQueueEntryOperator*)_finishedEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueue:self.queue info:@"INFO"  tagId:nil];
    [entry process];
    [entry finish];
    return entry;
}
- (LKQueueEntryOperator*)_suspendedEntry
{
    LKQueueEntryOperator* entry = [LKQueueEntryOperator queueEntryWithQueue:self.queue info:@"INFO" tagId:nil];
    [entry process];
    [entry suspend];
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
    entry = [LKQueueEntryOperator queueEntryWithQueue:self.queue
                                                   info:info
                                                  tagId:@"TAG"];

    STAssertEquals(entry.queue, self.queue, nil);
    STAssertEquals(entry.state, LKQueueEntryStateWating, nil);
    STAssertEqualObjects([(NSDictionary*)entry.info objectForKey:@"TITLE"], @"TEST", nil);
    STAssertNotNil(entry.created, nil);
    STAssertTrue([entry.created compare:date]==NSOrderedDescending, nil);
    STAssertTrue([entry.created isEqualToDate:entry.modified], nil);
    STAssertEquals(entry.tagId, @"TAG", nil);
    STAssertFalse(entry.processingFailed, nil);
    
    entry.processingFailed = YES;
    STAssertTrue(entry.processingFailed, nil);
    
    entry.context = @"CONTEXT";
    STAssertEqualObjects(entry.context, @"CONTEXT", nil);

    STAssertEquals((int)[entry.logs count], 0, nil);    
}

- (void)testClean
{
    NSDictionary* info = nil;
    LKQueueEntryOperator* entry = nil;
    
    info = [NSDictionary dictionaryWithObject:@"TEST" forKey:@"TITLE"];
    entry = [LKQueueEntryOperator queueEntryWithQueue:self.queue info:info tagId:nil];
    BOOL result = [entry clean];

    NSFileManager* fileMananger = [NSFileManager defaultManager];
    NSString* logPath = [entry performSelector:@selector(_logsFilePath)];
    BOOL exisited2 = [fileMananger fileExistsAtPath:logPath];

    STAssertTrue(result, @"Invalid cleanup result", nil);
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
    STAssertEquals(entry.state, LKQueueEntryStateWating, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);

    // wating -> processing[o]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry process];
    STAssertTrue(ret, @"waiting->processing[o]");
    STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);

    // waiting -> finished[o]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry finish];
    STAssertTrue(ret, @"wating -> finished[o]");
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // waiting -> suspending[o]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry suspend];
    STAssertTrue(ret, @"waiting->suspending[o]");
    STAssertEquals(entry.state, LKQueueEntryStateSuspending, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
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
    STAssertFalse(ret, @"processing->waiting[x]");
    STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // processing -> processing[x]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry process];
    STAssertFalse(ret, @"processing->processing[x]");
    STAssertEquals(entry.state, LKQueueEntryStateProcessing, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // processing -> finished[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry finish];
    STAssertTrue(ret, @"processing->finished[o]");
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // processing -> suspending[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry suspend];
    STAssertTrue(ret, @"processing->suspending[o]");
    STAssertEquals(entry.state, LKQueueEntryStateSuspending, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
}

- (void)testFinishedState
{
    LKQueueEntryOperator* entry = nil;
    NSDate* modified;
    BOOL ret;
    
    // finshed -> waiting[x]
    entry = [self _finishedEntry];
    modified = entry.modified;
    ret = [entry wait];
    STAssertFalse(ret, @"finished->wating[x]");
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);

    // finshed -> processing[x]
    entry = [self _finishedEntry];
    modified = entry.modified;
    ret = [entry process];
    STAssertFalse(ret, @"finished->processing[x]");
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // finshed -> finished[x]
    entry = [self _finishedEntry];
    modified = entry.modified;
    ret = [entry finish];
    STAssertFalse(ret, @"finished->finished[x]");
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // finshed -> suspending[x]
    entry = [self _finishedEntry];
    modified = entry.modified;
    ret = [entry suspend];
    STAssertFalse(ret, @"finished->suspending[x]");
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
}


- (void)testSuspendingState
{
    LKQueueEntryOperator* entry = nil;
    NSDate* modified;
    BOOL ret;
    
    // suspending -> waiting[o]
    entry = [self _suspendedEntry];
    modified = entry.modified;
    ret = [entry wait];
    STAssertTrue(ret, @"suspending->wating[o]");
    STAssertEquals(entry.state, LKQueueEntryStateWating, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // suspending -> processing[x]
    entry = [self _suspendedEntry];
    modified = entry.modified;
    ret = [entry process];
    STAssertFalse(ret, @"suspending->processing[x]");
    STAssertEquals(entry.state, LKQueueEntryStateSuspending, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
    // suspending -> finished[o]
    entry = [self _suspendedEntry];
    modified = entry.modified;
    ret = [entry finish];
    STAssertTrue(ret, @"suspending->finished(sccessful)[o]");
    STAssertEquals(entry.state, LKQueueEntryStateFinished, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedDescending, nil);
    
    // suspending -> suspending[x]
    entry = [self _suspendedEntry];
    modified = entry.modified;
    ret = [entry suspend];
    STAssertFalse(ret, @"suspending->suspending[x]");
    STAssertEquals(entry.state, LKQueueEntryStateSuspending, nil);
    STAssertEquals([entry.modified compare:modified], NSOrderedSame, nil);
    
}


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
    
    entry = [self _suspendedEntry];
    canRemove = entry.canRemove;
    STAssertTrue(canRemove, nil);
}

- (void)testHasFinished
{
    LKQueueEntryOperator* entry = nil;
    BOOL hasFinished;
    
    entry = [self _waitingEntry];
    hasFinished = entry.hasFinished;
    STAssertFalse(hasFinished, nil);
    
    entry = [self _processingEntry];
    hasFinished = entry.hasFinished;
    STAssertFalse(hasFinished, nil);
    
    entry = [self _finishedEntry];
    hasFinished = entry.hasFinished;
    STAssertTrue(hasFinished, nil);
    
    entry = [self _suspendedEntry];
    hasFinished = entry.hasFinished;
    STAssertFalse(hasFinished, nil);
}


- (void)testAddLog
{
    LKQueueEntry* entry1 = [self _waitingEntry];
    for (int i=0; i < 3; i++) {
        NSDictionary* log = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSString stringWithFormat:@"LOG-A-%02", i+1], @"title",
                             [NSString stringWithFormat:@"DETAIL-A-%02\n", i+1], @"detail",
                             nil];
        [entry1 addLog:log];
    }

    LKQueueEntry*entry2 = [self _waitingEntry];
    for (int i=0; i < 6; i++) {
        NSDictionary* log = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSString stringWithFormat:@"LOG-B-%02", i+1], @"title",
                             [NSString stringWithFormat:@"DETAIL-B-%02\n", i+1], @"detail",
                             nil];
        [entry2 addLog:log];
    }

    STAssertEquals((int)[entry1.logs count], 3, nil);
    STAssertEquals((int)[entry2.logs count], 6, nil);
    
    for (int i=0; i < 3; i++) {
        NSDictionary* log = [entry1.logs objectAtIndex:i];
        NSString* title = [NSString stringWithFormat:@"LOG-A-%02", i+1];
        NSString* detail = [NSString stringWithFormat:@"DETAIL-A-%02\n", i+1];
        STAssertTrue([[log objectForKey:@"title"] isEqualToString:title], nil);
        STAssertTrue([[log objectForKey:@"detail"] isEqualToString:detail], nil);
    }

    for (int i=0; i < 6; i++) {
        NSDictionary* log = [entry2.logs objectAtIndex:i];
        NSString* title = [NSString stringWithFormat:@"LOG-B-%02", i+1];
        NSString* detail = [NSString stringWithFormat:@"DETAIL-B-%02\n", i+1];
        STAssertTrue([[log objectForKey:@"title"] isEqualToString:title], nil);
        STAssertTrue([[log objectForKey:@"detail"] isEqualToString:detail], nil);
    }
}


@end
