//
//  iTermViewController.m
//  iTerm
//
//  Created by Richard Markiewicz on 2014-12-10.
//
//

#import "iTermViewController.h"

#import "iTermController.h"
#import "PTYScrollView.h"
#import "SessionView.h"

#import "ITAddressBookMgr.h"

#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <pwd.h>

@interface iTermViewController()

@end

@implementation iTermViewController

@synthesize session;
@synthesize tab;

int number_;
id owner_;
NSDictionary *settings_;
NSDictionary *options_;

- (id)initWithOwner:(id)owner andSettings:(NSDictionary *)settings
{
    self = [super init];
    
    if(self)
    {
        autocompleteView = [[AutocompleteView alloc] init];
        
        number_ = [[iTermController sharedInstance] allocateWindowNumber];
        owner_ = owner;
        settings_ = [NSDictionary dictionaryWithDictionary:settings];
        
        return self;
    }
    
    return nil;
}

- (void)dealloc
{
    [autocompleteView shutdown];
    [pbHistoryView shutdown];
    [pbHistoryView release];
    [autocompleteView release];
    
    [super dealloc];
}

- (NSView *)nativeView
{
    return [self.session view];
}

- (NSWindow *)window
{
    return [[NSApplication sharedApplication] mainWindow];
}

- (void)connectWithOptions:(NSDictionary *)options
{
    Profile* prototype;
    
    if(options)
    {
        prototype = [self generateBookmarkFromOptions:options];
        
        options_ = options;
    }
    else
    {
        NSMutableDictionary* aDict = [[[NSMutableDictionary alloc] init] autorelease];
        [ITAddressBookMgr setDefaultsInBookmark:aDict];
        [aDict setObject:[ProfileModel freshGuid] forKey:KEY_GUID];
        
        prototype = aDict;
    }
    
    NSMutableString *cmd;
    NSArray *arguments;
    NSString *pwd;
    BOOL isUTF8;
    
    arguments = [prototype objectForKey:@"ARGS"];

    NSSize initialSize = NSZeroSize;
    if(settings_)
    {
        initialSize = [[settings_ valueForKey:@"InitialSize"] sizeValue];
    }

    [self addNewSession:prototype];
    [self setupSession:self.session title:@"" withSize:&initialSize];
    
    [self.session setPreferencesFromAddressBookEntry:prototype];
    
    self.tab = [[PTYTab alloc] initWithSession:self.session];
    [self.tab setParentWindow:self];
 
    [self.session setIgnoreResizeNotifications:false];
    [self.tab setReportIdealSizeAsCurrent:false];
    
    BOOL loginShell;
    
    cmd = [[NSMutableString alloc] initWithString:[ITAddressBookMgr bookmarkCommand:prototype isLoginSession:&loginShell forObjectType:iTermTabObject]];

    if(loginShell)
    {
        [cmd breakDownCommandToPath:&cmd cmdArgs:&arguments];
    }

    pwd = [ITAddressBookMgr bookmarkWorkingDirectory:prototype forObjectType:iTermWindowObject];
    NSDictionary *env = [NSDictionary dictionaryWithObject:pwd forKey:@"PWD"];
    isUTF8 = ([[prototype objectForKey:KEY_CHARACTER_ENCODING] unsignedIntValue] == NSUTF8StringEncoding);

    NSString *name = [[[NSMutableString alloc] initWithString:[prototype objectForKey:KEY_NAME]] autorelease];
    
    [self.session setName:name];
    [self.session startProgram:cmd arguments:arguments environment:env isUTF8:isUTF8 asLoginSession:loginShell];
    
    [self performSelectorOnMainThread:@selector(connectInternal) withObject:nil waitUntilDone:false];
}

- (void)connectInternal
{
    iTermController *controller = [iTermController sharedInstance];
    PseudoTerminal *terminal = [self.tab realParentWindow];
    [controller setCurrentTerminal:terminal];
    
    [self connectionStatusChanged:SessionStatusConnected];
}

- (void)connectionStatusChanged:(SessionStatus)status
{
    SEL connectionStatusChangedSelector = NSSelectorFromString(@"sessionStatusChanged:");
    
    if(owner_ && [owner_ respondsToSelector:connectionStatusChangedSelector])
    {
        [owner_ performSelector:connectionStatusChangedSelector withObject:[NSNumber numberWithInt:status]];
    }
}

- (void)resize
{
    [tab fitSessionToCurrentViewSize:self.session];
}

- (void)focus
{
    [[self currentSession] takeFocus];
}

