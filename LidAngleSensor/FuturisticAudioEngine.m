//
//  FuturisticAudioEngine.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import "FuturisticAudioEngine.h"
#import <AudioToolbox/AudioToolbox.h>

// Lightsaber parameter mapping constants
static const double kMinFrequency = 80.0;          // Hz - deep hum (closed lid)
static const double kMaxFrequency = 200.0;         // Hz - higher hum (open lid)
static const double kMinAngle = 0.0;               // degrees - closed lid
static const double kMaxAngle = 135.0;             // degrees - fully open lid

// Volume control constants - continuous lightsaber hum with velocity modulation
static const double kBaseVolume = 0.8;             // Base volume when at rest
static const double kVelocityVolumeBoost = 0.2;    // Additional volume boost from movement
static const double kVelocityFull = 10.0;          // deg/s - max volume boost at/under this velocity
static const double kVelocityQuiet = 100.0;        // deg/s - no volume boost over this velocity

// Lightsaber vibrato and harmonics
static const double kVibratoFrequency = 6.0;       // Hz - subtle vibrato rate
static const double kVibratoDepth = 0.05;          // Vibrato depth as fraction of frequency (5%)
static const double kHarmonicStrength = 0.3;       // Strength of harmonic content

// Smoothing constants
static const double kAngleSmoothingFactor = 0.2;       // Smooth frequency changes for lightsaber
static const double kVelocitySmoothingFactor = 0.3;    // Moderate smoothing for velocity
static const double kFrequencyRampTimeMs = 50.0;       // Frequency ramping time constant
static const double kVolumeRampTimeMs = 80.0;          // Volume ramping time constant
static const double kMovementThreshold = 0.3;          // Minimum angle change to register movement
static const double kMovementTimeoutMs = 150.0;        // Time before velocity decay
static const double kVelocityDecayFactor = 0.8;        // Decay rate when no movement
static const double kAdditionalDecayFactor = 0.9;      // Additional decay after timeout

// Audio constants
static const double kSampleRate = 44100.0;
static const UInt32 kBufferSize = 512;

@interface FuturisticAudioEngine ()

// Audio engine components
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioSourceNode *sourceNode;
@property (nonatomic, strong) AVAudioMixerNode *mixerNode;

// State tracking
@property (nonatomic, assign) double lastLidAngle;
@property (nonatomic, assign) double smoothedLidAngle;
@property (nonatomic, assign) double lastUpdateTime;
@property (nonatomic, assign) double smoothedVelocity;
@property (nonatomic, assign) double targetFrequency;
@property (nonatomic, assign) double targetVolume;
@property (nonatomic, assign) double currentFrequency;
@property (nonatomic, assign) double currentVolume;
@property (nonatomic, assign) BOOL isFirstUpdate;
@property (nonatomic, assign) NSTimeInterval lastMovementTime;

// Oscillator phases for lightsaber sound generation
@property (nonatomic, assign) double fundamentalPhase;
@property (nonatomic, assign) double harmonicPhase;
@property (nonatomic, assign) double vibratoPhase;

@end

@implementation FuturisticAudioEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _isFirstUpdate = YES;
        _lastUpdateTime = CACurrentMediaTime();
        _lastMovementTime = CACurrentMediaTime();
        _lastLidAngle = 0.0;
        _smoothedLidAngle = 0.0;
        _smoothedVelocity = 0.0;
        _targetFrequency = kMinFrequency;
        _targetVolume = kBaseVolume;
        _currentFrequency = kMinFrequency;
        _currentVolume = kBaseVolume;
        _fundamentalPhase = 0.0;
        _harmonicPhase = 0.0;
        _vibratoPhase = 0.0;
        
        if (![self setupAudioEngine]) {
            NSLog(@"[FuturisticAudioEngine] Failed to setup audio engine");
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self stopEngine];
}

#pragma mark - Audio Engine Setup

- (BOOL)setupAudioEngine {
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.mixerNode = self.audioEngine.mainMixerNode;
    
    // Create audio format for our synthesis
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                             sampleRate:kSampleRate
                                                               channels:1
                                                            interleaved:NO];
    
    // Create source node for lightsaber sound generation
    __weak typeof(self) weakSelf = self;
    self.sourceNode = [[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL * _Nonnull isSilence, const AudioTimeStamp * _Nonnull timestamp, AVAudioFrameCount frameCount, AudioBufferList * _Nonnull outputData) {
        return [weakSelf renderLightsaberSound:isSilence timestamp:timestamp frameCount:frameCount outputData:outputData];
    }];
    
    // Attach and connect the source node directly to mixer (no filtering needed)
    [self.audioEngine attachNode:self.sourceNode];
    [self.audioEngine connect:self.sourceNode to:self.mixerNode format:format];
    
    return YES;
}

