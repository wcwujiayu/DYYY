#import "DYYYHideShareContentViewHooks.h"

#import "AwemeHeaders.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <string.h>

static NSString *const kDYYYHideShareContentViewKey = @"DYYYHideShareContentView";

typedef void (*DYYYVoidLayoutIMP)(id, SEL);
typedef void (*DYYYVoidObjectIMP)(id, SEL, id);

static atomic_bool gDYYYHideShareContentViewHooksStarted = false;
static DYYYVoidLayoutIMP gOrigStrongifyShareContentLayout = NULL;
static DYYYVoidObjectIMP gOrigStrongifyShareContentV3Update = NULL;

static BOOL DYYYHideShareContentViewEnabled(void) {
    return DYYYGetBool(kDYYYHideShareContentViewKey);
}

static BOOL DYYYHideShareContentClassDefinesSelector(Class targetClass, SEL selector) {
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

static void DYYYHideShareContentChrome(UIView *view) {
    if (![view isKindOfClass:[UIView class]]) {
        return;
    }
    UIView *parentView = view.superview;
    if (parentView) {
        parentView.hidden = YES;
    } else {
        view.hidden = YES;
    }
}

static void DYYYHideShareContentLogTriggerOnce(const char *target) {
    static NSMutableSet<NSString *> *logged = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      logged = [NSMutableSet set];
    });
    NSString *name = target ? @(target) : @"";
    if (name.length == 0) {
        return;
    }
    @synchronized(logged) {
        if ([logged containsObject:name]) {
            return;
        }
        [logged addObject:name];
    }
    NSLog(@"[DYYY][RuntimeHook][HideShareContent] hook-trigger %s", target);
}

static BOOL DYYYHideShareContentInstallHook(Class targetClass, SEL selector, const char *expectedEncoding, IMP replacement,
                                            IMP *originalSlot) {
    if (!targetClass || !selector || !expectedEncoding || !replacement || !originalSlot) {
        return NO;
    }

    Method method = class_getInstanceMethod(targetClass, selector);
    const char *actualEncoding = method ? method_getTypeEncoding(method) : NULL;
    if (!method || !actualEncoding || strcmp(actualEncoding, expectedEncoding) != 0) {
        NSLog(@"[DYYY][RuntimeHook][HideShareContent] hook-skip class=%s sel=%@ encoding=%s", class_getName(targetClass),
              NSStringFromSelector(selector), actualEncoding ?: "(null)");
        return NO;
    }

    IMP currentIMP = method_getImplementation(method);
    if (currentIMP == replacement) {
        return *originalSlot != NULL;
    }
    if (*originalSlot) {
        return NO;
    }

    BOOL definedOnClass = DYYYHideShareContentClassDefinesSelector(targetClass, selector);
    if (!definedOnClass) {
        if (!class_addMethod(targetClass, selector, replacement, actualEncoding)) {
            NSLog(@"[DYYY][RuntimeHook][HideShareContent] class_addMethod 失败：%s %@", class_getName(targetClass),
                  NSStringFromSelector(selector));
            return NO;
        }
        *originalSlot = currentIMP;
        return YES;
    }

    IMP originalIMP = method_setImplementation(method, replacement);
    if (!originalIMP || originalIMP == replacement) {
        NSLog(@"[DYYY][RuntimeHook][HideShareContent] 无法保存原 IMP：%s %@", class_getName(targetClass),
              NSStringFromSelector(selector));
        return NO;
    }
    *originalSlot = originalIMP;
    return YES;
}

static void DYYYStrongifyShareContentLayoutSubviews(id self, SEL _cmd) {
    if (gOrigStrongifyShareContentLayout) {
        gOrigStrongifyShareContentLayout(self, _cmd);
    }
    if (DYYYHideShareContentViewEnabled()) {
        DYYYHideShareContentLogTriggerOnce("AWEPlayInteractionStrongifyShareContentView.layoutSubviews");
        DYYYHideShareContentChrome(self);
    }
}

static void DYYYStrongifyShareContentV3UpdateWithViewModel(id self, SEL _cmd, id viewModel) {
    if (gOrigStrongifyShareContentV3Update) {
        gOrigStrongifyShareContentV3Update(self, _cmd, viewModel);
    }
    if (DYYYHideShareContentViewEnabled()) {
        DYYYHideShareContentLogTriggerOnce("AWEPlayInteractionStrongifyShareContentViewV3.updateWithViewModel:");
        DYYYHideShareContentChrome(self);
    }
}

static void DYYYInstallHideShareContentViewHooksIfNeeded(void) {
    Class legacyClass = objc_getClass("AWEPlayInteractionStrongifyShareContentView");
    if (legacyClass) {
        DYYYHideShareContentInstallHook(legacyClass, @selector(layoutSubviews), "v16@0:8",
                                        (IMP)DYYYStrongifyShareContentLayoutSubviews,
                                        (IMP *)&gOrigStrongifyShareContentLayout);
    }

    Class v3Class = objc_getClass("AWEPlayInteractionStrongifyShareContentViewV3");
    if (v3Class) {
        DYYYHideShareContentInstallHook(v3Class, @selector(updateWithViewModel:), "v24@0:8@16",
                                        (IMP)DYYYStrongifyShareContentV3UpdateWithViewModel,
                                        (IMP *)&gOrigStrongifyShareContentV3Update);
    }

    NSUInteger installed = (gOrigStrongifyShareContentLayout ? 1 : 0) + (gOrigStrongifyShareContentV3Update ? 1 : 0);
    static NSInteger lastLoggedCount = -1;
    if ((NSInteger)installed != lastLoggedCount) {
        lastLoggedCount = (NSInteger)installed;
        NSLog(@"[DYYY][RuntimeHook][HideShareContent] 安装完成，成功 %lu 个目标 legacy=%d v3=%d", (unsigned long)installed,
              gOrigStrongifyShareContentLayout ? 1 : 0, gOrigStrongifyShareContentV3Update ? 1 : 0);
    }
}

void DYYYStartHideShareContentViewHooks(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYHideShareContentViewHooksStarted, &expected, true)) {
        return;
    }

    DYYYInstallHideShareContentViewHooksIfNeeded();
    NSArray<NSNumber *> *delays = @[ @0.2, @0.8, @2.0, @5.0 ];
    for (NSNumber *delay in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          DYYYInstallHideShareContentViewHooksIfNeeded();
        });
    }
}
