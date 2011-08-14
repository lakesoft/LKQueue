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

#import "LKQueueEntry.h"
#import "LKQueueEntryLog.h"

@implementation LKQueueEntry

@synthesize entryId = entryId_;
@synthesize info = info_;
@synthesize resources = resources_;
@synthesize state = state_;
@synthesize result = result_;
@synthesize created = created_;
@synthesize modified = modified_;
@synthesize logs = logs_;
@synthesize context = context_;

@synthesize canRemove;
@synthesize hasFinished;

- (void)dealloc {
    [super dealloc];
}

- (void)addQueueEntryLog:(LKQueueEntryLog*)queueEntyLog
{
    // do nothing (should be overwritten in subclass)
}


@end
