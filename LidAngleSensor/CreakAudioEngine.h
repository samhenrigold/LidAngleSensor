//
//  CreakAudioEngine.h
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * CreakAudioEngine provides real-time door creak audio that responds to MacBook lid angle changes.
 * 
 * Features:
 * - Real-time angular velocity calculation with multi-stage noise filtering
 * - Dynamic gain and pitch/tempo mapping based on movement speed
 * - Smooth parameter ramping to avoid audio artifacts
 * - Deadzone to prevent chattering at minimal movement
 * - Optimized for low-latency, responsive audio feedback
 * 
 * Audio Behavior:
 * - Slow movement (1-10 deg/s): Maximum creak volume
 * - Medium movement (10-100 deg/s): Gradual fade to silence
 * - Fast movement (100+ deg/s): Silent
 */
@interface CreakAudioEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isEngineRunning;
@property (nonatomic, assign, readonly) double currentVelocity;
@property (nonatomic, assign, readonly) double currentGain;
@property (nonatomic, assign, readonly) double currentRate;
@property (nonatomic, assign, readonly) double currentStabilizedAngle; // Angle after hysteresis filter

// Jitter filter configuration (live‑tunable)
@property (nonatomic, assign) BOOL jitterFilterEnabled;          // Enable/disable jitter suppression
@property (nonatomic, assign) double jitterAmplitudeDeg;          // Peak‑to‑peak amplitude threshold (deg)
@property (nonatomic, assign) double jitterTimeWindowMs;          // Time window to consider (ms)
@property (nonatomic, assign) double jitterMinDeltaDeg;           // Min delta to count a sign flip (deg)
@property (nonatomic, assign) NSUInteger jitterMinSignFlips;      // Required alternations in window

/**
 * Initialize the audio engine and load audio files.
 * @return Initialized engine instance, or nil if initialization failed
 */
- (instancetype)init;

/**
 * Start the audio engine and begin playback.
 */
- (void)startEngine;

/**
 * Stop the audio engine and halt playback.
 */
- (void)stopEngine;

/**
 * Update the creak audio based on new lid angle measurement.
 * This method calculates angular velocity, applies smoothing, and updates audio parameters.
 * @param lidAngle Current lid angle in degrees
 */
- (void)updateWithLidAngle:(double)lidAngle;

/**
 * Manually set the angular velocity (for testing purposes).
 * @param velocity Angular velocity in degrees per second
 */
- (void)setAngularVelocity:(double)velocity;

/** Reset internal jitter history (e.g., when toggling the filter). */
- (void)resetJitterHistory;

@end
