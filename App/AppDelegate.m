#import "AppDelegate.h"
#import "GSOpenSave.h"

@interface GSLoggingButton : NSButton
@end

@implementation GSLoggingButton

- (void)mouseDown:(NSEvent *)event
{
  (void)event;
  fprintf(stderr, "Event: MouseDown (%s)\n", [[self title] UTF8String]);
  fflush(stderr);
  if ([self target] != nil && [self action] != NULL) {
    fprintf(stderr, "Event: DispatchAction (%s)\n", [[self title] UTF8String]);
    fflush(stderr);
    id target = [self target];
    SEL action = [self action];
    if ([target respondsToSelector:action]) {
      [target performSelector:action withObject:self];
    }
  }
}

- (void)mouseUp:(NSEvent *)event
{
  (void)event;
  fprintf(stderr, "Event: MouseUp (%s)\n", [[self title] UTF8String]);
  fflush(stderr);
}

@end

@interface AppDelegate ()
@property (nonatomic, retain) NSWindow *window;
@property (nonatomic, retain) NSTextField *modeLabel;
@property (nonatomic, retain) NSTextField *resultLabel;
@property (nonatomic, retain) NSTimer *heartbeatTimer;
@end

@implementation AppDelegate

- (void)dealloc
{
  [_heartbeatTimer invalidate];
  [_heartbeatTimer release];
  [_modeLabel release];
  [_resultLabel release];
  [_window release];
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  (void)notification;
  NSRect frame = NSMakeRect(200, 200, 520, 220);
  self.window = [[[NSWindow alloc] initWithContentRect:frame
                                             styleMask:(NSTitledWindowMask |
                                                        NSClosableWindowMask |
                                                        NSResizableWindowMask)
                                               backing:NSBackingStoreBuffered
                                                 defer:NO] autorelease];
  [self.window setTitle:@"OpenSave Test"];

  NSView *contentView = [self.window contentView];

  NSButton *openButton = [self buttonWithTitle:@"Open Panel"
                                       action:@selector(openPanelAction:)
                                         frame:NSMakeRect(20, 140, 160, 32)];
  [contentView addSubview:openButton];

  NSButton *saveButton = [self buttonWithTitle:@"Save Panel"
                                       action:@selector(savePanelAction:)
                                         frame:NSMakeRect(200, 140, 160, 32)];
  [contentView addSubview:saveButton];

  NSButton *toggleButton = [self buttonWithTitle:@"Toggle Mode"
                                         action:@selector(toggleModeAction:)
                                           frame:NSMakeRect(380, 140, 120, 32)];
  [contentView addSubview:toggleButton];

  NSButton *dirButton = [self buttonWithTitle:@"Set Default Dir"
                                      action:@selector(setDefaultDirAction:)
                                        frame:NSMakeRect(20, 108, 160, 28)];
  [contentView addSubview:dirButton];

  self.modeLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 95, 480, 24)] autorelease];
  [self.modeLabel setEditable:NO];
  [self.modeLabel setBezeled:NO];
  [self.modeLabel setDrawsBackground:NO];
  [contentView addSubview:self.modeLabel];

  self.resultLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 60, 480, 24)] autorelease];
  [self.resultLabel setEditable:NO];
  [self.resultLabel setBezeled:NO];
  [self.resultLabel setDrawsBackground:NO];
  [self.resultLabel setStringValue:@"Result: (none)"];
  [contentView addSubview:self.resultLabel];

  [self updateModeLabel];

  NSTimer *timer = [NSTimer timerWithTimeInterval:2.0
                                           target:self
                                         selector:@selector(heartbeat:)
                                         userInfo:nil
                                          repeats:YES];
  self.heartbeatTimer = timer;
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];


  [self.window makeKeyAndOrderFront:nil];
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action frame:(NSRect)frame
{
  NSButton *button = [[[GSLoggingButton alloc] initWithFrame:frame] autorelease];
  [button setButtonType:NSMomentaryPushInButton];
  [button setTitle:title];
  [button setTarget:self];
  [button setAction:action];
  return button;
}

