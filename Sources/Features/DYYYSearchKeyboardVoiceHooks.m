#import "DYYYSearchKeyboardVoiceHooks.h"

#import "AwemeHeaders.h"

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <stdlib.h>
#import <string.h>

static NSString *const kDYYYHideKeyboardAIKey = @"DYYYHideKeyboardAI";
static const char *const kDYYYSearchFrameworkImageMarker = "/AWESearchFramework.framework/";
static const char *const kDYYYVoiceSearchManagerClassName = "AWEVoiceSearchManager";
static const char *const kDYYYNewVoiceEntranceClassName = "AWEVoiceSearchNewEntranceView";
static const char *const kDYYYVoiceEntranceClassName = "AWEVoiceSearchEntranceView";
static const char *const kDYYYAISearchElementClassName = "AWESearchKeyboardAISearchElement";
static const char *const kDYYYGeneralSearchAIBallClassName = "AWEGeneralSearchAIBallButton";
static const char *const kDYYYGeneralSearchAIModeButtonClassName = "AWEGeneralSearchAIModeButton";
static const char *const kDYYYGeneralSearchAIModeManagerClassName = "AWEGeneralSearchAIModeManager";

typedef void (*DYYYVoidIMP)(id, SEL);
typedef void (*DYYYVoidObjectIMP)(id, SEL, id);
typedef void (*DYYYVoidBoolIMP)(id, SEL, BOOL);
typedef void (*DYYYVoidObjectBoolIMP)(id, SEL, id, BOOL);
typedef void (*DYYYVoidObjectObjectIMP)(id, SEL, id, id);
typedef id (*DYYYObjectGetterIMP)(id, SEL);

static atomic_bool gDYYYNewVoiceEntranceHookLogged = false;
static atomic_bool gDYYYNewVoiceEntranceFirstHitLogged = false;
static atomic_bool gDYYYVoiceSearchManagerHookLogged = false;
static atomic_bool gDYYYVoiceSearchCreatorFirstHitLogged = false;
static atomic_bool gDYYYLegacyVoiceEntranceHookLogged = false;
static atomic_bool gDYYYAISearchElementHookLogged = false;
static atomic_bool gDYYYGeneralSearchAIBallHookLogged = false;
static atomic_bool gDYYYGeneralSearchAIBallFirstHitLogged = false;
static atomic_bool gDYYYGeneralSearchAIModeButtonHookLogged = false;
static atomic_bool gDYYYGeneralSearchAIModeManagerHookLogged = false;

static IMP gOrigNewVoiceEntranceSetHidden = NULL;
static IMP gOrigNewVoiceEntranceLayout = NULL;
static IMP gOrigNewVoiceEntranceDidMoveToWindow = NULL;
static IMP gOrigVoiceSearchCreateEntrance = NULL;

static IMP gOrigLegacyVoiceEntranceSetHidden = NULL;
static IMP gOrigLegacyVoiceEntranceLayout = NULL;
static IMP gOrigLegacyVoiceEntranceDidMoveToWindow = NULL;

static IMP gOrigAISearchContentView = NULL;
static IMP gOrigAISearchSetContentView = NULL;
static IMP gOrigAISearchSetupUI = NULL;
static IMP gOrigAISearchSetupNewUI = NULL;
static IMP gOrigAISearchElementDidSetup = NULL;
static IMP gOrigAISearchTabbarHidden = NULL;

static IMP gOrigAIBallSetHidden = NULL;
static IMP gOrigAIBallLayout = NULL;
static IMP gOrigAIBallDidMoveToWindow = NULL;
static IMP gOrigAIBallDidMoveToSuperview = NULL;
static IMP gOrigAIBallUpdateWithConfig = NULL;

static IMP gOrigAIModeButtonSetHidden = NULL;
static IMP gOrigAIModeButtonLayout = NULL;
static IMP gOrigAIModeButtonDidMoveToWindow = NULL;
static IMP gOrigAIModeButtonDidMoveToSuperview = NULL;
static IMP gOrigAIModeButtonUpdateWithConfig = NULL;

