#import "DYYYHighFPSHooks.h"

#import "AwemeHeaders.h"
#import "DYYYConstants.h"

#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <substrate.h>

/*
 * 基于对 Aweme 39.8 解包的静态证据（.ipa_extract_3980）：
 * 1) Info.plist 无 CADisableMinimumFrameDurationOnPhone → CADisplayLink 会被系统钳在 60Hz
 * 2) AwemeCore 存在 AWEProMotionFPSBooster（boostFPSForScrolling/Appearance/... / degradeFPS）
 * 3) AwemeCore 存在 AWEDisplayLinkDegradeManager（disableDegradeOperation / degradeFPS）
 *
 * 开启最高帧率后默认：热状态偏高或低电量模式时自动降档（无独立设置项）。
 */

static NSString *const kDYYYCADisableMinimumFrameDurationOnPhoneKey = @"CADisableMinimumFrameDurationOnPhone";

static atomic_bool gDYYYHighFPSStarted = false;
static atomic_bool gDYYYCFBundleHookInstalled = false;
static atomic_bool gDYYYDegradeHookInstalled = false;
static atomic_bool gDYYYLoadObserversInstalled = false;

static BOOL gDYYYProMotionDiskKeyKnown = NO;
static BOOL gDYYYProMotionDiskKeyValue = NO;
static BOOL gDYYYHighFPSThrottled = NO;

static id gDYYYThermalObserver = nil;
static id gDYYYPowerObserver = nil;

static IMP gOrigSetDisableDegradeOperation = NULL;
typedef void (*DYYYVoidBoolIMP)(id, SEL, BOOL);
typedef id (*DYYYObjectGetterIMP)(id, SEL);

static CFTypeRef (*gOrigCFBundleGetValueForInfoDictionaryKey)(CFBundleRef, CFStringRef) = NULL;

static BOOL DYYYHighFPSEnabled(void) {
    return DYYYGetBoolCached(DYYY_ENABLE_HIGH_FPS_KEY);
}

/// 负载过重：热状态 ≥ Fair，或系统低电量模式。
static BOOL DYYYHighFPSLoadRequiresThrottle(void) {
    NSProcessInfo *info = [NSProcessInfo processInfo];
    if (info.isLowPowerModeEnabled) {
        return YES;
    }
    return info.thermalState >= NSProcessInfoThermalStateFair;
}

/// 高帧率生效且当前不在降档：才强制 boost / 禁止宿主降帧。
static BOOL DYYYHighFPSShouldBoost(void) {
    return DYYYHighFPSEnabled() && !gDYYYHighFPSThrottled;
}

#pragma mark - Helpers

static id DYYYCallSharedIfPossible(Class cls) {
    if (!cls) {
        return nil;
    }
    static const char *kSharedSels[] = {
        "sharedInstance",
        "sharedManager",
        "p_sharedInstance",
        "defaultManager",
        "manager",
    };
    for (size_t i = 0; i < sizeof(kSharedSels) / sizeof(kSharedSels[0]); i++) {
        SEL sel = sel_registerName(kSharedSels[i]);
        if (![cls respondsToSelector:sel]) {
            continue;
        }
        id obj = ((DYYYObjectGetterIMP)objc_msgSend)(cls, sel);
        if (obj) {
            return obj;
        }
    }
    return nil;
}

static BOOL DYYYPerformVoidOnTarget(id target, const char *selName) {
    if (!target || !selName) {
        return NO;
    }
    SEL sel = sel_registerName(selName);
    if (![target respondsToSelector:sel]) {
        return NO;
    }
    ((void (*)(id, SEL))objc_msgSend)(target, sel);
    return YES;
}

static id DYYYProMotionBoosterTarget(Class *outClass) {
    Class cls = NSClassFromString(@"AWEProMotionFPSBooster");
    if (outClass) {
        *outClass = cls;
    }
    if (!cls) {
        return nil;
    }
    id booster = DYYYCallSharedIfPossible(cls);
    return booster ?: (id)cls;
}

#pragma mark - ProMotion Info.plist unlock

static NSString *DYYYMainBundleInfoPlistPath(void) {
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    if (bundlePath.length == 0) {
        return nil;
    }
    return [bundlePath stringByAppendingPathComponent:@"Info.plist"];
}