- (BOOL)fitSessionToCurrentViewSize:(PTYSession*)aSession
{
    if ([aSession isTmuxClient])
    {
        return NO;
    }
    
    NSSize temp = [self sessionSizeForViewSize:aSession];
    
    int width = temp.width;
    int height = temp.height;
    
    if ([aSession rows] == height && [aSession columns] == width)
    {
        return NO;
    }
    if (width == [aSession columns] && height == [aSession rows])
    {
        return NO;
    }
    
    [aSession setWidth:width height:height];
    
    [[aSession SCROLLVIEW] setLineScroll:[[aSession TEXTVIEW] lineHeight]];
    [[aSession SCROLLVIEW] setPageScroll:2*[[aSession TEXTVIEW] lineHeight]];
    
    if ([aSession backgroundImagePath])
    {
        [aSession setBackgroundImagePath:[aSession backgroundImagePath]];
    }
    
    return YES;
}

- (NSSize)sessionSizeForViewSize:(PTYSession *)aSession
{
    [[aSession SCROLLVIEW] setHasVerticalScroller:true];
    NSSize size = [[aSession view] maximumPossibleScrollViewContentSize];

    int width = (size.width - MARGIN * 2) / [[aSession TEXTVIEW] charWidth];
    int height = (size.height - VMARGIN * 2) / [[aSession TEXTVIEW] lineHeight];
    
    if (width <= 0)
    {
        NSLog(@"WARNING: Session has %d width", width);
        width = 1;
    }
    if (height <= 0)
    {
        NSLog(@"WARNING: Session has %d height", height);
        height = 1;
    }
    
    return NSMakeSize(width, height);
}

- (id)addNewSession:(NSDictionary *)addressbookEntry
{
    assert(addressbookEntry);
    
    // Initialize a new session
    PTYSession *aSession = [[PTYSession alloc] init];
    [[aSession SCREEN] setUnlimitedScrollback:[[addressbookEntry objectForKey:KEY_UNLIMITED_SCROLLBACK] boolValue]];
    [[aSession SCREEN] setScrollback:[[addressbookEntry objectForKey:KEY_SCROLLBACK_LINES] intValue]];
    
    // set our preferences
    [aSession setAddressBookEntry:addressbookEntry];
    [aSession SCREEN];
    
    self.session = aSession;
    
    [aSession release];
    
    return aSession;
}

