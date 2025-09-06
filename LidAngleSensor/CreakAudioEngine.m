//
//  CreakAudioEngine.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import "CreakAudioEngine.h"
#import <float.h>

// Audio parameter mapping constants (tuned for immediate response)
static const double kDeadzone = 0.10;         // deg/s - minimal deadzone to avoid chatter
static const double kVelocityFull = 10.0;     // deg/s - max creak volume at/under this velocity
static const double kVelocityQuiet = 100.0;   // deg/s - silent by/over this velocity (fast movement)

// Pitch variation constants  
static const double kMinRate = 0.80;          // Minimum varispeed rate (lower pitch for slow movement)
static const double kMaxRate = 1.10;          // Maximum varispeed rate (higher pitch for fast movement)

// Smoothing and timing constants (reduced for low latency)
static const double kAngleSmoothingFactor = 0.85;     // Favor new data heavily for instant reaction
static const double kVelocitySmoothingFactor = 0.9;   // Fast velocity update with slight smoothing
static const double kMovementThreshold = 0.05;        // Detect very small movements (degrees)
static const double kGainRampTimeMs = 1.0;            // Near-instant gain changes
static const double kRateRampTimeMs = 1.0;            // Near-instant pitch/tempo changes
static const double kMovementTimeoutMs = 30.0;        // Slightly shorter timeout
static const double kVelocityDecayFactor = 0.65;      // Mild decay when idle
static const double kAdditionalDecayFactor = 0.85;    // Mild extra decay after timeout

// Rapid flip/jitter suppression (defaults)
// Some sensors can rapidly flip ±4° around a plateau, producing large
// instantaneous velocities but negligible net movement. Detect this
// pattern over a short window and treat it as no movement.
static const NSUInteger kJitterWindowMaxCount = 6;     // up to last 6 samples
static const double kDefaultJitterAmplitudeDeg = 8.5;  // peak-to-peak ≤ 8.5° (≈±4°)
static const double kDefaultJitterTimeWindowMs = 120.0;// samples within last 120ms
static const double kDefaultJitterMinDeltaDeg = 0.3;   // min delta to count a sign flip
static const NSUInteger kDefaultJitterMinSignFlips = 2;// require at least 2 alternations

@interface CreakAudioEngine ()

// Audio engine components
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *creakPlayerNode;
@property (nonatomic, strong) AVAudioUnitVarispeed *varispeadUnit;
@property (nonatomic, strong) AVAudioMixerNode *mixerNode;

// Audio files
@property (nonatomic, strong) AVAudioFile *creakLoopFile;

// State tracking
@property (nonatomic, assign) double lastLidAngle;
@property (nonatomic, assign) double smoothedLidAngle;
@property (nonatomic, assign) double lastUpdateTime;
@property (nonatomic, assign) double smoothedVelocity;
@property (nonatomic, assign) double targetGain;
@property (nonatomic, assign) double targetRate;
@property (nonatomic, assign) double currentGain;
@property (nonatomic, assign) double currentRate;
@property (nonatomic, assign) BOOL isFirstUpdate;
@property (nonatomic, assign) NSTimeInterval lastMovementTime;

// History for jitter detection
@property (nonatomic, strong) NSMutableArray<NSNumber *> *angleHistory;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *timeHistory;

// Hysteresis/plateau stabilizer
@property (nonatomic, assign) double stabilizedAngle;
@property (nonatomic, assign) BOOL hasStabilizedAngle;
@property (nonatomic, assign) NSTimeInterval hysteresisOutsideStart;

@end

@implementation CreakAudioEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _isFirstUpdate = YES;
        _lastUpdateTime = CACurrentMediaTime();
        _lastMovementTime = CACurrentMediaTime();
        _lastLidAngle = 0.0;
        _smoothedLidAngle = 0.0;
        _smoothedVelocity = 0.0;
        _targetGain = 0.0;
        _targetRate = 1.0;
        _currentGain = 0.0;
        _currentRate = 1.0;
        _angleHistory = [NSMutableArray arrayWithCapacity:kJitterWindowMaxCount];
        _timeHistory = [NSMutableArray arrayWithCapacity:kJitterWindowMaxCount];
        _hasStabilizedAngle = NO;
        _stabilizedAngle = 0.0;
        _hysteresisOutsideStart = 0.0;

        // Jitter defaults
        _jitterFilterEnabled = YES;
        _jitterAmplitudeDeg = kDefaultJitterAmplitudeDeg;
        _jitterTimeWindowMs = kDefaultJitterTimeWindowMs;
        _jitterMinDeltaDeg = kDefaultJitterMinDeltaDeg;
        _jitterMinSignFlips = kDefaultJitterMinSignFlips;
        
        if (![self setupAudioEngine]) {
            NSLog(@"[CreakAudioEngine] Failed to setup audio engine");
            return nil;
        }
        
        if (![self loadAudioFiles]) {
            NSLog(@"[CreakAudioEngine] Failed to load audio files");
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self stopEngine];
}

