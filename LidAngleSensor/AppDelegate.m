//
//  AppDelegate.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import "AppDelegate.h"
#import "LidAngleSensor.h"
#import "CreakAudioEngine.h"
#import "ThereminAudioEngine.h"
#import "NSLabel.h"

typedef NS_ENUM(NSInteger, AudioMode) {
    AudioModeCreak,
    AudioModeTheremin
};

@interface AppDelegate ()
@property (strong, nonatomic) LidAngleSensor *lidSensor;
@property (strong, nonatomic) CreakAudioEngine *creakAudioEngine;
@property (strong, nonatomic) ThereminAudioEngine *thereminAudioEngine;
@property (strong, nonatomic) NSLabel *angleLabel;
@property (strong, nonatomic) NSLabel *statusLabel;
@property (strong, nonatomic) NSLabel *velocityLabel;
@property (strong, nonatomic) NSLabel *audioStatusLabel;
@property (strong, nonatomic) NSButton *audioToggleButton;
@property (strong, nonatomic) NSSegmentedControl *modeSelector;
@property (strong, nonatomic) NSLabel *modeLabel;
@property (strong, nonatomic) NSTimer *updateTimer;
@property (nonatomic, assign) AudioMode currentAudioMode;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.currentAudioMode = AudioModeCreak; // Default to creak mode
    [self createWindow];
    [self initializeLidSensor];
    [self initializeAudioEngines];
    [self startUpdatingDisplay];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.lidSensor stopLidAngleUpdates];
    [self.creakAudioEngine stopEngine];
    [self.thereminAudioEngine stopEngine];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)createWindow {
    // Create the main window (taller to accommodate mode + jitter controls)
    NSRect windowFrame = NSMakeRect(100, 100, 500, 650);
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:NSWindowStyleMaskTitled |
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"MacBook Lid Angle Sensor"];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];

    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    [self.window setContentView:contentView];

    // Angle label
    self.angleLabel = [[NSLabel alloc] init];
    [self.angleLabel setStringValue:@"Initializing..."];
    [self.angleLabel setFont:[NSFont monospacedDigitSystemFontOfSize:48 weight:NSFontWeightLight]];
    [self.angleLabel setAlignment:NSTextAlignmentCenter];
    [self.angleLabel setTextColor:[NSColor systemBlueColor]];
    [contentView addSubview:self.angleLabel];

    // Velocity label
    self.velocityLabel = [[NSLabel alloc] init];
    [self.velocityLabel setStringValue:@"Velocity: 00 deg/s"];
    [self.velocityLabel setFont:[NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightRegular]];
    [self.velocityLabel setAlignment:NSTextAlignmentCenter];
    [contentView addSubview:self.velocityLabel];

    // Status label
    self.statusLabel = [[NSLabel alloc] init];
    [self.statusLabel setStringValue:@"Detecting sensor..."];
    [self.statusLabel setFont:[NSFont systemFontOfSize:14]];
    [self.statusLabel setAlignment:NSTextAlignmentCenter];
    [self.statusLabel setTextColor:[NSColor secondaryLabelColor]];
    [contentView addSubview:self.statusLabel];

    // Audio toggle
    self.audioToggleButton = [[NSButton alloc] init];
    [self.audioToggleButton setTitle:@"Start Audio"];
    [self.audioToggleButton setBezelStyle:NSBezelStyleRounded];
    [self.audioToggleButton setTarget:self];
    [self.audioToggleButton setAction:@selector(toggleAudio:)];
    [self.audioToggleButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.audioToggleButton];

    // Audio status
    self.audioStatusLabel = [[NSLabel alloc] init];
    [self.audioStatusLabel setStringValue:@""];
    [self.audioStatusLabel setFont:[NSFont systemFontOfSize:14]];
    [self.audioStatusLabel setAlignment:NSTextAlignmentCenter];
    [self.audioStatusLabel setTextColor:[NSColor secondaryLabelColor]];
    [contentView addSubview:self.audioStatusLabel];
    
    // Create mode label
    self.modeLabel = [[NSLabel alloc] init];
    [self.modeLabel setStringValue:@"Audio Mode:"];
    [self.modeLabel setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium]];
    [self.modeLabel setAlignment:NSTextAlignmentCenter];
    [self.modeLabel setTextColor:[NSColor labelColor]];
    [contentView addSubview:self.modeLabel];
    
    // Create mode selector
    self.modeSelector = [[NSSegmentedControl alloc] init];
    [self.modeSelector setSegmentCount:2];
    [self.modeSelector setLabel:@"Creak" forSegment:0];
    [self.modeSelector setLabel:@"Theremin" forSegment:1];
    [self.modeSelector setSelectedSegment:0]; // Default to creak
    [self.modeSelector setTarget:self];
    [self.modeSelector setAction:@selector(modeChanged:)];
    [self.modeSelector setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.modeSelector];
    
    // Set up auto layout constraints

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Angle label
        [self.angleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:40],
        [self.angleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.angleLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Velocity label
        [self.velocityLabel.topAnchor constraintEqualToAnchor:self.angleLabel.bottomAnchor constant:15],
        [self.velocityLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.velocityLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Status label
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.velocityLabel.bottomAnchor constant:15],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.statusLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Audio toggle
        [self.audioToggleButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:15],
        [self.audioToggleButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],

        // Audio status
        [self.audioStatusLabel.topAnchor constraintEqualToAnchor:self.audioToggleButton.bottomAnchor constant:10],
        [self.audioStatusLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.audioStatusLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Mode label
        [self.modeLabel.topAnchor constraintEqualToAnchor:self.audioStatusLabel.bottomAnchor constant:25],
        [self.modeLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.modeLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],
        
        // Mode selector
        [self.modeSelector.topAnchor constraintEqualToAnchor:self.modeLabel.bottomAnchor constant:10],
        [self.modeSelector.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.modeSelector.widthAnchor constraintEqualToConstant:200],
        [self.modeSelector.heightAnchor constraintEqualToConstant:28],
    ]];
}

