//  RootViewController.h

#import <UIKit/UIKit.h>

@class LKQueue;
@interface RootViewController : UITableViewController {

}

@property (nonatomic, strong) LKQueue* queue;

- (IBAction)addEntry:(id)sender;

@end
