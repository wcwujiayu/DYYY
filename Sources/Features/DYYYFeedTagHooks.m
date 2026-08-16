#import "DYYYFeedTagHooks.h"

#import "AwemeHeaders.h"
#import "DYYYRuntimeHookInstaller.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdatomic.h>

static NSString *const kDYYYHideItemTagKey = @"DYYYHideItemTag";
static NSString *const kDYYYHideLiveGIFKey = @"DYYYHideLiveGIF";
static void *const kDYYYVideoTypeTagRestoreAttemptedKey = (void *)&kDYYYVideoTypeTagRestoreAttemptedKey;
static const char *kDYYYVoidNoArgumentEncodings[] = { "v16@0:8" };

typedef void (*DYYYVoidNoArgumentIMP)(id, SEL);

static DYYYVoidNoArgumentIMP gDYYYOriginalItemTagLayoutSubviews;
static DYYYVoidNoArgumentIMP gDYYYOriginalVideoTypeTagSetupUI;
static DYYYVoidNoArgumentIMP gDYYYOriginalVideoTypeTagLayoutSubviews;
static atomic_bool gDYYYFeedTagHooksStarted = false;
static BOOL gDYYYTagSettingRefreshScheduled = NO;

static NSHashTable<UIView *> *DYYYTrackedItemTagViews(void) {
    static NSHashTable<UIView *> *views;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        views = [NSHashTable weakObjectsHashTable];
    });
    return views;
}

static NSHashTable<UIView *> *DYYYTrackedVideoTypeTagViews(void) {
    static NSHashTable<UIView *> *views;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        views = [NSHashTable weakObjectsHashTable];
    });
    return views;
}

static void DYYYRequestTagSuperviewLayout(UIView *view, BOOL immediately) {
    UIView *parent = view.superview;
    if (!parent) {
        return;
    }
    [parent setNeedsLayout];
    if (immediately) {
        [parent layoutIfNeeded];
    }
}

static void DYYYSyncViewHiddenToSetting(UIView *view, BOOL hide, BOOL layoutImmediately) {
    if (view.hidden == hide) {
        return;
    }
    view.hidden = hide;
    DYYYRequestTagSuperviewLayout(view, layoutImmediately);
}

static void DYYYApplyCorrelationItemTagSetting(UIView *view, BOOL layoutImmediately) {
    if (![view isKindOfClass:[UIView class]]) {
        return;
    }
    DYYYSyncViewHiddenToSetting(view, DYYYGetBool(kDYYYHideItemTagKey), layoutImmediately);
}

static BOOL DYYYVideoTypeTagLooksEmpty(UIView *view) {
    if (view.subviews.count == 0) {
        return YES;
    }
    if (![view respondsToSelector:@selector(tagLabel)]) {
        return NO;
    }
    id label = ((id (*)(id, SEL))objc_msgSend)(view, @selector(tagLabel));
    return label == nil;
}

static void DYYYRestoreVideoTypeTagContentIfNeeded(UIView *view, BOOL layoutImmediately) {
    if (DYYYGetBool(kDYYYHideLiveGIFKey) || !DYYYVideoTypeTagLooksEmpty(view) ||
        objc_getAssociatedObject(view, kDYYYVideoTypeTagRestoreAttemptedKey)) {
        return;
    }

    id viewModel = nil;
    if ([view respondsToSelector:@selector(viewModel)]) {
        viewModel = ((id (*)(id, SEL))objc_msgSend)(view, @selector(viewModel));
    }
    if (!viewModel) {
        return;
    }

    objc_setAssociatedObject(view, kDYYYVideoTypeTagRestoreAttemptedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([view respondsToSelector:@selector(configWithViewModel:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(view, @selector(configWithViewModel:), viewModel);
    } else if ([view respondsToSelector:@selector(setupUI)]) {
        ((void (*)(id, SEL))objc_msgSend)(view, @selector(setupUI));
    }
    [view setNeedsLayout];
    DYYYRequestTagSuperviewLayout(view, layoutImmediately);
}

static void DYYYApplyVideoTypeTagSetting(UIView *view, BOOL layoutImmediately) {
    if (![view isKindOfClass:[UIView class]]) {
        return;
    }
    BOOL hide = DYYYGetBool(kDYYYHideLiveGIFKey);
    DYYYSyncViewHiddenToSetting(view, hide, layoutImmediately);
    if (!hide) {
        DYYYRestoreVideoTypeTagContentIfNeeded(view, layoutImmediately);
    }
}

static void DYYYRefreshTrackedTagSettings(void) {
    for (UIView *view in [DYYYTrackedItemTagViews() allObjects]) {
        DYYYApplyCorrelationItemTagSetting(view, NO);
    }
    for (UIView *view in [DYYYTrackedVideoTypeTagViews() allObjects]) {
        DYYYApplyVideoTypeTagSetting(view, NO);
    }
}

static void DYYYEnsureTagSettingObserver(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                          object:[NSUserDefaults standardUserDefaults]
                                                           queue:nil
                                                      usingBlock:^(__unused NSNotification *notification) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (gDYYYTagSettingRefreshScheduled) {
                    return;
                }
                gDYYYTagSettingRefreshScheduled = YES;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(),
                               ^{
                    gDYYYTagSettingRefreshScheduled = NO;
                    DYYYRefreshTrackedTagSettings();
                });
            });
        }];
    });
}

