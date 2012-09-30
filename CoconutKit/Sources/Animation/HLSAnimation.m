//
//  HLSAnimation.m
//  CoconutKit
//
//  Created by Samuel Défago on 2/8/11.
//  Copyright 2011 Hortis. All rights reserved.
//

#import "HLSAnimation.h"

#import "HLSAnimationStep+Friend.h"
#import "HLSAssert.h"
#import "HLSConverters.h"
#import "HLSFloat.h"
#import "HLSLayerAnimationStep.h"
#import "HLSLogger.h"
#import "HLSUserInterfaceLock.h"
#import "HLSZeroingWeakRef.h"
#import "NSArray+HLSExtensions.h"
#import "NSString+HLSExtensions.h"

static NSString * const kDelayLayerAnimationTag = @"HLSDelayLayerAnimationStep";

@interface HLSAnimation () <HLSAnimationStepDelegate>

+ (NSArray *)copyForAnimationSteps:(NSArray *)animationSteps;

@property (nonatomic, retain) NSArray *animationSteps;
@property (nonatomic, retain) NSArray *animationStepCopies;
@property (nonatomic, retain) NSEnumerator *animationStepsEnumerator;
@property (nonatomic, retain) HLSAnimationStep *currentAnimationStep;
@property (nonatomic, assign, getter=isRunning) BOOL running;
@property (nonatomic, assign, getter=isCancelling) BOOL cancelling;
@property (nonatomic, assign, getter=isTerminating) BOOL terminating;
@property (nonatomic, retain) HLSZeroingWeakRef *delegateZeroingWeakRef;

- (void)playAnimated:(BOOL)animated
     withRepeatCount:(NSUInteger)repeatCount
  currentRepeatCount:(NSUInteger)currentRepeatCount
          afterDelay:(NSTimeInterval)delay;
- (void)playNextAnimationStepAnimated:(BOOL)animated;

- (NSArray *)reverseAnimationSteps;

- (void)applicationDidEnterBackground:(NSNotification *)notification;

@end

@implementation HLSAnimation

#pragma mark Class methods

+ (HLSAnimation *)animationWithAnimationSteps:(NSArray *)animationSteps
{
    return [[[[self class] alloc] initWithAnimationSteps:animationSteps] autorelease];
}

+ (HLSAnimation *)animationWithAnimationStep:(HLSAnimationStep *)animationStep
{
    NSArray *animationSteps = nil;
    if (animationStep) {
        animationSteps = [NSArray arrayWithObject:animationStep];
    }
    return [HLSAnimation animationWithAnimationSteps:animationSteps];
}

+ (NSArray *)copyForAnimationSteps:(NSArray *)animationSteps
{
    NSMutableArray *animationStepCopies = [NSMutableArray array];
    for (HLSAnimationStep *animationStep in animationSteps) {
        [animationStepCopies addObject:[animationStep copy]];
    }
    return [NSArray arrayWithArray:animationStepCopies];
}

#pragma mark Object creation and destruction

