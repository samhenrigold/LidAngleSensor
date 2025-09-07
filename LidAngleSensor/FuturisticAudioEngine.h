//
//  FuturisticAudioEngine.h
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * FuturisticAudioEngine provides real-time futuristic electronic audio that responds to MacBook lid angle changes.
 * 
 * Features:
 * - Real-time synthesized electronic sounds based on lid angle
 * - Smooth frequency transitions with filter sweeps
 * - Volume control based on angular velocity
 * - Subtle LFO modulation for movement effects
 * - Clean, electronic sound design
 * 
 * Audio Behavior:
 * - Lid angle maps to filter cutoff frequency (closed = low filter, open = high filter)
 * - Movement velocity controls volume and LFO rate (slow movement = loud, fast = quiet)
 * - Smooth parameter interpolation for clean electronic quality
 */
@interface FuturisticAudioEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isEngineRunning;
@property (nonatomic, assign, readonly) double currentVelocity;
@property (nonatomic, assign, readonly) double currentFrequency;
@property (nonatomic, assign, readonly) double currentVolume;

/**
 * Initialize the futuristic audio engine.
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
 * Update the futuristic audio based on new lid angle measurement.
 * This method calculates filter frequency mapping and volume based on movement.
 * @param lidAngle Current lid angle in degrees
 */
- (void)updateWithLidAngle:(double)lidAngle;

/**
 * Manually set the angular velocity (for testing purposes).
 * @param velocity Angular velocity in degrees per second
 */
- (void)setAngularVelocity:(double)velocity;

@end