- (void)initializeLidSensor {
    self.lidSensor = [[LidAngleSensor alloc] init];
    if (self.lidSensor.isAvailable) {
        [self.statusLabel setStringValue:@"Sensor detected - Reading angle..."];
        [self.statusLabel setTextColor:[NSColor systemGreenColor]];
    } else {
        [self.statusLabel setStringValue:@"Lid angle sensor not available on this device"];
        [self.statusLabel setTextColor:[NSColor systemRedColor]];
        [self.angleLabel setStringValue:@"Not Available"];
        [self.angleLabel setTextColor:[NSColor systemRedColor]];
    }
}

- (void)initializeAudioEngines {
    self.creakAudioEngine = [[CreakAudioEngine alloc] init];
    self.thereminAudioEngine = [[ThereminAudioEngine alloc] init];
    if (self.creakAudioEngine && self.thereminAudioEngine) {
        [self.audioStatusLabel setStringValue:@""];
    } else {
        [self.audioStatusLabel setStringValue:@"Audio initialization failed"];
        [self.audioStatusLabel setTextColor:[NSColor systemRedColor]];
        [self.audioToggleButton setEnabled:NO];
    }
}

- (IBAction)toggleAudio:(id)sender {
    id currentEngine = [self currentAudioEngine];
    if (!currentEngine) {
        return;
    }
    
    if ([currentEngine isEngineRunning]) {
        [currentEngine stopEngine];
        [self.audioToggleButton setTitle:@"Start Audio"];
        [self.audioStatusLabel setStringValue:@""];
    } else {
        [currentEngine startEngine];
        [self.audioToggleButton setTitle:@"Stop Audio"];
        [self.audioStatusLabel setStringValue:@""];
    }
}

- (IBAction)modeChanged:(id)sender {
    NSSegmentedControl *control = (NSSegmentedControl *)sender;
    AudioMode newMode = (AudioMode)control.selectedSegment;
    
    // Stop current engine if running
    id currentEngine = [self currentAudioEngine];
    BOOL wasRunning = [currentEngine isEngineRunning];
    if (wasRunning) {
        [currentEngine stopEngine];
    }
    
    // Update mode
    self.currentAudioMode = newMode;
    
    // Start new engine if the previous one was running
    if (wasRunning) {
        id newEngine = [self currentAudioEngine];
        [newEngine startEngine];
        [self.audioToggleButton setTitle:@"Stop Audio"];
    } else {
        [self.audioToggleButton setTitle:@"Start Audio"];
    }
    
    [self.audioStatusLabel setStringValue:@""];
}