static void DYYYTrackAndApplyItemTag(UIView *view) {
    DYYYEnsureTagSettingObserver();
    [DYYYTrackedItemTagViews() addObject:view];
    DYYYApplyCorrelationItemTagSetting(view, NO);
}

static void DYYYTrackAndApplyVideoTypeTag(UIView *view) {
    DYYYEnsureTagSettingObserver();
    [DYYYTrackedVideoTypeTagViews() addObject:view];
    DYYYApplyVideoTypeTagSetting(view, NO);
}

static void DYYYItemTagLayoutSubviews(id self, SEL _cmd) {
    if (gDYYYOriginalItemTagLayoutSubviews) {
        gDYYYOriginalItemTagLayoutSubviews(self, _cmd);
    }
    DYYYTrackAndApplyItemTag(self);
}

static void DYYYVideoTypeTagSetupUI(id self, SEL _cmd) {
    if (gDYYYOriginalVideoTypeTagSetupUI) {
        gDYYYOriginalVideoTypeTagSetupUI(self, _cmd);
    }
    DYYYTrackAndApplyVideoTypeTag(self);
}

static void DYYYVideoTypeTagLayoutSubviews(id self, SEL _cmd) {
    if (gDYYYOriginalVideoTypeTagLayoutSubviews) {
        gDYYYOriginalVideoTypeTagLayoutSubviews(self, _cmd);
    }
    DYYYTrackAndApplyVideoTypeTag(self);
}

static BOOL DYYYFeedTagStatusNeedsRetry(DYYYRuntimeHookInstallStatus status) {
    return status == DYYYRuntimeHookInstallStatusTargetClassMissing ||
           status == DYYYRuntimeHookInstallStatusTargetMethodMissing;
}

static BOOL DYYYInstallFeedTagHooksOnce(void) {
    DYYYRuntimeHookInstallResult itemLayout = DYYYInstallRuntimeHook((DYYYRuntimeHookRequest){
        .identifier = "feed.tags.item-layout",
        .targetClass = objc_getClass("AWECorrelationItemTag"),
        .selector = @selector(layoutSubviews),
        .classMethod = NO,
        .replacement = (IMP)DYYYItemTagLayoutSubviews,
        .allowedTypeEncodings = kDYYYVoidNoArgumentEncodings,
        .allowedTypeEncodingCount = 1,
        .originalImplementation = (IMP *)&gDYYYOriginalItemTagLayoutSubviews,
    });
    DYYYRuntimeHookInstallResult videoSetup = DYYYInstallRuntimeHook((DYYYRuntimeHookRequest){
        .identifier = "feed.tags.video-setup",
        .targetClass = objc_getClass("AWEVideoTypeTagView"),
        .selector = @selector(setupUI),
        .classMethod = NO,
        .replacement = (IMP)DYYYVideoTypeTagSetupUI,
        .allowedTypeEncodings = kDYYYVoidNoArgumentEncodings,
        .allowedTypeEncodingCount = 1,
        .originalImplementation = (IMP *)&gDYYYOriginalVideoTypeTagSetupUI,
    });
    DYYYRuntimeHookInstallResult videoLayout = DYYYInstallRuntimeHook((DYYYRuntimeHookRequest){
        .identifier = "feed.tags.video-layout",
        .targetClass = objc_getClass("AWEVideoTypeTagView"),
        .selector = @selector(layoutSubviews),
        .classMethod = NO,
        .replacement = (IMP)DYYYVideoTypeTagLayoutSubviews,
        .allowedTypeEncodings = kDYYYVoidNoArgumentEncodings,
        .allowedTypeEncodingCount = 1,
        .originalImplementation = (IMP *)&gDYYYOriginalVideoTypeTagLayoutSubviews,
    });

    DYYYRuntimeHookInstallResult results[] = { itemLayout, videoSetup, videoLayout };
    BOOL needsRetry = NO;
    for (NSUInteger index = 0; index < sizeof(results) / sizeof(results[0]); index++) {
        DYYYRuntimeHookInstallStatus status = results[index].status;
        needsRetry |= DYYYFeedTagStatusNeedsRetry(status);
        if (status != DYYYRuntimeHookInstallStatusInstalled &&
            status != DYYYRuntimeHookInstallStatusAlreadyInstalled &&
            !DYYYFeedTagStatusNeedsRetry(status)) {
            NSLog(@"[DYYY][HookManager][FeedTag] install rejected status=%@ encoding=%s",
                  DYYYRuntimeHookInstallStatusName(status),
                  results[index].actualTypeEncoding ?: "<missing>");
        }
    }
    return !needsRetry;
}

void DYYYStartFeedTagHooks(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong_explicit(&gDYYYFeedTagHooksStarted,
                                                  &expected,
                                                  true,
                                                  memory_order_acq_rel,
                                                  memory_order_acquire)) {
        return;
    }

    if (DYYYInstallFeedTagHooksOnce()) {
        return;
    }
    NSArray<NSNumber *> *delays = @[ @0.2, @0.8, @2.0, @5.0, @10.0 ];
    for (NSNumber *delay in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(),
                       ^{
            DYYYInstallFeedTagHooksOnce();
        });
    }
}