#pragma mark - Engine Control

- (void)startEngine {
    if (self.isEngineRunning) {
        return;
    }
    
    NSError *error;
    if (![self.audioEngine startAndReturnError:&error]) {
        NSLog(@"[FuturisticAudioEngine] Failed to start audio engine: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"[FuturisticAudioEngine] Started futuristic engine");
}

- (void)stopEngine {
    if (!self.isEngineRunning) {
        return;
    }
    
    [self.audioEngine stop];
    NSLog(@"[FuturisticAudioEngine] Stopped futuristic engine");
}

- (BOOL)isEngineRunning {
    return self.audioEngine.isRunning;
}

#pragma mark - Sound Generation

- (OSStatus)renderLightsaberSound:(BOOL *)isSilence
                        timestamp:(const AudioTimeStamp *)timestamp
                       frameCount:(AVAudioFrameCount)frameCount
                       outputData:(AudioBufferList *)outputData {
    
    float *output = (float *)outputData->mBuffers[0].mData;
    
    // Always generate sound (continuous lightsaber hum)
    *isSilence = NO;
    
    // Calculate phase increments
    double vibratoPhaseIncrement = 2.0 * M_PI * kVibratoFrequency / kSampleRate;
    
    // Generate lightsaber hum samples
    for (AVAudioFrameCount i = 0; i < frameCount; i++) {
        // Calculate vibrato modulation
        double vibratoModulation = sin(self.vibratoPhase) * kVibratoDepth;
        double modulatedFrequency = self.currentFrequency * (1.0 + vibratoModulation);
        
        // Calculate phase increments for fundamental and harmonics
        double fundamentalPhaseIncrement = 2.0 * M_PI * modulatedFrequency / kSampleRate;
        double harmonicPhaseIncrement = 2.0 * M_PI * (modulatedFrequency * 3.0) / kSampleRate; // Third harmonic
        
        // Generate fundamental frequency (main hum)
        double fundamental = sin(self.fundamentalPhase);
        
        // Generate third harmonic for richer sound
        double harmonic = sin(self.harmonicPhase) * kHarmonicStrength;
        
        // Combine fundamental and harmonic
        double lightsaberHum = fundamental + harmonic;
        
        // Apply volume and prevent clipping
        output[i] = (float)(lightsaberHum * self.currentVolume * 0.4);
        
        // Update phases
        self.fundamentalPhase += fundamentalPhaseIncrement;
        self.harmonicPhase += harmonicPhaseIncrement;
        self.vibratoPhase += vibratoPhaseIncrement;
        
        // Wrap phases to prevent accumulation of floating point errors
        if (self.fundamentalPhase >= 2.0 * M_PI) {
            self.fundamentalPhase -= 2.0 * M_PI;
        }
        if (self.harmonicPhase >= 2.0 * M_PI) {
            self.harmonicPhase -= 2.0 * M_PI;
        }
        if (self.vibratoPhase >= 2.0 * M_PI) {
            self.vibratoPhase -= 2.0 * M_PI;
        }
    }
    
    return noErr;
}

#pragma mark - Lid Angle Processing

- (void)updateWithLidAngle:(double)lidAngle {
    double currentTime = CACurrentMediaTime();
    
    if (self.isFirstUpdate) {
        self.lastLidAngle = lidAngle;
        self.smoothedLidAngle = lidAngle;
        self.lastUpdateTime = currentTime;
        self.lastMovementTime = currentTime;
        self.isFirstUpdate = NO;
        
        // Set initial parameters based on angle
        [self updateTargetParametersWithAngle:lidAngle velocity:0.0];
        return;
    }
    
    // Calculate time delta
    double deltaTime = currentTime - self.lastUpdateTime;
    if (deltaTime <= 0 || deltaTime > 1.0) {
        // Skip if time delta is invalid or too large
        self.lastUpdateTime = currentTime;
        return;
    }
    
    // Stage 1: Smooth the raw angle input
    self.smoothedLidAngle = (kAngleSmoothingFactor * lidAngle) + 
                           ((1.0 - kAngleSmoothingFactor) * self.smoothedLidAngle);
    
    // Stage 2: Calculate velocity from smoothed angle data
    double deltaAngle = self.smoothedLidAngle - self.lastLidAngle;
    double instantVelocity;
    
    // Apply movement threshold
    if (fabs(deltaAngle) < kMovementThreshold) {
        instantVelocity = 0.0;
    } else {
        instantVelocity = fabs(deltaAngle / deltaTime);
        self.lastLidAngle = self.smoothedLidAngle;
    }
    
    // Stage 3: Apply velocity smoothing and decay
    if (instantVelocity > 0.0) {
        self.smoothedVelocity = (kVelocitySmoothingFactor * instantVelocity) + 
                               ((1.0 - kVelocitySmoothingFactor) * self.smoothedVelocity);
        self.lastMovementTime = currentTime;
    } else {
        self.smoothedVelocity *= kVelocityDecayFactor;
    }
    
    // Additional decay if no movement for extended period
    double timeSinceMovement = currentTime - self.lastMovementTime;
    if (timeSinceMovement > (kMovementTimeoutMs / 1000.0)) {
        self.smoothedVelocity *= kAdditionalDecayFactor;
    }
    
    // Update state for next iteration
    self.lastUpdateTime = currentTime;
    
    // Update target parameters
    [self updateTargetParametersWithAngle:self.smoothedLidAngle velocity:self.smoothedVelocity];
    
    // Apply smooth parameter transitions
    [self rampToTargetParameters];
}

- (void)setAngularVelocity:(double)velocity {
    self.smoothedVelocity = velocity;
    [self updateTargetParametersWithAngle:self.smoothedLidAngle velocity:velocity];
    [self rampToTargetParameters];
}

- (void)updateTargetParametersWithAngle:(double)angle velocity:(double)velocity {
    // Map angle to lightsaber hum frequency using exponential curve
    double normalizedAngle = fmax(0.0, fmin(1.0, (angle - kMinAngle) / (kMaxAngle - kMinAngle)));
    
    // Use exponential mapping for more musical frequency distribution
    double frequencyRatio = pow(normalizedAngle, 0.6); // Smoother curve for lightsaber
    self.targetFrequency = kMinFrequency + frequencyRatio * (kMaxFrequency - kMinFrequency);
    
    // Calculate continuous volume with velocity-based boost
    double velocityBoost = 0.0;
    if (velocity > 0.0) {
        // Use smoothstep curve for natural volume boost response
        double e0 = 0.0;
        double e1 = kVelocityQuiet;
        double t = fmin(1.0, fmax(0.0, (velocity - e0) / (e1 - e0)));
        double s = t * t * (3.0 - 2.0 * t); // smoothstep function
        velocityBoost = (1.0 - s) * kVelocityVolumeBoost; // invert: slow = more boost, fast = less boost
    }
    
    // Combine base volume with velocity boost
    self.targetVolume = kBaseVolume + velocityBoost;
    self.targetVolume = fmax(0.0, fmin(1.0, self.targetVolume));
}

// Helper function for parameter ramping
- (double)rampValue:(double)current toward:(double)target withDeltaTime:(double)dt timeConstantMs:(double)tauMs {
    double alpha = fmin(1.0, dt / (tauMs / 1000.0));
    return current + (target - current) * alpha;
}

- (void)rampToTargetParameters {
    // Calculate delta time for ramping
    static double lastRampTime = 0;
    double currentTime = CACurrentMediaTime();
    if (lastRampTime == 0) lastRampTime = currentTime;
    double deltaTime = currentTime - lastRampTime;
    lastRampTime = currentTime;
    
    // Ramp current values toward targets for smooth transitions
    self.currentFrequency = [self rampValue:self.currentFrequency toward:self.targetFrequency withDeltaTime:deltaTime timeConstantMs:kFrequencyRampTimeMs];
    self.currentVolume = [self rampValue:self.currentVolume toward:self.targetVolume withDeltaTime:deltaTime timeConstantMs:kVolumeRampTimeMs];
}

#pragma mark - Property Accessors

- (double)currentVelocity {
    return self.smoothedVelocity;
}

- (double)currentFrequency {
    return _currentFrequency;
}

@end