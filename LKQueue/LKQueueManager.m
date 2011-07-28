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
#import "LKQueueManager.h"
#import "LKQueue.h"

#define LK_QUEUE_PATH               @"__LKQueue__"
#define LK_QUEUE_LIST_FILENAME      @"QueueList.plist"

@interface LKQueueManager()
@property (nonatomic, retain) NSMutableDictionary* queueList;   // queueId  => queueName (persistent)
@property (nonatomic, retain) NSMutableDictionary* queueCache;  // queueId  => LKQueue   (volatile)
@end


@implementation LKQueueManager

@synthesize queueList = queueList_;
@synthesize queueCache = queueCache_;

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Private
//------------------------------------------------------------------------------

static NSString* _md5String(NSString* string)
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

- (NSString*)_queueListFilePath
{
    return [[self path] stringByAppendingPathComponent:LK_QUEUE_LIST_FILENAME];
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
    NSString* path = [self path];
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

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Basics
//------------------------------------------------------------------------------

- (id)init
{
    self = [super init];
    if (self) {
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

- (void)dealloc {
    self.queueList = nil;
    self.queueCache = nil;
    [super dealloc];
}

+ (LKQueueManager*)sharedManager
{
    static LKQueueManager* sharedManager_ = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedManager_ = [[LKQueueManager alloc] init];
        NSLog(@"%@", [sharedManager_ path]);
    });
    return sharedManager_;
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
            queue = [[[LKQueue alloc] initWithId:queueId
                                        basePath:[self path]] autorelease];
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
        if ([fileManager removeItemAtPath:[self path] error:&error]) {
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

- (NSString*)path
{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                 NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:LK_QUEUE_PATH];
}


@end

