#import "MASShortcutView.h"
#import "MASShortcut.h"
#import "NSImage+FlippedDrawing.h"

#define HINT_BUTTON_WIDTH 23.0
#define BUTTON_FONT_SIZE 12.0
#define SEGMENT_CHROME_WIDTH 6.0

#pragma mark -

@interface MASShortcutView () // Private accessors

@property (nonatomic, getter = isHinting) BOOL hinting;
@property (nonatomic, getter = isHighlighted) BOOL highlighted;
@property (nonatomic) BOOL hintHighlighted;
@property (nonatomic) BOOL mouseIsOver;
@property (nonatomic, copy) NSString *shortcutPlaceholder;

@end

#pragma mark -

@implementation MASShortcutView

@synthesize enabled = _enabled;
@synthesize highlighted = _highlighted;
@synthesize hintHighlighted = _hintHighlighted;
@synthesize hinting = _hinting;
@synthesize mouseIsOver = _mouseIsOver;
@synthesize shortcutValue = _shortcutValue;
@synthesize shortcutPlaceholder = _shortcutPlaceholder;
@synthesize shortcutValueChange = _shortcutValueChange;
@synthesize recording = _recording;
@synthesize appearance = _appearance;

#pragma mark -

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _shortcutCell = [[NSButtonCell alloc] init];
        _shortcutCell.buttonType = NSPushOnPushOffButton;
        _shortcutCell.font = [[NSFontManager sharedFontManager] convertFont:_shortcutCell.font toSize:BUTTON_FONT_SIZE];
        _enabled = YES;
        [self resetShortcutCellStyle];
    }
    return self;
}

- (void)dealloc
{
    [_shortcutCell release]; _shortcutCell = nil;
    [self activateEventMonitoring:NO];
    [self activateResignObserver:NO];
    [super dealloc];
}

#pragma mark - Public accessors

- (void)setEnabled:(BOOL)flag
{
    if (_enabled != flag) {
        _enabled = flag;
        [self updateTrackingAreas];
        self.recording = NO;
        [self setNeedsDisplay:YES];
    }
}

- (void)setAppearance:(MASShortcutViewAppearance)appearance
{
    if (_appearance != appearance) {
        _appearance = appearance;
        [self resetShortcutCellStyle];
        [self setNeedsDisplay:YES];
    }
}

- (void)resetShortcutCellStyle
{
    switch (_appearance) {
        case MASShortcutViewAppearanceDefault: {
            _shortcutCell.bezelStyle = NSRoundRectBezelStyle;
            break;
        }
        case MASShortcutViewAppearanceTexturedRect: {
            _shortcutCell.bezelStyle = NSTexturedRoundedBezelStyle;
            break;
        }
        case MASShortcutViewAppearanceRounded: {
            _shortcutCell.bezelStyle = NSRoundedBezelStyle;
            break;
        }
    }
}