- (void)resetJitterHistory {
    [self.angleHistory removeAllObjects];
    [self.timeHistory removeAllObjects];
}

#pragma mark - Audio Engine Setup

- (BOOL)setupAudioEngine {
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    // Create audio nodes
    self.creakPlayerNode = [[AVAudioPlayerNode alloc] init];
    self.varispeadUnit = [[AVAudioUnitVarispeed alloc] init];
    self.mixerNode = self.audioEngine.mainMixerNode;
    
    // Attach nodes to engine
    [self.audioEngine attachNode:self.creakPlayerNode];
    [self.audioEngine attachNode:self.varispeadUnit];
    
    // Audio connections will be made after loading the file to use its native format
    return YES;
}

- (BOOL)loadAudioFiles {
    NSBundle *bundle = [NSBundle mainBundle];
    
    // Load creak loop file
    NSString *creakPath = [bundle pathForResource:@"CREAK_LOOP" ofType:@"wav"];
    if (!creakPath) {
        NSLog(@"[CreakAudioEngine] Could not find CREAK_LOOP.wav");
        return NO;
    }
    
    NSError *error;
    NSURL *creakURL = [NSURL fileURLWithPath:creakPath];
    self.creakLoopFile = [[AVAudioFile alloc] initForReading:creakURL error:&error];
    if (!self.creakLoopFile) {
        NSLog(@"[CreakAudioEngine] Failed to load CREAK_LOOP.wav: %@", error.localizedDescription);
        return NO;
    }
    
    // Connect the audio graph using the file's native format
    AVAudioFormat *fileFormat = self.creakLoopFile.processingFormat;
    
    // Connect audio graph: CreakPlayer -> Varispeed -> Mixer
    [self.audioEngine connect:self.creakPlayerNode to:self.varispeadUnit format:fileFormat];
    [self.audioEngine connect:self.varispeadUnit to:self.mixerNode format:fileFormat];
    return YES;
}

#pragma mark - Engine Control

- (void)startEngine {
    if (self.isEngineRunning) {
        return;
    }
    
    NSError *error;
    if (![self.audioEngine startAndReturnError:&error]) {
        NSLog(@"[CreakAudioEngine] Failed to start audio engine: %@", error.localizedDescription);
        return;
    }
    
    // Start looping the creak sound
    [self startCreakLoop];
}

- (void)stopEngine {
    if (!self.isEngineRunning) {
        return;
    }
    
    [self.creakPlayerNode stop];
    [self.audioEngine stop];
}

- (BOOL)isEngineRunning {
    return self.audioEngine.isRunning;
}

#pragma mark - Creak Loop Management

- (void)startCreakLoop {
    if (!self.creakPlayerNode || !self.creakLoopFile) {
        return;
    }
    
    // Reset file position to beginning
    self.creakLoopFile.framePosition = 0;
    
    // Schedule the creak loop to play continuously
    AVAudioFrameCount frameCount = (AVAudioFrameCount)self.creakLoopFile.length;
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.creakLoopFile.processingFormat
                                                             frameCapacity:frameCount];
    
    NSError *error;
    if (![self.creakLoopFile readIntoBuffer:buffer error:&error]) {
        NSLog(@"[CreakAudioEngine] Failed to read creak loop into buffer: %@", error.localizedDescription);
        return;
    }
    
    [self.creakPlayerNode scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    [self.creakPlayerNode play];
    
    // Set initial volume to 0 (will be controlled by gain)
    self.creakPlayerNode.volume = 0.0;
}

#pragma mark - Velocity Calculation and Parameter Mapping

