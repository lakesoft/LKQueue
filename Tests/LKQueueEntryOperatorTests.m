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

    XCTAssertEqual(entry.queue, self.queue);
    XCTAssertEqual(entry.state, LKQueueEntryStateWating);
    XCTAssertEqualObjects([(NSDictionary*)entry.info objectForKey:@"TITLE"], @"TEST");
    XCTAssertNotNil(entry.created);
    XCTAssertTrue([entry.created compare:date]==NSOrderedDescending);
    XCTAssertTrue([entry.created isEqualToDate:entry.modified]);
    XCTAssertEqual(entry.tagId, @"TAG");
    XCTAssertFalse(entry.processingFailed);
    
    entry.processingFailed = YES;
    XCTAssertTrue(entry.processingFailed);
    
    entry.context = @"CONTEXT";
    XCTAssertEqualObjects(entry.context, @"CONTEXT");

    XCTAssertEqual((int)[entry.logs count], 0);    
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

    XCTAssertTrue(result, @"Invalid cleanup result", nil);
    XCTAssertFalse(exisited2, @"%@ does exists.", logPath);
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
    XCTAssertFalse(ret, @"waiting->waiting[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateWating);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);

    // wating -> processing[o]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry process];
    XCTAssertTrue(ret, @"waiting->processing[o]");
    XCTAssertEqual(entry.state, LKQueueEntryStateProcessing);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedDescending);

    // waiting -> finished[o]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry finish];
    XCTAssertTrue(ret, @"wating -> finished[o]");
    XCTAssertEqual(entry.state, LKQueueEntryStateFinished);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedDescending);
    
    // waiting -> suspending[o]
    entry = [self _waitingEntry];
    modified = entry.modified;
    ret = [entry suspend];
    XCTAssertTrue(ret, @"waiting->suspending[o]");
    XCTAssertEqual(entry.state, LKQueueEntryStateSuspending);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedDescending);
    
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
    XCTAssertFalse(ret, @"processing->waiting[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateProcessing);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);
    
    // processing -> processing[x]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry process];
    XCTAssertFalse(ret, @"processing->processing[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateProcessing);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);
    
    // processing -> finished[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry finish];
    XCTAssertTrue(ret, @"processing->finished[o]");
    XCTAssertEqual(entry.state, LKQueueEntryStateFinished);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedDescending);
    
    // processing -> suspending[o]
    entry = [self _processingEntry];
    modified = entry.modified;
    ret = [entry suspend];
    XCTAssertTrue(ret, @"processing->suspending[o]");
    XCTAssertEqual(entry.state, LKQueueEntryStateSuspending);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedDescending);
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
    XCTAssertFalse(ret, @"finished->wating[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateFinished);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);

    // finshed -> processing[x]
    entry = [self _finishedEntry];
    modified = entry.modified;
    ret = [entry process];
    XCTAssertFalse(ret, @"finished->processing[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateFinished);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);
    
    // finshed -> finished[x]
    entry = [self _finishedEntry];
    modified = entry.modified;
    ret = [entry finish];
    XCTAssertFalse(ret, @"finished->finished[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateFinished);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);
    
    // finshed -> suspending[x]
    entry = [self _finishedEntry];
    modified = entry.modified;
    ret = [entry suspend];
    XCTAssertFalse(ret, @"finished->suspending[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateFinished);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);
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
    XCTAssertTrue(ret, @"suspending->wating[o]");
    XCTAssertEqual(entry.state, LKQueueEntryStateWating);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedDescending);
    
    // suspending -> processing[x]
    entry = [self _suspendedEntry];
    modified = entry.modified;
    ret = [entry process];
    XCTAssertFalse(ret, @"suspending->processing[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateSuspending);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);
    
    // suspending -> finished[o]
    entry = [self _suspendedEntry];
    modified = entry.modified;
    ret = [entry finish];
    XCTAssertTrue(ret, @"suspending->finished(sccessful)[o]");
    XCTAssertEqual(entry.state, LKQueueEntryStateFinished);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedDescending);
    
    // suspending -> suspending[x]
    entry = [self _suspendedEntry];
    modified = entry.modified;
    ret = [entry suspend];
    XCTAssertFalse(ret, @"suspending->suspending[x]");
    XCTAssertEqual(entry.state, LKQueueEntryStateSuspending);
    XCTAssertEqual([entry.modified compare:modified], NSOrderedSame);
    
}


- (void)testCanRemove
{
    LKQueueEntryOperator* entry = nil;
    BOOL canRemove;

    entry = [self _waitingEntry];
    canRemove = entry.canRemove;
    XCTAssertTrue(canRemove);

    entry = [self _processingEntry];
    canRemove = entry.canRemove;
    XCTAssertFalse(canRemove);

    entry = [self _finishedEntry];
    canRemove = entry.canRemove;
    XCTAssertTrue(canRemove);
    
    entry = [self _suspendedEntry];
    canRemove = entry.canRemove;
    XCTAssertTrue(canRemove);
}

- (void)testHasFinished
{
    LKQueueEntryOperator* entry = nil;
    BOOL hasFinished;
    
    entry = [self _waitingEntry];
    hasFinished = entry.hasFinished;
    XCTAssertFalse(hasFinished);
    
    entry = [self _processingEntry];
    hasFinished = entry.hasFinished;
    XCTAssertFalse(hasFinished);
    
    entry = [self _finishedEntry];
    hasFinished = entry.hasFinished;
    XCTAssertTrue(hasFinished);
    
    entry = [self _suspendedEntry];
    hasFinished = entry.hasFinished;
    XCTAssertFalse(hasFinished);
}


- (void)testAddLog
{
    LKQueueEntry* entry1 = [self _waitingEntry];
    for (int i=0; i < 3; i++) {
        NSDictionary* log = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSString stringWithFormat:@"LOG-A-%02d", i+1], @"title",
                             [NSString stringWithFormat:@"DETAIL-A-%02d\n", i+1], @"detail",
                             nil];
        [entry1 addLog:log];
    }

    LKQueueEntry*entry2 = [self _waitingEntry];
    for (int i=0; i < 6; i++) {
        NSDictionary* log = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSString stringWithFormat:@"LOG-B-%02d", i+1], @"title",
                             [NSString stringWithFormat:@"DETAIL-B-%02d\n", i+1], @"detail",
                             nil];
        [entry2 addLog:log];
    }

    XCTAssertEqual((int)[entry1.logs count], 3);
    XCTAssertEqual((int)[entry2.logs count], 6);
    
    for (int i=0; i < 3; i++) {
        NSDictionary* log = [entry1.logs objectAtIndex:i];
        NSString* title = [NSString stringWithFormat:@"LOG-A-%02d", i+1];
        NSString* detail = [NSString stringWithFormat:@"DETAIL-A-%02d\n", i+1];
        XCTAssertTrue([[log objectForKey:@"title"] isEqualToString:title]);
        XCTAssertTrue([[log objectForKey:@"detail"] isEqualToString:detail]);
    }

    for (int i=0; i < 6; i++) {
        NSDictionary* log = [entry2.logs objectAtIndex:i];
        NSString* title = [NSString stringWithFormat:@"LOG-B-%02d", i+1];
        NSString* detail = [NSString stringWithFormat:@"DETAIL-B-%02d\n", i+1];
        XCTAssertTrue([[log objectForKey:@"title"] isEqualToString:title]);
        XCTAssertTrue([[log objectForKey:@"detail"] isEqualToString:detail]);
    }
}


@end
