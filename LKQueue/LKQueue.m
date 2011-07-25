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

#define LK_QUEUE_PATH       @"__FBQueue__"
#define LK_QUEUE_FILENAME   @"queue.dat"
#define LK_TAG_FILENAME   @"queue.tag"

@interface LKQueue()
@property (nonatomic, retain) NSString* queueId;
@property (nonatomic, copy  ) NSString* name;
@property (nonatomic, retain) NSMutableArray* list;
@property (nonatomic, retain) NSString* path;
@property (nonatomic, retain) NSMutableDictionary* tags;
@end


static NSMutableDictionary* queues_;


@implementation LKQueue

@synthesize queueId = queueId_;
@synthesize name = name_;
@synthesize list = list_;
@synthesize path = path_;
@synthesize tags = tags_;

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Private
//------------------------------------------------------------------------------

NSString* _md5String(NSString* string)
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

- (NSString*)_queueFilePath
{
    return [self.path stringByAppendingPathComponent:LK_QUEUE_FILENAME];
}

- (NSString*)_tagFilePath
{
    return [self.path stringByAppendingPathComponent:LK_TAG_FILENAME];
}

// not thread safe
// --> must be called in @synchronized(self.list)
- (BOOL)_saveList
{
    NSString* filePath = [self _queueFilePath];
    if ([NSKeyedArchiver archiveRootObject:self.list toFile:filePath]) {
        return YES;
    } else {
        NSLog(@"%s|[ERROR]Failed to save the queue file: %@",
              __PRETTY_FUNCTION__, filePath);
        return NO;
    }
}

// not thread safe
// --> must be called in @synchronized(self.tags)
- (BOOL)_saveTags
{
    NSString* filePath = [self _tagFilePath];
    if ([NSKeyedArchiver archiveRootObject:self.tags toFile:filePath]) {
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

- (NSString*)_tagIdForName:(NSString*)name
{
    if (name) {
        return _md5String(name);
    } else {
        return nil;
    }
}

// return tagId
- (NSString*)_addTagName:(NSString*)name
{
    if (name) {
        NSString* tagId = [self _tagIdForName:name];
        @synchronized (self.tags) {
            if (![self.tags objectForKey:name]) {
                [self.tags setObject:name forKey:tagId];
                [self _saveTags];
            }
        }
        return tagId;
    } else {
        return nil;
    }
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
        self.queueId = [[self class] queueIdForName:name];
        self.name = name;
        
        [self _setupPath];
        
        NSFileManager* fileManager = [NSFileManager defaultManager];

        // [1] queue
        NSString* queueFilePath = [self _queueFilePath];
        if ([fileManager fileExistsAtPath:queueFilePath]) {
            self.list = [NSKeyedUnarchiver unarchiveObjectWithFile:queueFilePath];
            if (self.list == nil) {
                NSLog(@"%s|[ERROR] Failed to restore the queue file: %@",
                      __PRETTY_FUNCTION__, queueFilePath);
                return NO;
            }
            for (LKQueueEntryOperator* entry in self.list) {
                if (entry.state == LKQueueEntryStateProcessing) {
                    [entry wait];
                }
            }

        } else {
            // new queue
            self.list = [NSMutableArray array];
            [self _saveList];
        }

        // [2] tag
        NSString* tagFilePath = [self _tagFilePath];
        if ([fileManager fileExistsAtPath:tagFilePath]) {
            self.tags = [NSKeyedUnarchiver unarchiveObjectWithFile:tagFilePath];
            if (self.tags == nil) {
                NSLog(@"%s|[ERROR] Failed to restore the tag file: %@",
                      __PRETTY_FUNCTION__, tagFilePath);
                return NO;
            }
            
        } else {
            // new tag
            self.tags = [NSMutableDictionary dictionary];
            [self _saveTags];
        }

    }
    return self;
}

- (void)dealloc {
    self.name = nil;
    self.list = nil;
    self.path = nil;
    self.tags = nil;
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

+ (BOOL)hasExistedQueueWithName:(NSString*)name
{
    BOOL hasExisted = NO;
    
    @synchronized (queues_) {
        if ([queues_ objectForKey:name]) {
            hasExisted = YES;
        } else {
            NSString* path = [self pathForQueueId:[self queueIdForName:name]];
            NSFileManager* fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:path]) {
                hasExisted = YES;
            }
        }
    }
    return hasExisted;
}

+ (BOOL)removeQueueWithName:(NSString*)name
{
    if ([self hasExistedQueueWithName:name]) {
        [self releaseQueueWithName:name];

        NSString* path = [self pathForQueueId:[self queueIdForName:name]];
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSError* error = nil;
        if ([fileManager removeItemAtPath:path error:&error]) {
            return YES;
        } else {
            NSLog(@"%s|[ERROR] Failed to remove the directory|%@",
                  __PRETTY_FUNCTION__, error);
            return NO;
        }
    }
    return NO;  // not found
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API
//------------------------------------------------------------------------------

#pragma mark -
#pragma mark API ()

- (LKQueueEntry*)addEntryWithInfo:(NSDictionary*)info resources:(NSArray*)resources tagName:(NSString*)tagName
{
    NSString* tagId = [self _addTagName:tagName];
    LKQueueEntryOperator* entry =
        [LKQueueEntryOperator queueEntryWithQueueId:self.queueId
                                               info:info
                                          resources:resources
                                              tagId:tagId];
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
            if (entry.state == LKQueueEntryStateWating) {
                [entry process];    // -> processing
                [self _saveList];
                return entry;
            }
        }
    }
    return nil;
}

#pragma mark -
#pragma mark API (Entry operations)

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

- (BOOL)removeEntry:(LKQueueEntry*)entry
{
    @synchronized (self.list) {
        if ([self.list containsObject:entry]) {
            if (entry.canRemove) {
                [self.list removeObject:entry];
                [self _saveList];
                return YES;
            } else {
                return NO;
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
            if (entry.state == LKQueueEntryStateFinished) {
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


#pragma mark -
#pragma mark API (Accessing entry list)

- (NSUInteger)count
{
    return [self.list count];
}

- (NSUInteger)countOfEntryState:(LKQueueEntryState)state
{
    NSUInteger count = 0;
    for (LKQueueEntryOperator* entry in self.list) {
        if (entry.state == state) {
            count++;
        }
    }
    return count;
}

- (LKQueueEntry*)entryAtIndex:(NSInteger)index
{
    if (index < 0 || [self.list count] <= index) {
        return nil;
    }
    
    @synchronized (self.list) {
        return [self.list objectAtIndex:index];
    }
}

// API (Tag)
- (NSArray*)tagList
{
    return [self.tags allValues];
}


#pragma mark -
#pragma mark API (Cooperate with other queues)

- (BOOL)addEntry:(LKQueueEntry*)entry
{
    if (entry == nil || [self.list containsObject:entry]) {
        return NO;
    }

    LKQueueEntryOperator* newEntry =
        [LKQueueEntryOperator queueEntryWithQueueId:self.queueId
                                           info:entry.info
                                      resources:entry.resources
                                        tagId:((LKQueueEntryOperator*)entry).tagId];

    @synchronized (self.list) {
        [self.list addObject:newEntry];
        [self _saveList];
    }
    return YES;
}

#pragma mark -
#pragma mark API (etc)

+ (NSString*)queueIdForName:(NSString*)name
{
    NSString* queueId = _md5String(name);
    return queueId;
}

+ (NSString*)pathForQueueId:(NSString*)queueId
{
    NSString* basePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:LK_QUEUE_PATH];
    return [basePath stringByAppendingPathComponent:queueId];
}


@end