- (void)updateWithLidAngle:(double)lidAngle {
    double currentTime = CACurrentMediaTime();
    
    if (self.isFirstUpdate) {
        self.lastLidAngle = lidAngle;
        self.smoothedLidAngle = lidAngle;
        self.stabilizedAngle = lidAngle;
        self.hasStabilizedAngle = YES;
        self.lastUpdateTime = currentTime;
        self.lastMovementTime = currentTime;
        self.isFirstUpdate = NO;
        return;
    }
    
    // Calculate time delta
    double deltaTime = currentTime - self.lastUpdateTime;
    if (deltaTime <= 0 || deltaTime > 1.0) {
        // Skip if time delta is invalid or too large (likely app was backgrounded)
        self.lastUpdateTime = currentTime;
        return;
    }

    BOOL isJitter = NO;
    if (self.jitterFilterEnabled) {
        // Maintain short history for jitter detection
        [self.angleHistory addObject:@(lidAngle)];
        [self.timeHistory addObject:@(currentTime)];
        // Trim to window by time
        double windowStart = currentTime - (self.jitterTimeWindowMs / 1000.0);
        while (self.timeHistory.count > 0 && self.timeHistory.firstObject.doubleValue < windowStart) {
            [self.angleHistory removeObjectAtIndex:0];
            [self.timeHistory removeObjectAtIndex:0];
        }
        // Trim to max count
        while (self.angleHistory.count > kJitterWindowMaxCount) {
            [self.angleHistory removeObjectAtIndex:0];
            [self.timeHistory removeObjectAtIndex:0];
        }

        // Detect rapid flip jitter pattern and freeze angle if present
        if (self.angleHistory.count >= 4) {
            double minA = DBL_MAX, maxA = -DBL_MAX;
            for (NSNumber *n in self.angleHistory) {
                double v = n.doubleValue;
                if (v < minA) minA = v;
                if (v > maxA) maxA = v;
            }
            double peakToPeak = maxA - minA;
            if (peakToPeak <= self.jitterAmplitudeDeg) {
                // Count sign alternations of successive deltas
                NSInteger flips = 0;
                double prevSign = 0.0;
                for (NSUInteger i = 1; i < self.angleHistory.count; i++) {
                    double d = self.angleHistory[i].doubleValue - self.angleHistory[i-1].doubleValue;
                    if (fabs(d) < self.jitterMinDeltaDeg) continue;
                    double s = (d > 0.0) ? 1.0 : -1.0;
                    if (prevSign == 0.0) {
                        prevSign = s;
                    } else if (s != prevSign) {
                        flips++;
                        prevSign = s;
                    }
                }
                if (flips >= (NSInteger)self.jitterMinSignFlips) {
                    isJitter = YES;
                }
            }
        }
        if (isJitter) {
            // Treat as no movement: freeze to last stable (hysteresis) angle
            lidAngle = self.hasStabilizedAngle ? self.stabilizedAngle : self.lastLidAngle;
        }
    }

    // Apply hysteresis/plateau stabilization to suppress ±small back-and-forth around a center
    // Schmitt-trigger style with persistence
    static const double kHystInnerDeg = 2.0;    // within this band -> clamp to stable
    static const double kHystOuterDeg = 5.0;    // outside this band -> update immediately
    static const double kHystPersistMs = 80.0;  // otherwise require persistence before updating

    if (!self.hasStabilizedAngle) {
        self.stabilizedAngle = lidAngle;
        self.hasStabilizedAngle = YES;
    } else {
        double diff = lidAngle - self.stabilizedAngle;
        double ad = fabs(diff);
        if (ad <= kHystInnerDeg) {
            // Inside inner band: keep stable, reset persistence timer
            self.hysteresisOutsideStart = 0.0;
            lidAngle = self.stabilizedAngle;
        } else if (ad >= kHystOuterDeg) {
            // Large change: accept immediately
            self.stabilizedAngle = lidAngle;
            self.hysteresisOutsideStart = 0.0;
        } else {
            // Between inner and outer: require persistence
            if (self.hysteresisOutsideStart == 0.0) {
                self.hysteresisOutsideStart = currentTime;
            }
            double elapsed = currentTime - self.hysteresisOutsideStart;
            if (elapsed >= (kHystPersistMs / 1000.0)) {
                self.stabilizedAngle = lidAngle;
                self.hysteresisOutsideStart = 0.0;
            } else {
                lidAngle = self.stabilizedAngle;
            }
        }
    }
    
    // Stage 1: Smooth the raw angle input to eliminate sensor jitter
    self.smoothedLidAngle = (kAngleSmoothingFactor * lidAngle) + 
                           ((1.0 - kAngleSmoothingFactor) * self.smoothedLidAngle);
    
    // Stage 2: Calculate velocity from smoothed angle data
    double deltaAngle = self.smoothedLidAngle - self.lastLidAngle;
    double instantVelocity;
    
    // Apply movement threshold to eliminate remaining noise
    if (fabs(deltaAngle) < kMovementThreshold) {
        instantVelocity = 0.0;
    } else {
        instantVelocity = fabs(deltaAngle / deltaTime);
        self.lastLidAngle = self.smoothedLidAngle;
    }
    
    // Stage 3: Apply velocity smoothing and decay
    if (!isJitter && instantVelocity > 0.0) {
        // Real movement detected - apply moderate smoothing
        self.smoothedVelocity = (kVelocitySmoothingFactor * instantVelocity) + 
                               ((1.0 - kVelocitySmoothingFactor) * self.smoothedVelocity);
        self.lastMovementTime = currentTime;
    } else {
        // No movement detected - apply fast decay
        self.smoothedVelocity *= kVelocityDecayFactor;
    }
    
    // Additional decay if no movement for extended period
    double timeSinceMovement = currentTime - self.lastMovementTime;
    if (timeSinceMovement > (kMovementTimeoutMs / 1000.0)) {
        self.smoothedVelocity *= kAdditionalDecayFactor;
    }
    
    // Update state for next iteration
    self.lastUpdateTime = currentTime;
    
    // Apply velocity-based parameter mapping
    [self updateAudioParametersWithVelocity:self.smoothedVelocity];
}

