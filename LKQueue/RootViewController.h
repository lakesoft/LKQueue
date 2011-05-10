//
//  RootViewController.h
//  FBQueue
//
//  Created by Hiroshi Hashiguchi on 11/04/12.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FBQueue;
@interface RootViewController : UITableViewController {

}

@property (nonatomic, retain) FBQueue* queue;

- (IBAction)addEntry:(id)sender;

@end
