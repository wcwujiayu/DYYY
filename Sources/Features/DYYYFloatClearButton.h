#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

@class HideUIButton;

extern HideUIButton *hideButton;
extern BOOL isPureViewVisible;
extern BOOL isAppActive;
extern BOOL dyyyIsPerformingFloatClearOperation;
extern BOOL isAppInTransition;
extern NSArray *targetClassNames;
extern BOOL dyyyInteractionViewVisible;
extern BOOL dyyyCommentViewVisible;
extern char dyyyClearOriginalAlphaKey;

BOOL DYYYIsDynamicAlphaView(UIView *view);
BOOL DYYYShouldExemptClearTargetView(UIView *view);
void DYYYApplyClearTargetViewHiddenState(UIView *view);
void DYYYRestoreClearTargetViewStateIfNeeded(UIView *view);

void updateClearButtonVisibility(void);
void initTargetClassNames(void);
void reloadClearButtonConfiguration(void);
void DYYYApplyFloatClearProgressStateToView(UIView *view);

#ifdef __cplusplus
}
#endif

@interface HideUIButton : UIButton
@property(nonatomic, assign) BOOL isElementsHidden;
@property(nonatomic, assign) BOOL isLocked;
@property(nonatomic, strong) NSMutableArray *hiddenViewsList;
@property(nonatomic, assign) CGFloat originalAlpha;
@property(nonatomic, strong) NSTimer *checkTimer;
@property(nonatomic, strong) NSTimer *fadeTimer;
@property(nonatomic, strong) UIView *edgeIndicatorView;
- (void)resetFadeTimer;
- (void)loadSavedPosition;
- (void)resetToDefaultPosition;
- (void)hideUIElements;
- (void)findAndHideViews:(NSArray *)classNames;
- (void)safeResetState;
- (void)startPeriodicCheck;
- (UIViewController *)findViewController:(UIView *)view;
- (void)loadIcons;
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
- (void)handleTap;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)handleTouchDown;
- (void)handleTouchUpOutside;
- (void)saveLockState;
- (void)loadLockState;
@end
