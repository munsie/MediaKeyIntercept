//
//  MKIAppDelegate.m
//  MediaKeyIntercept
//
//  Created by Dennis Munsie on 11/12/13.
//  Copyright (c) 2013 Dennis Munsie. All rights reserved.
//

#import "MKIAppDelegate.h"
#import <IOKit/hidsystem/ev_keymap.h>

#define SPSystemDefinedEventMediaKeys 8

#define DEFAULT_DISABLE_PLAY_KEY        @"disable_play"
#define DEFAULT_DISABLE_PREVIOUS_KEY    @"disable_previous"
#define DEFAULT_DISABLE_NEXT_KEY        @"disable_next"
#define DEFAULT_DISABLE_VOLUME_UP_KEY   @"disable_volume_up"
#define DEFAULT_DISABLE_VOLUME_DOWN_KEY @"disable_volume_down"
#define DEFAULT_DISABLE_MUTE_KEY        @"disable_mute"
#define DEFAULT_DISABLE_EJECT_KEY       @"disable_eject"

@interface MKIAppDelegate()<NSMenuDelegate> {
  CFMachPortRef _eventPort;
  CFRunLoopSourceRef _eventPortSource;
  CFRunLoopRef _tapThreadRL;
  BOOL _disablePlay;
  BOOL _disableNext;
  BOOL _disablePrevious;
  BOOL _disableVolumeUp;
  BOOL _disableVolumeDown;
  BOOL _disableMute;
  BOOL _disableEject;
  NSStatusItem *_statusItem;
  NSMenu *_statusMenu;
  NSMenuItem *_playMenuItem;
  NSMenuItem *_nextMenuItem;
  NSMenuItem *_previousMenuItem;
  NSMenuItem *_volumeUpMenuItem;
  NSMenuItem *_volumeDownMenuItem;
  NSMenuItem *_muteMenuItem;
  NSMenuItem *_ejectMenuItem;
  NSMenuItem *_separatorMenuItem;
  NSMenuItem *_nameMenuItem;
  NSMenuItem *_versionMenuItem;
  NSMenuItem *_quitMenuItem;
}
-(CGEventRef)tapEventCallbackProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event;
@end

static CGEventRef tapEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
  @autoreleasepool {
    MKIAppDelegate *self = (__bridge MKIAppDelegate *)(refcon);
    return [self tapEventCallbackProxy:proxy type:type event:event];
  }
}

@implementation MKIAppDelegate
#pragma mark NSApplicationDelegate methods
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [self restoreDefaults];
  [self setupStatusItemMenu];
  [self startWatchingMediaKeys];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
  [self stopWatchingMediaKeys];
  [self saveDefaults];
}

#pragma mark - Defaults
-(void)restoreDefaults {
  _disablePlay = [[[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_DISABLE_PLAY_KEY] boolValue];
  _disablePrevious = [[[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_DISABLE_PREVIOUS_KEY] boolValue];
  _disableNext = [[[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_DISABLE_NEXT_KEY] boolValue];
  _disableVolumeUp = [[[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_DISABLE_VOLUME_UP_KEY] boolValue];
  _disableVolumeDown = [[[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_DISABLE_VOLUME_DOWN_KEY] boolValue];
  _disableMute = [[[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_DISABLE_MUTE_KEY] boolValue];
  _disableEject = [[[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_DISABLE_EJECT_KEY] boolValue];
}

-(void)saveDefaults {
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_disablePlay] forKey:DEFAULT_DISABLE_PLAY_KEY];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_disablePrevious] forKey:DEFAULT_DISABLE_PREVIOUS_KEY];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_disableNext] forKey:DEFAULT_DISABLE_NEXT_KEY];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_disableVolumeUp] forKey:DEFAULT_DISABLE_VOLUME_UP_KEY];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_disableVolumeDown] forKey:DEFAULT_DISABLE_VOLUME_DOWN_KEY];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_disableMute] forKey:DEFAULT_DISABLE_MUTE_KEY];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:_disableEject] forKey:DEFAULT_DISABLE_EJECT_KEY];
}

