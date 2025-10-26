//
//  ThereminAudioEngine.h
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * ThereminAudioEngine provides real-time theremin-like audio that responds to MacBook lid angle changes.
 * 
 * Features:
 * - Real-time sine wave synthesis based on lid angle
 * - Smooth frequency transitions to avoid audio artifacts
 * - Volume control based on angular velocity
 * - Configurable frequency range mapping
 * - Low-latency audio generation
 * 
 * Audio Behavior:
 * - Lid angle maps to frequency (closed = low pitch, open = high pitch)
 * - Movement velocity controls volume (slow movement = loud, fast = quiet)
 * - Smooth parameter interpolation for musical quality
 */
@interface ThereminAudioEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isEngineRunning;
@property (nonatomic, assign, readonly) double currentVelocity;
@property (nonatomic, assign, readonly) double currentFrequency;
@property (nonatomic, assign, readonly) double currentVolume;

/**
 * Initialize the theremin audio engine.
 * @return Initialized engine instance, or nil if initialization failed
 */
- (instancetype)init;

/**
 * Start the audio engine and begin tone generation.
 */
- (void)startEngine;

/**
 * Stop the audio engine and halt tone generation.
 */
- (void)stopEngine;

/**
 * Update the theremin audio based on new lid angle measurement.
 * This method calculates frequency mapping and volume based on movement.
 * @param lidAngle Current lid angle in degrees
 */
- (void)updateWithLidAngle:(double)lidAngle;

/**
 * Manually set the angular velocity (for testing purposes).
 * @param velocity Angular velocity in degrees per second
 */
- (void)setAngularVelocity:(double)velocity;

@end
