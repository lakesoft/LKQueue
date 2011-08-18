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

#import <Foundation/Foundation.h>

// ** Do not change order **
typedef enum {
    LKQueueEntryStateWating = 0,
    LKQueueEntryStateProcessing,
    LKQueueEntryStateSuspending,
    LKQueueEntryStateFinished,
} LKQueueEntryState;

@class LKQueueEntryLog;

@interface LKQueueEntry : NSObject

// persistent properties
@property (nonatomic, retain, readonly) NSString* entryId;
@property (nonatomic, retain, readonly) id <NSCoding> info;
@property (nonatomic, assign, readonly) LKQueueEntryState state;
@property (nonatomic, retain, readonly) NSDate* created;
@property (nonatomic, retain, readonly) NSDate* modified;
@property (nonatomic, retain, readonly) NSArray* logs;

@property (nonatomic, retain) id context;   // volatile (not persistent)

// status
@property (nonatomic, assign, readonly) BOOL canRemove;
@property (nonatomic, assign, readonly) BOOL hasFinished;

// API (log)
- (void)addQueueEntryLog:(LKQueueEntryLog*)queueEntyLog;

@end