- (void)setAngularVelocity:(double)velocity {
    self.smoothedVelocity = velocity;
    [self updateAudioParametersWithVelocity:velocity];
}

- (void)updateAudioParametersWithVelocity:(double)velocity {
    double speed = velocity; // Velocity is already absolute
    
    // Calculate target gain: slow movement = loud creak, fast movement = quiet/silent
    double gain;
    if (speed < kDeadzone) {
        gain = 0.0; // Below deadzone: no sound
    } else {
        // Use inverted smoothstep curve for natural volume response
        double e0 = fmax(0.0, kVelocityFull - 0.5);
        double e1 = kVelocityQuiet + 0.5;
        double t = fmin(1.0, fmax(0.0, (speed - e0) / (e1 - e0)));
        double s = t * t * (3.0 - 2.0 * t); // smoothstep function
        gain = 1.0 - s; // invert: slow = loud, fast = quiet
        gain = fmax(0.0, fmin(1.0, gain));
    }
    
    // Calculate target pitch/tempo rate based on movement speed
    double normalizedVelocity = fmax(0.0, fmin(1.0, speed / kVelocityQuiet));
    double rate = kMinRate + normalizedVelocity * (kMaxRate - kMinRate);
    rate = fmax(kMinRate, fmin(kMaxRate, rate));
    
    // Store targets for smooth ramping
    self.targetGain = gain;
    self.targetRate = rate;
    
    // Apply smooth parameter transitions
    [self rampToTargetParameters];
}

// Helper function for parameter ramping
- (double)rampValue:(double)current toward:(double)target withDeltaTime:(double)dt timeConstantMs:(double)tauMs {
    double alpha = fmin(1.0, dt / (tauMs / 1000.0)); // linear ramp coefficient
    return current + (target - current) * alpha;
}

- (void)rampToTargetParameters {
    if (!self.isEngineRunning) {
        return;
    }
    
    // Calculate delta time for ramping
    static double lastRampTime = 0;
    double currentTime = CACurrentMediaTime();
    if (lastRampTime == 0) lastRampTime = currentTime;
    double deltaTime = currentTime - lastRampTime;
    lastRampTime = currentTime;
    
    // Ramp current values toward targets for smooth transitions
    self.currentGain = [self rampValue:self.currentGain toward:self.targetGain withDeltaTime:deltaTime timeConstantMs:kGainRampTimeMs];
    self.currentRate = [self rampValue:self.currentRate toward:self.targetRate withDeltaTime:deltaTime timeConstantMs:kRateRampTimeMs];
    
    // Apply ramped values to audio nodes (2x multiplier for audible volume)
    self.creakPlayerNode.volume = (float)(self.currentGain * 2.0);
    self.varispeadUnit.rate = (float)self.currentRate;
}

#pragma mark - Property Accessors

- (double)currentVelocity {
    return self.smoothedVelocity;
}

- (double)currentGain {
    return _currentGain;
}

- (double)currentRate {
    return _currentRate;
}

- (double)currentStabilizedAngle {
    return self.hasStabilizedAngle ? self.stabilizedAngle : self.smoothedLidAngle;
}

@end
