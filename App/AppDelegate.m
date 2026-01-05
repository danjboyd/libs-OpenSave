#import "AppDelegate.h"
#import "GSOpenSave.h"

@interface AppDelegate ()
@property (nonatomic, retain) NSWindow *window;
@property (nonatomic, retain) NSTextField *modeLabel;
@property (nonatomic, retain) NSTextField *resultLabel;
@end

@implementation AppDelegate

- (void)dealloc
{
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

  [self.window makeKeyAndOrderFront:nil];
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action frame:(NSRect)frame
{
  NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
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
  NSLog(@"Open panel requested (mode: %@).",
        (GSOpenSaveGetMode() == GSOpenSaveModeGtk) ? @"GTK" : @"GNUstep");
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
  NSLog(@"Save panel requested (mode: %@).",
        (GSOpenSaveGetMode() == GSOpenSaveModeGtk) ? @"GTK" : @"GNUstep");
  NSInteger result = [panel runModal];
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
  [self updateModeLabel];
}

- (void)updateModeLabel
{
  NSString *mode = (GSOpenSaveGetMode() == GSOpenSaveModeGtk) ? @"GTK" : @"GNUstep";
  [self.modeLabel setStringValue:[NSString stringWithFormat:@"Mode: %@", mode]];
}

- (void)updateResultLabelWithText:(NSString *)text
{
  if (text == nil) {
    text = @"Result: (none)";
  }
  [self.resultLabel setStringValue:text];
}

@end
