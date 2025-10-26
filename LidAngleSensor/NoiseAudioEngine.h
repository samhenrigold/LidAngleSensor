//
//  NoiseAudioEngine.h
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * Synthesized filtered noise
 *
 * Generate random noise, and filter it with a second order low pass filter, with a high quality
 * factor (Q) and a cutoff frequency mapped to the lid angle.
 * Biquad coeffs are updated with bilinear transform so that filter remains stable
 *
 * Most of the code was copied from from ThereminAudioEngine.m
 */
@interface NoiseAudioEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isEngineRunning;
@property (nonatomic, assign, readonly) double currentVelocity;
@property (nonatomic, assign, readonly) double currentFrequency;
@property (nonatomic, assign, readonly) double currentVolume;

/**
 * Initialize the audio engine.
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
 * Update  based on new lid angle measurement.
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