#pragma mark - Status Item Menu
-(void)setupStatusItemMenu {
  _statusMenu = [[NSMenu alloc] initWithTitle:@""];
  _statusMenu.delegate = self;
  
  _previousMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(enableDisablePreviousKey:) keyEquivalent:@""];
  [_previousMenuItem setTarget:self];
  _playMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(enableDisablePlayKey:) keyEquivalent:@""];
  [_playMenuItem setTarget:self];
  _nextMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(enableDisableNextKey:) keyEquivalent:@""];
  [_nextMenuItem setTarget:self];
  _muteMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(enableDisableMuteKey:) keyEquivalent:@""];
  [_muteMenuItem setTarget:self];
  _volumeDownMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(enableDisableVolumeDownKey:) keyEquivalent:@""];
  [_volumeDownMenuItem setTarget:self];
  _volumeUpMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(enableDisableVolumeUpKey:) keyEquivalent:@""];
  [_volumeUpMenuItem setTarget:self];
  _ejectMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(enableDisableEjectKey:) keyEquivalent:@""];
  [_ejectMenuItem setTarget:self];

  // setup the alternate menu items
  _nameMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Media Key Intercept", nil) action:nil keyEquivalent:@""];
  [_nameMenuItem setEnabled:NO];
  NSString *versionString = [NSString stringWithFormat:NSLocalizedString(@"Version %@ (%@)", nil),
                             [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                             [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
  _versionMenuItem = [[NSMenuItem alloc] initWithTitle:versionString action:nil keyEquivalent:@""];
  [_versionMenuItem setEnabled:NO];
  _quitMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(quit:) keyEquivalent:@""];
  [_quitMenuItem setTarget:self];
  
  // setup the NSStatusItem
  _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
  _statusItem.button.image = [NSImage imageWithSystemSymbolName:@"music.quarternote.3" accessibilityDescription:NSLocalizedString(@"MediaKeyIntercept", nil)];
  [_statusItem.button setEnabled:YES];
  [_statusItem setMenu:_statusMenu];
  
  [self updateMenuItemNames];
}

-(void)enableDisablePreviousKey:(id)sender {
  _disablePrevious = !_disablePrevious;
  [self updateMenuItemNames];
}

-(void)enableDisablePlayKey:(id)sender {
  _disablePlay = !_disablePlay;
  [self updateMenuItemNames];
}

-(void)enableDisableNextKey:(id)sender {
  _disableNext = !_disableNext;
  [self updateMenuItemNames];
}

-(void)enableDisableMuteKey:(id)sender {
  _disableMute = !_disableMute;
  [self updateMenuItemNames];
}

-(void)enableDisableVolumeDownKey:(id)sender {
  _disableVolumeDown = !_disableVolumeDown;
  [self updateMenuItemNames];
}

-(void)enableDisableVolumeUpKey:(id)sender {
  _disableVolumeUp = !_disableVolumeUp;
  [self updateMenuItemNames];
}

-(void)enableDisableEjectKey:(id)sender {
  _disableEject = !_disableEject;
  [self updateMenuItemNames];
}

-(void)menuWillOpen:(NSMenu *)menu {
  [_statusMenu removeAllItems];
  if([NSEvent modifierFlags] & NSEventModifierFlagOption) {
    [_statusMenu addItem:_nameMenuItem];
    [_statusMenu addItem:_versionMenuItem];
    [_statusMenu addItem:[NSMenuItem separatorItem]];
    [_statusMenu addItem:_quitMenuItem];
  } else {
    [_statusMenu addItem:_previousMenuItem];
    [_statusMenu addItem:_playMenuItem];
    [_statusMenu addItem:_nextMenuItem];
    [_statusMenu addItem:[NSMenuItem separatorItem]];
    [_statusMenu addItem:_muteMenuItem];
    [_statusMenu addItem:_volumeDownMenuItem];
    [_statusMenu addItem:_volumeUpMenuItem];
    [_statusMenu addItem:[NSMenuItem separatorItem]];
    [_statusMenu addItem:_ejectMenuItem];
  }
}

-(void)quit:(id)sender {
  [[NSApplication sharedApplication] terminate:sender];
}

-(void)updateMenuItemNames {
  _previousMenuItem.title = _disablePrevious ? NSLocalizedString(@"Enable Previous Key", nil) :
                                               NSLocalizedString(@"Disable Previous Key", nil);
  _playMenuItem.title = _disablePlay ? NSLocalizedString(@"Enable Play Key", nil) :
                                       NSLocalizedString(@"Disable Play Key", nil);
  _nextMenuItem.title = _disableNext ? NSLocalizedString(@"Enable Next Key", nil) :
                                       NSLocalizedString(@"Disable Next Key", nil);
  _muteMenuItem.title = _disableMute ? NSLocalizedString(@"Enable Mute Key", nil) :
                                       NSLocalizedString(@"Disable Mute Key", nil);
  _volumeDownMenuItem.title = _disableVolumeDown ? NSLocalizedString(@"Enable Volume Down Key", nil) :
                                                   NSLocalizedString(@"Disable Volume Down Key", nil);
  _volumeUpMenuItem.title = _disableVolumeUp ? NSLocalizedString(@"Enable Volume Up Key", nil) :
                                               NSLocalizedString(@"Disable Volume Up Key", nil);
  _ejectMenuItem.title = _disableEject ? NSLocalizedString(@"Enable Eject Key", nil) :
                                         NSLocalizedString(@"Disable Eject Key", nil);
}

#pragma mark - Media Key Handler
-(void)startWatchingMediaKeys {
  _eventPort = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                CGEventMaskBit(NX_SYSDEFINED),
                                tapEventCallback,
                                (__bridge void *)(self));
  assert(_eventPort != NULL);
  
  _eventPortSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, _eventPort, 0);
  assert(_eventPortSource != NULL);
  
  // Let's do this in a separate thread so that a slow app doesn't lag the event tap
  [NSThread detachNewThreadSelector:@selector(eventTapThread) toTarget:self withObject:nil];
}

