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

// -------------
// state diagram
// -------------
//
//                                                finish
//           +-----------+ process +------------+  /fail +-----------+ clear
// [start]-->|   wating  |-------->| processing |------->| finished  |------>[x]
//           |           |<--------|            |   +--->|           |
//           +-----------+ wait    +------------+   |    +-----------+
//              |                         |         |
//              |                         |interrupt|
//              | wait +------------+     |         |
//              +<-----|interrupting|<----+         |
//                     |            |---------------+
//                     +------------+     finish/fail
//
//

#import <Foundation/Foundation.h>
#import "LKQueueEntry.h"

@class LKQueueEntry;
@interface LKQueue : NSObject {
 
    NSString* queueId_;
    NSString* name_;
    NSMutableArray* list_;      // <LKQueueEntryOperator>
    
    NSString* path_;
}
@property (nonatomic, retain, readonly) NSString* queueId;
@property (nonatomic, copy  , readonly) NSString* name;
@property (nonatomic, retain, readonly) NSString* path;

// API
+ (LKQueue*)queueWithName:(NSString*)name;
+ (void)releaseQueueWithName:(NSString*)name;

- (LKQueueEntry*)addEntryWithInfo:(NSDictionary*)info resources:(NSArray*)resources;
- (LKQueueEntry*)getEntryForProcessing;

- (BOOL)finishEntry:(LKQueueEntry*)entry;
- (BOOL)failEntry:(LKQueueEntry*)entry;
- (BOOL)waitEntry:(LKQueueEntry*)entry;
- (BOOL)interruptEntry:(LKQueueEntry*)entry;

- (void)clearFinishedEntry; 
- (void)removeAllEntries;

- (NSUInteger)count;
- (NSUInteger)countOfWating;
- (NSArray*)queueList;

+ (NSString*)pathForQueueId:(NSString*)queueId;

@end
