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


// API (Queue management)
+ (LKQueue*)queueWithName:(NSString*)name;
+ (void)releaseQueueWithName:(NSString*)name;
+ (BOOL)hasExistedQueueWithName:(NSString*)name;
+ (BOOL)removeQueueWithName:(NSString*)name;


// API (Basics)
- (LKQueueEntry*)addEntryWithInfo:(NSDictionary*)info resources:(NSArray*)resources tagName:(NSString*)tagName;
- (LKQueueEntry*)getEntryForProcessing;


// API (Entry operations)
- (BOOL)finishEntry:(LKQueueEntry*)entry;
- (BOOL)failEntry:(LKQueueEntry*)entry;
- (BOOL)waitEntry:(LKQueueEntry*)entry;
- (BOOL)interruptEntry:(LKQueueEntry*)entry;
- (BOOL)removeEntry:(LKQueueEntry*)entry;           // NOTE: can't remove a entry while processing
- (void)removeFinishedEntry; 
- (void)removeAllEntries;


// API (Accessing entryies)
- (NSUInteger)count;
- (NSUInteger)countOfEntryState:(LKQueueEntryState)state;
- (NSUInteger)countForTagName:(NSString*)tagName;
- (LKQueueEntry*)entryAtIndex:(NSInteger)index;
- (NSArray*)entries;                                // NOTE: the return values are snapshots
- (NSArray*)entriesForTagName:(NSString*)tagName;   // NOTE: the return values are snapshots


// API (Tag)
- (NSArray*)tagNames;


// API (Cooperate with other queues)
- (BOOL)addEntry:(LKQueueEntry*)entry;


// API (etc)
+ (NSString*)queueIdForName:(NSString*)name;
+ (NSString*)pathForQueueId:(NSString*)queueId;

@end
