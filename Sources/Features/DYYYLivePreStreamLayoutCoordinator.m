#import "DYYYLivePreStreamLayoutCoordinator.h"

#import <dlfcn.h>
#import <objc/runtime.h>

#import "AwemeHeaders.h"
#import "DYYYUtils.h"

@interface DYYYLivePreStreamTransformState : NSObject

@property(nonatomic, assign) CGAffineTransform baseTransform;
@property(nonatomic, assign) CGAffineTransform appliedTransform;
@property(nonatomic, assign) BOOL hasAppliedTransform;

@end

@implementation DYYYLivePreStreamTransformState
@end

@interface DYYYLivePreStreamControllerState : NSObject

@property(nonatomic, weak) UIViewController *viewController;
@property(nonatomic, strong) NSHashTable<UIView *> *managedViews;
@property(nonatomic, copy) NSArray<id> *notificationTokens;
@property(nonatomic, assign) NSUInteger generation;
@property(nonatomic, assign) BOOL updateScheduled;
@property(nonatomic, assign) BOOL applyingLayout;
@property(nonatomic, assign) BOOL layoutActive;

@end

@implementation DYYYLivePreStreamControllerState

- (void)dealloc {
    for (id token in self.notificationTokens) {
        [[NSNotificationCenter defaultCenter] removeObserver:token];
    }
}

@end

@implementation DYYYLivePreStreamLayoutCoordinator

static char kDYYYLivePreStreamControllerStateKey;
static char kDYYYLivePreStreamTransformStateKey;

+ (BOOL)isLivePreStreamController:(UIViewController *)viewController {
    Class targetClass = NSClassFromString(@"AWELiveNewPreStreamViewController");
    return targetClass && [viewController isKindOfClass:targetClass];
}

+ (BOOL)transformsNearlyEqual:(CGAffineTransform)lhs rhs:(CGAffineTransform)rhs {
    const CGFloat epsilon = 0.001;
    return fabs(lhs.a - rhs.a) <= epsilon && fabs(lhs.b - rhs.b) <= epsilon &&
           fabs(lhs.c - rhs.c) <= epsilon && fabs(lhs.d - rhs.d) <= epsilon &&
           fabs(lhs.tx - rhs.tx) <= epsilon && fabs(lhs.ty - rhs.ty) <= epsilon;
}

+ (NSString *)liveStackSizeChangeNotificationName {
    static NSString *notificationName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      void *symbol = dlsym(RTLD_DEFAULT, "kIESLiveStackViewSizeChangeNotification");
      if (symbol) {
          __unsafe_unretained NSString *resolvedName = *(__unsafe_unretained NSString **)symbol;
          if ([resolvedName isKindOfClass:NSString.class] && resolvedName.length > 0) {
              notificationName = [resolvedName copy];
          }
      }
      if (notificationName.length == 0) {
          notificationName = @"kIESLiveStackViewSizeChangeNotification";
      }
    });
    return notificationName;
}

+ (DYYYLivePreStreamControllerState *)stateForController:(UIViewController *)viewController createIfNeeded:(BOOL)createIfNeeded {
    if (![self isLivePreStreamController:viewController]) {
        return nil;
    }

    DYYYLivePreStreamControllerState *state = objc_getAssociatedObject(viewController, &kDYYYLivePreStreamControllerStateKey);
    if (state || !createIfNeeded) {
        return state;
    }

    state = [[DYYYLivePreStreamControllerState alloc] init];
    state.viewController = viewController;
    state.managedViews = [NSHashTable weakObjectsHashTable];

    __weak DYYYLivePreStreamControllerState *weakState = state;
    NSString *notificationName = [self liveStackSizeChangeNotificationName];
    id sizeChangeToken = [[NSNotificationCenter defaultCenter] addObserverForName:notificationName
                                                                            object:nil
                                                                             queue:[NSOperationQueue mainQueue]
                                                                        usingBlock:^(NSNotification *notification) {
                                                                          DYYYLivePreStreamControllerState *strongState = weakState;
                                                                          UIViewController *controller = strongState.viewController;
                                                                          if (!strongState.layoutActive || !controller || !controller.view.window) {
                                                                              return;
                                                                          }

                                                                          id object = notification.object;
                                                                          if ([object isKindOfClass:UIView.class]) {
                                                                              UIViewController *owner = [DYYYUtils firstAvailableViewControllerFromView:(UIView *)object];
                                                                              if (owner && owner != controller) {
                                                                                  return;
                                                                              }
                                                                          }
                                                                          [DYYYLivePreStreamLayoutCoordinator scheduleUpdateForController:controller];
                                                                        }];
    id defaultsToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                                          object:NSUserDefaults.standardUserDefaults
                                                                           queue:[NSOperationQueue mainQueue]
                                                                      usingBlock:^(__unused NSNotification *notification) {
                                                                        DYYYLivePreStreamControllerState *strongState = weakState;
                                                                        if (strongState.layoutActive && strongState.viewController.view.window) {
                                                                            [DYYYLivePreStreamLayoutCoordinator scheduleUpdateForController:strongState.viewController];
                                                                        }
                                                                      }];
    NSMutableArray<id> *tokens = [NSMutableArray array];
    if (sizeChangeToken) {
        [tokens addObject:sizeChangeToken];
    }
    if (defaultsToken) {
        [tokens addObject:defaultsToken];
    }
    state.notificationTokens = [tokens copy];
    objc_setAssociatedObject(viewController, &kDYYYLivePreStreamControllerStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return state;
}

