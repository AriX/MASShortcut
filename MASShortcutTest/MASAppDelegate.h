//
//  MASAppDelegate.h
//  MASShortcutTest
//
//  Created by Ari on 2/2/13.
//
//

#import <Cocoa/Cocoa.h>
#import "MASShortcutView.h"

@interface MASAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet MASShortcutView *shortcutView;

@end
