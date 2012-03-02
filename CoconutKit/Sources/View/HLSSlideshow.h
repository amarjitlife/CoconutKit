//
//  HLSSlideshow.h
//  CoconutKit
//
//  Created by Samuel Défago on 17.10.11.
//  Copyright (c) 2011 Hortis. All rights reserved.
//

/**
 * Available transition effects
 */
typedef enum {
    HLSSlideShowEffectEnumBegin = 0,
    HLSSlideShowEffectNone = HLSSlideShowEffectEnumBegin,                           // No transition
    HLSSlideShowEffectCrossDissolve,                                                // Cross-dissolve
    HLSSlideShowEffectKenBurns,                                                     // Ken-Burns effect (random zooming and panning, cross-dissolve)
    HLSSlideShowEffectHorizontalRibbon,                                             // Images slide from left to right
    HLSSlideshowEffectInverseHorizontalRibbon,                                      // Images slide from right to left
    HLSSlideshowEffectVerticalRibbon,                                               // Images slide from top to bottom
    HLSSlideshowEffectInverseVerticalRibbon,                                        // Images slide from bottom to top
    HLSSlideShowEffectEnumEnd,
    HLSSlideShowEffectEnumSize = HLSSlideShowEffectEnumEnd - HLSSlideShowEffectEnumBegin
} HLSSlideShowEffect;

/**
 * A slideshow creation displaying images using one of several built-in transition effects.
 *
 * You can instantiate a slideshow view either using a nib or programmatically. It then suffices to set its images property 
 * to the array of images which must be displayed. Other properties provide for further customization.
 *
 * You should not alter the frame of a slideshow while it is running. This is currently not supported.
 *
 * Designated initializer: initWithFrame:
 */
@interface HLSSlideshow : UIView {
@private
    HLSSlideShowEffect m_effect;
    NSArray *m_imageViews;                      // Two image views needed (front / back buffer) to create smooth cross-dissolve transitions
    NSArray *m_imageNamesOrPaths;
    NSMutableArray *m_animations;               // Two animations in parallel (at most)
    BOOL m_running;
    NSInteger m_currentImageIndex;
    NSInteger m_currentImageViewIndex;
    NSTimeInterval m_imageDuration;
    NSTimeInterval m_transitionDuration;
    BOOL m_random;
}

/**
 * The transition effect to be applied
 *
 * This property can be changed while the slideshow is running
 */
@property (nonatomic, assign) HLSSlideShowEffect effect;

/**
 * An array giving the names (for images inside the main bundle) or the full path of the images to be displayed. Images
 * are displayed in an endless loop, either sequentially or in a random order (see random property). 
 *
 * This property can be changed while the slideshow is running
 */
@property (nonatomic, retain) NSArray *imageNamesOrPaths;

/**
 * How much time an image stays visible. Default is 10 seconds. 
 *
 * This property can be changed while the slideshow is running
 */
@property (nonatomic, assign) NSTimeInterval imageDuration;

/**
 * The duration of the cross dissolve transition between two images (this setting is ignored by slideshows which do
 * not involve a cross-dissolve transition between images). Default is 3 seconds. 
 *
 * This property can be changed while the slideshow is running
 */
@property (nonatomic, assign) NSTimeInterval transitionDuration;

/**
 * If set to YES, images will be played in a random order. If set to NO, they are played sequentially
 * Default is NO
 *
 * This property can be changed while the slideshow is running
 */
@property (nonatomic, assign) BOOL random;

/**
 * Start / stop the slideshow
 */
- (void)play;
- (void)stop;

/**
 * Return YES iff the slideshow is running
 */
- (BOOL)isRunning;

@end