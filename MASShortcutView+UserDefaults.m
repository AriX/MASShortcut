#import "MASShortcutView+UserDefaults.h"
#import "MASShortcut.h"
#import <objc/runtime.h>

@interface MASShortcutDefaultsObserver : NSObject {

    MASShortcut *_originalShortcut;
    NSString *_userDefaultsKey;
    MASShortcutView *_shortcutView;

}

@property (nonatomic, readonly) NSString *userDefaultsKey;
@property (nonatomic, readonly, weak) MASShortcutView *shortcutView;

- (id)initWithShortcutView:(MASShortcutView *)shortcutView userDefaultsKey:(NSString *)userDefaultsKey;

@end

#pragma mark -

@implementation MASShortcutView (UserDefaults)

void *kDefaultsObserver = &kDefaultsObserver;

- (NSString *)associatedUserDefaultsKey
{
    MASShortcutDefaultsObserver *defaultsObserver = objc_getAssociatedObject(self, kDefaultsObserver);
    return defaultsObserver.userDefaultsKey;
}

- (void)setAssociatedUserDefaultsKey:(NSString *)associatedUserDefaultsKey
{
    // First, stop observing previous shortcut view
    objc_setAssociatedObject(self, kDefaultsObserver, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Next, start observing current shortcut view
    MASShortcutDefaultsObserver *defaultsObserver = [[MASShortcutDefaultsObserver alloc] initWithShortcutView:self userDefaultsKey:associatedUserDefaultsKey];
    objc_setAssociatedObject(self, kDefaultsObserver, defaultsObserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [defaultsObserver release];
}

@end

#pragma mark -

@implementation MASShortcutDefaultsObserver

@synthesize userDefaultsKey = _userDefaultsKey;
@synthesize shortcutView = _shortcutView;

#pragma mark -

- (id)initWithShortcutView:(MASShortcutView *)shortcutView userDefaultsKey:(NSString *)userDefaultsKey
{
    self = [super init];
    if (self) {
        _originalShortcut = shortcutView.shortcutValue;
        _shortcutView = shortcutView;
        _userDefaultsKey = userDefaultsKey.copy;
        [self startObservingShortcutView];
    }
    return self;
}

- (void)dealloc
{
    // __weak _shortcutView is not yet deallocated because it refers MASShortcutDefaultsObserver
    [self stopObservingShortcutView];
    [super dealloc];
}

#pragma mark -

void *kShortcutValueObserver = &kShortcutValueObserver;

- (void)startObservingShortcutView
{
    // Read initial shortcut value from user preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:_userDefaultsKey];
    _shortcutView.shortcutValue = [MASShortcut shortcutWithData:data];

    // Observe the keyboard shortcut that user inputs by hand
    [_shortcutView addObserver:self forKeyPath:@"shortcutValue" options:0 context:kShortcutValueObserver];
}

- (void)stopObservingShortcutView
{
    // Stop observing keyboard hotkeys entered by user in the shortcut view
    [_shortcutView removeObserver:self forKeyPath:@"shortcutValue" context:kShortcutValueObserver];

    // Restore original hotkey in the shortcut view
    _shortcutView.shortcutValue = _originalShortcut;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kShortcutValueObserver) {
        MASShortcut *shortcut = [object valueForKey:keyPath];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:(shortcut.data ?: [NSKeyedArchiver archivedDataWithRootObject:nil]) forKey:_userDefaultsKey];
        [defaults synchronize];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