- (void)setupSession:(PTYSession *)aSession title:(NSString *)title withSize:(NSSize *)size
{
    NSParameterAssert(aSession != nil);
    
    NSDictionary *tempPrefs = [aSession addressBookEntry];
    
    int rows = [[tempPrefs objectForKey:KEY_ROWS] intValue];
    int columns = [[tempPrefs objectForKey:KEY_COLUMNS] intValue];
    
    NSSize charSize = [PTYTextView charSizeForFont:[ITAddressBookMgr fontWithDesc:[tempPrefs objectForKey:KEY_NORMAL_FONT]]
                                 horizontalSpacing:[[tempPrefs objectForKey:KEY_HORIZONTAL_SPACING] floatValue]
                                   verticalSpacing:[[tempPrefs objectForKey:KEY_VERTICAL_SPACING] floatValue]];

    NSRect sessionRect;
    
    if (size != nil)
    {
        BOOL hasScrollbar = [self scrollbarShouldBeVisible];
        NSSize contentSize = [PTYScrollView contentSizeForFrameSize:*size
                                              hasHorizontalScroller:NO
                                                hasVerticalScroller:hasScrollbar
                                                         borderType:NSNoBorder];
        rows = (contentSize.height - VMARGIN*2) / charSize.height;
        columns = (contentSize.width - MARGIN*2) / charSize.width;
        sessionRect.origin = NSZeroPoint;
        sessionRect.size = *size;
    }
    else
    {
        sessionRect = NSMakeRect(0, 0, columns * charSize.width + MARGIN * 2, rows * charSize.height + VMARGIN * 2);
    }
    
    if ([aSession setScreenSize:sessionRect parent:self])
    {
        [aSession setPreferencesFromAddressBookEntry:tempPrefs];
        [aSession loadInitialColorTable];
        [aSession setBookmarkName:[tempPrefs objectForKey:KEY_NAME]];
        [[aSession SCREEN] setDisplay:[aSession TEXTVIEW]];
        [[aSession TERMINAL] setTrace:YES];    // debug vt100 escape sequence decode
        
        if (title)
        {
            [aSession setName:title];
            [aSession setDefaultName:title];
            [self setWindowTitle];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (NSDictionary *)defaultOptions
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [ITAddressBookMgr setDefaultsInBookmark:dict];
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (NSDictionary *)generateBookmarkFromOptions:(NSDictionary *)options
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:[ProfileModel freshGuid] forKey:KEY_GUID];
    [dict setObject:[NSNumber numberWithBool:NO] forKey:KEY_DEFAULT_BOOKMARK];
    
    [dict setObject:[options objectForKey:KEY_COMMAND] forKey:KEY_COMMAND];
    [dict setObject:[options objectForKey:KEY_CUSTOM_COMMAND] forKey:KEY_CUSTOM_COMMAND];
    
    if([options objectForKey:@"ARGS"] != nil)
    {
        [dict setObject:[options objectForKey:@"ARGS"] forKey:@"ARGS"];
    }
    
    [dict setObject:[options objectForKey:KEY_INITIAL_TEXT] forKey:KEY_INITIAL_TEXT];
    
    [dict setObject:[options objectForKey:KEY_VERTICAL_SPACING] forKey:KEY_VERTICAL_SPACING];
    [dict setObject:[options objectForKey:KEY_HORIZONTAL_SPACING] forKey:KEY_HORIZONTAL_SPACING];
    [dict setObject:[options objectForKey:KEY_TRANSPARENCY] forKey:KEY_TRANSPARENCY];
    [dict setObject:[options objectForKey:KEY_NAME] forKey:KEY_NAME];
    
    // Colours
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_0_COLOR]] forKey:KEY_ANSI_0_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_1_COLOR]] forKey:KEY_ANSI_1_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_2_COLOR]] forKey:KEY_ANSI_2_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_3_COLOR]] forKey:KEY_ANSI_3_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_4_COLOR]] forKey:KEY_ANSI_4_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_5_COLOR]] forKey:KEY_ANSI_5_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_6_COLOR]] forKey:KEY_ANSI_6_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_7_COLOR]] forKey:KEY_ANSI_7_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_8_COLOR]] forKey:KEY_ANSI_8_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_9_COLOR]] forKey:KEY_ANSI_9_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_10_COLOR]] forKey:KEY_ANSI_10_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_11_COLOR]] forKey:KEY_ANSI_11_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_12_COLOR]] forKey:KEY_ANSI_12_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_13_COLOR]] forKey:KEY_ANSI_13_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_14_COLOR]] forKey:KEY_ANSI_14_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_ANSI_15_COLOR]] forKey:KEY_ANSI_15_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_FOREGROUND_COLOR]] forKey:KEY_FOREGROUND_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_BACKGROUND_COLOR]] forKey:KEY_BACKGROUND_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_BOLD_COLOR]] forKey:KEY_BOLD_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_SELECTION_COLOR]] forKey:KEY_SELECTION_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_SELECTED_TEXT_COLOR]] forKey:KEY_SELECTED_TEXT_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_CURSOR_COLOR]] forKey:KEY_CURSOR_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_CURSOR_TEXT_COLOR]] forKey:KEY_CURSOR_TEXT_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEYTEMPLATE_ANSI_X_COLOR]] forKey:KEYTEMPLATE_ANSI_X_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_SMART_CURSOR_COLOR]] forKey:KEY_SMART_CURSOR_COLOR];
//    [dict setObject:[ITAddressBookMgr encodeColor:[options valueForKey:KEY_MINIMUM_CONTRAST]] forKey:KEY_MINIMUM_CONTRAST];
    
    [dict setObject:[options valueForKey:KEY_ANSI_0_COLOR] forKey:KEY_ANSI_0_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_1_COLOR] forKey:KEY_ANSI_1_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_2_COLOR] forKey:KEY_ANSI_2_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_3_COLOR] forKey:KEY_ANSI_3_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_4_COLOR] forKey:KEY_ANSI_4_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_5_COLOR] forKey:KEY_ANSI_5_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_6_COLOR] forKey:KEY_ANSI_6_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_7_COLOR] forKey:KEY_ANSI_7_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_8_COLOR] forKey:KEY_ANSI_8_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_9_COLOR] forKey:KEY_ANSI_9_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_10_COLOR] forKey:KEY_ANSI_10_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_11_COLOR] forKey:KEY_ANSI_11_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_12_COLOR] forKey:KEY_ANSI_12_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_13_COLOR] forKey:KEY_ANSI_13_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_14_COLOR] forKey:KEY_ANSI_14_COLOR];
    [dict setObject:[options valueForKey:KEY_ANSI_15_COLOR] forKey:KEY_ANSI_15_COLOR];
    [dict setObject:[options valueForKey:KEY_FOREGROUND_COLOR] forKey:KEY_FOREGROUND_COLOR];
    [dict setObject:[options valueForKey:KEY_BACKGROUND_COLOR] forKey:KEY_BACKGROUND_COLOR];
    [dict setObject:[options valueForKey:KEY_BOLD_COLOR] forKey:KEY_BOLD_COLOR];
    [dict setObject:[options valueForKey:KEY_SELECTION_COLOR] forKey:KEY_SELECTION_COLOR];
    [dict setObject:[options valueForKey:KEY_SELECTED_TEXT_COLOR] forKey:KEY_SELECTED_TEXT_COLOR];
    [dict setObject:[options valueForKey:KEY_CURSOR_COLOR] forKey:KEY_CURSOR_COLOR];
    [dict setObject:[options valueForKey:KEY_CURSOR_TEXT_COLOR] forKey:KEY_CURSOR_TEXT_COLOR];
    [dict setObject:[options valueForKey:KEY_SMART_CURSOR_COLOR] forKey:KEY_SMART_CURSOR_COLOR];
