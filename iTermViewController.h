//
//  iTermViewController.h
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

typedef enum {
    SessionStatusConnected = 0,
    SessionStatusDisconnected = 1
} SessionStatus;

@interface iTermViewController : NSViewController<WindowControllerInterface, PasteboardHistoryWindowControllerDelegate>
{
    PTYSession *session;
    PTYTab *tab;
    AutocompleteView* autocompleteView;
    PasteboardHistoryWindowController* pbHistoryView;
    int nextSessionRows_;
    int nextSessionColumns_;
}

extern NSString *const ConnectionStatus_Connected;
extern NSString *const ConnectionStatus_Disconnected;

@property (nonatomic, retain) PTYSession *session;
@property (nonatomic, retain) PTYTab *tab;
@property (nonatomic, readonly) NSWindow *window;
@property (nonatomic, readonly) NSView *nativeView;

- (id)initWithOwner:(NSObject *)owner andSettings:(NSDictionary *)settings;
- (void)connectWithOptions:(NSDictionary *)options;

@end
