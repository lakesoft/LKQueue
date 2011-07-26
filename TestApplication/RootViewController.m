// RootViewController

#import "RootViewController.h"
#import "LKQueue.h"

@implementation RootViewController

@synthesize queue;

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIBarButtonItem* cleaunpButton =
    [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                   target:self 
                                                   action:@selector(cleanupEntries:)] autorelease];
    self.navigationItem.leftBarButtonItem = cleaunpButton;

    UIBarButtonItem* addButton =
    [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                   target:self 
                                                   action:@selector(addEntry:)] autorelease];
    self.navigationItem.rightBarButtonItem = addButton;

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

/*
 // Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations.
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
 */

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.queue count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:CellIdentifier] autorelease];
    }

    // Configure the cell.
    LKQueueEntry* entry = [self.queue
                           entryAtIndex:[self.queue count] - indexPath.row -1];
    
    cell.textLabel.text = [entry.info objectForKey:@"title"];

    switch (entry.state) {
        case LKQueueEntryStateWating:
            cell.detailTextLabel.text = @"Wating";
            break;
        case LKQueueEntryStateProcessing:
            cell.detailTextLabel.text = @"Processing";
            break;
        case LKQueueEntryStateFinished:
            if (entry.result == LKQueueEntryResultSuccessful) {
                cell.detailTextLabel.text = @"Finished";
            } else {
                cell.detailTextLabel.text = @"Failed";
            }
            break;
        case LKQueueEntryStateInterrupting:
            cell.detailTextLabel.text = @"Interrupting";
            break;
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // Delete the row from the data source.
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert)
    {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    /*
    <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
    // ...
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:detailViewController animated:YES];
    [detailViewController release];
	*/
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}

- (void)dealloc
{
    [super dealloc];
}

- (IBAction)cleanupEntries:(id)sender
{
    [self.queue removeFinishedEntry];
    [self.tableView reloadData];
}

- (IBAction)addEntry:(id)sender
{
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                             [[NSDate date] description], @"title", nil];
    [self.queue addEntryWithInfo:info resources:nil tagName:nil];
    [self.tableView reloadData];
}

@end
