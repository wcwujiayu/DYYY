#import "DYYYFPSOverlay.h"

#import "AwemeHeaders.h"
#import "DYYYConstants.h"
#import "DYYYUtils.h"

#import <QuartzCore/CADisplayLink.h>
#import <QuartzCore/CAFrameRateRange.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import <objc/runtime.h>
#import <stdatomic.h>

/*
 * 使用独立 UIWindow（跨页面长驻浮层），保证信息流、宿主页面与 DYYY 设置页均可看见。
 * 窗口不抢 key；空白区域 hitTest 透传，仅胶囊可交互。
 */

static NSString *const kDYYYFPSOverlayCenterXPercentKey = @"DYYYFPSOverlayCenterXPercent";
static NSString *const kDYYYFPSOverlayCenterYPercentKey = @"DYYYFPSOverlayCenterYPercent";
static NSString *const kDYYYFPSOverlayPositionLockedKey = @"DYYYFPSOverlayPositionLocked";

static atomic_bool gDYYYFPSOverlayStarted = false;
static id gDYYYFPSOverlayBecomeActiveObserver = nil;
static id gDYYYFPSOverlayResignActiveObserver = nil;
static id gDYYYFPSOverlayOrientationObserver = nil;

@interface DYYYFPSOverlayView : UIView
@property(nonatomic, strong) UILabel *fpsLabel;
@property(nonatomic, assign, getter=isDragging) BOOL dragging;
@property(nonatomic, assign, getter=isMovementLocked) BOOL movementLocked;
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;
@property(nonatomic, assign) CFTimeInterval lastTimestamp;
@property(nonatomic, assign) NSInteger frameCount;
@property(nonatomic, assign) NSInteger displayedFPS;
- (void)startSampling;
- (void)stopSampling;
- (void)restartSampling;
- (CGRect)frameByApplyingSavedPositionToFrame:(CGRect)frame inRoot:(UIView *)root;
@end

@interface DYYYFPSOverlayPassthroughWindow : UIWindow
@end

@implementation DYYYFPSOverlayPassthroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) {
        return nil;
    }
    return hit;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

@end

@implementation DYYYFPSOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
        self.layer.cornerRadius = 7.0;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
        self.layer.borderWidth = 0.5;
        self.accessibilityIdentifier = @"dyyy_fps_overlay_view";

        _fpsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _fpsLabel.textColor = [UIColor whiteColor];
        _fpsLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold];
        _fpsLabel.textAlignment = NSTextAlignmentCenter;
        _fpsLabel.adjustsFontSizeToFitWidth = YES;
        _fpsLabel.minimumScaleFactor = 0.75;
        _fpsLabel.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        _fpsLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        _fpsLabel.text = @"-- FPS";
        [self addSubview:_fpsLabel];

        _movementLocked = [[NSUserDefaults standardUserDefaults] boolForKey:kDYYYFPSOverlayPositionLockedKey];
        _lastTimestamp = 0;
        _frameCount = 0;
        _displayedFPS = -1;

        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPressGesture.minimumPressDuration = 0.5;
        [self addGestureRecognizer:longPressGesture];

        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [panGesture requireGestureRecognizerToFail:longPressGesture];
        [self addGestureRecognizer:panGesture];
    }
    return self;
}

- (void)dealloc {
    [self stopSampling];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.fpsLabel.frame = CGRectInset(self.bounds, 7.0, 2.0);
}

- (UIEdgeInsets)safeInsetsInRoot:(UIView *)root {
    if (@available(iOS 11.0, *)) {
        return root.safeAreaInsets;
    }
    return UIEdgeInsetsZero;
}

- (CGPoint)clampedCenter:(CGPoint)center viewSize:(CGSize)viewSize inRoot:(UIView *)root {
    UIEdgeInsets safeInsets = [self safeInsetsInRoot:root];
    CGFloat halfW = viewSize.width * 0.5;
    CGFloat halfH = viewSize.height * 0.5;
    CGFloat minX = safeInsets.left + halfW + 4.0;
    CGFloat maxX = CGRectGetWidth(root.bounds) - safeInsets.right - halfW - 4.0;
    CGFloat minY = safeInsets.top + halfH + 4.0;
    CGFloat maxY = CGRectGetHeight(root.bounds) - safeInsets.bottom - halfH - 4.0;
    if (minX > maxX) {
        center.x = CGRectGetMidX(root.bounds);
    } else {
        center.x = fmin(fmax(center.x, minX), maxX);
    }
    if (minY > maxY) {
        center.y = CGRectGetMidY(root.bounds);
    } else {
        center.y = fmin(fmax(center.y, minY), maxY);
    }
    return center;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *root = self.superview;
    if (self.isMovementLocked || !root) {
        return;
    }

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.dragging = YES;
        self.alpha = 0.8;
    }

    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:root];
        CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
        self.center = [self clampedCenter:newCenter viewSize:self.bounds.size inRoot:root];
        [gesture setTranslation:CGPointZero inView:root];
    }

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled ||
        gesture.state == UIGestureRecognizerStateFailed) {
        self.dragging = NO;
        self.alpha = 1.0;
        [self savePosition];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }

    self.movementLocked = !self.isMovementLocked;
    [[NSUserDefaults standardUserDefaults] setBool:self.isMovementLocked forKey:kDYYYFPSOverlayPositionLockedKey];
    if (self.isMovementLocked) {
        [self savePosition];
    }

    [DYYYUtils showToast:self.isMovementLocked ? @"帧率浮窗位置已锁定" : @"帧率浮窗位置已解锁"];
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

