//
// Copyright (c) 2011 Hiroshi Hashiguchi
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <CommonCrypto/CommonDigest.h>
#import "LKQueue.h"
#import "LKQueueEntryOperator.h"

#define FB_QUEUE_PATH       @"__FBQueue__"
#define FB_QUEUE_FILENAME   @"queue.dat"

@interface LKQueue()
@property (nonatomic, retain) NSString* queueId;
@property (nonatomic, copy  ) NSString* name;
@property (nonatomic, retain) NSMutableArray* list;
@property (nonatomic, retain) NSString* path;
@end


static NSMutableDictionary* queues_;


@implementation LKQueue

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
            for (LKQueueEntryOperator* entry in self.list) {
                if (entry.state == LKQueueStateProcessing) {
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

+ (LKQueue*)queueWithName:(NSString*)name
{
    LKQueue* queue = nil;
    
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

- (LKQueueEntry*)addEntryWithInfo:(NSDictionary*)info resources:(NSArray*)resources
{
    LKQueueEntryOperator* entry =
        [LKQueueEntryOperator queueEntryWithQueueId:self.queueId
                                               info:info
                                          resources:resources];
    @synchronized (self.list) {
        [self.list addObject:entry];
        [self _saveList];
    }
    return entry;
}

- (LKQueueEntry*)getEntryForProcessing
{
    @synchronized (self.list) {
        for (LKQueueEntryOperator* entry in self.list) {
            if (entry.state == LKQueueStateWating) {
                [entry process];    // -> processing
                [self _saveList];
                return entry;
            }
        }
    }
    return nil;
}

- (BOOL)waitEntry:(LKQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(LKQueueEntryOperator*)entry wait]) {
                [self _saveList];
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)finishEntry:(LKQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(LKQueueEntryOperator*)entry finish]) {
                [self _saveList];
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)interruptEntry:(LKQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(LKQueueEntryOperator*)entry interrupt]) {
                [self _saveList];
                return YES;
            }
        }
    }
    return NO;    
}

- (BOOL)failEntry:(LKQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if ([(LKQueueEntryOperator*)entry fail]) {
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
        for (LKQueueEntryOperator* entry in [[self.list copy] autorelease]) {
            if (entry.state == LKQueueStateFinished) {
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
    for (LKQueueEntryOperator* entry in self.list) {
        if (entry.state == LKQueueStateWating) {
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
