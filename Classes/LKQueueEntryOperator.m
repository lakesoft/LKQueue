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

#import "LKQueueEntryOperator.h"
#import "LKQueue.h"
#import "LKQueueManager.h"

// for archive
#define LK_QUEUE_ENTRY_KEY_QUEUE_ID     @"qid"
#define LK_QUEUE_ENTRY_KEY_ENTRY_ID     @"eid"
#define LK_QUEUE_ENTRY_KEY_TAG_ID       @"tid"
#define LK_QUEUE_ENTRY_KEY_STATE        @"sta"
#define LK_QUEUE_ENTRY_PROCESSING_FAILED   @"pfl"

// for meta
#define LK_QUEUE_ENTRY_META_INFO      @"__info__"
#define LK_QUEUE_ENTRY_META_CREATED   @"__created__"
#define LK_QUEUE_ENTRY_META_MODIFIED  @"__modified__"

@implementation LKQueueEntryOperator
@synthesize info = info_;
@synthesize state = state_;
@synthesize created = created_;
@synthesize modified = modified_;
@synthesize logs = logs_;

@synthesize queue = queue_;
@synthesize entryId = entryId_;
@synthesize tagId = tagId_;

@synthesize persistentDictionary = persistentDictionary_;

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Private
//------------------------------------------------------------------------------

- (NSString*)_filePathForExtension:(NSString*)extension
{
    return [[self.queue.path
             stringByAppendingPathComponent:self.entryId]
            stringByAppendingPathExtension:extension];    
}

// <queueId>/<entryId>.meta
- (NSString*)_infoFilePath
{
    return [self _filePathForExtension:@"info"];
}

// <queueId>/<entryId>.data
- (NSString*)_resourcesFilePath
{
    return [self _filePathForExtension:@"resources"];
}

- (NSString*)_logsFilePath
{
    return [self _filePathForExtension:@"logs"];
}

