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

#import "LKQueueEntryLog.h"

@interface LKQueueEntryLog()
@property (nonatomic, retain) NSDate* date;
@property (nonatomic, assign) LKQueueEntryLogType type;
@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* detail;
@end

@implementation LKQueueEntryLog
@synthesize date = date_;
@synthesize type = type_;
@synthesize title = title_;
@synthesize detail = detail_;

- (id)initWithType:(LKQueueEntryLogType)type title:(NSString*)title detail:(NSString*)detail {
    self = [super init];
    if (self) {
        self.date = [NSDate date];
        self.type = type;
        self.title = title;
        self.detail = detail;
    }
    return self;
}

+ (LKQueueEntryLog*)queueEntryLogWithType:(LKQueueEntryLogType)type title:(NSString*)title detail:(NSString*)detail;
{
    return [[[LKQueueEntryLog alloc] initWithType:type title:title detail:detail] autorelease];
}

- (NSString*)description
{
    NSString* typeString = nil;
    switch (self.type) {
        case LKQueueEntryLogTypeInformation:
            typeString = @"INFO";
            break;
            
        case LKQueueEntryLogTypeNotice:
            typeString = @"NOTICE";
            break;
            
        case LKQueueEntryLogTypeWarning:
            typeString = @"WARNING";
            break;
            
        case LKQueueEntryLogTypeError:
            typeString = @"ERROR";
            break;
    }
    return [NSString stringWithFormat:
            @"%@ [%@] %@\n%@",
            self.date, typeString, self.title, self.detail?self.detail:@""];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark NSCording
//------------------------------------------------------------------------------
// for archive
#define LK_QUEUE_ENTRY_LOG_KEY_DATE     @"date"
#define LK_QUEUE_ENTRY_LOG_KEY_TYPE     @"type"
#define LK_QUEUE_ENTRY_LOG_KEY_TITLE    @"title"
#define LK_QUEUE_ENTRY_LOG_KEY_DETAIL   @"detail"

- (void)encodeWithCoder:(NSCoder*)coder
{
	[coder encodeObject:self.date       forKey:LK_QUEUE_ENTRY_LOG_KEY_DATE];
	[coder encodeInt:self.type          forKey:LK_QUEUE_ENTRY_LOG_KEY_TYPE];
	[coder encodeObject:self.title      forKey:LK_QUEUE_ENTRY_LOG_KEY_TITLE];
	[coder encodeObject:self.detail     forKey:LK_QUEUE_ENTRY_LOG_KEY_DETAIL];
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super init];
    if (self) {
    	self.date   = [coder decodeObjectForKey:LK_QUEUE_ENTRY_LOG_KEY_DATE];
        self.type   = [coder decodeIntForKey:LK_QUEUE_ENTRY_LOG_KEY_TYPE];
        self.title  = [coder decodeObjectForKey:LK_QUEUE_ENTRY_LOG_KEY_TITLE];
        self.detail = [coder decodeObjectForKey:LK_QUEUE_ENTRY_LOG_KEY_DETAIL];

    }
    return self;
}

@end
