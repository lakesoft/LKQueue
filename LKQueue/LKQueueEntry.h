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
    LKQueueStateWating = 0,
    LKQueueStateProcessing,
    LKQueueStateInterrupting,
    LKQueueStateFinished,
} LKQueueState;

// ** Do not change order **
typedef enum {
    LKQueueResultUnfinished = 0,
    LKQueueResultSuccessful,
    LKQueueResultFailed,
    LKQueueResultInterrpted
} LKQueueResult;


@class LKQueueEntryLog;

@interface LKQueueEntry : NSObject {
    
    NSDictionary* info_;
    NSArray* resources_;

    LKQueueState state_;
    LKQueueResult result_;

    NSDate* created_;
    NSDate* modified_;

    id context_;
    
    NSMutableArray* logs_;
}

// persistent properties
@property (nonatomic, copy, readonly) NSDictionary* info;
@property (nonatomic, copy, readonly) NSArray* resources;
@property (nonatomic, assign, readonly) LKQueueState state;
@property (nonatomic, assign, readonly) LKQueueResult result;
@property (nonatomic, retain, readonly) NSDate* created;
@property (nonatomic, retain, readonly) NSDate* modified;
@property (nonatomic, retain, readonly) NSArray* logs;

// status
@property (nonatomic, assign, readonly) BOOL canRemove;

// API
- (void)addQueueEntryLog:(LKQueueEntryLog*)queueEntyLog;

@end
