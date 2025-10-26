//
//  NoiseAudioEngine.m
//  LidAngleSensor
//
//  Created by mi-art on 2025-10-26
//

#import "NoiseAudioEngine.h"
#import <AudioToolbox/AudioToolbox.h>

// Frequency parameter mapping constants
static const double kMinFrequency = 300.0;       // Hz
static const double kMaxFrequency = 4000.0;      // Hz
static const double kMinAngle = 0.0;             // degrees - closed lid
static const double kMaxAngle = 135.0;           // degrees - fully open lid

// Volume control constants
static const double kBaseVolume = 0.6;             // Base volume when at rest
static const double kVelocityVolumeBoost = 0.4;    // Additional volume boost from movement
static const double kVelocityQuiet = 80.0;         // deg/s - no volume boost over this velocity
static const BOOL kEnableVolumeModulation = false; // Bypass volume variation, sounds better IMO

// Filter quality factor
static const double kQ = 10;

// Smoothing constants
static const double kAngleSmoothingFactor = 0.4;      // Moderate smoothing for frequency
static const double kVelocitySmoothingFactor = 0.3;   // Moderate smoothing for velocity
static const double kFrequencyRampTimeMs = 3.0;      // Frequency ramping time constant
static const double kVolumeRampTimeMs = 50.0;         // Volume ramping time constant
static const double kMovementThreshold = 0.3;         // Minimum angle change to register movement
static const double kMovementTimeoutMs = 100.0;       // Time before velocity decay
static const double kVelocityDecayFactor = 0.7;       // Decay rate when no movement
static const double kAdditionalDecayFactor = 0.85;    // Additional decay after timeout

// Audio constants
static const double kSampleRate = 44100.0;

@interface NoiseAudioEngine ()

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

// Biquad filter coefficients
@property (nonatomic, assign) double b0, b1, b2, a1, a2;

// Biquad filter state variables
@property (nonatomic, assign) double x1, x2, y1, y2;


// Vibrato generation
@property (nonatomic, assign) double vibratoPhase;

@end

@implementation NoiseAudioEngine

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
        [self updateCoefficients];

        if (![self setupAudioEngine]) {
            NSLog(@"[NoiseAudioEngine] Failed to setup audio engine");
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

    // Create audio format for our sine wave
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                             sampleRate:kSampleRate
                                                               channels:1
                                                            interleaved:NO];

    // Create source node for sine wave generation
    __weak typeof(self) weakSelf = self;
    self.sourceNode = [[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL * _Nonnull isSilence, const AudioTimeStamp * _Nonnull timestamp, AVAudioFrameCount frameCount, AudioBufferList * _Nonnull outputData) {
        return [weakSelf renderSineWave:isSilence timestamp:timestamp frameCount:frameCount outputData:outputData];
    }];

    // Attach and connect the source node
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
        NSLog(@"[NoiseAudioEngine] Failed to start audio engine: %@", error.localizedDescription);
        return;
    }

    NSLog(@"[NoiseAudioEngine] Started noise engine");
}

- (void)stopEngine {
    if (!self.isEngineRunning) {
        return;
    }

    [self.audioEngine stop];
    NSLog(@"[NoiseAudioEngine] Stopped noise engine");
}

- (BOOL)isEngineRunning {
    return self.audioEngine.isRunning;
}

#pragma mark - Sine Wave Generation

- (void)updateCoefficients {
    float omega = 2.0 * M_PI * self.currentFrequency / kSampleRate;
    float alpha = sinf(omega) / (2.0 * kQ);
    float cos_omega = cosf(omega);

    float a0 = 1.0 + alpha;
    self.b0 = (1.0 - cos_omega) / 2.0 / a0;
    self.b1 = (1.0 - cos_omega) / a0;
    self.b2 = (1.0 - cos_omega) / 2.0 / a0;
    self.a1 = -2.0 * cos_omega / a0;
    self.a2 = (1.0 - alpha) / a0;
}


- (OSStatus)renderSineWave:(BOOL *)isSilence
                 timestamp:(const AudioTimeStamp *)timestamp
                frameCount:(AVAudioFrameCount)frameCount
                outputData:(AudioBufferList *)outputData {

    float *output = (float *)outputData->mBuffers[0].mData;

    // Always generate sound (continuous tone)
    *isSilence = NO;

    for (AVAudioFrameCount i = 0; i < frameCount; i++) {
        float x0 = ((float)arc4random() / UINT32_MAX) * 2.0 - 1.0;

        float y0 = self.b0 * x0 + self.b1 * self.x1 + self.b2 * self.x2
                 - self.a1 * self.y1 - self.a2 * self.y2;

        output[i] = y0;

        self.x2 = self.x1;
        self.x1 = x0;
        self.y2 = self.y1;
        self.y1 = y0;

        output[i] = output[i] * 0.1;

        if (kEnableVolumeModulation) {
            output[i] *= self.currentVolume;
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

        // Set initial frequency based on angle
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
    // Map angle to frequency using exponential curve for musical feel
    double normalizedAngle = fmax(0.0, fmin(1.0, (angle - kMinAngle) / (kMaxAngle - kMinAngle)));

    // Use exponential mapping for more musical frequency distribution
    double frequencyRatio = pow(normalizedAngle, 1); // Slight compression for better control
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
    self.currentFrequency = [self rampValue:self.currentFrequency toward:self.targetFrequency
    withDeltaTime:deltaTime timeConstantMs:kFrequencyRampTimeMs];

    [self updateCoefficients];

    self.currentVolume = [self rampValue:self.currentVolume toward:self.targetVolume withDeltaTime:deltaTime timeConstantMs:kVolumeRampTimeMs];
}

#pragma mark - Property Accessors

- (double)currentVelocity {
    return self.smoothedVelocity;
}

@end