static IMP gOrigAIModeManagerUpdateButton = NULL;
static IMP gOrigAIModeManagerPrepareHidden = NULL;
static IMP gOrigAIModeManagerSetAIBallButton = NULL;
static IMP gOrigAIModeManagerSetAIModeButton = NULL;
static IMP gOrigAIModeManagerFoldTipsToBall = NULL;
static IMP gOrigAIModeManagerFoldTipsToMode = NULL;
static IMP gOrigAIModeManagerContainerDidAppear = NULL;

static BOOL DYYYHideKeyboardAIEnabled(void) {
    return DYYYGetBool(kDYYYHideKeyboardAIKey);
}

static BOOL DYYYClassDefinesInstanceSelector(Class targetClass, SEL selector) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(targetClass, &methodCount);
    BOOL found = NO;
    for (unsigned int index = 0; index < methodCount; index++) {
        if (method_getName(methods[index]) == selector) {
            found = YES;
            break;
        }
    }
    free(methods);
    return found;
}

static BOOL DYYYInstallExactInstanceHook(Class targetClass,
                                         SEL selector,
                                         const char *expectedTypeEncoding,
                                         IMP replacement,
                                         IMP *originalSlot) {
    if (!targetClass || !selector || !expectedTypeEncoding || !replacement || !originalSlot) {
        return NO;
    }
    if (!DYYYClassDefinesInstanceSelector(targetClass, selector)) {
        return NO;
    }

    Method method = class_getInstanceMethod(targetClass, selector);
    const char *actualTypeEncoding = method ? method_getTypeEncoding(method) : NULL;
    if (!method || !actualTypeEncoding || strcmp(actualTypeEncoding, expectedTypeEncoding) != 0) {
        return NO;
    }

    IMP currentIMP = method_getImplementation(method);
    if (currentIMP == replacement) {
        return YES;
    }
    if (*originalSlot) {
        return NO;
    }

    IMP originalIMP = method_setImplementation(method, replacement);
    if (!originalIMP || originalIMP == replacement) {
        return NO;
    }
    *originalSlot = originalIMP;
    return YES;
}

static BOOL DYYYInstallSubclassOverride(Class targetClass,
                                        SEL selector,
                                        const char *expectedTypeEncoding,
                                        IMP replacement,
                                        IMP *originalSlot) {
    if (!targetClass || !selector || !expectedTypeEncoding || !replacement || !originalSlot) {
        return NO;
    }

    Method method = class_getInstanceMethod(targetClass, selector);
    const char *actualTypeEncoding = method ? method_getTypeEncoding(method) : NULL;
    if (!method || !actualTypeEncoding || strcmp(actualTypeEncoding, expectedTypeEncoding) != 0) {
        return NO;
    }

    IMP currentIMP = method_getImplementation(method);
    if (currentIMP == replacement) {
        return YES;
    }
    if (*originalSlot) {
        return NO;
    }

    if (DYYYClassDefinesInstanceSelector(targetClass, selector)) {
        IMP originalIMP = method_setImplementation(method, replacement);
        if (!originalIMP || originalIMP == replacement) {
            return NO;
        }
        *originalSlot = originalIMP;
        return YES;
    }

    // 继承方法仅在指定的抖音私有子类上增加覆盖，不修改 UIView 或搜索框架基类。
    if (!class_addMethod(targetClass, selector, replacement, actualTypeEncoding)) {
        return NO;
    }
    *originalSlot = currentIMP;
    return YES;
}

static void DYYYLogNewVoiceEntranceFirstHit(void) {
    bool expected = false;
    if (atomic_compare_exchange_strong(&gDYYYNewVoiceEntranceFirstHitLogged, &expected, true)) {
        NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] 已命中 AWEVoiceSearchNewEntranceView 并强制隐藏");
    }
}

#pragma mark - 39.8.0 manager-owned 语音搜索入口

static void DYYYForceHideNewVoiceEntranceIfNeeded(id entranceView) {
    if (!DYYYHideKeyboardAIEnabled() || !entranceView || !gOrigNewVoiceEntranceSetHidden) {
        return;
    }

    ((DYYYVoidBoolIMP)gOrigNewVoiceEntranceSetHidden)(entranceView, @selector(setHidden:), YES);
    DYYYLogNewVoiceEntranceFirstHit();
}

