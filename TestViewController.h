//
//  TestViewController.h
//  iTerm
//
//  Created by Richard Markiewicz on 2014-12-10.
//
//

#import <Cocoa/Cocoa.h>

#import "PTYSession.h"
#import "PTYTab.h"
#import "WindowControllerInterface.h"
#import "Autocomplete.h"
#import "PasteboardHistory.h"

@interface TestViewController : NSViewController<WindowControllerInterface>
{
    PTYSession *session;
    PTYTab *tab;
    NSViewController *parentViewController;
    NSWindow *window;
    AutocompleteView* autocompleteView;
    PasteboardHistoryWindowController* pbHistoryView;
    int nextSessionRows_;
    int nextSessionColumns_;
}

@property (nonatomic, retain) PTYSession *session;
@property (nonatomic, retain) PTYTab *tab;
@property (nonatomic, retain) NSWindow *window;

- (id)initWithParent:(NSViewController *)controller andWindow:(NSWindow *)mainWindow;

@end
