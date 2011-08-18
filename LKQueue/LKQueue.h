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
//                 +--------------------------------+
//                 |                                |
//                 |                                |
//           +-----------+         +------------+   +--->+-----------+ remove
// [start1]->|  waiting  |-------->| processing |------->| finished  |------>[x]
//           |           |         |            |   +--->|           |
//           +-----------+         +------------+   |    +-----------+
//              |  |                      |         |
//              |  |                      |         |
//              |  |   +------------+     |         |
//              |  +-->| suspending |<----+         |
//              +<-----|            |---------------+
// [start2]----------->+------------+
//
//

#import <Foundation/Foundation.h>
#import "LKQueueEntry.h"

@class LKQueueEntry;
@interface LKQueue : NSObject {
 
}
- (id)initWithId:(NSString*)queueId basePath:(NSString*)basePath;


// API (Properties)
@property (nonatomic, retain, readonly) NSString* queueId;
@property (nonatomic, retain, readonly) NSString* path;


// API (Basics)
- (LKQueueEntry*)addEntryWithInfo:(id <NSCoding>)info tagName:(NSString*)tagName;
- (LKQueueEntry*)addEntryWithInfo:(id <NSCoding>)info tagName:(NSString*)tagName suspending:(BOOL)suspending;
- (LKQueueEntry*)getEntryForProcessing;


// API (Entry operations)
- (BOOL)changeEntry:(LKQueueEntry*)entry toState:(LKQueueEntryState)state;
- (BOOL)removeEntry:(LKQueueEntry*)entry;           // NOTE: can't remove a entry while processing
- (void)removeAllEntries;
- (void)removeFinishedEntries; 
- (BOOL)saveInfoForEntry:(LKQueueEntry*)entry;


// API (Accessing entryies)
- (LKQueueEntry*)entryAtIndex:(NSInteger)index;
- (LKQueueEntry*)entryForId:(NSString*)entryId;
- (NSUInteger)count;
- (NSUInteger)countOfNotFinished;
- (NSUInteger)countOfState:(LKQueueEntryState)state;
- (NSArray*)entries;                                // NOTE: the return values are snapshots


// API (Accessing entryies with tag)
- (NSUInteger)countForTagName:(NSString*)tagName;
- (NSUInteger)countOfNotFinishedForTagName:(NSString*)tagName;
- (NSUInteger)countOfState:(LKQueueEntryState)state forTagName:(NSString*)tagName;
- (NSArray*)entriesForTagName:(NSString*)tagName;   // NOTE: the return values are snapshots


// API (Tag management)
- (BOOL)hasExistTagName:(NSString*)tagName;
- (NSArray*)tagNames;


// API (Cooperate with other queues)
- (BOOL)addEntry:(LKQueueEntry*)entry;


@end
