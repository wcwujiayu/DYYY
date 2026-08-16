#import <UIKit/UIKit.h>

@interface FloatingSpeedButton : UIButton
@property(nonatomic, weak) id interactionController;
@property(nonatomic, assign) BOOL isLocked;
@property(nonatomic, assign) BOOL justToggledLock;
@property(nonatomic, assign) BOOL isResponding;
@property(nonatomic, strong) NSTimer *statusCheckTimer;
@property(nonatomic, strong) NSTimer *fadeTimer;
@property(nonatomic, strong) NSTimer *autoHideTimer;
@property(nonatomic, strong) UIView *edgeIndicatorView;
@property(nonatomic, assign) BOOL isEdgeHidden;
@property(nonatomic, assign) BOOL dyyyEdgeHiddenByClearMode;
@property(nonatomic, assign) BOOL dyyyJustRestoredFromEdgeHidden;
@property(nonatomic, assign) CGFloat originalAlpha;
- (void)saveButtonPosition;
- (void)loadSavedPosition;
- (void)resetToDefaultPosition;
- (void)resetButtonState;
- (void)dyyy_schedulePresentationTimersIfNeeded;
- (void)toggleLockState;
- (void)resetFadeTimer;
- (void)dyyy_showEdgeIndicator;
- (void)dyyy_hideEdgeIndicator;
- (void)dyyy_restoreFromEdgeHidden;
- (void)dyyy_hideToEdgeForClearMode;
- (void)dyyy_restoreFromClearMode;
@end

#ifdef __cplusplus
extern "C" {
#endif

extern FloatingSpeedButton *speedButton;
extern BOOL dyyyCommentViewVisible;
extern BOOL dyyyInteractionViewVisible;
extern BOOL isFloatSpeedButtonEnabled;
extern BOOL speedButtonForceHidden;
extern BOOL showSpeedX;
extern CGFloat speedButtonSize;

extern NSArray *getSpeedOptions(void);

extern void showSpeedButton(void);
extern void hideSpeedButton(void);
extern NSArray *findViewControllersInHierarchy(UIViewController *rootViewController);
extern float getCurrentSpeed(void);
extern NSInteger getCurrentSpeedIndex(void);
extern void setCurrentSpeedIndex(NSInteger index);
extern void updateSpeedButtonUI(void);
extern void updateSpeedButtonVisibility(void);
extern void DYYYRefreshFloatSpeedButton(void);

#ifdef __cplusplus
}
#endif
