//  RootViewController.h

#import <UIKit/UIKit.h>

@class LKQueue;
@interface RootViewController : UITableViewController {

}

@property (nonatomic, retain) LKQueue* queue;

- (IBAction)addEntry:(id)sender;

@end