- (void)openPanelAction:(id)sender
{
  (void)sender;
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  fprintf(stderr, "Open panel requested (mode: %s).\n",
          (GSOpenSaveGetMode() == GSOpenSaveModeGtk) ? "GTK" : "GNUstep");
  fflush(stderr);
  NSInteger result = [panel runModal];
  if (result == NSFileHandlingPanelOKButton) {
    NSArray *filenames = [panel filenames];
    NSString *display = ([filenames count] > 0) ? [filenames componentsJoinedByString:@", "] : @"(none)";
    [self updateResultLabelWithText:[NSString stringWithFormat:@"Open: %@", display]];
    NSLog(@"Open panel result: %@", display);
  } else {
    [self updateResultLabelWithText:@"Open: (cancelled)"];
    NSLog(@"Open panel cancelled");
  }
}

- (void)savePanelAction:(id)sender
{
  (void)sender;
  NSSavePanel *panel = [NSSavePanel savePanel];
  GSOpenSaveMode mode = GSOpenSaveGetMode();
  fprintf(stderr, "Save panel requested (mode: %s).\n",
          (mode == GSOpenSaveModeGtk) ? "GTK" : "GNUstep");
  fflush(stderr);
  if (mode == GSOpenSaveModeGNUstep) {
    fprintf(stderr, "Warning: GNUstep save panel is unstable; using GTK for save.\n");
    fflush(stderr);
    GSOpenSaveSetMode(GSOpenSaveModeGtk);
  }
  NSInteger result = [panel runModal];
  if (mode == GSOpenSaveModeGNUstep) {
    GSOpenSaveSetMode(mode);
  }
  if (result == NSFileHandlingPanelOKButton) {
    NSString *filename = [panel filename];
    NSString *display = filename != nil ? filename : @"(none)";
    [self updateResultLabelWithText:[NSString stringWithFormat:@"Save: %@", display]];
    NSLog(@"Save panel result: %@", display);
  } else {
    [self updateResultLabelWithText:@"Save: (cancelled)"];
    NSLog(@"Save panel cancelled");
  }
}

- (void)toggleModeAction:(id)sender
{
  (void)sender;
  GSOpenSaveMode mode = GSOpenSaveGetMode();
  if (mode == GSOpenSaveModeGtk) {
    GSOpenSaveSetMode(GSOpenSaveModeGNUstep);
  } else {
    GSOpenSaveSetMode(GSOpenSaveModeGtk);
  }
  fprintf(stderr, "Mode toggled to: %s\n",
          (GSOpenSaveGetMode() == GSOpenSaveModeGtk) ? "GTK" : "GNUstep");
  fflush(stderr);
  [self updateModeLabel];
}

- (void)setDefaultDirAction:(id)sender
{
  (void)sender;
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:YES];
  [panel setCanChooseFiles:NO];
  NSInteger result = [panel runModal];
  if (result == NSFileHandlingPanelOKButton) {
    NSString *path = [panel filename];
    if (path != nil) {
      [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"GSOpenSaveDefaultDir"];
      fprintf(stderr, "Default directory set to: %s\n", [path UTF8String]);
      fflush(stderr);
      [self updateResultLabelWithText:[NSString stringWithFormat:@"Default Dir: %@", path]];
    }
  } else {
    fprintf(stderr, "Default directory selection cancelled\n");
    fflush(stderr);
  }
}

- (void)heartbeat:(NSTimer *)timer
{
  (void)timer;
  fprintf(stderr, "Heartbeat (mode: %s)\n",
          (GSOpenSaveGetMode() == GSOpenSaveModeGtk) ? "GTK" : "GNUstep");
  fflush(stderr);
}

- (void)updateModeLabel
{
  NSString *mode = (GSOpenSaveGetMode() == GSOpenSaveModeGtk) ? @"GTK" : @"GNUstep";
  [self.modeLabel setStringValue:[NSString stringWithFormat:@"Mode: %@", mode]];

  NSString *defaultDir = [[NSUserDefaults standardUserDefaults] objectForKey:@"GSOpenSaveDefaultDir"];
  if (defaultDir != nil) {
    fprintf(stderr, "Current default dir: %s\n", [defaultDir UTF8String]);
    fflush(stderr);
  }
}

- (void)updateResultLabelWithText:(NSString *)text
{
  if (text == nil) {
    text = @"Result: (none)";
  }
  [self.resultLabel setStringValue:text];
}

@end
