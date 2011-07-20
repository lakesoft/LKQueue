//
//  LKQueueEntryLogTests.m
//  LKQueue
//
//  Created by Hiroshi Hashiguchi on 11/07/20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LKQueueEntryLogTests.h"
#import "LKQueueEntryLog.h"

@implementation LKQueueEntryLogTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testQueueEntryLog
{
    LKQueueEntryLog* log;
    
    log = [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeInformation
                                           title:nil
                                          detail:nil];
    STAssertEquals(log.type, LKQueueEntryLogTypeInformation, nil);

    log = [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeNotice
                                           title:nil
                                          detail:nil];
    STAssertEquals(log.type, LKQueueEntryLogTypeNotice, nil);

    log = [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeWarning
                                           title:nil
                                          detail:nil];
    STAssertEquals(log.type, LKQueueEntryLogTypeWarning, nil);

    log = [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeError
                                           title:nil
                                          detail:nil];
    STAssertEquals(log.type, LKQueueEntryLogTypeError, nil);    
    
    log = [LKQueueEntryLog queueEntryLogWithType:LKQueueEntryLogTypeInformation
                                           title:@"TITLE"
                                          detail:@"DETAIL"];

    float delta = fabsf([log.date timeIntervalSinceNow]);
    STAssertTrue(delta < 0.1, nil);
    STAssertTrue([log.title isEqualToString:@"TITLE"], nil);
    STAssertTrue([log.detail isEqualToString:@"DETAIL"], nil);
}

@end