- (void)setRecording:(BOOL)flag
{
    // Only one recorder can be active at the moment
    static MASShortcutView *currentRecorder = nil;
    if (flag && (currentRecorder != self)) {
        currentRecorder.recording = NO;
        currentRecorder = flag ? self : nil;
    }
    
    // Only enabled view supports recording
    if (flag && !self.enabled) return;
    
    if (_recording != flag) {
        _recording = flag;
        self.shortcutPlaceholder = nil;
        [self resetToolTips];
        [self activateEventMonitoring:_recording];
        [self activateResignObserver:_recording];
        [self setNeedsDisplay:YES];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (_highlighted != highlighted) {
        _highlighted = highlighted;
        
        [self setNeedsDisplay:YES];
    }
}

- (void)setHintHighlighted:(BOOL)hintHighlighted
{
    if (_hintHighlighted != hintHighlighted) {
        _hintHighlighted = hintHighlighted;
        
        [self setNeedsDisplay:YES];
    }
}

- (void)setShortcutValue:(MASShortcut *)shortcutValue
{
    if (shortcutValue != _shortcutValue){
        [_shortcutValue release];
        _shortcutValue = [shortcutValue retain];
    }
    [self resetToolTips];
    // setNeedsDisplay: here causes an error to be printed out on -dealloc: "NSView not correctly initialized. Did you forget to call super?"
    // Everything seems to render properly without it, so let's leave it out for now.
    //[self setNeedsDisplay:YES];

    if (self.shortcutValueChange) {
        self.shortcutValueChange(self);
    }
}

- (void)setShortcutPlaceholder:(NSString *)shortcutPlaceholder
{
    if (_shortcutPlaceholder != shortcutPlaceholder){
        [_shortcutPlaceholder release];
        _shortcutPlaceholder = shortcutPlaceholder.copy;
    }
    [self setNeedsDisplay:YES];
}

#pragma mark - Drawing

- (BOOL)isFlipped
{
    return YES;
}

- (void)drawInRect:(NSRect)frame withTitle:(NSString *)title alignment:(NSTextAlignment)alignment state:(NSInteger)state
{
    _shortcutCell.title = title;
    _shortcutCell.alignment = alignment;
    _shortcutCell.state = state;
    _shortcutCell.enabled = self.enabled;
    _shortcutCell.highlighted = self.highlighted && self.mouseIsOver;

    switch (_appearance) {
        case MASShortcutViewAppearanceDefault: {
            [_shortcutCell drawWithFrame:frame inView:self];
            break;
        }
        case MASShortcutViewAppearanceTexturedRect: {
            [_shortcutCell drawWithFrame:NSRectFromCGRect(CGRectOffset(NSRectToCGRect(frame), 0.0, 1.0)) inView:self];
            break;
        }
        case MASShortcutViewAppearanceRounded: {
            [_shortcutCell drawWithFrame:NSRectFromCGRect(CGRectOffset(NSRectToCGRect(frame), 0.0, 1.0)) inView:self];
            break;
        }
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.shortcutValue) {
        [self drawInRect:self.bounds withTitle:nil
               alignment:NSRightTextAlignment state:NSOffState];
        
        CGRect shortcutRect;
        [self getShortcutRect:&shortcutRect hintRect:NULL];
        NSString *title = (self.recording
                           ? (_hinting
                              ? NSLocalizedString(@"Use Old Shortcut", @"Cancel action button for non-empty shortcut in recording state")
                              : (self.shortcutPlaceholder.length > 0
                                 ? self.shortcutPlaceholder
                                 : NSLocalizedString(@"Type New Shortcut", @"Non-empty shortcut button in recording state")))
                           : _shortcutValue ? _shortcutValue.description : @"");
        [self drawInRect:NSRectFromCGRect(shortcutRect) withTitle:title alignment:NSCenterTextAlignment state:self.isRecording ? NSOnState : NSOffState];
        
        NSString *imageName;
        if (self.recording)
            if (self.hintHighlighted && self.mouseIsOver)
                imageName = @"Revert-Highlighted";
            else
                imageName = @"Revert";
        else
            if (self.hintHighlighted && self.mouseIsOver)
                imageName = @"Clear-Highlighted";
            else
                imageName = @"Clear";
        
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:imageName]];
        [image drawAdjustedAtPoint:NSMakePoint(shortcutRect.size.width + 5.0f, 6.0f) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [image release];
    }
    else {
        if (self.recording)
        {
            [self drawInRect:self.bounds withTitle:nil alignment:NSRightTextAlignment state:NSOffState];
            
            CGRect shortcutRect;
            [self getShortcutRect:&shortcutRect hintRect:NULL];
            NSString *title = (_hinting
                               ? NSLocalizedString(@"Cancel", @"Cancel action button in recording state")
                               : (self.shortcutPlaceholder.length > 0
                                  ? self.shortcutPlaceholder
                                  : NSLocalizedString(@"Type Shortcut", @"Empty shortcut button in recording state")));
            [self drawInRect:NSRectFromCGRect(shortcutRect) withTitle:title alignment:NSCenterTextAlignment state:NSOnState];
            
            NSImage *image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:(self.hintHighlighted && self.mouseIsOver ? @"Clear-Highlighted" : @"Clear")]];
            [image drawAdjustedAtPoint:NSMakePoint(shortcutRect.size.width + 5.0f, 6.0f) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
            [image release];
        }
        else
        {
            [self drawInRect:self.bounds withTitle:NSLocalizedString(@"Click to record hotkey", @"Empty shortcut button in normal state")
                   alignment:NSCenterTextAlignment state:NSOffState];
        }
    }
}

#pragma mark - Mouse handling