-(void)stopWatchingMediaKeys {
  if(_tapThreadRL) {
    CFRunLoopStop(_tapThreadRL);
    _tapThreadRL = nil;
  }
  if(_eventPort) {
    CFMachPortInvalidate(_eventPort);
    CFRelease(_eventPort);
    _eventPort = nil;
  }
  if(_eventPortSource) {
    CFRelease(_eventPortSource);
    _eventPortSource = nil;
  }
}

-(void)eventTapThread {
  _tapThreadRL = CFRunLoopGetCurrent();
  CFRunLoopAddSource(_tapThreadRL, _eventPortSource, kCFRunLoopCommonModes);
  CFRunLoopRun();
}

-(CGEventRef)tapEventCallbackProxy:(CGEventTapProxy)proxy type:(CGEventType)type event:(CGEventRef)event {
  if(type == kCGEventTapDisabledByTimeout) {
    CGEventTapEnable(_eventPort, TRUE);
    return event;
  } else if(type == kCGEventTapDisabledByUserInput) {
    return event;
  }
  NSEvent *nsEvent = nil;
  @try {
    nsEvent = [NSEvent eventWithCGEvent:event];
  }
  @catch(NSException *e) {
    return event;
  }
  if(type != NX_SYSDEFINED || [nsEvent subtype] != SPSystemDefinedEventMediaKeys) {
    return event;
  }
  int keyCode = (([nsEvent data1] & 0xFFFF0000) >> 16);
  switch(keyCode) {
  case NX_KEYTYPE_PLAY:
    return _disablePlay ? NULL : event;
  case NX_KEYTYPE_NEXT:
  case NX_KEYTYPE_FAST:
    return _disableNext ? NULL : event;
  case NX_KEYTYPE_PREVIOUS:
  case NX_KEYTYPE_REWIND:
    return _disablePrevious ? NULL : event;
  case NX_KEYTYPE_SOUND_UP:
    return _disableVolumeUp ? NULL : event;
  case NX_KEYTYPE_SOUND_DOWN:
    return _disableVolumeDown ? NULL : event;
  case NX_KEYTYPE_MUTE:
    return _disableMute ? NULL : event;
  case NX_KEYTYPE_EJECT:
    return _disableEject ? NULL : event;
  default:
    return event;
  }
}
@end