- (void)savePosition {
    UIView *root = self.superview;
    if (!root) {
        return;
    }

    CGFloat rootWidth = CGRectGetWidth(root.bounds);
    CGFloat rootHeight = CGRectGetHeight(root.bounds);
    if (rootWidth <= 0.0 || rootHeight <= 0.0) {
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:self.center.x / rootWidth forKey:kDYYYFPSOverlayCenterXPercentKey];
    [defaults setDouble:self.center.y / rootHeight forKey:kDYYYFPSOverlayCenterYPercentKey];
}

- (CGRect)frameByApplyingSavedPositionToFrame:(CGRect)frame inRoot:(UIView *)root {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults objectForKey:kDYYYFPSOverlayCenterXPercentKey] || ![defaults objectForKey:kDYYYFPSOverlayCenterYPercentKey]) {
        return frame;
    }

    CGFloat rootWidth = CGRectGetWidth(root.bounds);
    CGFloat rootHeight = CGRectGetHeight(root.bounds);
    if (rootWidth <= 0.0 || rootHeight <= 0.0) {
        return frame;
    }

    CGFloat centerXPercent = fmin(fmax([defaults doubleForKey:kDYYYFPSOverlayCenterXPercentKey], 0.0), 1.0);
    CGFloat centerYPercent = fmin(fmax([defaults doubleForKey:kDYYYFPSOverlayCenterYPercentKey], 0.0), 1.0);
    CGPoint center = CGPointMake(rootWidth * centerXPercent, rootHeight * centerYPercent);
    center = [self clampedCenter:center viewSize:frame.size inRoot:root];
    frame.origin.x = center.x - frame.size.width * 0.5;
    frame.origin.y = center.y - frame.size.height * 0.5;
    return frame;
}

- (CGRect)defaultFrameInRoot:(UIView *)root {
    UIEdgeInsets safeInsets = [self safeInsetsInRoot:root];
    CGSize size = CGSizeMake(72.0, 24.0);
    CGFloat x = CGRectGetWidth(root.bounds) - safeInsets.right - size.width - 12.0;
    CGFloat y = safeInsets.top + 12.0;
    return CGRectMake(x, y, size.width, size.height);
}

- (void)applyPreferredRefreshRateToDisplayLink {
    if (!self.displayLink) {
        return;
    }

    NSInteger maxFPS = UIScreen.mainScreen.maximumFramesPerSecond;
    if (maxFPS <= 0) {
        maxFPS = 60;
    }

    if ([self.displayLink respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
        float max = (float)maxFPS;
        self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(max * 0.5f, max, max);
    }
    if ([self.displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
        self.displayLink.preferredFramesPerSecond = maxFPS;
    }
}

- (void)startSampling {
    if (self.displayLink) {
        [self applyPreferredRefreshRateToDisplayLink];
        return;
    }
    self.lastTimestamp = 0;
    self.frameCount = 0;
    self.displayedFPS = -1;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];
    [self applyPreferredRefreshRateToDisplayLink];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopSampling {
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.lastTimestamp = 0;
    self.frameCount = 0;
}

- (void)restartSampling {
    [self stopSampling];
    [self startSampling];
}

- (void)onDisplayLink:(CADisplayLink *)link {
    if (self.lastTimestamp <= 0) {
        self.lastTimestamp = link.timestamp;
        self.frameCount = 0;
        return;
    }

    self.frameCount += 1;
    CFTimeInterval delta = link.timestamp - self.lastTimestamp;
    if (delta < 0.25) {
        return;
    }

    NSInteger fps = (NSInteger)llround((double)self.frameCount / delta);
    if (fps < 0) {
        fps = 0;
    }
    self.lastTimestamp = link.timestamp;
    self.frameCount = 0;

    if (fps == self.displayedFPS) {
        return;
    }
    self.displayedFPS = fps;
    self.fpsLabel.text = [NSString stringWithFormat:@"%ld FPS", (long)fps];
}

@end

#pragma mark - Controller

static DYYYFPSOverlayPassthroughWindow *gDYYYFPSOverlayWindow = nil;
static DYYYFPSOverlayView *gDYYYFPSOverlayView = nil;

static BOOL DYYYFPSOverlayShouldShow(void) {
    return DYYYGetBoolCached(DYYY_ENABLE_HIGH_FPS_KEY) && DYYYGetBoolCached(DYYY_SHOW_FPS_OVERLAY_KEY);
}

static UIWindowScene *DYYYFPSOverlayActiveScene(void) {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *inactive = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene;
            }
            if (!inactive && windowScene.activationState == UISceneActivationStateForegroundInactive) {
                inactive = windowScene;
            }
        }
        if (inactive) {
            return inactive;
        }
        UIWindow *host = [DYYYUtils getActiveWindow];
        return host.windowScene;
    }
    return nil;
}