static void DYYYNewVoiceEntranceSetHidden(id self, SEL _cmd, BOOL hidden) {
    BOOL effectiveHidden = hidden || DYYYHideKeyboardAIEnabled();
    ((DYYYVoidBoolIMP)gOrigNewVoiceEntranceSetHidden)(self, _cmd, effectiveHidden);
    if (effectiveHidden && DYYYHideKeyboardAIEnabled()) {
        DYYYLogNewVoiceEntranceFirstHit();
    }
}

static void DYYYNewVoiceEntranceLayout(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigNewVoiceEntranceLayout)(self, _cmd);
    DYYYForceHideNewVoiceEntranceIfNeeded(self);
}

static void DYYYNewVoiceEntranceDidMoveToWindow(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigNewVoiceEntranceDidMoveToWindow)(self, _cmd);
    if (((UIView *)self).window) {
        DYYYForceHideNewVoiceEntranceIfNeeded(self);
    }
}

static id DYYYVoiceSearchCreateEntrance(id self, SEL _cmd) {
    id entranceView = ((DYYYObjectGetterIMP)gOrigVoiceSearchCreateEntrance)(self, _cmd);
    Class newEntranceClass = objc_lookUpClass(kDYYYNewVoiceEntranceClassName);
    Class voiceEntranceClass = objc_lookUpClass(kDYYYVoiceEntranceClassName);
    BOOL isKnownSearchVoiceEntrance =
        (newEntranceClass && [entranceView isKindOfClass:newEntranceClass]) ||
        (voiceEntranceClass && [entranceView isKindOfClass:voiceEntranceClass]);
    if (DYYYHideKeyboardAIEnabled() && isKnownSearchVoiceEntrance &&
        [entranceView isKindOfClass:[UIView class]]) {
        ((UIView *)entranceView).hidden = YES;

        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYVoiceSearchCreatorFirstHitLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] createVoiceSearchEntranceView 返回 %@，已隐藏",
                  NSStringFromClass([entranceView class]));
        }
    }
    return entranceView;
}

#pragma mark - 旧样式搜索语音入口（含键盘子类）

static void DYYYForceHideLegacyVoiceEntranceIfNeeded(id entranceView) {
    if (!DYYYHideKeyboardAIEnabled() || !entranceView || !gOrigLegacyVoiceEntranceSetHidden) {
        return;
    }
    ((DYYYVoidBoolIMP)gOrigLegacyVoiceEntranceSetHidden)(entranceView, @selector(setHidden:), YES);
}

static void DYYYLegacyVoiceEntranceSetHidden(id self, SEL _cmd, BOOL hidden) {
    BOOL effectiveHidden = hidden || DYYYHideKeyboardAIEnabled();
    ((DYYYVoidBoolIMP)gOrigLegacyVoiceEntranceSetHidden)(self, _cmd, effectiveHidden);
}

static void DYYYLegacyVoiceEntranceLayout(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigLegacyVoiceEntranceLayout)(self, _cmd);
    DYYYForceHideLegacyVoiceEntranceIfNeeded(self);
}

static void DYYYLegacyVoiceEntranceDidMoveToWindow(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigLegacyVoiceEntranceDidMoveToWindow)(self, _cmd);
    if (((UIView *)self).window) {
        DYYYForceHideLegacyVoiceEntranceIfNeeded(self);
    }
}

#pragma mark - 旧版本右下角 AI 搜索入口

static void DYYYHideAISearchElementIfNeeded(id element) {
    if (!DYYYHideKeyboardAIEnabled() || !element || !gOrigAISearchContentView) {
        return;
    }

    id contentView = ((DYYYObjectGetterIMP)gOrigAISearchContentView)(element, NSSelectorFromString(@"contentView"));
    if ([contentView isKindOfClass:[UIView class]]) {
        ((UIView *)contentView).hidden = YES;
        ((UIView *)contentView).userInteractionEnabled = NO;
    }
}

static id DYYYAISearchContentView(id self, SEL _cmd) {
    id contentView = ((DYYYObjectGetterIMP)gOrigAISearchContentView)(self, _cmd);
    if (DYYYHideKeyboardAIEnabled() && [contentView isKindOfClass:[UIView class]]) {
        ((UIView *)contentView).hidden = YES;
        ((UIView *)contentView).userInteractionEnabled = NO;
    }
    return contentView;
}