static void DYYYCaptureDiskProMotionKeyIfNeeded(void) {
    if (gDYYYProMotionDiskKeyKnown) {
        return;
    }
    gDYYYProMotionDiskKeyKnown = YES;
    NSString *path = DYYYMainBundleInfoPlistPath();
    NSDictionary *diskInfo = path.length ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
    id value = diskInfo[kDYYYCADisableMinimumFrameDurationOnPhoneKey];
    if ([value respondsToSelector:@selector(boolValue)]) {
        gDYYYProMotionDiskKeyValue = [value boolValue];
    }
}

static BOOL DYYYMutateMainBundleInfoDictionary(BOOL enabled) {
    CFBundleRef bundle = CFBundleGetMainBundle();
    if (!bundle) {
        return NO;
    }
    CFDictionaryRef info = CFBundleGetInfoDictionary(bundle);
    if (!info) {
        return NO;
    }
    CFMutableDictionaryRef mutableInfo = (CFMutableDictionaryRef)info;
    if (enabled) {
        CFDictionarySetValue(mutableInfo, CFSTR("CADisableMinimumFrameDurationOnPhone"), kCFBooleanTrue);
    } else {
        DYYYCaptureDiskProMotionKeyIfNeeded();
        if (gDYYYProMotionDiskKeyValue) {
            CFDictionarySetValue(mutableInfo, CFSTR("CADisableMinimumFrameDurationOnPhone"), kCFBooleanTrue);
        } else if (CFDictionaryContainsKey(mutableInfo, CFSTR("CADisableMinimumFrameDurationOnPhone"))) {
            CFDictionarySetValue(mutableInfo, CFSTR("CADisableMinimumFrameDurationOnPhone"), kCFBooleanFalse);
        }
    }
    return YES;
}

static BOOL DYYYWriteMainBundleInfoPlistIfPossible(BOOL enabled) {
    NSString *path = DYYYMainBundleInfoPlistPath();
    if (path.length == 0 || ![[NSFileManager defaultManager] isWritableFileAtPath:path]) {
        return NO;
    }
    DYYYCaptureDiskProMotionKeyIfNeeded();
    NSMutableDictionary *info = [[NSDictionary dictionaryWithContentsOfFile:path] mutableCopy];
    if (!info) {
        return NO;
    }
    if (enabled) {
        info[kDYYYCADisableMinimumFrameDurationOnPhoneKey] = @YES;
    } else if (gDYYYProMotionDiskKeyValue) {
        info[kDYYYCADisableMinimumFrameDurationOnPhoneKey] = @YES;
    } else {
        [info removeObjectForKey:kDYYYCADisableMinimumFrameDurationOnPhoneKey];
    }
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (!data) {
        return NO;
    }
    return [data writeToFile:path atomically:YES];
}

static CFTypeRef DYYYCFBundleGetValueForInfoDictionaryKey(CFBundleRef bundle, CFStringRef key) {
    // 门闩保持解锁，便于负载恢复后快速回到高刷；降档走宿主 degrade，不反复改写 plist。
    if (DYYYHighFPSEnabled() && key &&
        CFStringCompare(key, CFSTR("CADisableMinimumFrameDurationOnPhone"), 0) == kCFCompareEqualTo) {
        return kCFBooleanTrue;
    }
    if (gOrigCFBundleGetValueForInfoDictionaryKey) {
        return gOrigCFBundleGetValueForInfoDictionaryKey(bundle, key);
    }
    return NULL;
}

static void DYYYInstallCFBundleProMotionHookIfNeeded(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYCFBundleHookInstalled, &expected, true)) {
        return;
    }
    MSHookFunction((void *)CFBundleGetValueForInfoDictionaryKey,
                   (void *)DYYYCFBundleGetValueForInfoDictionaryKey,
                   (void **)&gOrigCFBundleGetValueForInfoDictionaryKey);
}

#pragma mark - AWEDisplayLinkDegradeManager

static void DYYYSetDisableDegradeOperation(id self, SEL _cmd, BOOL disable) {
    if (DYYYHighFPSShouldBoost()) {
        disable = YES;
    }
    if (gOrigSetDisableDegradeOperation) {
        ((DYYYVoidBoolIMP)gOrigSetDisableDegradeOperation)(self, _cmd, disable);
    }
}

