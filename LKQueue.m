//
//  FBQueue.m
//  FBQueue
//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import <CommonCrypto/CommonDigest.h>
#import "FBQueue.h"
#import "FBQueueEntryOperator.h"

#define FB_QUEUE_PATH       @"__FBQueue__"
#define FB_QUEUE_FILENAME   @"queue.dat"

@interface FBQueue()
@property (nonatomic, retain) NSString* queueId;
@property (nonatomic, copy  ) NSString* name;
@property (nonatomic, retain) NSMutableArray* list;
@property (nonatomic, retain) NSString* path;
@end


static NSMutableDictionary* queues_;


@implementation FBQueue

@synthesize queueId = queueId_;
@synthesize name = name_;
@synthesize list = list_;
@synthesize path = path_;

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Private
//------------------------------------------------------------------------------

- (NSString*)_md5String:(NSString*)string
{
    unsigned char result[16];
    const char* cString = [string UTF8String];

    CC_MD5(cString, strlen(cString), result ); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3], 
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ]; 
}

- (BOOL)_setupPath
{
    self.path = [[self class] pathForQueueId:self.queueId];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = nil;
    if (![fileManager fileExistsAtPath:self.path]) {
        if (![fileManager createDirectoryAtPath:self.path
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error]) {
            NSLog(@"%s|[ERROR] Can not create a directory|%@", __PRETTY_FUNCTION__, self.path);
            return NO;
        }
    }
    return YES;
}

- (NSString*)_filePath
{
    return [self.path stringByAppendingPathComponent:FB_QUEUE_FILENAME];
}

// not thread safe
// --> must be called in @synchronized(self.list)
- (BOOL)_saveList
{
    NSString* filePath = [self _filePath];
    if ([NSKeyedArchiver archiveRootObject:self.list toFile:filePath]) {
        return YES;
    } else {
        NSLog(@"%s|[ERROR]Failed to save the queue file: %@",
              __PRETTY_FUNCTION__, filePath);
        return NO;
    }
}


- (BOOL)_removeQueuePath
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = nil;
    if (![fileManager removeItemAtPath:self.path error:&error]) {
        NSLog(@"%s|[ERROR] Failed to remove the directory|%@",
              __PRETTY_FUNCTION__, error);
        return NO;
    }
    return YES;
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Initialization and deallocation
//------------------------------------------------------------------------------

+ (void)initialize
{
    if (queues_ == nil) {
        queues_ = [[NSMutableDictionary alloc] init];
    }
}

- (id)initWithName:(NSString*)name {
    self = [super init];
    if (self) {
        self.queueId = [self _md5String:name];
        self.name = name;
        
        [self _setupPath];
        
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSString* filePath = [self _filePath];
        if ([fileManager fileExistsAtPath:filePath]) {
            self.list = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
            if (self.list == nil) {
                NSLog(@"%s|[ERROR] Failed to restore the queue file: %@",
                      __PRETTY_FUNCTION__, filePath);
                return NO;
            }
            for (FBQueueEntryOperator* entry in self.list) {
                if (entry.state == FBQueueStateProcessing) {
                    [entry wait];
                }
            }
        } else {
            // new queue
            self.list = [NSMutableArray array];
            [self _saveList];
        }
    }
    return self;
}

- (void)dealloc {
    self.name = nil;
    self.list = nil;
    self.path = nil;
    [super dealloc];
}

+ (FBQueue*)queueWithName:(NSString*)name
{
    FBQueue* queue = nil;
    
    @synchronized (queues_) {
        queue = [queues_ objectForKey:name];
        if (queue == nil) {
            queue = [[self alloc] initWithName:name];
            [queues_ setObject:queue forKey:name];
            [queue release];
        }
    }
    return queue;
}


 + (void)releaseQueueWithName:(NSString*)name
{
    @synchronized (queues_) {
        [queues_ removeObjectForKey:name];
    }
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API
//------------------------------------------------------------------------------

- (FBQueueEntry*)addEntryWithInfo:(NSDictionary*)info resources:(NSArray*)resources
{
    FBQueueEntryOperator* entry =
        [FBQueueEntryOperator queueEntryWithQueueId:self.queueId
                                               info:info
                                          resources:resources];
    @synchronized (self.list) {
        [self.list addObject:entry];
        [self _saveList];
    }
    return entry;
}

- (FBQueueEntry*)getEntryForProcessing
{
    @synchronized (self.list) {
        for (FBQueueEntryOperator* entry in self.list) {
            if (entry.state == FBQueueStateWating) {
                [entry process];    // -> processing
                [self _saveList];
                return entry;
            }
        }
    }
    return nil;
}

- (BOOL)waitEntry:(FBQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(FBQueueEntryOperator*)entry wait]) {
                [self _saveList];
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)finishEntry:(FBQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(FBQueueEntryOperator*)entry finish]) {
                [self _saveList];
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)interruptEntry:(FBQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(FBQueueEntryOperator*)entry interrupt]) {
                [self _saveList];
                return YES;
            }
        }
    }
    return NO;    
}

- (BOOL)failEntry:(FBQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(FBQueueEntryOperator*)entry fail]) {
                [self _saveList];
                return YES;
            }
        }
    }
    return NO;
}


- (void)clearFinishedEntry
{
    @synchronized (self.list) {
        BOOL updated = NO;
        for (FBQueueEntryOperator* entry in [[self.list copy] autorelease]) {
            if (entry.state == FBQueueStateFinished) {
                [entry clean];
                [self.list removeObject:entry];
                updated = YES;
            }
        }
        if (updated) {
            [self _saveList];
        }
    }
}

- (void)removeAllEntries
{
    @synchronized (self.list) {
        [self.list removeAllObjects];
        [self _removeQueuePath];
        [self _setupPath];
        [self _saveList];
    }
}


- (NSUInteger)count
{
    return [self.list count];
}

- (NSUInteger)countOfWating
{
    NSUInteger count = 0;
    for (FBQueueEntryOperator* entry in self.list) {
        if (entry.state == FBQueueStateWating) {
            count++;
        }
    }
    return count;
}

- (NSArray*)queueList
{
    return self.list;
}


+ (NSString*)pathForQueueId:(NSString*)queueId
{
    NSString* basePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:FB_QUEUE_PATH];
    return [basePath stringByAppendingPathComponent:queueId];
}

@end