static void DYYYAISearchSetContentView(id self, SEL _cmd, id contentView) {
    ((DYYYVoidObjectIMP)gOrigAISearchSetContentView)(self, _cmd, contentView);
    if (DYYYHideKeyboardAIEnabled() && [contentView isKindOfClass:[UIView class]]) {
        ((UIView *)contentView).hidden = YES;
        ((UIView *)contentView).userInteractionEnabled = NO;
    }
}

static void DYYYAISearchSetupUI(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigAISearchSetupUI)(self, _cmd);
    DYYYHideAISearchElementIfNeeded(self);
}

static void DYYYAISearchSetupNewUI(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigAISearchSetupNewUI)(self, _cmd);
    DYYYHideAISearchElementIfNeeded(self);
}

static void DYYYAISearchElementDidSetup(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigAISearchElementDidSetup)(self, _cmd);
    DYYYHideAISearchElementIfNeeded(self);
}

static void DYYYAISearchTabbarHidden(id self, SEL _cmd, BOOL hidden) {
    BOOL effectiveHidden = hidden || DYYYHideKeyboardAIEnabled();
    ((DYYYVoidBoolIMP)gOrigAISearchTabbarHidden)(self, _cmd, effectiveHidden);
    DYYYHideAISearchElementIfNeeded(self);
}

#pragma mark - 综合搜索结果页 AI / 继续追问浮钮

static void DYYYLogGeneralSearchAIBallFirstHit(void) {
    bool expected = false;
    if (atomic_compare_exchange_strong(&gDYYYGeneralSearchAIBallFirstHitLogged, &expected, true)) {
        NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] 已命中综合搜索 AI 浮钮并强制隐藏（跳过创建）");
    }
}

static void DYYYForceHideGeneralSearchAIViewIfNeeded(id view, IMP setHiddenIMP) {
    if (!DYYYHideKeyboardAIEnabled() || !view) {
        return;
    }
    if (![view isKindOfClass:[UIView class]]) {
        return;
    }
    UIView *uiView = (UIView *)view;
    uiView.alpha = 0.0;
    uiView.userInteractionEnabled = NO;
    if (setHiddenIMP) {
        ((DYYYVoidBoolIMP)setHiddenIMP)(view, @selector(setHidden:), YES);
    } else {
        uiView.hidden = YES;
    }
}

static void DYYYAIBallSetHidden(id self, SEL _cmd, BOOL hidden) {
    BOOL effectiveHidden = hidden || DYYYHideKeyboardAIEnabled();
    if (DYYYHideKeyboardAIEnabled()) {
        ((UIView *)self).alpha = 0.0;
        ((UIView *)self).userInteractionEnabled = NO;
        DYYYLogGeneralSearchAIBallFirstHit();
    }
    ((DYYYVoidBoolIMP)gOrigAIBallSetHidden)(self, _cmd, effectiveHidden);
}

static void DYYYAIBallLayout(id self, SEL _cmd) {
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
    ((DYYYVoidIMP)gOrigAIBallLayout)(self, _cmd);
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
}

static void DYYYAIBallDidMoveToWindow(id self, SEL _cmd) {
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
    ((DYYYVoidIMP)gOrigAIBallDidMoveToWindow)(self, _cmd);
    if (((UIView *)self).window || DYYYHideKeyboardAIEnabled()) {
        DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
    }
}

static void DYYYAIBallDidMoveToSuperview(id self, SEL _cmd) {
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
    ((DYYYVoidIMP)gOrigAIBallDidMoveToSuperview)(self, _cmd);
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
    if (DYYYHideKeyboardAIEnabled()) {
        DYYYLogGeneralSearchAIBallFirstHit();
    }
}

static void DYYYAIBallUpdateWithConfig(id self, SEL _cmd, id config, BOOL animation) {
    // 开启时禁止动画展开，避免「先出现再消失」的闪一下。
    BOOL effectiveAnimation = DYYYHideKeyboardAIEnabled() ? NO : animation;
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
    ((DYYYVoidObjectBoolIMP)gOrigAIBallUpdateWithConfig)(self, _cmd, config, effectiveAnimation);
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIBallSetHidden);
    if (DYYYHideKeyboardAIEnabled()) {
        DYYYLogGeneralSearchAIBallFirstHit();
    }
}

