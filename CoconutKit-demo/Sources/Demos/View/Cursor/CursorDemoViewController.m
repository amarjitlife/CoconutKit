//
//  CursorDemoViewController.m
//  CoconutKit-demo
//
//  Created by Samuel Défago on 10.06.11.
//  Copyright 2011 Hortis. All rights reserved.
//

#import "CursorDemoViewController.h"

#import "CursorCustomPointerView.h"
#import "CursorFolderView.h"
#import "CursorPointerInfoViewController.h"
#import "CursorSelectedFolderView.h"

@interface CursorDemoViewController ()

@property (nonatomic, retain) UIPopoverController *popoverController;

@end

@implementation CursorDemoViewController

static NSArray *s_weekDays = nil;
static NSArray *s_completeRange = nil;
static NSArray *s_timeScales = nil;
static NSArray *s_folders = nil;

#pragma mark Class methods

+ (void)initialize
{
    s_weekDays = [[NSDateFormatter orderedWeekdaySymbols] retain];    
    s_completeRange = [[NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10",
                      @"11", @"12", @"13", @"14", @"15", @"16", nil] retain];
    s_folders = [[NSArray arrayWithObjects:@"A-F", @"G-L", @"M-R", @"S-Z", nil] retain];
}

#pragma mark Object creation and destruction

- (void)dealloc
{
    self.popoverController = nil;
    
    [super dealloc];
}

- (void)releaseViews
{
    [super releaseViews];
    
    self.weekDaysCursor = nil;
    self.weekDayIndexLabel = nil;
    self.randomRangeCursor = nil;
    self.randomRangeIndexLabel = nil;
    self.widthFactorSlider = nil;
    self.heightFactorSlider = nil;
    self.timeScalesCursor = nil;
    self.foldersCursor = nil;
    self.mixedFoldersCursor = nil;
}

#pragma mark Accessors and mutators

@synthesize weekDaysCursor = m_weekDaysCursor;

@synthesize weekDayIndexLabel = m_weekDayIndexLabel;

@synthesize randomRangeCursor = m_randomRangeCursor;

@synthesize randomRangeIndexLabel = m_randomRangeIndexLabel;

@synthesize widthFactorSlider = m_widthFactorSlider;

@synthesize heightFactorSlider = m_heightFactorSlider;

@synthesize timeScalesCursor = m_timeScalesCursor;

@synthesize foldersCursor = m_foldersCursor;

@synthesize mixedFoldersCursor = m_mixedFoldersCursor;

@synthesize popoverController = m_popoverController;

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.weekDaysCursor.dataSource = self;
    self.weekDaysCursor.delegate = self;
    [self.weekDaysCursor setSelectedIndex:3 animated:NO];
    
    self.randomRangeCursor.pointerView = [CursorCustomPointerView view];
    self.randomRangeCursor.dataSource = self;
    self.randomRangeCursor.delegate = self;
    [self.randomRangeCursor setSelectedIndex:4 animated:NO];
    
    self.timeScalesCursor.dataSource = self;
    self.timeScalesCursor.delegate = self;
    // Not perfectly centered with the font used. Tweak a little bit to get a perfect result
    self.timeScalesCursor.pointerViewTopLeftOffset = CGSizeMake(-11.f, -12.f);
    
    self.foldersCursor.dataSource = self;
    self.foldersCursor.delegate = self;
    self.foldersCursor.pointerViewTopLeftOffset = CGSizeMake(-10.f, -10.f);
    self.foldersCursor.pointerViewBottomRightOffset = CGSizeMake(10.f, 10.f);
    
    self.mixedFoldersCursor.dataSource = self;
    self.mixedFoldersCursor.delegate = self;
    
    self.weekDaysCursor.animationDuration = 0.05;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    m_originalRandomRangeCursorSize = self.randomRangeCursor.frame.size;
}

#pragma mark Orientation management

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // Restore the original bounds for the previous orientation before they are updated by the rotation animation. This
    // is needed since there is no simple way to get the view bounds for the new orientation without actually rotating
    // the view
    self.randomRangeCursor.bounds = CGRectMake(0.f, 0.f, m_originalRandomRangeCursorSize.width, m_originalRandomRangeCursorSize.height);
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    // The view has its new bounds (even if the rotation animation has not been played yet!). Store them so that we
    // are able to restore them when rotating again, and set size according to the previous size slider value. This
    // trick made in the -willRotate... and -willAnimateRotation... methods remains unnoticed!
    m_originalRandomRangeCursorSize = self.randomRangeCursor.bounds.size;
    [self sizeChanged:nil];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