- (BOOL)_setProtectionKeyWithFilePath:(NSString*)filePath
{
    NSDictionary* attributes =
    [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
    NSError* error = nil;
    if (![[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:filePath error:&error]) {
        NSLog(@"%s|[ERROR] Faild to set NSFileProtectionKey: %@",
              __PRETTY_FUNCTION__, error);
        return NO;
    }
    return YES;
}

- (BOOL)save
{
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:self.created  forKey:LK_QUEUE_ENTRY_META_CREATED];
    [dictionary setObject:self.modified forKey:LK_QUEUE_ENTRY_META_MODIFIED];
    [dictionary setObject:self.info     forKey:LK_QUEUE_ENTRY_META_INFO];
    self.persistentDictionary = dictionary;

    if ([NSKeyedArchiver archiveRootObject:self.persistentDictionary
                                    toFile:[self _infoFilePath]]) {        
        [self _setProtectionKeyWithFilePath:[self _infoFilePath]];
        return YES;
    } else {
        NSLog(@"%s|[ERROR] Faild to write a meta to file: %@",
              __PRETTY_FUNCTION__, [self _infoFilePath]);
        return NO;
    }
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Initialization and deallocation
//------------------------------------------------------------------------------
- (id)initWithQueue:(LKQueue*)queue info:(id <NSCoding>)info tagId:(NSString*)tagId
{
    self = [super init];
    if (self) {
        self.queue = queue;
        self.tagId = tagId;

        CFUUIDRef uuidObj = CFUUIDCreate(nil);
        NSString* str = (NSString*)CFUUIDCreateString(nil, uuidObj);
        self.entryId = str;
        [str release];
        CFRelease(uuidObj);

        self.state = LKQueueEntryStateWating;      

        // write info
        self.created = [NSDate date];
        self.modified = self.created;
        self.info = info;
        if (![self save]) {
            return nil;
        }

        // init (clear)
        self.created = nil;
        self.modified = nil;
        self.info = nil;
        self.persistentDictionary = nil;
        self.logs = nil;
    }
    return self;
}

- (void)dealloc {
    self.entryId = nil;
    self.info = nil;
    self.created = nil;
    self.modified = nil;
    self.logs = nil;

    self.tagId = nil;
    [super dealloc];
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API
//------------------------------------------------------------------------------
+ (LKQueueEntryOperator*)queueEntryWithQueue:(LKQueue*)queue info:(id <NSCoding>)info tagId:(NSString*)tagId
{
    return [[[self alloc] initWithQueue:queue info:info tagId:tagId] autorelease];
}

- (void)_updateModified
{
    self.modified = [NSDate date];
    [self save];
}

- (BOOL)finish
{
    if (state_ == LKQueueEntryStateWating ||
        state_ == LKQueueEntryStateProcessing ||
        state_ == LKQueueEntryStateSuspending) {
        state_ = LKQueueEntryStateFinished;
        [self _updateModified];
        return YES;
    }
    return NO;

}

- (BOOL)wait
{
    if (state_ == LKQueueEntryStateSuspending) {
        state_ = LKQueueEntryStateWating;
        [self _updateModified];
        return YES;
    }
    return NO;
}

- (BOOL)process
{
    if (state_ == LKQueueEntryStateWating) {
        state_ = LKQueueEntryStateProcessing;
        [self _updateModified];
        return YES;
    }
    return NO;
}

- (BOOL)suspend
{
    if (state_ == LKQueueEntryStateWating ||
        state_ == LKQueueEntryStateProcessing) {
        state_ = LKQueueEntryStateSuspending;
        [self _updateModified];
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
    
    NSString* logsFilePath = [self _logsFilePath];
    if ([fileManager fileExistsAtPath:logsFilePath]) {
        NSError* error =nil;
        if (![fileManager removeItemAtPath:logsFilePath error:&error]) {
            NSLog(@"%s|Failed to remove log file '%@':%@",
                  __PRETTY_FUNCTION__, logsFilePath, error);
            return NO;
        }
    }

    return YES;

}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API (overwritten)
//------------------------------------------------------------------------------
- (void)addLog:(id <NSCoding>)log
{
    NSArray* array = [self.logs arrayByAddingObject:log];
    [logs_ release];
    logs_ = [array retain];
    
    if ([NSKeyedArchiver archiveRootObject:logs_ toFile:[self _logsFilePath]]) {
        [self _setProtectionKeyWithFilePath:[self _logsFilePath]];
    } else {
        NSLog(@"%s|[ERROR] Faild to write a logs to file: %@",
              __PRETTY_FUNCTION__, [self _logsFilePath]);
    }
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark NSCording
//------------------------------------------------------------------------------

- (void)encodeWithCoder:(NSCoder*)coder
{
	[coder encodeObject:self.queue.queueId  forKey:LK_QUEUE_ENTRY_KEY_QUEUE_ID];
	[coder encodeInt:self.state             forKey:LK_QUEUE_ENTRY_KEY_STATE];
	[coder encodeObject:self.entryId        forKey:LK_QUEUE_ENTRY_KEY_ENTRY_ID];
	[coder encodeObject:self.tagId          forKey:LK_QUEUE_ENTRY_KEY_TAG_ID];
    [coder encodeBool:self.processingFailed forKey:LK_QUEUE_ENTRY_PROCESSING_FAILED];
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
        state_          = [coder decodeIntForKey:LK_QUEUE_ENTRY_KEY_STATE];
        self.entryId    = [coder decodeObjectForKey:LK_QUEUE_ENTRY_KEY_ENTRY_ID];
        self.tagId      = [coder decodeObjectForKey:LK_QUEUE_ENTRY_KEY_TAG_ID];
        self.processingFailed = [coder decodeBoolForKey:LK_QUEUE_ENTRY_PROCESSING_FAILED];
        
        // self.queue will be set in LKQueue class
    }
    return self;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Properties
//------------------------------------------------------------------------------
- (NSDictionary*)persistentDictionary
{
    if (persistentDictionary_ == nil) {
        self.persistentDictionary = [NSKeyedUnarchiver
                                 unarchiveObjectWithFile:[self _infoFilePath]];
    }
    return persistentDictionary_;
}

- (id <NSCoding>)info
{
    if (info_ == nil) {
        info_ = [[self.persistentDictionary objectForKey:LK_QUEUE_ENTRY_META_INFO] retain];
    }
    return info_;
}

- (NSDate*)created
{
    if (created_ == nil) {
        created_ = [[self.persistentDictionary objectForKey:LK_QUEUE_ENTRY_META_CREATED] retain];
    }
    return created_;
}

- (NSDate*)modified
{
    if (modified_ == nil) {
        modified_ = [[self.persistentDictionary objectForKey:LK_QUEUE_ENTRY_META_MODIFIED] retain];
    }
    return modified_;
}

- (NSArray*)logs
{
    if (logs_ == nil) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[self _logsFilePath]]) {
            self.logs = [NSKeyedUnarchiver
                          unarchiveObjectWithFile:[self _logsFilePath]];
        }
    }
    if (logs_ == nil) {
        logs_ = [[NSArray alloc] init];
    }
    return logs_;
}

- (BOOL)canRemove
{
    return (self.state != LKQueueEntryStateProcessing);
}

- (BOOL)hasFinished
{
    return (self.state == LKQueueEntryStateFinished);
}

@end