- (void)getShortcutRect:(CGRect *)shortcutRectRef hintRect:(CGRect *)hintRectRef
{
    CGRect shortcutRect, hintRect;
    CGFloat hintButtonWidth = HINT_BUTTON_WIDTH;
    switch (self.appearance) {
        case MASShortcutViewAppearanceTexturedRect: hintButtonWidth += 2.0; break;
        case MASShortcutViewAppearanceRounded: hintButtonWidth += 3.0; break;
        default: break;
    }
    CGRectDivide(NSRectToCGRect(self.bounds), &hintRect, &shortcutRect, hintButtonWidth, CGRectMaxXEdge);
    if (shortcutRectRef)  *shortcutRectRef = shortcutRect;
    if (hintRectRef) *hintRectRef = hintRect;
}

- (BOOL)locationInShortcutRect:(CGPoint)location
{
    CGRect shortcutRect;
    [self getShortcutRect:&shortcutRect hintRect:NULL];
    return CGRectContainsPoint(shortcutRect, NSPointToCGPoint([self convertPoint:NSPointFromCGPoint(location) fromView:nil]));
}

- (BOOL)locationInHintRect:(CGPoint)location
{
    CGRect hintRect;
    [self getShortcutRect:NULL hintRect:&hintRect];
    return CGRectContainsPoint(hintRect, NSPointToCGPoint([self convertPoint:NSPointFromCGPoint(location) fromView:nil]));
}

- (void)mouseDown:(NSEvent *)event {
    CGPoint location = NSPointToCGPoint(event.locationInWindow);
    if (self.enabled) {
        if (self.shortcutValue) {
            if (self.recording && [self locationInHintRect:location]) {
                self.hintHighlighted = YES;
            } else {
                if ([self locationInHintRect:location]) {
                    self.hintHighlighted = YES;
                } else if ([self locationInShortcutRect:location]) {
                    self.highlighted = YES;
                }
            }
        } else {
            if (self.recording && [self locationInHintRect:location]) {
                self.hintHighlighted = YES;
            } else if (!self.recording && ([self locationInShortcutRect:location] || [self locationInHintRect:location])) {
                self.highlighted = YES;
            }
        }
    } else {
        [super mouseDown:event];
    }
}

- (void)mouseUp:(NSEvent *)event
{
    CGPoint location = NSPointToCGPoint(event.locationInWindow);
    self.highlighted = NO;
    self.hintHighlighted = NO;
    
    if (self.enabled) {
        if (self.shortcutValue) {
            if (self.recording) {
                if ([self locationInHintRect:location]) {
                    self.recording = NO;
                }
            } else {
                if ([self locationInShortcutRect:location]) {
                    self.recording = YES;
                } else if ([self locationInHintRect:location]) {
                    self.shortcutValue = nil;
                }
            }
        } else {
            if (self.recording) {
                if ([self locationInHintRect:location])
                    self.recording = NO;
            } else {
                if ([self locationInHintRect:location] || [self locationInShortcutRect:location])
                    self.recording = YES;
            }
        }
    } else {
        [super mouseUp:event];
    }
}

#pragma mark - Handling mouse over

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    
    if (_hintArea) {
        [self removeTrackingArea:_hintArea];
        [_hintArea release];
        _hintArea = nil;
    }
    
    // Forbid hinting if view is disabled
    if (!self.enabled) return;
        
    NSTrackingAreaOptions options = (NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingEnabledDuringMouseDrag);
    _hintArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
    [self addTrackingArea:_hintArea];
}

- (void)setHinting:(BOOL)flag
{
    if (_hinting != flag) {
        _hinting = flag;
        
        [self setNeedsDisplay:YES];
    }
}