#pragma mark Memory warnings

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.popoverController = nil;
}

#pragma mark HLSCursorDataSource protocol implementation

- (UIView *)cursor:(HLSCursor *)cursor viewAtIndex:(NSUInteger)index selected:(BOOL)selected
{
    if (cursor == self.foldersCursor || (cursor == self.mixedFoldersCursor && index % 2 == 0)) {
        if (selected) {
            CursorSelectedFolderView *view = [CursorSelectedFolderView view];
            view.nameLabel.text = [s_folders objectAtIndex:index];
            return view;
        }
        else {
            CursorFolderView *view = [CursorFolderView view];
            view.nameLabel.text = [s_folders objectAtIndex:index];
            return view;        
        }
    }
    else {
        // Not defined using a view
        return nil;
    }
}

- (NSUInteger)numberOfElementsForCursor:(HLSCursor *)cursor
{
    if (cursor == self.weekDaysCursor) {
        return [s_weekDays count];
    }
    else if (cursor == self.randomRangeCursor) {
        // Omit up to 10 objects at the end of the array
        return arc4random() % 10 + [s_completeRange count] - 10 + 1;
    }
    else if (cursor == self.timeScalesCursor) {
        return [s_timeScales count];
    }
    else if (cursor == self.foldersCursor || cursor == self.mixedFoldersCursor) {
        return [s_folders count];
    }
    else {
        HLSLoggerError(@"Unknown cursor");
        return 0;
    }
}

- (NSString *)cursor:(HLSCursor *)cursor titleAtIndex:(NSUInteger)index
{
    if (cursor == self.weekDaysCursor) {
        return [s_weekDays objectAtIndex:index];
    }
    else if (cursor == self.randomRangeCursor) {
        return [s_completeRange objectAtIndex:index];
    }
    else if (cursor == self.timeScalesCursor) {
        return [s_timeScales objectAtIndex:index];
    }
    else if (cursor == self.mixedFoldersCursor && index % 2 != 0) {
        return [s_folders objectAtIndex:index];
    }
    else {
        return @"";
    }
}

- (UIFont *)cursor:(HLSCursor *)cursor fontAtIndex:(NSUInteger)index selected:(BOOL)selected
{
    if (cursor == self.timeScalesCursor) {
        return [UIFont fontWithName:@"ProximaNova-Regular" size:20.f];
    }
    else {
        // Default
        return nil;
    }
}

- (UIColor *)cursor:(HLSCursor *)cursor textColorAtIndex:(NSUInteger)index selected:(BOOL)selected
{
    if (cursor == self.randomRangeCursor) {
        return [UIColor blueColor];
    }
    else if (cursor == self.mixedFoldersCursor) {
        return [UIColor blackColor];
    }
    else {
        // Default
        return nil;
    }
}

- (UIColor *)cursor:(HLSCursor *)cursor shadowColorAtIndex:(NSUInteger)index selected:(BOOL)selected
{
    if (cursor == self.randomRangeCursor) {
        return [UIColor whiteColor];
    }
    else {
        // Default (no shadow)
        return nil;
    }
}

- (CGSize)cursor:(HLSCursor *)cursor shadowOffsetAtIndex:(NSUInteger)index selected:(BOOL)selected
{
    if (cursor == self.randomRangeCursor) {
        return CGSizeMake(0, 1);
    }
    else {
        return kCursorShadowOffsetDefault;
    }
}

#pragma mark HLSCursorDelegate protocol implementation

- (void)cursor:(HLSCursor *)cursor didMoveFromIndex:(NSUInteger)index
{
    HLSLoggerInfo(@"Cursor %p did move from index %d", cursor, index);
    
    if (cursor == self.weekDaysCursor) {
        self.weekDayIndexLabel.text = [NSString stringWithFormat:@"%@: %d", NSLocalizedString(@"Index", @"Index"), index];
        self.weekDayIndexLabel.textColor = [UIColor redColor];
    }
    else if (cursor == self.randomRangeCursor) {
        self.randomRangeIndexLabel.text = [NSString stringWithFormat:@"%@: %d", NSLocalizedString(@"Index", @"Index"), index];
        self.randomRangeIndexLabel.textColor = [UIColor redColor];
    }    
}