+ (DYYYLivePreStreamTransformState *)transformStateForView:(UIView *)view createIfNeeded:(BOOL)createIfNeeded {
    DYYYLivePreStreamTransformState *state = objc_getAssociatedObject(view, &kDYYYLivePreStreamTransformStateKey);
    if (!state && createIfNeeded) {
        state = [[DYYYLivePreStreamTransformState alloc] init];
        objc_setAssociatedObject(view, &kDYYYLivePreStreamTransformStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

+ (void)restoreManagedView:(UIView *)view clearState:(BOOL)clearState {
    if (!view) {
        return;
    }

    DYYYLivePreStreamTransformState *state = [self transformStateForView:view createIfNeeded:NO];
    if (!state) {
        return;
    }

    if (state.hasAppliedTransform && [self transformsNearlyEqual:view.transform rhs:state.appliedTransform]) {
        view.transform = state.baseTransform;
    }

    state.hasAppliedTransform = NO;
    if (clearState) {
        objc_setAssociatedObject(view, &kDYYYLivePreStreamTransformStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (CGAffineTransform)prepareBaseTransformForView:(UIView *)view {
    DYYYLivePreStreamTransformState *state = [self transformStateForView:view createIfNeeded:YES];
    CGAffineTransform currentTransform = view.transform;

    if (state.hasAppliedTransform && [self transformsNearlyEqual:currentTransform rhs:state.appliedTransform]) {
        currentTransform = state.baseTransform;
        if (![self transformsNearlyEqual:view.transform rhs:currentTransform]) {
            view.transform = currentTransform;
        }
    } else {
        state.baseTransform = currentTransform;
    }

    state.hasAppliedTransform = NO;
    return state.baseTransform;
}

+ (void)applyTransform:(CGAffineTransform)transform toView:(UIView *)view baseTransform:(CGAffineTransform)baseTransform {
    DYYYLivePreStreamTransformState *state = [self transformStateForView:view createIfNeeded:YES];
    state.baseTransform = baseTransform;
    state.appliedTransform = transform;
    state.hasAppliedTransform = YES;

    if (![self transformsNearlyEqual:view.transform rhs:transform]) {
        view.transform = transform;
    }
}

+ (BOOL)isVisibleView:(UIView *)view inWindow:(UIWindow *)window {
    if (!view || !window || view.window != window || view.hidden || view.alpha <= 0.01 || CGRectIsEmpty(view.bounds)) {
        return NO;
    }

    CGRect rect = [view convertRect:view.bounds toView:window];
    if (CGRectIsNull(rect) || CGRectIsInfinite(rect) || CGRectIsEmpty(rect)) {
        return NO;
    }

    return CGRectIntersectsRect(rect, window.bounds);
}

+ (NSArray<UIView *> *)visibleStackViewsInController:(UIViewController *)viewController window:(UIWindow *)window {
    UIView *rootView = viewController.view;
    Class elementStackClass = NSClassFromString(@"AWEElementStackView");
    Class liveStackClass = NSClassFromString(@"IESLiveStackView");
    if (!rootView || !window || (!elementStackClass && !liveStackClass)) {
        return @[];
    }

    NSMutableArray<UIView *> *stackViews = [NSMutableArray array];
    if (elementStackClass) {
        for (UIView *view in [DYYYUtils findAllSubviewsOfClass:elementStackClass inContainer:rootView]) {
            if ([self isVisibleView:view inWindow:window]) {
                [stackViews addObject:view];
            }
        }
    }
    if (liveStackClass) {
        for (UIView *view in [DYYYUtils findAllSubviewsOfClass:liveStackClass inContainer:rootView]) {
            if ([self isVisibleView:view inWindow:window] && ![stackViews containsObject:view]) {
                [stackViews addObject:view];
            }
        }
    }

    CGRect rootRect = [rootView convertRect:rootView.bounds toView:window];
    CGFloat minimumContentY = CGRectGetMinY(rootRect) + CGRectGetHeight(rootRect) * 0.35;
    NSIndexSet *offscreenIndexes = [stackViews indexesOfObjectsPassingTest:^BOOL(UIView *view, NSUInteger idx, BOOL *stop) {
      CGRect rect = [view convertRect:view.bounds toView:window];
      return CGRectGetMaxY(rect) < minimumContentY;
    }];
    [stackViews removeObjectsAtIndexes:offscreenIndexes];
    return [stackViews copy];
}

+ (NSArray<UIView *> *)topLevelTranslationRootsFromStackViews:(NSArray<UIView *> *)stackViews {
    NSMutableArray<UIView *> *roots = [NSMutableArray array];
    for (UIView *candidate in stackViews) {
        BOOL hasStackAncestor = NO;
        UIView *ancestor = candidate.superview;
        while (ancestor) {
            if ([stackViews containsObject:ancestor]) {
                hasStackAncestor = YES;
                break;
            }
            ancestor = ancestor.superview;
        }
        if (!hasStackAncestor) {
            [roots addObject:candidate];
        }
    }
    return [roots copy];
}

+ (NSString *)settingStringForKey:(NSString *)key {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value stringValue];
    }
    return nil;
}

+ (CGFloat)scaleValueForKey:(NSString *)key {
    NSString *scaleValue = [self settingStringForKey:key];
    if (scaleValue.length == 0) {
        return 1.0;
    }
    CGFloat scale = [scaleValue floatValue];
    return scale > 0.0 ? scale : 1.0;
}

+ (CGFloat)verticalOffsetYForKey:(NSString *)key {
    NSString *value = [self settingStringForKey:key];
    if (value.length == 0) {
        return 0.0;
    }
    // 与播放交互层一致：设置上移为正、下移为负，UIKit ty 取反。
    return -[value floatValue];
}

+ (BOOL)view:(UIView *)view containsClass:(Class)targetClass {
    return targetClass && [DYYYUtils containsSubviewOfClass:targetClass inContainer:view];
}

+ (BOOL)isRightInteractionStack:(UIView *)stackView {
    if (!stackView) {
        return NO;
    }
    NSString *label = stackView.accessibilityLabel ?: @"";
    if ([label isEqualToString:@"right"]) {
        return YES;
    }
    if ([self view:stackView containsClass:NSClassFromString(@"AFDCancelMuteAwemeView")] ||
        [self view:stackView containsClass:NSClassFromString(@"AWEPlayInteractionUserAvatarView")]) {
        return YES;
    }
    for (UIView *sub in [stackView.subviews copy]) {
        if (![sub respondsToSelector:@selector(elementClassName)]) {
            continue;
        }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *elementClassName = [sub performSelector:@selector(elementClassName)];
#pragma clang diagnostic pop
        if ([elementClassName isEqualToString:@"AWEPlayInteractionUserAvatarOptElementElement"]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)stackViewHasNestedScalableStack:(UIView *)stackView stackViews:(NSArray<UIView *> *)stackViews {
    Class guideClass = NSClassFromString(@"AWELivePrestreamGuideView");
    Class muteClass = NSClassFromString(@"AFDCancelMuteAwemeView");
    Class tagClass = NSClassFromString(@"AWELiveFeedLabelTagView");

    for (UIView *candidate in stackViews) {
        if (candidate == stackView || ![candidate isDescendantOfView:stackView]) {
            continue;
        }
        if ([self view:candidate containsClass:guideClass] ||
            [self view:candidate containsClass:muteClass] ||
            [self view:candidate containsClass:tagClass] ||
            [self isRightInteractionStack:candidate] ||
            [self view:candidate containsClass:NSClassFromString(@"AWELiveFeedStatusLabel")]) {
            return YES;
        }
    }
    return NO;
}

+ (NSMapTable<UIView *, NSValue *> *)localTransformsForStackViews:(NSArray<UIView *> *)stackViews {
    Class guideClass = NSClassFromString(@"AWELivePrestreamGuideView");
    Class tagClass = NSClassFromString(@"AWELiveFeedLabelTagView");
    Class enterLiveClass = NSClassFromString(@"AWELiveFeedStatusLabel");

    CGFloat nicknameScale = [self scaleValueForKey:@"DYYYNicknameScale"];
    CGFloat descriptionScale = [self scaleValueForKey:@"DYYYDescriptionScale"];
    CGFloat elementScale = [self scaleValueForKey:@"DYYYElementScale"];
    CGFloat nicknameOffset = [self verticalOffsetYForKey:@"DYYYNicknameVerticalOffset"];
    CGFloat descriptionOffset = [self verticalOffsetYForKey:@"DYYYDescriptionVerticalOffset"];

    NSMapTable<UIView *, NSValue *> *transforms = [NSMapTable strongToStrongObjectsMapTable];
    for (UIView *stackView in stackViews) {
        BOOL hasGuide = [self view:stackView containsClass:guideClass];
        BOOL hasTag = [self view:stackView containsClass:tagClass];
        BOOL hasEnterLive = [self view:stackView containsClass:enterLiveClass];
        BOOL isRightStack = [self isRightInteractionStack:stackView];
        if ((!hasGuide && !hasTag && !isRightStack && !hasEnterLive) ||
            [self stackViewHasNestedScalableStack:stackView stackViews:stackViews]) {
            continue;
        }

        CGFloat scale = 1.0;
        CGFloat tx = 0.0;
        CGFloat ty = 0.0;
        CGFloat boundsWidth = CGRectGetWidth(stackView.bounds);
        if (hasEnterLive) {
            // 「点击进入直播间」在预览页水平居中；沿用该层缩放，但 tx=0，避免左右缘补偿推偏。
            if (isRightStack) {
                scale = elementScale;
            } else if (hasTag) {
                BOOL hasDescriptionScale = fabs(descriptionScale - 1.0) > 0.0001;
                BOOL hasDescriptionOffset = fabs(descriptionOffset) > 0.0001;
                scale = hasDescriptionScale ? descriptionScale : nicknameScale;
                ty = hasDescriptionOffset ? descriptionOffset : nicknameOffset;
            } else {
                scale = nicknameScale;
                ty = nicknameOffset;
            }
            tx = 0.0;
        } else if (isRightStack) {
            scale = elementScale;
            tx = (boundsWidth - boundsWidth * scale) / 2.0;
        } else if (hasGuide) {
            scale = nicknameScale;
            tx = -boundsWidth * (1.0 - scale) / 2.0;
            ty = nicknameOffset;
        } else if (hasTag) {
            // 直播胶囊对齐文案缩放与 Y 轴；未单独设置时回退昵称，避免停在原位。
            BOOL hasDescriptionScale = fabs(descriptionScale - 1.0) > 0.0001;
            BOOL hasDescriptionOffset = fabs(descriptionOffset) > 0.0001;
            scale = hasDescriptionScale ? descriptionScale : nicknameScale;
            tx = -boundsWidth * (1.0 - scale) / 2.0;
            ty = hasDescriptionOffset ? descriptionOffset : nicknameOffset;
        }

        if (!hasEnterLive) {
            for (UIView *subview in [stackView.subviews copy]) {
                CGFloat viewHeight = CGRectGetHeight(subview.bounds);
                ty += (viewHeight - viewHeight * scale) / 2.0;
            }
        }
        [transforms setObject:[NSValue valueWithCGAffineTransform:CGAffineTransformMake(scale, 0.0, 0.0, scale, tx, ty)]
                       forKey:stackView];
    }
    return transforms;
}

+ (UIView *)activeTabBarInWindow:(UIWindow *)window {
    Class tabBarClass = NSClassFromString(@"AWENormalModeTabBar");
    if (!window || !tabBarClass) {
        return nil;
    }

    UIView *bestTabBar = nil;
    CGFloat bestVisibleArea = 0.0;
    CGFloat bestMaximumY = -CGFLOAT_MAX;
    for (UIView *tabBar in [DYYYUtils findAllSubviewsOfClass:tabBarClass inContainer:window]) {
        if (![self isVisibleView:tabBar inWindow:window]) {
            continue;
        }

        CGRect rect = [tabBar convertRect:tabBar.bounds toView:window];
        CGRect intersection = CGRectIntersection(rect, window.bounds);
        CGFloat visibleArea = CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
        if (visibleArea <= 0.0 || CGRectGetMidY(intersection) < CGRectGetMidY(window.bounds)) {
            continue;
        }

        CGFloat maximumY = CGRectGetMaxY(intersection);
        if (!bestTabBar || visibleArea > bestVisibleArea + 0.5 ||
            (fabs(visibleArea - bestVisibleArea) <= 0.5 && maximumY > bestMaximumY)) {
            bestTabBar = tabBar;
            bestVisibleArea = visibleArea;
            bestMaximumY = maximumY;
        }
    }
    return bestTabBar;
}

+ (CGFloat)requiredUpwardOffsetForRoots:(NSArray<UIView *> *)roots window:(UIWindow *)window {
    if (!DYYYGetBool(@"DYYYEnableFullScreen") || roots.count == 0 || !window) {
        return 0.0;
    }

    UIView *tabBar = [self activeTabBarInWindow:window];
    if (!tabBar) {
        return 0.0;
    }

    CGRect tabBarRect = [tabBar convertRect:tabBar.bounds toView:window];
    CGRect visibleTabBarRect = CGRectIntersection(tabBarRect, window.bounds);
    if (CGRectIsNull(visibleTabBarRect) || CGRectIsEmpty(visibleTabBarRect)) {
        return 0.0;
    }

    CGRect contentRect = CGRectNull;
    for (UIView *root in roots) {
        CGRect rect = [root convertRect:root.bounds toView:window];
        if (CGRectIsNull(rect) || CGRectIsInfinite(rect) || CGRectIsEmpty(rect)) {
            continue;
        }
        contentRect = CGRectIsNull(contentRect) ? rect : CGRectUnion(contentRect, rect);
    }
    if (CGRectIsNull(contentRect) || CGRectIsEmpty(contentRect)) {
        return 0.0;
    }

    const CGFloat spacing = 6.0;
    CGFloat overlap = CGRectGetMaxY(contentRect) - (CGRectGetMinY(visibleTabBarRect) - spacing);
    if (!isfinite(overlap) || overlap <= 0.0) {
        return 0.0;
    }

    CGFloat visibleTabBarHeight = CGRectGetHeight(visibleTabBarRect);
    CGFloat maximumOffset = MIN(CGRectGetHeight(window.bounds) * 0.22, MAX(visibleTabBarHeight * 1.5, visibleTabBarHeight + 24.0));
    return MIN(overlap, MAX(maximumOffset, 0.0));
}

+ (void)updateLayoutForController:(UIViewController *)viewController {
    NSAssert(NSThread.isMainThread, @"直播预览布局只能在主线程更新");
    DYYYLivePreStreamControllerState *controllerState = [self stateForController:viewController createIfNeeded:YES];
    if (!controllerState || !controllerState.layoutActive || controllerState.applyingLayout) {
        return;
    }

    controllerState.applyingLayout = YES;
    @try {
        UIView *rootView = viewController.view;
        UIWindow *window = rootView.window;
        if (!window || rootView.hidden || rootView.alpha <= 0.01) {
            [self restoreLayoutForController:viewController];
            return;
        }

        NSArray<UIView *> *stackViews = [self visibleStackViewsInController:viewController window:window];
        NSArray<UIView *> *translationRoots = [self topLevelTranslationRootsFromStackViews:stackViews];
        NSMapTable<UIView *, NSValue *> *localTransforms = [self localTransformsForStackViews:stackViews];

        NSMutableOrderedSet<UIView *> *managedViews = [NSMutableOrderedSet orderedSetWithArray:translationRoots];
        [managedViews addObjectsFromArray:localTransforms.keyEnumerator.allObjects];

        NSSet<UIView *> *currentManagedViews = [NSSet setWithArray:managedViews.array];
        for (UIView *previousView in controllerState.managedViews.allObjects) {
            if (![currentManagedViews containsObject:previousView]) {
                [self restoreManagedView:previousView clearState:YES];
            }
        }

        NSMapTable<UIView *, NSValue *> *baseTransforms = [NSMapTable strongToStrongObjectsMapTable];
        NSMapTable<UIView *, NSValue *> *preparedTransforms = [NSMapTable strongToStrongObjectsMapTable];
        for (UIView *view in managedViews) {
            CGAffineTransform baseTransform = [self prepareBaseTransformForView:view];
            CGAffineTransform localTransform = CGAffineTransformIdentity;
            NSValue *localValue = [localTransforms objectForKey:view];
            if (localValue) {
                localTransform = localValue.CGAffineTransformValue;
            }
            CGAffineTransform preparedTransform = CGAffineTransformConcat(baseTransform, localTransform);
            [baseTransforms setObject:[NSValue valueWithCGAffineTransform:baseTransform] forKey:view];
            [preparedTransforms setObject:[NSValue valueWithCGAffineTransform:preparedTransform] forKey:view];
            if (![self transformsNearlyEqual:view.transform rhs:preparedTransform]) {
                view.transform = preparedTransform;
            }
        }

        CGFloat upwardOffset = [self requiredUpwardOffsetForRoots:translationRoots window:window];
        NSSet<UIView *> *translationRootSet = [NSSet setWithArray:translationRoots];
        for (UIView *view in managedViews) {
            CGAffineTransform finalTransform = [preparedTransforms objectForKey:view].CGAffineTransformValue;
            if ([translationRootSet containsObject:view]) {
                finalTransform.ty -= upwardOffset;
            }
            [self applyTransform:finalTransform
                         toView:view
                  baseTransform:[baseTransforms objectForKey:view].CGAffineTransformValue];
        }

        controllerState.managedViews = [NSHashTable weakObjectsHashTable];
        for (UIView *view in managedViews) {
            [controllerState.managedViews addObject:view];
        }
    } @finally {
        controllerState.applyingLayout = NO;
    }
}

+ (void)scheduleUpdateForView:(UIView *)view {
    if (!view) {
        return;
    }

    void (^scheduleBlock)(void) = ^{
      UIViewController *viewController = [DYYYUtils firstAvailableViewControllerFromView:view];
      if ([self isLivePreStreamController:viewController]) {
          [self scheduleUpdateForController:viewController];
      }
    };

    if (NSThread.isMainThread) {
        scheduleBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), scheduleBlock);
    }
}

+ (void)scheduleUpdateForController:(UIViewController *)viewController {
    if (!viewController) {
        return;
    }

    if (!NSThread.isMainThread) {
        __weak UIViewController *weakController = viewController;
        dispatch_async(dispatch_get_main_queue(), ^{
          [self scheduleUpdateForController:weakController];
        });
        return;
    }

    DYYYLivePreStreamControllerState *state = [self stateForController:viewController createIfNeeded:YES];
    if (!state || !state.layoutActive) {
        return;
    }

    state.generation += 1;
    NSUInteger generation = state.generation;
    if (!state.updateScheduled) {
        state.updateScheduled = YES;
        __weak UIViewController *weakController = viewController;
        dispatch_async(dispatch_get_main_queue(), ^{
          UIViewController *strongController = weakController;
          DYYYLivePreStreamControllerState *strongState = [self stateForController:strongController createIfNeeded:NO];
          strongState.updateScheduled = NO;
          if (strongController && strongState.layoutActive) {
              [self updateLayoutForController:strongController];
          }
        });
    }

    __weak UIViewController *weakController = viewController;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      UIViewController *strongController = weakController;
      DYYYLivePreStreamControllerState *strongState = [self stateForController:strongController createIfNeeded:NO];
      if (strongController && strongState.layoutActive && strongState.generation == generation) {
          [self updateLayoutForController:strongController];
      }
    });
}

+ (void)activateLayoutForController:(UIViewController *)viewController {
    if (!viewController) {
        return;
    }

    if (!NSThread.isMainThread) {
        __weak UIViewController *weakController = viewController;
        dispatch_async(dispatch_get_main_queue(), ^{
          [self activateLayoutForController:weakController];
        });
        return;
    }

    DYYYLivePreStreamControllerState *state = [self stateForController:viewController createIfNeeded:YES];
    if (!state) {
        return;
    }
    state.layoutActive = YES;
    [self scheduleUpdateForController:viewController];
}

+ (void)restoreLayoutForController:(UIViewController *)viewController {
    if (!viewController) {
        return;
    }

    if (!NSThread.isMainThread) {
        __weak UIViewController *weakController = viewController;
        dispatch_async(dispatch_get_main_queue(), ^{
          [self restoreLayoutForController:weakController];
        });
        return;
    }

    DYYYLivePreStreamControllerState *state = [self stateForController:viewController createIfNeeded:NO];
    if (!state) {
        return;
    }

    state.layoutActive = NO;
    for (UIView *view in state.managedViews.allObjects) {
        [self restoreManagedView:view clearState:YES];
    }
    state.managedViews = [NSHashTable weakObjectsHashTable];
    state.generation += 1;
}

@end