static void DYYYAIModeButtonSetHidden(id self, SEL _cmd, BOOL hidden) {
    BOOL effectiveHidden = hidden || DYYYHideKeyboardAIEnabled();
    if (DYYYHideKeyboardAIEnabled()) {
        ((UIView *)self).alpha = 0.0;
        ((UIView *)self).userInteractionEnabled = NO;
    }
    ((DYYYVoidBoolIMP)gOrigAIModeButtonSetHidden)(self, _cmd, effectiveHidden);
}

static void DYYYAIModeButtonLayout(id self, SEL _cmd) {
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
    ((DYYYVoidIMP)gOrigAIModeButtonLayout)(self, _cmd);
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
}

static void DYYYAIModeButtonDidMoveToWindow(id self, SEL _cmd) {
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
    ((DYYYVoidIMP)gOrigAIModeButtonDidMoveToWindow)(self, _cmd);
    if (((UIView *)self).window || DYYYHideKeyboardAIEnabled()) {
        DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
    }
}

static void DYYYAIModeButtonDidMoveToSuperview(id self, SEL _cmd) {
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
    ((DYYYVoidIMP)gOrigAIModeButtonDidMoveToSuperview)(self, _cmd);
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
}

static void DYYYAIModeButtonUpdateWithConfig(id self, SEL _cmd, id config, BOOL animation) {
    BOOL effectiveAnimation = DYYYHideKeyboardAIEnabled() ? NO : animation;
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
    ((DYYYVoidObjectBoolIMP)gOrigAIModeButtonUpdateWithConfig)(self, _cmd, config, effectiveAnimation);
    DYYYForceHideGeneralSearchAIViewIfNeeded(self, gOrigAIModeButtonSetHidden);
}

static void DYYYAIModeManagerRemoveAIButtonIfNeeded(id manager) {
    if (!DYYYHideKeyboardAIEnabled() || !manager) {
        return;
    }
    SEL removeSelector = NSSelectorFromString(@"removeAIButton");
    if (![manager respondsToSelector:removeSelector]) {
        return;
    }
    ((void (*)(id, SEL))objc_msgSend)(manager, removeSelector);
}

static void DYYYAIModeManagerUpdateButton(id self, SEL _cmd, id model, id containerView) {
    if (DYYYHideKeyboardAIEnabled()) {
        // 跳过宿主创建/上屏浮钮，从源头消除闪一下；仍保留 model 供其它状态读取。
        if (model) {
            SEL setDefaultHidden = NSSelectorFromString(@"setDefaultHidden:");
            if ([model respondsToSelector:setDefaultHidden]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(model, setDefaultHidden, YES);
            }
            SEL setModel = NSSelectorFromString(@"setAiButtonModel:");
            if ([self respondsToSelector:setModel]) {
                ((void (*)(id, SEL, id))objc_msgSend)(self, setModel, model);
            }
        }
        DYYYAIModeManagerRemoveAIButtonIfNeeded(self);
        DYYYLogGeneralSearchAIBallFirstHit();
        return;
    }
    ((DYYYVoidObjectObjectIMP)gOrigAIModeManagerUpdateButton)(self, _cmd, model, containerView);
}

static void DYYYAIModeManagerPrepareHidden(id self, SEL _cmd, BOOL hidden) {
    BOOL effectiveHidden = hidden || DYYYHideKeyboardAIEnabled();
    ((DYYYVoidBoolIMP)gOrigAIModeManagerPrepareHidden)(self, _cmd, effectiveHidden);
    if (DYYYHideKeyboardAIEnabled()) {
        DYYYAIModeManagerRemoveAIButtonIfNeeded(self);
    }
}

static void DYYYAIModeManagerSetAIBallButton(id self, SEL _cmd, id button) {
    ((DYYYVoidObjectIMP)gOrigAIModeManagerSetAIBallButton)(self, _cmd, button);
    DYYYForceHideGeneralSearchAIViewIfNeeded(button, gOrigAIBallSetHidden);
    if (DYYYHideKeyboardAIEnabled() && button) {
        DYYYLogGeneralSearchAIBallFirstHit();
    }
}

