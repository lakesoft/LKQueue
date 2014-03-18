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

// Directory
//
// (basePath) ...default: ~/Caches/_LKQueue_/
//   |
//   |-- "queue name1"/
//   |-- "queue name2"/
//   |-- "queue name3"/
//

#import <CommonCrypto/CommonDigest.h>
#import "LKQueueManager.h"
#import "LKQueue.h"

#define LK_QUEUE_DEFAULT_PATH       @"_LKQueue_"
#define LK_QUEUE_LIST_FILENAME      @"QueueList.plist"

@interface LKQueueManager()
@property (nonatomic, copy  ) NSString* path;
@property (nonatomic, strong) NSMutableDictionary* queueList;   // queueId  => queueName (persistent)
@property (nonatomic, strong) NSMutableDictionary* queueCache;  // queueId  => LKQueue   (volatile)
@end


@implementation LKQueueManager

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

- (NSString*)_queueListFilePath
{
    return [self.path stringByAppendingPathComponent:LK_QUEUE_LIST_FILENAME];
}

- (BOOL)_restoreQueueList
{
    self.queueList = nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* filePath = [self _queueListFilePath];
    if ([fileManager fileExistsAtPath:filePath]) {
        self.queueList = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
    }
    return self.queueList ? YES : NO;
}

- (BOOL)_saveQueueList
{
    NSString* filePath = [self _queueListFilePath];
    if ([self.queueList writeToFile:filePath atomically:YES]) {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSError* error = nil;
        NSDictionary* attributes =
        [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
        [fileManager setAttributes:attributes ofItemAtPath:filePath error:&error];
    } else {
        NSLog(@"%s|[ERROR]Failed to save the queue file: %@",
              __PRETTY_FUNCTION__, filePath);
        return NO;
    }
    return YES;
}

- (NSString*)_queueIdWithName:(NSString*)queueName
{
    NSString* queueId = _md5String(queueName);
    return queueId;   
}

- (BOOL)_createLKQueueDirectory
{
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

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Basics
//------------------------------------------------------------------------------
- (id)initWithPath:(NSString*)path
{
    if (path == nil) {
        NSLog(@"[ERROR] path must be not-nil");
        return nil;
    }

    self = [super init];
    if (self) {
        self.path = path;
        [self _createLKQueueDirectory];
        if (![self _restoreQueueList]) {
            // new
            self.queueList = [NSMutableDictionary dictionary];
            [self _saveQueueList];
        }
        self.queueCache = [NSMutableDictionary dictionary];
    }
    return self;
}


+ (instancetype)defaultManager
{
    static LKQueueManager* _sharedManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedManager = [[LKQueueManager alloc] initWithPath:[self defaultPath]];
    });
    return _sharedManager;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API (Queue management)
//------------------------------------------------------------------------------
- (LKQueue*)queueWithName:(NSString*)queueName
{
    NSString* queueId = [self _queueIdWithName:queueName];
    
    @synchronized (self) {
        if (![self.queueList objectForKey:queueId]) {
            // [new] setup queueList
            [self.queueList setObject:queueName forKey:queueId];
            [self _saveQueueList];
        }

        // setup queueCache
        LKQueue* queue = [self.queueCache objectForKey:queueId];
        if (queue == nil) {
            queue = [[LKQueue alloc] initWithId:queueId
                                        basePath:self.path];
            [self.queueCache setObject:queue forKey:queueId];
        }
        return queue;
    }
}

- (void)releaseCacheWithQueue:(LKQueue*)queue
{
    @synchronized (self.queueCache) {
        [self.queueCache removeObjectForKey:queue.queueId];
    }
}

- (BOOL)removeQueue:(LKQueue*)queue
{
    @synchronized (self) {
        [self.queueCache removeObjectForKey:queue.queueId];

        [self.queueList removeObjectForKey:queue.queueId];
        [self _saveQueueList];

        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSError* error = nil;
        if ([fileManager removeItemAtPath:queue.path error:&error]) {
            return YES;
        } else {
            NSLog(@"%s|[ERROR] Failed to remove the directory|%@",
                  __PRETTY_FUNCTION__, error);
            return NO;
        }
    }
}

- (BOOL)removeAllQueues
{
    @synchronized (self) {
        [self.queueCache removeAllObjects];
        [self.queueList removeAllObjects];
        
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSError* error = nil;
        if ([fileManager removeItemAtPath:self.path error:&error]) {
            [self _createLKQueueDirectory];
            [self _saveQueueList];
            return YES;
        } else {
            NSLog(@"%s|[ERROR] Failed to remove the directory|%@",
                  __PRETTY_FUNCTION__, error);
            return NO;
        }
    }    
}


//------------------------------------------------------------------------------
#pragma mark -
#pragma mark API (Inspection)
//------------------------------------------------------------------------------
- (NSDictionary*)queues
{
    @synchronized (self.queueList) {
        return [NSDictionary dictionaryWithDictionary:self.queueList];
    }
}

+ (NSString*)defaultPath
{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                 NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:LK_QUEUE_DEFAULT_PATH];
}


@end

