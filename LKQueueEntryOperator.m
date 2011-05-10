//
//  FBQueueEntry.m
//  FBQueue
//
//  Created by Hiroshi Hashiguchi on 11/04/21.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FBQueueEntryOperator.h"
#import "FBQueue.h"

// for archive
#define FB_QUEUE_ENTRY_KEY_QUEUE_ID     @"qid"
#define FB_QUEUE_ENTRY_KEY_ENTRY_ID     @"eid"
#define FB_QUEUE_ENTRY_KEY_STATE        @"sta"
#define FB_QUEUE_ENTRY_KEY_RESULT       @"rlt"

// for meta
#define FB_QUEUE_ENTRY_META_TIMESTAMP   @"__timestamp__"


@interface FBQueueEntryOperator()
@property (nonatomic, retain) NSString* queueId;
@property (nonatomic, retain) NSString* entryId;

@end

@implementation FBQueueEntryOperator

@synthesize queueId = queueId_;
@synthesize entryId = entryId_;


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Private
//------------------------------------------------------------------------------

- (NSString*)_filePathForExtension:(NSString*)extension
{
    return [[[FBQueue pathForQueueId:self.queueId]
             stringByAppendingPathComponent:self.entryId]
            stringByAppendingPathExtension:extension];    
}

// <queueId>/<entryId>.meta
- (NSString*)_infoFilePath
{
    return [self _filePathForExtension:@".info"];
}

// <queueId>/<entryId>.data
- (NSString*)_resourcesFilePath
{
    return [self _filePathForExtension:@".resources"];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Initialization and deallocation
//------------------------------------------------------------------------------
- (id)initWithQueueId:(NSString*)queueId info:(NSDictionary*)info resources:(NSArray*)resources
{
    self = [super init];
    if (self) {
        self.queueId = queueId;

        CFUUIDRef uuidObj = CFUUIDCreate(nil);
        self.entryId = (NSString*)CFUUIDCreateString(nil, uuidObj);
        CFRelease(uuidObj);

        if (info == nil) {
            info = [NSDictionary dictionary];
        }
        state_ = FBQueueStateWating;      
        result_ = FBQueueResultUnfinished;

        /* not retain for releasing
        info_ = [info retain];
        resources_ = [resources retain];
        */
        
        timestamp_ = [[NSDate date] retain];
        NSMutableDictionary* infoToWrite =
            [NSMutableDictionary dictionaryWithDictionary:info];
        [infoToWrite setObject:timestamp_ forKey:FB_QUEUE_ENTRY_META_TIMESTAMP];

        // write as XML
        if (![infoToWrite writeToFile:[self _infoFilePath] atomically:YES]) {
            NSLog(@"%s|[ERROR] Faild to write a meta to file: %@",
                  __PRETTY_FUNCTION__, [self _infoFilePath]);
            return nil;
        }

        // write as binary
        if (resources && ![NSKeyedArchiver archiveRootObject:resources toFile:[self _resourcesFilePath]]) {
            NSLog(@"%s|[ERROR] Faild to write a resources to file: %@",
                  __PRETTY_FUNCTION__, [self _resourcesFilePath]);
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    self.queueId = nil;
    self.entryId = nil;
    [info_ release];
    [resources_ release];
    [timestamp_ release];
    [super dealloc];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API
//------------------------------------------------------------------------------
+ (FBQueueEntryOperator*)queueEntryWithQueueId:(NSString*)queueId info:(NSDictionary*)info resources:(NSArray*)resources
{
    return [[[self alloc] initWithQueueId:queueId info:info resources:resources] autorelease];
}

- (BOOL)finish
{
    BOOL ret = NO;
    switch (state_) {
        case FBQueueStateInterrupting:
            state_ = FBQueueStateFinished;
            result_ = FBQueueResultInterrpted;
            ret = YES;
            break;
            
        case FBQueueStateProcessing:
            state_ = FBQueueStateFinished;
            result_ = FBQueueResultSuccessful;
            ret = YES;
            break;
            
        default:
            break;
    }
    return ret;
}

- (BOOL)fail
{
    if (state_ == FBQueueStateProcessing ||
        state_ == FBQueueStateInterrupting) {
        state_ = FBQueueStateFinished;
        result_ = FBQueueResultFailed;
        return YES;
    }
    return NO;    
}

- (BOOL)wait
{
    if (state_ == FBQueueStateProcessing ||
        state_ == FBQueueStateInterrupting) {
        state_ = FBQueueStateWating;
        return YES;
    }
    return NO;
}

- (BOOL)process
{
    if (state_ == FBQueueStateWating) {
        state_ = FBQueueStateProcessing;
        return YES;
    }
    return NO;
}

- (BOOL)interrupt
{
    if (state_ == FBQueueStateProcessing) {
        state_ = FBQueueStateInterrupting;
        return YES;
    }
    return NO;    
}


- (BOOL)clean
{
    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSString* infoFilePath = [self _infoFilePath];
    if ([fileManager fileExistsAtPath:infoFilePath]) {
        NSError* error =nil;
        if (![fileManager removeItemAtPath:infoFilePath error:&error]) {
            NSLog(@"%s|Failed to remove info file '%@':%@",
                  __PRETTY_FUNCTION__, infoFilePath, error);
            return NO;
        }
    }
    
    NSString* resourcesFilePath = [self _resourcesFilePath];
    if ([fileManager fileExistsAtPath:resourcesFilePath]) {
        NSError* error =nil;
        if (![fileManager removeItemAtPath:resourcesFilePath error:&error]) {
            NSLog(@"%s|Failed to remove resource file '%@':%@",
                  __PRETTY_FUNCTION__, resourcesFilePath, error);
            return NO;
        }
    }
    return YES;

}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark NSCording
//------------------------------------------------------------------------------

- (void)encodeWithCoder:(NSCoder*)coder
{
	[coder encodeObject:self.queueId    forKey:FB_QUEUE_ENTRY_KEY_QUEUE_ID];
	[coder encodeInt:self.state         forKey:FB_QUEUE_ENTRY_KEY_STATE];
	[coder encodeInt:self.result        forKey:FB_QUEUE_ENTRY_KEY_RESULT];
	[coder encodeObject:self.entryId    forKey:FB_QUEUE_ENTRY_KEY_ENTRY_ID];
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
        self.queueId    = [coder decodeObjectForKey:FB_QUEUE_ENTRY_KEY_QUEUE_ID];
        state_          = [coder decodeIntForKey:FB_QUEUE_ENTRY_KEY_STATE];
        result_         = [coder decodeIntForKey:FB_QUEUE_ENTRY_KEY_RESULT];
        self.entryId    = [coder decodeObjectForKey:FB_QUEUE_ENTRY_KEY_ENTRY_ID];
    }
    return self;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Properties
//------------------------------------------------------------------------------

- (NSArray*)resources
{
    if (resources_ == nil) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[self _resourcesFilePath]]) {
            resources_ = [[NSKeyedUnarchiver
                  unarchiveObjectWithFile:[self _resourcesFilePath]] retain];
        }
    }
    return resources_;
}


- (NSDictionary*)info
{
    if (info_ == nil) {
        info_ = [[NSDictionary alloc] initWithContentsOfFile:[self _infoFilePath]];
    }
    return info_;
}

- (NSDate*)timestamp
{
    if (timestamp_ == nil) {
        timestamp_ = [[self.info objectForKey:FB_QUEUE_ENTRY_META_TIMESTAMP] retain];
    }
    return timestamp_;
}

@end