- (id)currentAudioEngine {
    switch (self.currentAudioMode) {
        case AudioModeCreak:
            return self.creakAudioEngine;
        case AudioModeTheremin:
            return self.thereminAudioEngine;
        default:
            return self.creakAudioEngine;
    }
}

- (void)startUpdatingDisplay {
    // Faster updates (100Hz) to minimize control latency
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.010
                                                        target:self
                                                      selector:@selector(updateAngleDisplay)
                                                      userInfo:nil
                                                       repeats:YES];
    self.updateTimer.tolerance = 0.0;
    [[NSRunLoop mainRunLoop] addTimer:self.updateTimer forMode:NSRunLoopCommonModes];
}

-(void)updateAngleDisplay {
    if (!self.lidSensor.isAvailable) return;
    double rawAngle = [self.lidSensor lidAngle];
    if (rawAngle == -2.0) {
        [self.angleLabel setStringValue:@"Read Error"];
        [self.angleLabel setTextColor:[NSColor systemOrangeColor]];
        [self.statusLabel setStringValue:@"Failed to read sensor data"];
        [self.statusLabel setTextColor:[NSColor systemOrangeColor]];
        return;
    }

    // Update engine first, then display stabilized angle (creak) or raw (theremin)
    double displayAngle = rawAngle;
    if (self.currentAudioMode == AudioModeCreak) {
        if (self.creakAudioEngine) {
            [self.creakAudioEngine updateWithLidAngle:rawAngle];
            displayAngle = self.creakAudioEngine.currentStabilizedAngle;
            double velocity = self.creakAudioEngine.currentVelocity;
            int rv = (int)llround(velocity);
            if (rv < 100) {
                [self.velocityLabel setStringValue:[NSString stringWithFormat:@"Velocity: %02d deg/s", rv]];
            } else {
                [self.velocityLabel setStringValue:[NSString stringWithFormat:@"Velocity: %d deg/s", rv]];
            }
            if (self.creakAudioEngine.isEngineRunning) {
                [self.audioStatusLabel setStringValue:[NSString stringWithFormat:@"Gain: %.2f, Rate: %.2f", self.creakAudioEngine.currentGain, self.creakAudioEngine.currentRate]];
            }
        }
    } else { // Theremin
        if (self.thereminAudioEngine) {
            [self.thereminAudioEngine updateWithLidAngle:rawAngle];
            double velocity = self.thereminAudioEngine.currentVelocity;
            int rv = (int)llround(velocity);
            if (rv < 100) {
                [self.velocityLabel setStringValue:[NSString stringWithFormat:@"Velocity: %02d deg/s", rv]];
            } else {
                [self.velocityLabel setStringValue:[NSString stringWithFormat:@"Velocity: %d deg/s", rv]];
            }
            if (self.thereminAudioEngine.isEngineRunning) {
                [self.audioStatusLabel setStringValue:[NSString stringWithFormat:@"Freq: %.1f Hz, Vol: %.2f", self.thereminAudioEngine.currentFrequency, self.thereminAudioEngine.currentVolume]];
            }
        }
    }
    [self.angleLabel setStringValue:[NSString stringWithFormat:@"%.1f°", displayAngle]];
    [self.angleLabel setTextColor:[NSColor systemBlueColor]];

    NSString *status;
    if (displayAngle < 5.0) status = @"Lid is closed";
    else if (displayAngle < 45.0) status = @"Lid slightly open";
    else if (displayAngle < 90.0) status = @"Lid partially open";
    else if (displayAngle < 135.0) status = @"Lid mostly open";
    else status = @"Lid fully open";
    [self.statusLabel setStringValue:status];
    [self.statusLabel setTextColor:[NSColor secondaryLabelColor]];
}

@end
