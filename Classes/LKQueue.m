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

#define LK_QUEUE_FILENAME   @"queue.dat"
#define LK_TAG_FILENAME     @"queue.tag"

@interface LKQueue()
@property (nonatomic, strong) NSString* queueId;
@property (nonatomic, strong) NSString* path;
@property (nonatomic, strong) NSMutableDictionary* tags;
@property (nonatomic, strong) NSMutableArray* entryList;      // <LKQueueEntryOperator>
@end


@implementation LKQueue

@synthesize queueId = queueId_;
@synthesize path = path_;
@synthesize tags = tags_;

@synthesize entryList = entryList_;

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Private
//------------------------------------------------------------------------------

static NSString* _md5String(NSString* string)
{
    unsigned char result[16];
    const char* cString = [string UTF8String];

    CC_MD5(cString, (CC_LONG)strlen(cString), result ); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3], 
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ]; 
}

- (BOOL)_createDirectoryWithPath:(NSString*)path
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = nil;
    if (![fileManager fileExistsAtPath:path]) {
        if (![fileManager createDirectoryAtPath:path
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error]) {
            NSLog(@"%s|[ERROR] Can not create a directory|%@", __PRETTY_FUNCTION__, path);
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
// --> must be called in @synchronized(self.entryList)
- (BOOL)_saveList
{
    NSString* filePath = [self _queueFilePath];
    if ([NSKeyedArchiver archiveRootObject:self.entryList toFile:filePath]) {
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


- (BOOL)_removeQueueFolder
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

// must be in @synchronized(self.entryList)
- (void)_removeEntry:(LKQueueEntryOperator*)entry
{
    // remove entry
    [entry clean];
    [self.entryList removeObject:entry];

    // remove tag
    if (entry.tagId) {
        NSMutableSet* set = [NSMutableSet set];
        for (LKQueueEntryOperator* e in self.entryList) {
            if (e.tagId) {
                [set addObject:e.tagId];
            }
        }
        if (![set containsObject:entry.tagId]) {
            [self.tags removeObjectForKey:entry.tagId];
        }
    }
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Initialization and deallocation
//------------------------------------------------------------------------------

- (id)initWithId:(NSString*)queueId basePath:(NSString*)basePath
{
    self = [super init];
    if (self) {
        self.queueId = queueId;
        self.path = [basePath stringByAppendingPathComponent:queueId];
        
        [self _createDirectoryWithPath:self.path];
        
        NSFileManager* fileManager = [NSFileManager defaultManager];

        // [1] queue
        NSString* queueFilePath = [self _queueFilePath];
        if ([fileManager fileExistsAtPath:queueFilePath]) {
            self.entryList = [NSKeyedUnarchiver unarchiveObjectWithFile:queueFilePath];
            if (self.entryList == nil) {
                NSLog(@"%s|[ERROR] Failed to restore the queue file: %@",
                      __PRETTY_FUNCTION__, queueFilePath);
                return NO;
            }
            // resuming (processing -> suspending)
            for (LKQueueEntryOperator* entry in self.entryList) {
                entry.queue = self;
                if (entry.state == LKQueueEntryStateProcessing) {
                    [entry suspend];
                }
            }

        } else {
            // new queue
            self.entryList = [NSMutableArray array];
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


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API
//------------------------------------------------------------------------------

- (LKQueueEntry*)addEntryWithInfo:(id <NSCoding>)info tagName:(NSString*)tagName
{
    return [self addEntryWithInfo:info tagName:tagName suspending:NO];
}

- (LKQueueEntry*)addEntryWithInfo:(id <NSCoding>)info tagName:(NSString*)tagName suspending:(BOOL)suspending
{
    NSString* tagId = [self _addTagName:tagName];
    LKQueueEntryOperator* entry =
    [LKQueueEntryOperator queueEntryWithQueue:self
                                         info:info
                                        tagId:tagId];
    
    if (suspending) {
        [entry suspend];
    }
    @synchronized (self.entryList) {
        [self.entryList addObject:entry];
        [self _saveList];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:LKQueueDidAddEntryNotification
                                                        object:self];

    return entry;
    
}

- (LKQueueEntry*)getEntryForProcessing
{
    @synchronized (self.entryList) {
        for (LKQueueEntryOperator* entry in self.entryList) {
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

- (BOOL)changeEntry:(LKQueueEntry*)entry toState:(LKQueueEntryState)state
{
    BOOL result = NO;

    @synchronized (self.entryList) {
        if ([self.entryList containsObject:entry]) {
            switch (state) {
                case LKQueueEntryStateWating:
                    result = [(LKQueueEntryOperator*)entry wait];
                    break;
                    
                case LKQueueEntryStateProcessing:
                    result = [(LKQueueEntryOperator*)entry process];    //TODO: test
                    break;
                    
                case LKQueueEntryStateFinished:
                    result = [(LKQueueEntryOperator*)entry finish];
                    break;

                case LKQueueEntryStateSuspending:
                    result = [(LKQueueEntryOperator*)entry suspend];
                    break;

                default:
                    break;
            }
            if (result) {
                [self _saveList];
            }
        }
    }
    return result;
}

- (BOOL)removeEntry:(LKQueueEntry*)entry
{
    @synchronized (self.entryList) {
        if ([self.entryList containsObject:entry]) {
            if (entry.canRemove) {
                [self _removeEntry:(LKQueueEntryOperator*)entry];
                [self _saveList];
                [self _saveTags];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:LKQueueDidRemoveEntryNotification
                                                                    object:self];
                return YES;
            } else {
                return NO;
            }
        }
    }
    return NO;    
}


- (void)removeFinishedEntries
{
    @synchronized (self.entryList) {
        BOOL updated = NO;
        for (LKQueueEntryOperator* entry in [self.entryList copy]) {
            if (entry.state == LKQueueEntryStateFinished) {
                [self _removeEntry:entry];
                updated = YES;
            }
        }
        if (updated) {
            [self _saveList];
            [self _saveTags];
            [[NSNotificationCenter defaultCenter] postNotificationName:LKQueueDidRemoveEntryNotification
                                                                object:self];
        }
    }
}

- (void)removeAllEntries
{
    @synchronized (self.entryList) {
        [self.entryList removeAllObjects];
        [self.tags removeAllObjects];
        [self _removeQueueFolder];
        [self _createDirectoryWithPath:self.path];
        [self _saveList];
        [self _saveTags];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:LKQueueDidRemoveEntryNotification
                                                        object:self];

}

- (BOOL)saveInfoForEntry:(LKQueueEntry*)entry
{
    return [(LKQueueEntryOperator*)entry save];
}

- (NSUInteger)resumeAllEntries
{
    NSUInteger count = 0;

    for (LKQueueEntryOperator* entry in self.entryList) {
        if (entry.state == LKQueueEntryStateSuspending && !entry.processingFailed) {
            [(LKQueueEntryOperator*)entry wait];
            count++;
        }
    }
    [self _saveList];
    return count;
}

#pragma mark -
#pragma mark API (Accessing entryies)

- (NSUInteger)count
{
    return [self.entryList count];
}


- (NSUInteger)countOfNotFinished
{
    NSUInteger count = 0;
    for (LKQueueEntryOperator* entry in self.entryList) {
        if (!entry.hasFinished) {
            count++;
        }
    }
    return count;    
}

- (NSUInteger)countOfState:(LKQueueEntryState)state
{
    NSUInteger count = 0;
    for (LKQueueEntryOperator* entry in self.entryList) {
        if (entry.state == state) {
            count++;
        }
    }
    return count;
}

- (LKQueueEntry*)entryAtIndex:(NSInteger)index
{
    if (index < 0 || [self.entryList count] <= index) {
        return nil;
    }
    
    @synchronized (self.entryList) {
        return [self.entryList objectAtIndex:index];
    }
}

- (LKQueueEntry*)entryForId:(NSString*)entryId
{
    @synchronized (self.entryList) {
        for (LKQueueEntryOperator* entry in self.entryList) {
            if ([entry.entryId isEqualToString:entryId]) {
                return entry;
            }
        }
        return nil;
    }
}

- (NSArray*)entries
{
    @synchronized (self.entryList) {
        NSArray* entries = [self.entryList copy];
        return entries;
    }
}


#pragma mark -
#pragma mark API (Accessing entryies with tag)

- (NSUInteger)countForTagName:(NSString*)tagName
{
    if (![self hasExistTagName:tagName]) {
        return 0;
    }

    NSUInteger count = 0;
    NSString* tagId = [self _tagIdForName:tagName];

    for (LKQueueEntryOperator* entry in self.entryList) {
        if ([entry.tagId isEqualToString:tagId]) {
            count++;
        }
    }
    return count;
}

- (NSUInteger)countOfNotFinishedForTagName:(NSString*)tagName
{
    if (![self hasExistTagName:tagName]) {
        return 0;
    }
    
    NSUInteger count = 0;
    NSString* tagId = [self _tagIdForName:tagName];

    for (LKQueueEntryOperator* entry in self.entryList) {
        if ([entry.tagId isEqualToString:tagId] && !entry.hasFinished) {
            count++;
        }
    }
    return count;
}

- (NSUInteger)countOfState:(LKQueueEntryState)state forTagName:(NSString*)tagName
{
    if (![self hasExistTagName:tagName]) {
        return 0;
    }
    
    NSUInteger count = 0;
    NSString* tagId = [self _tagIdForName:tagName];
    
    for (LKQueueEntryOperator* entry in self.entryList) {
        if ([entry.tagId isEqualToString:tagId] && entry.state == state) {
            count++;
        }
    }
    return count;    
}

- (NSArray*)entriesForTagName:(NSString*)tagName
{
    NSMutableArray* result = [NSMutableArray array];
    if (![self hasExistTagName:tagName]) {
        return result;
    }
    
    NSString* tagId = [self _tagIdForName:tagName];
    
    for (LKQueueEntryOperator* entry in self.entryList) {
        if ([tagId isEqualToString:entry.tagId]) {
            [result addObject:entry];
        }
    }
    return result;
}



#pragma mark -
#pragma mark API (Tag management)

- (BOOL)hasExistTagName:(NSString*)tagName
{
    NSString* tagId = [self _tagIdForName:tagName];
    return ([self.tags objectForKey:tagId] != nil);
}

- (NSArray*)tagNames
{
    return [[self.tags allValues] sortedArrayUsingComparator:^(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
}



#pragma mark -
#pragma mark API (Cooperate with other queues)

- (BOOL)addEntry:(LKQueueEntry*)entry
{
    if (entry == nil || [self.entryList containsObject:entry]) {
        return NO;
    }

    LKQueueEntryOperator* newEntry =
        [LKQueueEntryOperator queueEntryWithQueue:self
                                             info:entry.info
                                            tagId:((LKQueueEntryOperator*)entry).tagId];

    @synchronized (self.entryList) {
        [self.entryList addObject:newEntry];
        [self _saveList];
        [self _saveTags];
    }
    return YES;
}


@end
