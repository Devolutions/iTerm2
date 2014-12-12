//
//  TestViewController.m
//  iTerm
//
//  Created by Richard Markiewicz on 2014-12-10.
//
//

#import "TestViewController.h"

#import "iTermController.h"

#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <pwd.h>

@interface TestViewController()

@end

@implementation TestViewController

@synthesize session;
@synthesize tab;
@synthesize window;

// TODO: AppDelegate?
// TODO: Make delegate of mainwindow and implement didEnter/didExitFullScreen
// TODO: Future? futureInvalidateRestorableState
// TODO: Implement rest of pseudo terminal? Sessions?
// broadcastInputToSessions, useTransparency, windowOrderFront/Back/deMinituarise/performMitiuarise/setFrameTopLeftPoint
// fitWindowToTab, windowdidresize, number

// resize
// previoustab, nexttab
// closesession
// currentsessionname
// maxframe
// scrollbarshouldbevisible
// sessionsizeforviewsize
// fitsessiontocurrentviewsize
// sessionwwasremoved
// defaultbookmark
// setmark
// jumptomark
// autocomplete
// pastespecial, pastehistory
// smallerfont, biggerfont
// clearbuffer, clearscollback
// disconnect
// runcommand, sendtext
// focussession - Called from managed
// buildbookmark
// refreshscreen, contentsize
// connectionstatuschanged (int?)
// togglefind
// dealloc

int number_;

- (id)initWithParent:(NSViewController *)controller andWindow:(NSWindow *)mainWindow
{
    self = [super init];
    
    if(self)
    {
        self.window = window;
        
        parentViewController = controller;
        autocompleteView = [[AutocompleteView alloc] init];
        pbHistoryView = [[PasteboardHistoryWindowController alloc] init];
        
        number_ = [[iTermController sharedInstance] allocateWindowNumber];
        
        return self;
    }
    
    return nil;
}

- (void)connect //withOptions
{
    Profile* prototype = [[ProfileModel sharedInstance] defaultBookmark];
    
    if (!prototype)
    {
        NSMutableDictionary* aDict = [[[NSMutableDictionary alloc] init] autorelease];
        [ITAddressBookMgr setDefaultsInBookmark:aDict];
        [aDict setObject:[ProfileModel freshGuid] forKey:KEY_GUID];
        prototype = aDict;
    }
    
    NSSize initialSize = NSMakeSize(640, 480);
    
    [self addNewSession:prototype];
    [self setupSession:self.session title:@"" withSize:&initialSize];
    
    [self.session setPreferencesFromAddressBookEntry:prototype];
    
    self.tab = [[PTYTab alloc] initWithSession:self.session];
    [self.tab setParentWindow:self]; // correct??
 
    [self.session setIgnoreResizeNotifications:false];
    [self.tab setReportIdealSizeAsCurrent:false];
    
    [self performSelectorOnMainThread:@selector(connectInternal) withObject:nil waitUntilDone:false];
    
    //    *(int8_t *)(self + 0x14) = 0x0;
    //    ebx = self;
    //    var_2C = [self buildBookmark:arg_8];
    //    var_30 = [arg_8 objectForKey:@"Command"];
    //    var_34 = [arg_8 objectForKey:@"Arguments"];
    //    *(ebx + 0xc) = [ebx addNewSession:var_2C];
    //    eax = [arg_8 objectForKey:@"InitialFrame"];
    //    if (eax != 0x0) {
    //        *var_28 = [eax rectValue];
    //        esp = esp - 0x4;
    //    }
    //    else {
    //        var_28 = intrinsic_movaps(var_28, intrinsic_xorps(xmm0, xmm0));
    //    }
    //    eax = *(ebx + 0xc);
    //    [ebx setupSession:eax title:@"Royal TSX" withSize:var_20];
    //    eax = *(ebx + 0xc);
    //    [eax setPreferencesFromAddressBookEntry:var_2C];
    //    eax = [PTYTab alloc];
    //    eax = [eax initWithSession:*(ebx + 0xc)];
    //    *(ebx + 0x10) = eax;
    //    [eax setParentWindow:ebx];
    //    eax = *(ebx + 0xc);
    //    [eax setIgnoreResizeNotifications:0x0];
    //    eax = *(ebx + 0x10);
    //    [eax setReportIdealSizeAsCurrent:0x0];
    //    [ebx connectionStatusChanged:0x1 withContent:@""];
    //    eax = [NSArray arrayWithObjects:var_30, var_34, 0x0];
    //    eax = [ebx performSelectorOnMainThread:@selector(connectFinal:) withObject:eax waitUntilDone:0x0];
    //    return;
}