- (id)initWithAnimationSteps:(NSArray *)animationSteps
{
    if ((self = [super init])) {
        if (! animationSteps) {
            self.animationSteps = [NSArray array];
        }
        else {
            HLSAssertObjectsInEnumerationAreKindOfClass(animationSteps, HLSAnimationStep);
            self.animationSteps = [HLSAnimation copyForAnimationSteps:animationSteps];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (id)init
{
    HLSForbiddenInheritedMethod();
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    
    [self cancel];
    
    self.animationSteps = nil;
    self.animationStepCopies = nil;
    self.animationStepsEnumerator = nil;
    self.currentAnimationStep = nil;
    self.tag = nil;
    self.userInfo = nil;
    self.delegateZeroingWeakRef = nil;
    
    [super dealloc];
}

#pragma mark Accessors and mutators

@synthesize animationSteps = m_animationSteps;

@synthesize animationStepCopies = m_animationStepCopies;

@synthesize animationStepsEnumerator = m_animationStepsEnumerator;

@synthesize currentAnimationStep = m_currentAnimationStep;

@synthesize tag = m_tag;

@synthesize userInfo = m_userInfo;

@synthesize lockingUI = m_lockingUI;

@synthesize running = m_running;

- (BOOL)isPaused
{
    return [self.currentAnimationStep isPaused];
}

@synthesize cancelling = m_cancelling;

@synthesize terminating = m_terminating;

@synthesize delegateZeroingWeakRef = m_delegateZeroingWeakRef;

- (id<HLSAnimationDelegate>)delegate
{
    return self.delegateZeroingWeakRef.object;
}

- (void)setDelegate:(id<HLSAnimationDelegate>)delegate
{
    self.delegateZeroingWeakRef = [[[HLSZeroingWeakRef alloc] initWithObject:delegate] autorelease];
    [self.delegateZeroingWeakRef addCleanupAction:@selector(cancel) onTarget:self];
}

- (NSTimeInterval)duration
{
    NSTimeInterval duration = 0.;
    for (HLSAnimationStep *animationStep in self.animationSteps) {
        duration += animationStep.duration;
    }
    return duration;
}

#pragma mark Animation

- (void)playAnimated:(BOOL)animated
{
    [self playAnimated:animated withRepeatCount:1 currentRepeatCount:0 afterDelay:0.];
}

- (void)playAfterDelay:(NSTimeInterval)delay
{    
    [self playAnimated:YES withRepeatCount:1 currentRepeatCount:0 afterDelay:delay];
}

- (void)playWithRepeatCount:(NSUInteger)repeatCount animated:(BOOL)animated
{
    [self playAnimated:animated withRepeatCount:repeatCount currentRepeatCount:0 afterDelay:0.f];
}

- (void)playWithRepeatCount:(NSUInteger)repeatCount afterDelay:(NSTimeInterval)delay
{
    [self playAnimated:YES withRepeatCount:repeatCount currentRepeatCount:0 afterDelay:delay];
}

- (void)playAnimated:(BOOL)animated
     withRepeatCount:(NSUInteger)repeatCount
  currentRepeatCount:(NSUInteger)currentRepeatCount
          afterDelay:(NSTimeInterval)delay
{
    if (repeatCount == 0) {
        HLSLoggerError(@"repeatCount cannot be 0");
        return;
    }
    
    if (repeatCount == NSUIntegerMax && ! animated) {
        HLSLoggerError(@"An animation running indefinitely must be played with animated = YES");
        return;
    }
    
    if (! animated && ! doubleeq(delay, 0.)) {
        HLSLoggerWarn(@"A delay has been defined, but the animation is played non-animated. The delay will be ignored");
        delay = 0.;
    }
    
    if (floatlt(delay, 0.)) {
        delay = 0;
        HLSLoggerWarn(@"Negative delay. Fixed to 0");
    }
        
    // Cannot be played if already running and trying to play the first time
    if (currentRepeatCount == 0) {
        if (self.running) {
            HLSLoggerDebug(@"The animation is already running");
            return;
        }
                
        self.running = YES;
    
        // Lock the UI during the animation
        if (self.lockingUI) {
            [[HLSUserInterfaceLock sharedUserInterfaceLock] lock];
        }
    }
    
    // Animation steps carry state information. To avoid issues when playing the same animation step several times (most
    // notably when repeatCount > 1), we work on a deep copy of them
    self.animationStepCopies = [HLSAnimation copyForAnimationSteps:self.animationSteps];
        
    m_animated = animated;
    m_repeatCount = repeatCount;
    m_currentRepeatCount = currentRepeatCount;
    
    // Create a dummy animation step to simulate the delay. This way we avoid two potential issues:
    //   - if an animation step subclass is implemented using an animation framework which does not support delays,
    //     delayed animations would not be possible
    //   - there is an issue with Core Animation delays: CALayer properties must namely be updated ASAP (ideally
    //     when creating the animation), but this cannot be done with delayed Core Animations (otherwise the animated
    //     layer reaches its end state before the animation has actually started). In such cases, properties should
    //     be set in the -animationDidStart: animation callback. This works well in most cases, but it is too late
    //     (after all, the start delegate method is called 'didStart', not 'willStart') if the animated layers are
    //     heavy, e.g. with may transparent sublayers, creating an ugly flickering in animations. By creating delays
    //     with a dummy layer animation step, this problem vanishes
    HLSLayerAnimationStep *delayAnimationStep = [HLSLayerAnimationStep animationStep];
    delayAnimationStep.tag = kDelayLayerAnimationTag;
    delayAnimationStep.duration = delay;
    
    // Set the dummy animation step as current animation step, so that cancel / terminate work as expected, even
    // if they occur during the initial delay period
    self.currentAnimationStep = delayAnimationStep;
    [delayAnimationStep playWithDelegate:self animated:animated];
}

- (void)playNextAnimationStepAnimated:(BOOL)animated
{
    // First call?
    if (! self.animationStepsEnumerator) {
        self.animationStepsEnumerator = [self.animationStepCopies objectEnumerator];
    }
    
    // Proceeed with the next step (if any)
    self.currentAnimationStep = [self.animationStepsEnumerator nextObject];
    if (self.currentAnimationStep) {
        [self.currentAnimationStep playWithDelegate:self animated:animated];
    }
    // Done with the animation
    else {
        // Empty animations (without animation steps) must still call the animationWillStart:animated delegate method
        if (m_currentRepeatCount == 0 && [self.animationStepCopies count] == 0) {
            if ([self.delegate respondsToSelector:@selector(animationWillStart:animated:)]) {
                [self.delegate animationWillStart:self animated:animated];
            }
        }
        
        self.animationStepsEnumerator = nil;
                
        // Could theoretically overflow if m_repeatCount == NSUIntegerMax, but this would still yield a correct
        // behavior here
        ++m_currentRepeatCount;
        
        if ((m_repeatCount == NSUIntegerMax && self.terminating)
                || (m_repeatCount != NSUIntegerMax && m_currentRepeatCount == m_repeatCount)) {
            // Unlock the UI
            if (self.lockingUI) {
                [[HLSUserInterfaceLock sharedUserInterfaceLock] unlock];
            }
            
            if (! self.cancelling) {
                if ([self.delegate respondsToSelector:@selector(animationDidStop:animated:)]) {
                    [self.delegate animationDidStop:self animated:self.terminating ? NO : animated];
                }
            }
        }
                
        // Repeat if needed. If an indefinitely running animation is interrupted, stop playing, otherwise play it
        // until the end
        if ((m_repeatCount == NSUIntegerMax && ! self.cancelling && ! self.terminating)
                || (m_repeatCount != NSUIntegerMax && m_currentRepeatCount != m_repeatCount)) {
            [self playAnimated:(self.cancelling || self.terminating) ? NO : m_animated
               withRepeatCount:m_repeatCount
            currentRepeatCount:m_currentRepeatCount
                    afterDelay:0.];
        }
        // The end of the animation has been reached. Reset its status variables
        else {
            self.running = NO;
            self.cancelling = NO;
            self.terminating = NO;
        }
    }
}

- (void)pause
{
    if (! self.running) {
        HLSLoggerDebug(@"The animation is not running, nothing to pause");
        return;
    }
    
    if (self.cancelling || self.terminating) {
        HLSLoggerDebug(@"The animation is being cancelled or terminated");
        return;
    }
    
    if (self.paused) {
        HLSLoggerDebug(@"The animation is already paused");
        return;
    }
    
    [self.currentAnimationStep pause];
}

- (void)resume
{
    if (! self.paused) {
        HLSLoggerDebug(@"The animation has not being paused. Nothing to resume");
        return;
    }
    
    [self.currentAnimationStep resume];
}

- (void)cancel
{
    if (! self.running) {
        HLSLoggerDebug(@"The animation is not running, nothing to cancel");
        return;
    }
    
    if (self.cancelling || self.terminating) {
        HLSLoggerDebug(@"The animation is already being cancelled or terminated");
        return;
    }
    
    self.cancelling = YES;
    
    // Cancel all animations
    [self.currentAnimationStep terminate];
}

- (void)terminate
{
    if (! self.running) {
        HLSLoggerDebug(@"The animation is not running, nothing to terminate");
        return;
    }
    
    if (self.cancelling || self.terminating) {
        HLSLoggerDebug(@"The animation is already being cancelled or terminated");
        return;
    }
    
    self.terminating = YES;
    
    // Cancel all animations
    [self.currentAnimationStep terminate];
}

#pragma mark Creating animations variants from an existing animation

- (HLSAnimation *)animationWithDuration:(NSTimeInterval)duration
{
    if (doublelt(duration, 0.f)) {
        HLSLoggerError(@"The duration cannot be negative");
        return nil;
    }
    
    HLSAnimation *animation = [[self copy] autorelease];
    
    // Find out which factor must be applied to each animation step to preserve the animation appearance for the
    // specified duration
    double factor = duration / [self duration];
    
    // Distribute the total duration evenly among animation steps
    for (HLSAnimationStep *animationStep in animation.animationSteps) {
        animationStep.duration *= factor;
    }
    
    return animation;
}

- (NSArray *)reverseAnimationSteps
{
    NSMutableArray *reverseAnimationSteps = [NSMutableArray array];
    for (HLSAnimationStep *animationStep in [self.animationSteps reverseObjectEnumerator]) {
        [reverseAnimationSteps addObject:[animationStep reverseAnimationStep]];
    }
    return [NSArray arrayWithArray:reverseAnimationSteps];
}

- (HLSAnimation *)reverseAnimation
{
    HLSAnimation *reverseAnimation = [HLSAnimation animationWithAnimationSteps:[self reverseAnimationSteps]];
    reverseAnimation.tag = [self.tag isFilled] ? [NSString stringWithFormat:@"reverse_%@", self.tag] : nil;
    reverseAnimation.lockingUI = self.lockingUI;
    reverseAnimation.delegate = self.delegate;
    reverseAnimation.userInfo = self.userInfo;
    
    return reverseAnimation;
}

- (HLSAnimation *)loopAnimation
{
    NSMutableArray *animationSteps = [NSMutableArray arrayWithArray:self.animationSteps];
    [animationSteps addObjectsFromArray:[self reverseAnimationSteps]];
    
    // Add a loop_ prefix to all animation step tags
    for (HLSAnimationStep *animationStep in animationSteps) {
        animationStep.tag = [animationStep.tag isFilled] ? [NSString stringWithFormat:@"loop_%@", animationStep.tag] : nil;
    }
    
    HLSAnimation *loopAnimation = [HLSAnimation animationWithAnimationSteps:[NSArray arrayWithArray:animationSteps]];
    loopAnimation.tag = [self.tag isFilled] ? [NSString stringWithFormat:@"loop_%@", self.tag] : nil;
    loopAnimation.lockingUI = self.lockingUI;
    loopAnimation.delegate = self.delegate;
    loopAnimation.userInfo = self.userInfo;
    
    return loopAnimation;
}

#pragma mark HLSAnimationStepDelegate protocol implementation

- (void)animationStepDidStop:(HLSAnimationStep *)animationStep animated:(BOOL)animated finished:(BOOL)finished
{
    // Still send all delegate notifications if terminating
    if (! self.cancelling) {
        // Notify that the animation begins when the initial delay animation (always played) ends. This way
        // we get rid of subtle differences which might arise with animation steps only being able to notify
        // when they did start, rather than when they will
        if ([animationStep.tag isEqualToString:kDelayLayerAnimationTag]) {
            // Note that if a delay has been set, this event is not fired until the delay period is over, as for UIView animation blocks)
            if (m_currentRepeatCount == 0) {
                if ([self.delegate respondsToSelector:@selector(animationWillStart:animated:)]) {
                    [self.delegate animationWillStart:self animated:animated];
                }
            }
        }
        else {
            if ([self.delegate respondsToSelector:@selector(animationStepFinished:animated:)]) {
                [self.delegate animationStepFinished:animationStep animated:animated];
            }
        }
    }
    
    // Play the next step (or the first step if the initial delay animation step has ended(), but non-animated if the
    // animation did not reach completion normally
    [self playNextAnimationStepAnimated:finished ? animated : NO];
}

#pragma mark NSCopying protocol implementation

- (id)copyWithZone:(NSZone *)zone
{
    HLSAnimation *animationCopy = nil;
    if (self.animationSteps) {
        NSMutableArray *animationStepCopies = [NSMutableArray array];
        for (HLSAnimationStep *animationStep in self.animationSteps) {
            HLSAnimationStep *animationStepCopy = [[animationStep copyWithZone:zone] autorelease];
            [animationStepCopies addObject:animationStepCopy];
        }
        animationCopy = [[HLSAnimation allocWithZone:zone] initWithAnimationSteps:[NSMutableArray arrayWithArray:animationStepCopies]];
    }
    else {
        animationCopy = [[HLSAnimation allocWithZone:zone] initWithAnimationSteps:nil];
    }
    
    animationCopy.tag = self.tag;
    animationCopy.lockingUI = self.lockingUI;
    animationCopy.delegate = self.delegate;
    animationCopy.userInfo = self.userInfo;
    
    return animationCopy;
}

#pragma mark Notification callbacks

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    // Safest strategy: Terminate all animations when the application enters background
    [self terminate];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; animationSteps: %@; tag: %@; lockingUI: %@; delegate: %p>",
            [self class],
            self,
            self.animationSteps,
            self.tag,
            HLSStringFromBool(self.lockingUI),
            self.delegate];
}

@end