static void DYYYFPSOverlayTearDown(void) {
    [gDYYYFPSOverlayView stopSampling];
    [gDYYYFPSOverlayView removeFromSuperview];
    gDYYYFPSOverlayView = nil;

    gDYYYFPSOverlayWindow.hidden = YES;
    gDYYYFPSOverlayWindow.rootViewController = nil;
    gDYYYFPSOverlayWindow = nil;
}

static void DYYYFPSOverlayLayoutPill(void) {
    if (!gDYYYFPSOverlayView || !gDYYYFPSOverlayWindow) {
        return;
    }
    UIView *root = gDYYYFPSOverlayWindow.rootViewController.view;
    if (!root) {
        return;
    }
    if (gDYYYFPSOverlayView.isDragging) {
        return;
    }
    CGRect defaultFrame = [gDYYYFPSOverlayView defaultFrameInRoot:root];
    gDYYYFPSOverlayView.frame = [gDYYYFPSOverlayView frameByApplyingSavedPositionToFrame:defaultFrame inRoot:root];
}

static void DYYYFPSOverlayEnsureOnMain(void) {
    if (!DYYYFPSOverlayShouldShow()) {
        DYYYFPSOverlayTearDown();
        return;
    }

    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        scene = DYYYFPSOverlayActiveScene();
        if (!scene) {
            return;
        }
    }

    BOOL createdWindow = NO;
    if (!gDYYYFPSOverlayWindow) {
        if (@available(iOS 13.0, *)) {
            gDYYYFPSOverlayWindow = [[DYYYFPSOverlayPassthroughWindow alloc] initWithWindowScene:scene];
        } else {
            gDYYYFPSOverlayWindow = [[DYYYFPSOverlayPassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }
        // 高于宿主内容与 DYYY 设置页，低于系统 Alert。
        gDYYYFPSOverlayWindow.windowLevel = UIWindowLevelStatusBar + 120.0;
        gDYYYFPSOverlayWindow.backgroundColor = [UIColor clearColor];
        gDYYYFPSOverlayWindow.opaque = NO;
        gDYYYFPSOverlayWindow.userInteractionEnabled = YES;

        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        gDYYYFPSOverlayWindow.rootViewController = rootVC;
        createdWindow = YES;
    } else if (@available(iOS 13.0, *)) {
        if (scene && gDYYYFPSOverlayWindow.windowScene != scene) {
            gDYYYFPSOverlayWindow.windowScene = scene;
        }
    }

    UIView *rootView = gDYYYFPSOverlayWindow.rootViewController.view;
    if (!gDYYYFPSOverlayView) {
        gDYYYFPSOverlayView = [[DYYYFPSOverlayView alloc] initWithFrame:CGRectZero];
        [rootView addSubview:gDYYYFPSOverlayView];
    } else if (gDYYYFPSOverlayView.superview != rootView) {
        [gDYYYFPSOverlayView removeFromSuperview];
        [rootView addSubview:gDYYYFPSOverlayView];
    }

    gDYYYFPSOverlayWindow.hidden = NO;
    gDYYYFPSOverlayView.hidden = NO;
    gDYYYFPSOverlayView.alpha = 1.0;
    [rootView bringSubviewToFront:gDYYYFPSOverlayView];
    DYYYFPSOverlayLayoutPill();

    if (createdWindow || !gDYYYFPSOverlayView.displayLink) {
        [gDYYYFPSOverlayView restartSampling];
    } else {
        [gDYYYFPSOverlayView startSampling];
    }
}

void DYYYApplyFPSOverlaySettingChange(void) {
    void (^block)(void) = ^{
      DYYYFPSOverlayEnsureOnMain();
    };
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

void DYYYStartFPSOverlay(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYFPSOverlayStarted, &expected, true)) {
        return;
    }

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    gDYYYFPSOverlayBecomeActiveObserver =
        [center addObserverForName:UIApplicationDidBecomeActiveNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *note) {
                          DYYYApplyFPSOverlaySettingChange();
                        }];
    gDYYYFPSOverlayResignActiveObserver =
        [center addObserverForName:UIApplicationWillResignActiveNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *note) {
                          [gDYYYFPSOverlayView stopSampling];
                        }];
    gDYYYFPSOverlayOrientationObserver =
        [center addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *note) {
                          if (DYYYFPSOverlayShouldShow()) {
                              DYYYFPSOverlayEnsureOnMain();
                              DYYYFPSOverlayLayoutPill();
                          }
                        }];

    dispatch_async(dispatch_get_main_queue(), ^{
      DYYYApplyFPSOverlaySettingChange();
    });
}