static NSString* UserShell() {
    struct passwd* pw;
    pw = getpwuid(geteuid());
    if (!pw) {
        NSLog(@"No passwd entry for effective uid %d", geteuid());
        endpwent();
        return nil;
    }
    NSString* shell = [NSString stringWithUTF8String:pw->pw_shell];
    endpwent();
    return shell;
}

- (void)connectInternal
{
    //    var_10 = *(self + 0xc);
    //    esi = [arg_8 objectAtIndex:0x0];
    //    edi = [arg_8 objectAtIndex:0x1];
    //    eax = [NSDictionary dictionary];
    //    [var_10 startProgram:esi arguments:edi environment:eax isUTF8:0x1 asLoginSession:0x1];
    //    esi = [iTermController sharedInstance];
    //    eax = *(self + 0x10);
    //    eax = [eax realParentWindow];
    //    [esi setCurrentTerminal:eax];
    //    eax = [self connectionStatusChanged:0x2 withContent:@""];
    //    return;
    
    NSString *path = UserShell();
    NSArray *arguments = [NSArray array];
    
    [self.session startProgram:path arguments:arguments environment:[NSDictionary dictionary] isUTF8:YES asLoginSession:YES];
    
    iTermController *controller = [iTermController sharedInstance];
    PseudoTerminal *terminal = [self.tab realParentWindow];
    [controller setCurrentTerminal:terminal];
    
    [parentViewController.view addSubview:self.session.view];
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
    
    [aSession SCREEN]; // TODO: Is this needed?
    
    self.session = aSession;
    
    [aSession release];
    
    return aSession;
}