static void DYYYAIModeManagerSetAIModeButton(id self, SEL _cmd, id button) {
    ((DYYYVoidObjectIMP)gOrigAIModeManagerSetAIModeButton)(self, _cmd, button);
    DYYYForceHideGeneralSearchAIViewIfNeeded(button, gOrigAIModeButtonSetHidden);
}

static void DYYYAIModeManagerFoldTipsToBall(id self, SEL _cmd) {
    if (DYYYHideKeyboardAIEnabled()) {
        DYYYAIModeManagerRemoveAIButtonIfNeeded(self);
        return;
    }
    ((DYYYVoidIMP)gOrigAIModeManagerFoldTipsToBall)(self, _cmd);
}

static void DYYYAIModeManagerFoldTipsToMode(id self, SEL _cmd) {
    if (DYYYHideKeyboardAIEnabled()) {
        DYYYAIModeManagerRemoveAIButtonIfNeeded(self);
        return;
    }
    ((DYYYVoidIMP)gOrigAIModeManagerFoldTipsToMode)(self, _cmd);
}

static void DYYYAIModeManagerContainerDidAppear(id self, SEL _cmd) {
    ((DYYYVoidIMP)gOrigAIModeManagerContainerDidAppear)(self, _cmd);
    DYYYAIModeManagerRemoveAIButtonIfNeeded(self);
}

#pragma mark - 安装与框架延迟加载

static void DYYYInstallNewVoiceEntranceHooks(void) {
    Class targetClass = objc_lookUpClass(kDYYYNewVoiceEntranceClassName);
    if (!targetClass) {
        return;
    }

    BOOL installed =
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(setHidden:),
                                    "v20@0:8B16",
                                    (IMP)DYYYNewVoiceEntranceSetHidden,
                                    &gOrigNewVoiceEntranceSetHidden) &&
        DYYYInstallExactInstanceHook(targetClass,
                                     @selector(layoutSubviews),
                                     "v16@0:8",
                                     (IMP)DYYYNewVoiceEntranceLayout,
                                     &gOrigNewVoiceEntranceLayout) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(didMoveToWindow),
                                    "v16@0:8",
                                    (IMP)DYYYNewVoiceEntranceDidMoveToWindow,
                                    &gOrigNewVoiceEntranceDidMoveToWindow);

    if (installed) {
        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYNewVoiceEntranceHookLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] AWEVoiceSearchNewEntranceView Hook 已安装");
        }
    }
}

static void DYYYInstallVoiceSearchManagerHooks(void) {
    Class targetClass = objc_lookUpClass(kDYYYVoiceSearchManagerClassName);
    if (!targetClass) {
        return;
    }

    BOOL installed = DYYYInstallExactInstanceHook(targetClass,
                                                   NSSelectorFromString(@"createVoiceSearchEntranceView"),
                                                   "@16@0:8",
                                                   (IMP)DYYYVoiceSearchCreateEntrance,
                                                   &gOrigVoiceSearchCreateEntrance);
    if (installed) {
        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYVoiceSearchManagerHookLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] AWEVoiceSearchManager.createVoiceSearchEntranceView Hook 已安装");
        }
    }
}

static void DYYYInstallLegacyVoiceEntranceHooks(void) {
    Class targetClass = objc_lookUpClass(kDYYYVoiceEntranceClassName);
    if (!targetClass) {
        return;
    }

    BOOL installed =
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(setHidden:),
                                    "v20@0:8B16",
                                    (IMP)DYYYLegacyVoiceEntranceSetHidden,
                                    &gOrigLegacyVoiceEntranceSetHidden) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(layoutSubviews),
                                    "v16@0:8",
                                    (IMP)DYYYLegacyVoiceEntranceLayout,
                                    &gOrigLegacyVoiceEntranceLayout) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(didMoveToWindow),
                                    "v16@0:8",
                                    (IMP)DYYYLegacyVoiceEntranceDidMoveToWindow,
                                    &gOrigLegacyVoiceEntranceDidMoveToWindow);

    if (installed) {
        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYLegacyVoiceEntranceHookLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] AWEVoiceSearchEntranceView Hook 已安装（含旧版键盘子类）");
        }
    }
}