//    [dict setObject:[options valueForKey:KEY_MINIMUM_CONTRAST] forKey:KEY_MINIMUM_CONTRAST];
    
    // Get display options
    [dict setObject:[options objectForKey:KEY_NORMAL_FONT] forKey:KEY_NORMAL_FONT];
    [dict setObject:[options objectForKey:KEY_NON_ASCII_FONT] forKey:KEY_NON_ASCII_FONT];
    [dict setObject:[options objectForKey:KEY_BLINKING_CURSOR] forKey:KEY_BLINKING_CURSOR];
    [dict setObject:[options objectForKey:KEY_CURSOR_TYPE] forKey:KEY_CURSOR_TYPE];
    [dict setObject:[options objectForKey:KEY_ASCII_ANTI_ALIASED] forKey:KEY_ASCII_ANTI_ALIASED];
    [dict setObject:[options objectForKey:KEY_NONASCII_ANTI_ALIASED] forKey:KEY_NONASCII_ANTI_ALIASED];
    
    // Get terminal options
    [dict setObject:[options objectForKey:KEY_CLOSE_SESSIONS_ON_END] forKey:KEY_CLOSE_SESSIONS_ON_END];
    [dict setObject:[options objectForKey:KEY_SILENCE_BELL] forKey:KEY_SILENCE_BELL];
    [dict setObject:[options objectForKey:KEY_XTERM_MOUSE_REPORTING] forKey:KEY_XTERM_MOUSE_REPORTING];
    [dict setObject:[options objectForKey:KEY_SET_LOCALE_VARS] forKey:KEY_SET_LOCALE_VARS];
    [dict setObject:[options objectForKey:KEY_CHARACTER_ENCODING] forKey:KEY_CHARACTER_ENCODING];
    [dict setObject:[options objectForKey:KEY_SCROLLBACK_LINES] forKey:KEY_SCROLLBACK_LINES];
    [dict setObject:[options objectForKey:KEY_UNLIMITED_SCROLLBACK] forKey:KEY_UNLIMITED_SCROLLBACK];
    [dict setObject:[options objectForKey:KEY_TERMINAL_TYPE] forKey:KEY_TERMINAL_TYPE];
    
    // Get session options
    [dict setObject:[options objectForKey:KEY_AUTOLOG] forKey:KEY_AUTOLOG];
    [dict setObject:[options objectForKey:KEY_LOGDIR] forKey:KEY_LOGDIR];
    [dict setObject:[options objectForKey:KEY_SEND_CODE_WHEN_IDLE] forKey:KEY_SEND_CODE_WHEN_IDLE];
    [dict setObject:[options objectForKey:KEY_IDLE_CODE] forKey:KEY_IDLE_CODE];
    
    // Get keyboard options
    [dict setObject:[options objectForKey:KEY_OPTION_KEY_SENDS] forKey:KEY_OPTION_KEY_SENDS];
    [dict setObject:[options objectForKey:KEY_RIGHT_OPTION_KEY_SENDS] forKey:KEY_RIGHT_OPTION_KEY_SENDS];
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (void)autocomplete
{
    if ([[autocompleteView window] isVisible])
    {
        [autocompleteView more];
    }
    else
    {
        [autocompleteView popInSession:[self currentSession]];
    }
}

- (void)clearBuffer
{
    [[self currentSession] clearBuffer];
}