// Set the session's address book and initialize its screen and name. Sets the
// window title to the session's name. If size is not nil then the session is initialized to fit
// a view of that size; otherwise the size is derived from the existing window if there is already
// an open tab, or its bookmark's preference if it's the first session in the window.
- (void)setupSession:(PTYSession *)aSession title:(NSString *)title withSize:(NSSize *)size
{
    NSDictionary *tempPrefs;
    
    NSParameterAssert(aSession != nil);
    
    // set some default parameters
    if ([aSession addressBookEntry] == nil)
    {
        tempPrefs = [[ProfileModel sharedInstance] defaultBookmark];
        
        if (tempPrefs != nil)
        {
            // Use the default bookmark. This path is taken with applescript's
            // "make new session at the end of sessions" command.
            [aSession setAddressBookEntry:tempPrefs];
        }
        else
        {
            // get the hardcoded defaults
            NSMutableDictionary* dict = [[[NSMutableDictionary alloc] init] autorelease];
            [ITAddressBookMgr setDefaultsInBookmark:dict];
            [dict setObject:[ProfileModel freshGuid] forKey:KEY_GUID];
            [aSession setAddressBookEntry:dict];
            tempPrefs = dict;
        }
    }
    else
    {
        tempPrefs = [aSession addressBookEntry];
    }
    
    int rows = [[tempPrefs objectForKey:KEY_ROWS] intValue];
    int columns = [[tempPrefs objectForKey:KEY_COLUMNS] intValue];
    
//    if (desiredRows_ < 0)
//    {
//        desiredRows_ = rows;
//        desiredColumns_ = columns;
//    }
    
    if (nextSessionRows_)
    {
        rows = nextSessionRows_;
        nextSessionRows_ = 0;
    }
    
    if (nextSessionColumns_)
    {
        columns = nextSessionColumns_;
        nextSessionColumns_ = 0;
    }
    
    NSSize charSize = [PTYTextView charSizeForFont:[ITAddressBookMgr fontWithDesc:[tempPrefs objectForKey:KEY_NORMAL_FONT]]
                                 horizontalSpacing:[[tempPrefs objectForKey:KEY_HORIZONTAL_SPACING] floatValue]
                                   verticalSpacing:[[tempPrefs objectForKey:KEY_VERTICAL_SPACING] floatValue]];
    
//    if (windowType_ == WINDOW_TYPE_TOP ||
//        windowType_ == WINDOW_TYPE_BOTTOM ||
//        windowType_ == WINDOW_TYPE_LEFT)
//    {
//        NSRect windowFrame = [[self window] frame];
//        BOOL hasScrollbar = [self scrollbarShouldBeVisible];
//        NSSize contentSize = [PTYScrollView contentSizeForFrameSize:windowFrame.size
//                                              hasHorizontalScroller:NO
//                                                hasVerticalScroller:hasScrollbar
//                                                         borderType:NSNoBorder];
//        if (windowType_ != WINDOW_TYPE_LEFT)
//        {
//            columns = (contentSize.width - MARGIN*2) / charSize.width;
//        }
//    }
    
//    if (size == nil && [TABVIEW numberOfTabViewItems] != 0)
//    {
//        NSSize contentSize = [[[self currentSession] SCROLLVIEW] documentVisibleRect].size;
//        rows = (contentSize.height - VMARGIN*2) / charSize.height;
//        columns = (contentSize.width - MARGIN*2) / charSize.width;
//    }
    
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
        [self safelySetSessionSize:aSession rows:rows columns:columns];
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

- (void)loadView
{
    NSLog(@"LOADVIEW");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

//void * -[iTerm2ViewController buildBookmark:](void * self, void * _cmd, void * arg2) {
//    edi = [NSMutableDictionary dictionary];
//    var_14 = edi;
//    [edi setObject:@"No" forKey:@"Default Bookmark"];
//    eax = [arg_8 objectForKey:@"DisplayName"];
//    [edi setObject:eax forKey:@"Name"];
//    eax = [ProfileModel freshGuid];
//    [edi setObject:eax forKey:@"Guid"];
//    eax = [NSNumber numberWithInt:0xffffffff];
//    [edi setObject:eax forKey:@"Screen"];
//    eax = [NSNumber numberWithBool:0x0];
//    [edi setObject:eax forKey:@"Disable Smcup Rmcup"];
//    eax = [arg_8 objectForKey:@"VerticalCharSpacing"];
//    [edi setObject:eax forKey:@"Vertical Spacing"];
//    eax = [arg_8 objectForKey:@"HorizontalCharSpacing"];
//    [edi setObject:eax forKey:@"Horizontal Spacing"];
//    [edi setObject:@"No" forKey:@"Custom Command"];
//    eax = [NSNumber numberWithInt:0x0];
//    [edi setObject:eax forKey:@"Window Type"];
//    eax = [arg_8 objectForKey:@"TerminalType"];
//    [edi setObject:eax forKey:@"Terminal Type"];
//    eax = [arg_8 objectForKey:@"ScrollbackLines"];
//    [edi setObject:eax forKey:@"Scrollback Lines"];
//    eax = [arg_8 objectForKey:@"UnlimitedScrollback"];
//    [edi setObject:eax forKey:@"Unlimited Scrollback"];
//    eax = [NSNumber numberWithInt:0x18];
//    [edi setObject:eax forKey:@"Rows"];
//    eax = [NSNumber numberWithInt:0x50];
//    [edi setObject:eax forKey:@"Columns"];
//    eax = [NSNumber numberWithInt:0x0];
//    [edi setObject:eax forKey:@"Flashing Bell"];
//    [edi setObject:@"No" forKey:@"Custom Directory"];
//    var_18 = NSString;
//    var_1C = [arg_8 objectForKey:@"FontName"];
//    eax = [arg_8 objectForKey:@"FontSize"];
//    objc_msgSend_fpret(eax, @selector(floatValue));
//    asm{ fstp       qword [ss:esp+0x10] };
//    eax = objc_msgSend(@selector(stringWithFormat:), @"%@ %g", var_1C);
//    [edi setObject:eax forKey:@"Normal Font"];
//    var_18 = NSString;
//    var_1C = [arg_8 objectForKey:@"NonAsciiFontName"];
//    eax = [arg_8 objectForKey:@"NonAsciiFontSize"];
//    objc_msgSend_fpret(eax, @selector(floatValue));
//    asm{ fstp       qword [ss:esp+0x10] };
//    eax = objc_msgSend(@selector(stringWithFormat:), @"%@ %g", var_1C);
//    [edi setObject:eax forKey:@"Non Ascii Font"];
//    eax = [arg_8 objectForKey:@"CloseOnSessionEnd"];
//    [edi setObject:eax forKey:@"Close Sessions On End"];
//    eax = [arg_8 objectForKey:@"BlinkCursor"];
//    [edi setObject:eax forKey:@"Blinking Cursor"];
//    edi = [arg_8 objectForKey:@"Transparency"];
//    esi = var_14;
//    [var_14 setObject:edi forKey:@"Transparency"];
//    objc_msgSend_fpret(edi, @selector(floatValue));
//    asm{ fstp       dword [ss:ebp+var_10] };
//    if (intrinsic_ucomiss(intrinsic_movss(xmm0, var_10), intrinsic_xorps(xmm1, xmm1)) > 0x0) {
//        *(int8_t *)(self + 0x15) = 0x1;
//    }
//    eax = [NSNumber numberWithFloat:0x0];
//    [esi setObject:eax forKey:@"Blend"];
//    eax = [NSNumber numberWithFloat:0x0];
//    [esi setObject:eax forKey:@"Blur Radius"];
//    eax = [NSNumber numberWithBool:0x0];
//    [esi setObject:eax forKey:@"Blur"];
//    eax = [NSNumber numberWithInt:0x0];
//    [esi setObject:eax forKey:@"Visual Bell"];
//    eax = [NSNumber numberWithInt:0x0];
//    [esi setObject:eax forKey:@"Ambiguous Double Width"];
//    eax = [arg_8 objectForKey:@"Encoding"];
//    [esi setObject:eax forKey:@"Character Encoding"];
//    eax = [arg_8 objectForKey:@"FontAntiAlias"];
//    [esi setObject:eax forKey:@"Anti Aliasing"];
//    eax = [arg_8 objectForKey:@"NonAsciiFontAntiAlias"];
//    [esi setObject:eax forKey:@"Non-ASCII Anti Aliased"];
//    eax = [arg_8 objectForKey:@"Ansi0Color"];
//    eax = [ITAddressBookMgr encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 0 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi1Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 1 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi2Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 2 Color"];
//    eax = [arg_8 objectForKey:@"Ansi3Color"];
//    eax = [ITAddressBookMgr encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 3 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi4Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 4 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi5Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 5 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi6Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 6 Color"];
//    eax = [arg_8 objectForKey:@"Ansi7Color"];
//    eax = [ITAddressBookMgr encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 7 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi8Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 8 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi9Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 9 Color"];
//    eax = [arg_8 objectForKey:@"Ansi10Color"];
//    eax = [ITAddressBookMgr encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 10 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi11Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 11 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi12Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 12 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi13Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 13 Color"];
//    eax = [arg_8 objectForKey:@"Ansi14Color"];
//    eax = [ITAddressBookMgr encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 14 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"Ansi15Color"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Ansi 15 Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"ForegroundColor"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Foreground Color"];
//    eax = [arg_8 objectForKey:@"BackgroundColor"];
//    eax = [ITAddressBookMgr encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Background Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"SelectionColor"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Selection Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"SelectedTextColor"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Selected Text Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"CursorColor"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Cursor Color"];
//    var_18 = ITAddressBookMgr;
//    eax = [arg_8 objectForKey:@"CursorTextColor"];
//    eax = [var_18 encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Cursor Text Color"];
//    eax = [arg_8 objectForKey:@"SmartCursorColor"];
//    [var_14 setObject:eax forKey:@"Smart Cursor Color"];
//    eax = [arg_8 objectForKey:@"BoldColor"];
//    eax = [ITAddressBookMgr encodeColor:eax];
//    [var_14 setObject:eax forKey:@"Bold Color"];
//    eax = [NSNumber numberWithInt:0x0];
//    [var_14 setObject:eax forKey:@"BM Growl"];
//    esi = arg_8;
//    eax = [esi objectForKey:@"SetLocaleVariables"];
//    [var_14 setObject:eax forKey:@"Set Local Environment Vars"];
//    eax = [esi objectForKey:@"SilenceBell"];
//    [var_14 setObject:eax forKey:@"Silence Bell"];
//    eax = [NSNumber numberWithInt:0x0];
//    [var_14 setObject:eax forKey:@"Idle Code"];
//    eax = [esi objectForKey:@"KeepAlive"];
//    [var_14 setObject:eax forKey:@"Send Code When Idle"];
//    edi = @"EnableLogging";
//    if ([esi objectForKey:edi] != 0x0) {
//        eax = [esi objectForKey:@"LogDirectory"];
//        eax = [eax isEqualToString:@""];
//        if (LOBYTE(eax) == 0x0) {
//            eax = [esi objectForKey:edi];
//            [var_14 setObject:eax forKey:@"Automatically Log"];
//            eax = [esi objectForKey:@"LogDirectory"];
//            [var_14 setObject:eax forKey:@"Log Directory"];
//        }
//    }
//    edi = @"CursorAppearance";
//    eax = [esi objectForKey:edi];
//    eax = [eax intValue];
//    ecx = 0x0;
//    if (eax != 0x1) {
//        ecx = (LOBYTE([[esi objectForKey:edi] intValue] != 0x2 ? 0x1 : 0x0) & 0xff) + 0x1;
//    }
//    eax = [NSNumber numberWithInt:ecx];
//    edi = var_14;
//    [edi setObject:eax forKey:@"Cursor Type"];
//    COND = [[esi objectForKey:@"NumPadMode"] intValue] == 0x0;
//    eax = iTermKeyBindingMgr;
//    ecx = @selector(setKeyMappingsToPreset:inBookmark:);
//    if (!COND) {
//        edx = @"xterm Defaults";
//    }
//    else {
//        edx = @"xterm with Numeric Keypad";
//    }
//    objc_msgSend(eax, ecx, edx);
//    [iTermKeyBindingMgr setMappingAtIndex:0x0 forKey:@"0xf702-0x260000" action:0xb value:@"0x1b 0x1b 0x5b 0x44" createNew:0x1 inBookmark:edi];
//    [iTermKeyBindingMgr setMappingAtIndex:0x0 forKey:@"0xf702-0x280000" action:0xb value:@"0x1b 0x1b 0x5b 0x44" createNew:0x1 inBookmark:edi];
//    [iTermKeyBindingMgr setMappingAtIndex:0x0 forKey:@"0xf703-0x280000" action:0xb value:@"0x1b 0x1b 0x5b 0x43" createNew:0x1 inBookmark:edi];
//    eax = [arg_8 objectForKey:@"EnableXtermMouseReporting"];
//    [edi setObject:eax forKey:@"Mouse Reporting"];
//    eax = [arg_8 objectForKey:@"LeftOptionKeyMode"];
//    [edi setObject:eax forKey:@"Option Key Sends"];
//    eax = [arg_8 objectForKey:@"RightOptionKeyMode"];
//    [edi setObject:eax forKey:@"Right Option Key Sends"];
//    eax = [arg_8 objectForKey:@"DeleteKeySendsCtrlH"];
//    eax = [eax boolValue];
//    COND = LOBYTE(eax) == 0x0;
//    eax = iTermKeyBindingMgr;
//    if (COND) {
//    }
//    objc_msgSend(STK0, STK-1);
//    eax = edi;
//    return eax;
//}

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
    [[self window] futureInvalidateRestorableState];
}

- (BOOL)inInstantReplay
{
    return false;
}

- (int)number
{
    return number_;
}

// Push a size change to a session (and on to its shell) but clamps the size to
// reasonable minimum and maximum limits.
// Set the session to a size that fits on the screen.
- (void)safelySetSessionSize:(PTYSession*)aSession rows:(int)rows columns:(int)columns
{
//    if ([aSession exited])
//    {
//        return;
//    }
//    
//    BOOL hasScrollbar = [self scrollbarShouldBeVisible];
//    
//    if (windowType_ == WINDOW_TYPE_NORMAL)
//    {
//        int width = columns;
//        int height = rows;
//        if (width < 20) {
//            width = 20;
//        }
//        if (height < 2) {
//            height = 2;
//        }
//        
//        // With split panes it is very difficult to directly compute the maximum size of any
//        // given pane. However, any growth in a pane can be taken up by the window as a whole.
//        // We compute the maximum amount the window can grow and ensure that the rows and columns
//        // won't cause the window to exceed the max size.
//        
//        // 1. Figure out how big the tabview can get assuming window decoration remains unchanged.
//        NSSize maxFrame = [self maxFrame].size;
//        NSSize decoration = [self windowDecorationSize];
//        NSSize maxTabSize;
//        maxTabSize.width = maxFrame.width - decoration.width;
//        maxTabSize.height = maxFrame.height - decoration.height;
//        
//        // 2. Figure out how much the window could grow by in rows and columns.
//        NSSize currentSize = [TABVIEW frame].size;
//        if ([TABVIEW numberOfTabViewItems] == 0) {
//            currentSize = NSZeroSize;
//        }
//        NSSize maxGrowth;
//        maxGrowth.width = maxTabSize.width - currentSize.width;
//        maxGrowth.height = maxTabSize.height - currentSize.height;
//        int maxNewRows = maxGrowth.height / [[aSession TEXTVIEW] lineHeight];
//        
//        // 3. Compute the number of rows and columns we're trying to grow by.
//        int newRows = rows - [aSession rows];
//        // 4. Cap growth if it exceeds the maximum. Do nothing if it's shrinking.
//        if (newRows > maxNewRows) {
//            int error = newRows - maxNewRows;
//            height -= error;
//        }
//        PtyLog(@"safelySetSessionSize - set to %dx%d", width, height);
//        [aSession setWidth:width height:height];
//        [[aSession SCROLLVIEW] setHasVerticalScroller:hasScrollbar];
//        [[aSession SCROLLVIEW] setLineScroll:[[aSession TEXTVIEW] lineHeight]];
//        [[aSession SCROLLVIEW] setPageScroll:2*[[aSession TEXTVIEW] lineHeight]];
//        if ([aSession backgroundImagePath]) {
//            [aSession setBackgroundImagePath:[aSession backgroundImagePath]];
//        }
//    }
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
    // TODO...
    return NSMakeRect(0, 0, 100, 100);
}

- (NSScreen*)windowScreen
{
    return [NSScreen mainScreen];
}

@end