- (void)cursor:(HLSCursor *)cursor didMoveToIndex:(NSUInteger)index
{
    HLSLoggerInfo(@"Cursor %p did move to index %d", cursor, index);
    
    if (cursor == self.weekDaysCursor) {
        self.weekDayIndexLabel.text = [NSString stringWithFormat:@"%@: %d", NSLocalizedString(@"Index", @"Index"), index];
        self.weekDayIndexLabel.textColor = [UIColor blackColor];
    }
    else if (cursor == self.randomRangeCursor) {
        self.randomRangeIndexLabel.text = [NSString stringWithFormat:@"%@: %d", NSLocalizedString(@"Index", @"Index"), index];
        self.randomRangeIndexLabel.textColor = [UIColor blackColor];
        
        CursorCustomPointerView *pointerView = (CursorCustomPointerView *)cursor.pointerView;
        pointerView.valueLabel.text = [s_completeRange objectAtIndex:index];
    }
}

- (void)cursorDidStartDragging:(HLSCursor *)cursor nearIndex:(NSUInteger)index
{
    HLSLoggerInfo(@"Cursor %p did start dragging near index %d", cursor, index);
    
    if (cursor == self.randomRangeCursor) {
        if (! self.popoverController) {
            CursorPointerInfoViewController *infoViewController = [[[CursorPointerInfoViewController alloc] init] autorelease];
            self.popoverController = [[[UIPopoverController alloc] initWithContentViewController:infoViewController] autorelease];
            self.popoverController.popoverContentSize = infoViewController.view.frame.size;
        }        
    }
}

- (void)cursor:(HLSCursor *)cursor didDragNearIndex:(NSUInteger)index
{
    HLSLoggerInfo(@"Cursor %p did drag near index %d", cursor, index);
    
    if (cursor == self.randomRangeCursor) {
        CursorPointerInfoViewController *infoViewController = (CursorPointerInfoViewController *)self.popoverController.contentViewController;
        infoViewController.valueLabel.text = [s_completeRange objectAtIndex:index];
        
        [self.popoverController dismissPopoverAnimated:NO];
        [self.popoverController presentPopoverFromRect:cursor.pointerView.bounds
                                                inView:cursor.pointerView
                              permittedArrowDirections:UIPopoverArrowDirectionDown
                                              animated:NO];
        
        CursorCustomPointerView *pointerView = (CursorCustomPointerView *)cursor.pointerView;
        pointerView.valueLabel.text = [s_completeRange objectAtIndex:index];
    }
}

- (void)cursorDidStopDragging:(HLSCursor *)cursor nearIndex:(NSUInteger)index
{
    HLSLoggerInfo(@"Cursor %p did stop dragging near index %d", cursor, index);
    
    if (cursor == self.randomRangeCursor) {
        [self.popoverController dismissPopoverAnimated:NO];
    }
}

#pragma mark Event callbacks

- (IBAction)moveWeekDaysPointerToNextDay:(id)sender
{
    [self.weekDaysCursor setSelectedIndex:[self.weekDaysCursor selectedIndex] + 1 animated:YES];
}

- (IBAction)reloadRandomRangeCursor:(id)sender
{
    [self.randomRangeCursor reloadData];
}

- (void)sizeChanged:(id)sender
{
    self.randomRangeCursor.bounds = CGRectMake(0.f,
                                               0.f,
                                               m_originalRandomRangeCursorSize.width * self.widthFactorSlider.value,
                                               m_originalRandomRangeCursorSize.height * self.heightFactorSlider.value);
}

#pragma mark Localization

- (void)localize
{
    [super localize];
    
    self.title = NSLocalizedString(@"Cursor", @"Cursor");
    
    [s_timeScales release];
    s_timeScales = [[NSArray arrayWithObjects:[NSLocalizedString(@"Year", @"Year") uppercaseString],
                     [NSLocalizedString(@"Month", @"Month") uppercaseString],
                     [NSLocalizedString(@"Week", @"Week") uppercaseString],
                     [NSLocalizedString(@"Day", @"Day") uppercaseString],
                     nil] retain];
    
    [self.weekDaysCursor reloadData];
    [self.timeScalesCursor reloadData];
}

@end
