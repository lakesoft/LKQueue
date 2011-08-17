// LKQueueAppDelegate

#import "LKQueueAppDelegate.h"
#import "RootViewController.h"
#import "LKQueue.h"
#import "LKQueueManager.h"

#define QUEUE_NAME  @"Queue"


@implementation LKQueueAppDelegate


@synthesize window=_window;

@synthesize navigationController=_navigationController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    // Add the navigation controller's view to the window and display.
    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];
    
    LKQueue* queue = [[LKQueueManager defaultManager] queueWithName:QUEUE_NAME];
    RootViewController* rootViewController = (RootViewController*)self.navigationController.topViewController;
    rootViewController.queue = queue;

    dispatch_queue_t d_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t d_group = dispatch_group_create();
    
    for (int i=0; i < 3; i++) {
        dispatch_group_async(d_group, d_queue, ^{
        
            while (1) {
                LKQueueEntry* entry = [queue getEntryForProcessing];

                if (entry) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [rootViewController.tableView reloadData];
                    });
                    
                    [NSThread sleepForTimeInterval:2.0];
                    [queue finishEntry:entry];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [rootViewController.tableView reloadData];
                    });
                }
                [NSThread sleepForTimeInterval:1.0];
            }
        });
    }
    
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    [[[LKQueueManager defaultManager] queueWithName:QUEUE_NAME] removeFinishedEntries];
}

- (void)dealloc
{
    [_window release];
    [_navigationController release];
    [super dealloc];
}

@end