- (void)clearScrollbackBuffer
{
    [[self currentSession] clearScrollbackBuffer];
}

- (void)saveScrollPosition
{
    [[self currentSession] saveScrollPosition];
}

- (void)jumpToSavedScrollPosition
{
    [[self currentSession] jumpToSavedScrollPosition];
}

- (BOOL)hasSavedScrollPosition
{
    return [[self currentSession] hasSavedScrollPosition];
}

- (void)biggerFont
{
    [self.currentSession changeFontSizeDirection:1];
}

- (void)smallerFont
{
    [self.currentSession changeFontSizeDirection:-1];
}

- (void)openPasteHistory
{
    if (!pbHistoryView)
    {
        pbHistoryView = [[PasteboardHistoryWindowController alloc] init];
        pbHistoryView.delegate = self;
    }
    
    [pbHistoryView popInSession:[self currentSession]];
}

- (void)disconnect
{
    [self closeSession:self.currentSession];
}

- (void)pasteSlowly
{
    [self pasteWithFlags:2];
}

- (void)pasteEscaping
{
    [self pasteWithFlags:1];
}

- (void)pasteWithFlags:(int)flags
{
    NSString* pbStr = [PTYSession pasteboardString];
    
    if (pbStr)
    {
        [self.currentSession pasteString:pbStr flags:flags];
    }
}

#pragma mark PseudoTerminal

- (BOOL)scrollbarShouldBeVisible
{
    return true;
}

- (BOOL)windowInited
{
    return true;
}

- (BOOL)useTransparency
{
    return false;
}

- (BOOL)broadcastInputToSession:(PTYSession *)session
{
    return NO;
}

- (void)futureInvalidateRestorableState
{

}

- (BOOL)inInstantReplay
{
    return false;
}

- (int)number
{
    return number_;
}

- (NSArray*)sessions
{
    return [NSArray arrayWithObject:self.session];
}

// Max window frame size that fits on screens.
- (NSRect)maxFrame
{
    NSRect visibleFrame = NSZeroRect;
    
    for (NSScreen* screen in [NSScreen screens])
    {
        visibleFrame = NSUnionRect(visibleFrame, [screen visibleFrame]);
    }
    
    return visibleFrame;
}

- (void)sessionWasRemoved
{

}

#pragma mark - PasteboardHistoryWindowControllerDelegate

- (void)pasteboardHistoryWindowDidClose
{
    [pbHistoryView shutdown];
    [pbHistoryView autorelease];
    pbHistoryView = nil;
}

#pragma mark WindowControllerInterface

- (void)sessionInitiatedResize:(PTYSession*)session width:(int)width height:(int)height
{
    
}

- (BOOL)fullScreen
{
    return false;
}

- (BOOL)anyFullScreen
{
    return false;
}

- (void)closeSession:(PTYSession*)aSession
{
    [aSession terminate];
    
    [self connectionStatusChanged:SessionStatusDisconnected];
}

- (IBAction)nextTab:(id)sender
{

}

- (IBAction)previousTab:(id)sender
{

}

- (void)setLabelColor:(NSColor *)color forTabViewItem:tabViewItem
{
    
}

- (void)setTabColor:(NSColor *)color forTabViewItem:tabViewItem
{
    
}

- (NSColor*)tabColorForTabViewItem:(NSTabViewItem*)tabViewItem
{
    return 0x0;
}

- (void)enableBlur:(double)radius
{
    
}

- (void)disableBlur
{
    
}

- (BOOL)tempTitle
{
    return false;
}

- (void)fitWindowToTab:(PTYTab*)tab
{
    
}

- (PTYTabView *)tabView
{
    return nil;
}

- (PTYSession *)currentSession
{
    return session;
}

- (void)setWindowTitle
{
    
}

- (void)resetTempTitle
{
    
}

- (PTYTab*)currentTab
{
    return tab;
}

- (void)closeTab:(PTYTab*)theTab
{
    // Do nothing
}

- (void)windowSetFrameTopLeftPoint:(NSPoint)point
{
    
}

- (void)windowPerformMiniaturize:(id)sender
{
    
}

- (void)windowDeminiaturize:(id)sender
{
    
}

- (void)windowOrderFront:(id)sender
{
    
}

- (void)windowOrderBack:(id)sender
{
    
}

- (BOOL)windowIsMiniaturized
{
    return false;
}

- (NSRect)windowFrame
{
    return NSZeroRect;
}

- (NSScreen*)windowScreen
{
    return [NSScreen mainScreen];
}

@end