static void DYYYApplyDisplayLinkDegradePolicy(BOOL forceDisableDegrade) {
    Class cls = NSClassFromString(@"AWEDisplayLinkDegradeManager");
    id mgr = DYYYCallSharedIfPossible(cls);
    if (!mgr) {
        mgr = cls;
    }
    if (!mgr) {
        NSLog(@"[DYYY][RuntimeHook][HighFPS] AWEDisplayLinkDegradeManager 未找到");
        return;
    }

    SEL setDisableSel = @selector(setDisableDegradeOperation:);
    if ([mgr respondsToSelector:setDisableSel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(mgr, setDisableSel, forceDisableDegrade);
        NSLog(@"[DYYY][RuntimeHook][HighFPS] setDisableDegradeOperation:%d", forceDisableDegrade);
    }

    bool expected = false;
    if (cls && atomic_compare_exchange_strong(&gDYYYDegradeHookInstalled, &expected, true)) {
        Method instanceMethod = class_getInstanceMethod(cls, setDisableSel);
        if (instanceMethod) {
            IMP previous = method_setImplementation(instanceMethod, (IMP)DYYYSetDisableDegradeOperation);
            if (previous && previous != (IMP)DYYYSetDisableDegradeOperation) {
                gOrigSetDisableDegradeOperation = previous;
                NSLog(@"[DYYY][RuntimeHook][HighFPS] 已 Hook setDisableDegradeOperation:");
            }
        } else {
            NSLog(@"[DYYY][RuntimeHook][HighFPS] setDisableDegradeOperation: 实例方法未找到");
        }
    }
}

#pragma mark - AWEProMotionFPSBooster

static void DYYYInvokeProMotionFPSBooster(void) {
    Class cls = nil;
    id primary = DYYYProMotionBoosterTarget(&cls);
    if (!cls) {
        NSLog(@"[DYYY][RuntimeHook][HighFPS] AWEProMotionFPSBooster 类未加载");
        return;
    }

    NSUInteger hit = 0;
    id targets[] = {primary, cls};
    static const char *kBoostSels[] = {
        "boostFPSForScrolling",
        "boostFPSForAppearance",
        "boostFPSForVCAppearance",
        "SetHighRefreshRate",
        "setHighRefreshRate",
    };

    for (size_t t = 0; t < sizeof(targets) / sizeof(targets[0]); t++) {
        id target = targets[t];
        if (!target) {
            continue;
        }
        for (size_t i = 0; i < sizeof(kBoostSels) / sizeof(kBoostSels[0]); i++) {
            if (DYYYPerformVoidOnTarget(target, kBoostSels[i])) {
                hit += 1;
            }
        }
        SEL setHigh = @selector(setHighRefreshRate:);
        if ([target respondsToSelector:setHigh]) {
            NSMethodSignature *sig = [target methodSignatureForSelector:setHigh];
            if (sig.numberOfArguments == 3) {
                const char *type = [sig getArgumentTypeAtIndex:2];
                if (type && (type[0] == 'B' || type[0] == 'c' || type[0] == 'C')) {
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(target, setHigh, YES);
                    hit += 1;
                } else if (type && (type[0] == 'q' || type[0] == 'Q' || type[0] == 'i' || type[0] == 'I' || type[0] == 'l' || type[0] == 'L')) {
                    NSInteger maxFPS = UIScreen.mainScreen.maximumFramesPerSecond;
                    if (maxFPS <= 0) {
                        maxFPS = 120;
                    }
                    ((void (*)(id, SEL, NSInteger))objc_msgSend)(target, setHigh, maxFPS);
                    hit += 1;
                }
            }
        }
    }

    NSLog(@"[DYYY][RuntimeHook][HighFPS] ProMotion booster 命中 %lu 个入口", (unsigned long)hit);
}

static void DYYYInvokeProMotionFPSDegrade(void) {
    Class cls = nil;
    id primary = DYYYProMotionBoosterTarget(&cls);
    if (!cls) {
        return;
    }

    NSUInteger hit = 0;
    id targets[] = {primary, cls};
    static const char *kDegradeSels[] = {
        "degradeFPS",
        "boostFPSForVCDisAppearance",
    };
    for (size_t t = 0; t < sizeof(targets) / sizeof(targets[0]); t++) {
        id target = targets[t];
        if (!target) {
            continue;
        }
        for (size_t i = 0; i < sizeof(kDegradeSels) / sizeof(kDegradeSels[0]); i++) {
            if (DYYYPerformVoidOnTarget(target, kDegradeSels[i])) {
                hit += 1;
            }
        }
    }
    NSLog(@"[DYYY][RuntimeHook][HighFPS] ProMotion degrade 命中 %lu 个入口", (unsigned long)hit);
}

#pragma mark - Auto throttle (built-in)

static void DYYYHighFPSEnterThrottle(void) {
    if (gDYYYHighFPSThrottled) {
        return;
    }
    gDYYYHighFPSThrottled = YES;
    NSProcessInfo *info = [NSProcessInfo processInfo];
    NSLog(@"[DYYY][RuntimeHook][HighFPS] 自动降档 thermal=%ld lowPower=%d",
          (long)info.thermalState,
          info.isLowPowerModeEnabled);
    DYYYInvokeProMotionFPSDegrade();
    // 允许宿主 DisplayLink 降帧；Hook 在 ShouldBoost=NO 时不再强制 YES。
    DYYYApplyDisplayLinkDegradePolicy(NO);
}

static void DYYYHighFPSExitThrottle(void) {
    if (!gDYYYHighFPSThrottled) {
        return;
    }
    gDYYYHighFPSThrottled = NO;
    NSLog(@"[DYYY][RuntimeHook][HighFPS] 负载恢复，重新拉高帧率");
    DYYYApplyDisplayLinkDegradePolicy(YES);
    DYYYInvokeProMotionFPSBooster();
}

static void DYYYHighFPSReevaluateLoad(void) {
    if (!DYYYHighFPSEnabled()) {
        gDYYYHighFPSThrottled = NO;
        return;
    }
    if (DYYYHighFPSLoadRequiresThrottle()) {
        DYYYHighFPSEnterThrottle();
    } else {
        DYYYHighFPSExitThrottle();
    }
}

static void DYYYInstallLoadObserversIfNeeded(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYLoadObserversInstalled, &expected, true)) {
        return;
    }

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    gDYYYThermalObserver =
        [center addObserverForName:NSProcessInfoThermalStateDidChangeNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *note) {
                          DYYYHighFPSReevaluateLoad();
                        }];
    gDYYYPowerObserver =
        [center addObserverForName:NSProcessInfoPowerStateDidChangeNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *note) {
                          DYYYHighFPSReevaluateLoad();
                        }];
}

