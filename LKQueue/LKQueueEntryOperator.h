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

//
// NOTE: Thread *not* safe
//

#import <Foundation/Foundation.h>
#import "LKQueueEntry.h"

@class LKQueue;
@interface LKQueueEntryOperator : LKQueueEntry <NSCoding> {

}
@property (nonatomic, copy) NSDictionary* info;
@property (nonatomic, copy) NSArray* resources;
@property (nonatomic, assign) LKQueueEntryState state;
@property (nonatomic, assign) LKQueueEntryResult result;
@property (nonatomic, retain) NSDate* created;
@property (nonatomic, retain) NSDate* modified;
@property (nonatomic, retain) NSArray* logs;

@property (nonatomic, assign) LKQueue* queue;
@property (nonatomic, retain) NSString* entryId;
@property (nonatomic, retain) NSString* tagId;

// API
+ (LKQueueEntryOperator*)queueEntryWithQueue:(LKQueue*)queue info:(NSDictionary*)info resources:(NSArray*)resources tagId:(NSString*)tagId;

- (BOOL)finish;
- (BOOL)fail;
- (BOOL)wait;
- (BOOL)process;
- (BOOL)interrupt;

- (BOOL)clean;  // remove persistant files


@end