- (void)setMouseIsOver:(BOOL)mouseIsOver
{
    if (_mouseIsOver != mouseIsOver) {
        _mouseIsOver = mouseIsOver;
        
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseEntered:(NSEvent *)event
{
    self.mouseIsOver = YES;
}

- (void)mouseExited:(NSEvent *)event
{
    self.mouseIsOver = NO;
    self.hinting = NO;
}

- (void)mouseMoved:(NSEvent *)event
{
    CGPoint location = NSPointToCGPoint(event.locationInWindow);
    self.hinting = [self locationInHintRect:location];
}

void *kUserDataShortcut = &kUserDataShortcut;
void *kUserDataHint = &kUserDataHint;

- (void)resetToolTips
{
    if (_shortcutToolTipTag) {
        [self removeToolTip:_shortcutToolTipTag], _shortcutToolTipTag = 0;
    }
    if (_hintToolTipTag) {
        [self removeToolTip:_hintToolTipTag], _hintToolTipTag = 0;
    }
    
    if ((self.shortcutValue == nil) || self.recording || !self.enabled) return;

    CGRect shortcutRect, hintRect;
    [self getShortcutRect:&shortcutRect hintRect:&hintRect];
    _shortcutToolTipTag = [self addToolTipRect:NSRectFromCGRect(shortcutRect) owner:self userData:kUserDataShortcut];
    _hintToolTipTag = [self addToolTipRect:NSRectFromCGRect(hintRect) owner:self userData:kUserDataHint];
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(CGPoint)point userData:(void *)data
{
    if (data == kUserDataShortcut) {
        return NSLocalizedString(@"Click to record new shortcut", @"Tooltip for non-empty shortcut button");
    }
    else if (data == kUserDataHint) {
        return NSLocalizedString(@"Delete shortcut", @"Tooltip for hint button near the non-empty shortcut");
    }
    return nil;
}

#pragma mark - Event monitoring

- (void)activateEventMonitoring:(BOOL)shouldActivate
{
    static BOOL isActive = NO;
    if (isActive == shouldActivate) return;
    isActive = shouldActivate;
    
    static id eventMonitor = nil;
    if (shouldActivate) {
        __block MASShortcutView *weakSelf = self;
        NSEventMask eventMask = (NSKeyDownMask | NSFlagsChangedMask);
        eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:eventMask handler:^(NSEvent *event) {

            MASShortcut *shortcut = [MASShortcut shortcutWithEvent:event];
            if ((shortcut.keyCode == kVK_Delete) || (shortcut.keyCode == kVK_ForwardDelete)) {
                // Delete shortcut
                weakSelf.shortcutValue = nil;
                weakSelf.recording = NO;
                event = nil;
            }
            else if (shortcut.keyCode == kVK_Escape) {
                // Cancel recording
                weakSelf.recording = NO;
                event = nil;
            }
            else if (shortcut.shouldBypass) {
                // Command + W, Command + Q, ESC should deactivate recorder
                weakSelf.recording = NO;
            }
            else {
                // Verify possible shortcut
                if (shortcut.keyCodeString.length > 0) {
                    if (shortcut.valid) {
                        // Verify that shortcut is not used
                        NSError *error = nil;
                        if ([shortcut isTakenError:&error]) {
                            // Prevent cancel of recording when Alert window is key
                            [weakSelf activateResignObserver:NO];
                            [weakSelf activateEventMonitoring:NO];
                            NSString *format = NSLocalizedString(@"The key combination %@ cannot be used",
                                                                 @"Title for alert when shortcut is already used");
                            NSRunCriticalAlertPanel([NSString stringWithFormat:format, shortcut], error.localizedDescription,
                                                    NSLocalizedString(@"OK", @"Alert button when shortcut is already used"),
                                                    nil, nil);
                            weakSelf.shortcutPlaceholder = nil;
                            [weakSelf activateResignObserver:YES];
                            [weakSelf activateEventMonitoring:YES];
                        }
                        else {
                            weakSelf.shortcutValue = shortcut;
                            weakSelf.recording = NO;
                        }
                    }
                    else {
                        // Key press with or without SHIFT is not valid input
                        NSBeep();
                    }
                }
                else {
                    // User is playing with modifier keys
                    weakSelf.shortcutPlaceholder = shortcut.modifierFlagsString;
                }
                event = nil;
            }
            return event;
        }];
    }
    else {
        [NSEvent removeMonitor:eventMonitor];
    }
}

- (void)activateResignObserver:(BOOL)shouldActivate
{
    static BOOL isActive = NO;
    if (isActive == shouldActivate) return;
    isActive = shouldActivate;
    
    static id observer = nil;
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    if (shouldActivate) {
        __block MASShortcutView *weakSelf = self;
        observer = [notificationCenter addObserverForName:NSWindowDidResignKeyNotification object:self.window
                                                queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
                                                    weakSelf.recording = NO;
                                                }];
    }
    else {
        [notificationCenter removeObserver:observer];
    }
}

@end
