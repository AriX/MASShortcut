//
//  MASAppDelegate.m
//  MASShortcutTest
//
//  Created by Ari on 2/2/13.
//
//

#import "MASAppDelegate.h"
#import <MASShortcut/MASShortcut.h>

static NSString * const kPreferenceGlobalShortcut = @"TestShortcut";

@implementation MASAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [MASShortcut setAllowsAnyHotkeyWithOptionModifier:YES];
    
    self.shortcutView.appearance = MASShortcutViewAppearanceTexturedRect;
    self.shortcutView.associatedUserDefaultsKey = kPreferenceGlobalShortcut;
    
    [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kPreferenceGlobalShortcut handler:^{
        [NSApp activateIgnoringOtherApps:YES];
        
        NSAlert *alert = [NSAlert alertWithMessageText:@"MASShortcut Demo" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Wasn't that easy?"];
        alert.icon = [NSImage imageNamed:NSImageNameMenuOnStateTemplate];
        [alert runModal];
    }];
}

@end