static void DYYYInstallAISearchElementHooks(void) {
    Class targetClass = objc_lookUpClass(kDYYYAISearchElementClassName);
    if (!targetClass) {
        return;
    }

    BOOL contentViewInstalled =
        DYYYInstallSubclassOverride(targetClass,
                                    NSSelectorFromString(@"contentView"),
                                    "@16@0:8",
                                    (IMP)DYYYAISearchContentView,
                                    &gOrigAISearchContentView) &&
        DYYYInstallSubclassOverride(targetClass,
                                    NSSelectorFromString(@"setContentView:"),
                                    "v24@0:8@16",
                                    (IMP)DYYYAISearchSetContentView,
                                    &gOrigAISearchSetContentView);

    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"setupUI"),
                                 "v16@0:8",
                                 (IMP)DYYYAISearchSetupUI,
                                 &gOrigAISearchSetupUI);
    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"setupNewUI"),
                                 "v16@0:8",
                                 (IMP)DYYYAISearchSetupNewUI,
                                 &gOrigAISearchSetupNewUI);
    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"host_elementViewDidSetup"),
                                 "v16@0:8",
                                 (IMP)DYYYAISearchElementDidSetup,
                                 &gOrigAISearchElementDidSetup);
    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"host_tabbarHidden:"),
                                 "v20@0:8B16",
                                 (IMP)DYYYAISearchTabbarHidden,
                                 &gOrigAISearchTabbarHidden);

    if (contentViewInstalled) {
        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYAISearchElementHookLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] 旧版搜索键盘 AI 元素 Hook 已安装");
        }
    }
}

static void DYYYInstallGeneralSearchAIBallHooks(void) {
    Class targetClass = objc_lookUpClass(kDYYYGeneralSearchAIBallClassName);
    if (!targetClass) {
        return;
    }

    BOOL installed =
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(setHidden:),
                                    "v20@0:8B16",
                                    (IMP)DYYYAIBallSetHidden,
                                    &gOrigAIBallSetHidden) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(layoutSubviews),
                                    "v16@0:8",
                                    (IMP)DYYYAIBallLayout,
                                    &gOrigAIBallLayout) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(didMoveToWindow),
                                    "v16@0:8",
                                    (IMP)DYYYAIBallDidMoveToWindow,
                                    &gOrigAIBallDidMoveToWindow) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(didMoveToSuperview),
                                    "v16@0:8",
                                    (IMP)DYYYAIBallDidMoveToSuperview,
                                    &gOrigAIBallDidMoveToSuperview);

    BOOL updateInstalled = DYYYInstallExactInstanceHook(targetClass,
                                                        NSSelectorFromString(@"updateWithConfig:animation:"),
                                                        "v28@0:8@16B24",
                                                        (IMP)DYYYAIBallUpdateWithConfig,
                                                        &gOrigAIBallUpdateWithConfig);

    if (installed || updateInstalled) {
        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYGeneralSearchAIBallHookLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] AWEGeneralSearchAIBallButton Hook 已安装");
        }
    }
}

static void DYYYInstallGeneralSearchAIModeButtonHooks(void) {
    Class targetClass = objc_lookUpClass(kDYYYGeneralSearchAIModeButtonClassName);
    if (!targetClass) {
        return;
    }

    BOOL installed =
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(setHidden:),
                                    "v20@0:8B16",
                                    (IMP)DYYYAIModeButtonSetHidden,
                                    &gOrigAIModeButtonSetHidden) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(layoutSubviews),
                                    "v16@0:8",
                                    (IMP)DYYYAIModeButtonLayout,
                                    &gOrigAIModeButtonLayout) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(didMoveToWindow),
                                    "v16@0:8",
                                    (IMP)DYYYAIModeButtonDidMoveToWindow,
                                    &gOrigAIModeButtonDidMoveToWindow) &&
        DYYYInstallSubclassOverride(targetClass,
                                    @selector(didMoveToSuperview),
                                    "v16@0:8",
                                    (IMP)DYYYAIModeButtonDidMoveToSuperview,
                                    &gOrigAIModeButtonDidMoveToSuperview);

    BOOL updateInstalled = DYYYInstallExactInstanceHook(targetClass,
                                                        NSSelectorFromString(@"updateWithConfig:animation:"),
                                                        "v28@0:8@16B24",
                                                        (IMP)DYYYAIModeButtonUpdateWithConfig,
                                                        &gOrigAIModeButtonUpdateWithConfig);

    if (installed || updateInstalled) {
        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYGeneralSearchAIModeButtonHookLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] AWEGeneralSearchAIModeButton Hook 已安装");
        }
    }
}