#pragma mark - Apply / Start

static void DYYYApplyProMotionUnlock(BOOL enabled) {
    DYYYCaptureDiskProMotionKeyIfNeeded();
    DYYYInstallCFBundleProMotionHookIfNeeded();
    BOOL mutated = DYYYMutateMainBundleInfoDictionary(enabled);
    BOOL written = DYYYWriteMainBundleInfoPlistIfPossible(enabled);
    id runtimeValue = [[NSBundle mainBundle] objectForInfoDictionaryKey:kDYYYCADisableMinimumFrameDurationOnPhoneKey];
    NSLog(@"[DYYY][RuntimeHook][HighFPS] ProMotion门闩 enabled=%d mutate=%d write=%d runtime=%@ diskOriginal=%d maxFPS=%ld",
          enabled,
          mutated,
          written,
          runtimeValue,
          gDYYYProMotionDiskKeyValue,
          (long)UIScreen.mainScreen.maximumFramesPerSecond);
}

void DYYYApplyHighFPSSettingChange(BOOL enabled) {
    void (^block)(void) = ^{
      DYYYInstallLoadObserversIfNeeded();
      DYYYApplyProMotionUnlock(enabled);
      if (!enabled) {
          gDYYYHighFPSThrottled = NO;
          return;
      }
      // 先按当前负载决定 boost 或降档。
      gDYYYHighFPSThrottled = NO;
      if (DYYYHighFPSLoadRequiresThrottle()) {
          DYYYHighFPSEnterThrottle();
      } else {
          DYYYApplyDisplayLinkDegradePolicy(YES);
          DYYYInvokeProMotionFPSBooster();
      }
    };
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

void DYYYStartHighFPSHooks(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYHighFPSStarted, &expected, true)) {
        return;
    }

    DYYYInstallCFBundleProMotionHookIfNeeded();
    DYYYInstallLoadObserversIfNeeded();

    if (DYYYHighFPSEnabled()) {
        DYYYApplyHighFPSSettingChange(YES);
    } else {
        DYYYCaptureDiskProMotionKeyIfNeeded();
        NSLog(@"[DYYY][RuntimeHook][HighFPS] 已就绪（默认关闭），diskOriginal ProMotion=%d", gDYYYProMotionDiskKeyValue);
    }

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
                                                    if (!DYYYHighFPSEnabled()) {
                                                        return;
                                                    }
                                                    DYYYHighFPSReevaluateLoad();
                                                    if (DYYYHighFPSShouldBoost()) {
                                                        DYYYApplyDisplayLinkDegradePolicy(YES);
                                                        DYYYInvokeProMotionFPSBooster();
                                                    }
                                                  }];
}