static void DYYYInstallGeneralSearchAIModeManagerHooks(void) {
    Class targetClass = objc_lookUpClass(kDYYYGeneralSearchAIModeManagerClassName);
    if (!targetClass) {
        return;
    }

    BOOL primaryInstalled =
        DYYYInstallExactInstanceHook(targetClass,
                                     NSSelectorFromString(@"updateAIModeButtonWith:containerView:"),
                                     "v32@0:8@16@24",
                                     (IMP)DYYYAIModeManagerUpdateButton,
                                     &gOrigAIModeManagerUpdateButton) &&
        DYYYInstallExactInstanceHook(targetClass,
                                     NSSelectorFromString(@"prepareForNewRoundIsHidden:"),
                                     "v20@0:8B16",
                                     (IMP)DYYYAIModeManagerPrepareHidden,
                                     &gOrigAIModeManagerPrepareHidden);

    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"setAiBallButton:"),
                                 "v24@0:8@16",
                                 (IMP)DYYYAIModeManagerSetAIBallButton,
                                 &gOrigAIModeManagerSetAIBallButton);
    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"setAiModeButton:"),
                                 "v24@0:8@16",
                                 (IMP)DYYYAIModeManagerSetAIModeButton,
                                 &gOrigAIModeManagerSetAIModeButton);
    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"foldTipsToAIBallButton"),
                                 "v16@0:8",
                                 (IMP)DYYYAIModeManagerFoldTipsToBall,
                                 &gOrigAIModeManagerFoldTipsToBall);
    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"foldTipsToAIModeButton"),
                                 "v16@0:8",
                                 (IMP)DYYYAIModeManagerFoldTipsToMode,
                                 &gOrigAIModeManagerFoldTipsToMode);
    DYYYInstallExactInstanceHook(targetClass,
                                 NSSelectorFromString(@"containerViewDidAppear"),
                                 "v16@0:8",
                                 (IMP)DYYYAIModeManagerContainerDidAppear,
                                 &gOrigAIModeManagerContainerDidAppear);

    if (primaryInstalled) {
        bool expected = false;
        if (atomic_compare_exchange_strong(&gDYYYGeneralSearchAIModeManagerHookLogged, &expected, true)) {
            NSLog(@"[DYYY][RuntimeHook][HideKeyboardAI] AWEGeneralSearchAIModeManager Hook 已安装（跳过创建防闪）");
        }
    }
}

static void DYYYInstallSearchKeyboardHooks(void) {
    DYYYInstallNewVoiceEntranceHooks();
    DYYYInstallVoiceSearchManagerHooks();
    DYYYInstallLegacyVoiceEntranceHooks();
    DYYYInstallAISearchElementHooks();
    DYYYInstallGeneralSearchAIBallHooks();
    DYYYInstallGeneralSearchAIModeButtonHooks();
    DYYYInstallGeneralSearchAIModeManagerHooks();
}

static BOOL DYYYIsSearchFrameworkImage(const struct mach_header *header) {
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t index = 0; index < imageCount; index++) {
        if (_dyld_get_image_header(index) != header) {
            continue;
        }
        const char *imageName = _dyld_get_image_name(index);
        return imageName && strstr(imageName, kDYYYSearchFrameworkImageMarker) != NULL;
    }
    return NO;
}

static void DYYYSearchFrameworkImageAdded(const struct mach_header *header, intptr_t slide) {
    (void)slide;
    if (!DYYYIsSearchFrameworkImage(header)) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      DYYYInstallSearchKeyboardHooks();
    });
}

void DYYYStartSearchKeyboardVoiceHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      _dyld_register_func_for_add_image(DYYYSearchFrameworkImageAdded);

      for (NSNumber *delayNumber in @[@0.0, @0.2, @0.8, @2.0]) {
          NSTimeInterval delay = delayNumber.doubleValue;
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                         dispatch_get_main_queue(), ^{
                           DYYYInstallSearchKeyboardHooks();
                         });
      }
    });
}
