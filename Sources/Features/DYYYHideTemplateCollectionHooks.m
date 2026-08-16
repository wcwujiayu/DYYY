#import "DYYYHideTemplateCollectionHooks.h"

#import "AwemeHeaders.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdatomic.h>

static NSString *const kDYYYHideTemplateVideoKey = @"DYYYHideTemplateVideo";
static NSString *const kDYYYHideTemplatePlayletKey = @"DYYYHideTemplatePlaylet";
static NSString *const kDYYYHideCommentViewsKey = @"DYYYHideCommentViews";
static NSString *const kDYYYShowPlayletModuleServiceClassName = @"AWEShowPlayletModuleService";
static NSString *const kDYYYCommentVCHeaderBarManagerClassName = @"AWECommentVCHederBarManager";
static NSString *const kDYYYCommentContainerInnerViewHolderClassName =
    @"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewHolder";

typedef void (*DYYYVoidLayoutIMP)(id, SEL);
typedef void (*DYYYVoidVoidIMP)(id, SEL);
typedef double (*DYYYDoubleIMP)(id, SEL);
typedef id (*DYYYIdContextIMP)(id, SEL, id);
typedef id (*DYYYIdNoArgIMP)(id, SEL);
typedef void (*DYYYVoidChangeBoundsIMP)(id, SEL, id, CGSize);
typedef BOOL (*DYYYBoolAwemeReferStringIMP)(id, SEL, id, id);
typedef void (*DYYYVoidHeaderBarAppearIMP)(id, SEL, id, id, id, BOOL);
typedef CGSize (*DYYYSizeForItemIMP)(id, SEL, NSInteger, id, CGSize);
typedef void (*DYYYVoidConfigCellIMP)(id, SEL, id, NSInteger, id);

static atomic_bool gDYYYHideTemplateCollectionHooksStarted = false;
static char kDYYYCommentHeaderTemplateCollapseModelKey;

static DYYYVoidLayoutIMP gOrigAntiAddictedNoticeBarLayout = NULL;
static DYYYDoubleIMP gOrigAntiAddictedNoticeBarSuggestedHeight = NULL;
static DYYYVoidLayoutIMP gOrigTemplatePlayletViewLayout = NULL;
static DYYYVoidVoidIMP gOrigMixVideoInfoElementUpdateBar = NULL;
static NSMutableDictionary<NSString *, NSValue *> *gOrigCommentHeaderBuildVirtualViewIMPs = nil;
static NSMutableDictionary<NSString *, NSValue *> *gOrigCommentHeaderBuildSubComponentsIMPs = nil;
static DYYYVoidChangeBoundsIMP gOrigCommentHeaderChangeBoundsToSize = NULL;
static CGSize (*gOrigCommentHeaderInitialSize)(id, SEL) = NULL;
static DYYYBoolAwemeReferStringIMP gOrigShowPlayletShouldShowCommentHeader = NULL;
static DYYYVoidHeaderBarAppearIMP gOrigCommentVCHeaderBarAppear = NULL;
static DYYYVoidLayoutIMP gOrigCommentContainerInnerViewHolderSetup = NULL;
static DYYYSizeForItemIMP gOrigCommentHeaderSectionSizeForItem = NULL;
static DYYYDoubleIMP gOrigCommentHeaderSectionCurrentHeight = NULL;
static DYYYVoidConfigCellIMP gOrigCommentHeaderSectionConfigCell = NULL;

static BOOL DYYYHideTemplateVideoEnabled(void) {
    return DYYYGetBool(kDYYYHideTemplateVideoKey);
}

static BOOL DYYYHideTemplatePlayletEnabled(void) {
    return DYYYGetBool(kDYYYHideTemplatePlayletKey);
}

static BOOL DYYYHideTemplateCollectionCommentHeaderEnabled(void) {
    return DYYYHideTemplateVideoEnabled() || DYYYHideTemplatePlayletEnabled();
}

static BOOL DYYYHideCommentViewsEnabled(void) {
    return DYYYGetBool(kDYYYHideCommentViewsKey);
}

static Class DYYYResolveSwiftClass(NSString *moduleClassName, NSString *mangledClassName) {
    Class cls = NSClassFromString(moduleClassName);
    if (!cls && mangledClassName.length > 0) {
        cls = objc_getClass(mangledClassName.UTF8String);
    }
    if (!cls && moduleClassName.length > 0) {
        cls = objc_getClass(moduleClassName.UTF8String);
    }
    return cls;
}

static BOOL DYYYInstallRuntimeHook(Class cls,
                                   SEL selector,
                                   IMP replacement,
                                   IMP *originalSlot,
                                   BOOL isClassMethod) {
    if (!cls || !selector || !replacement || !originalSlot || *originalSlot != NULL) {
        return *originalSlot != NULL;
    }

    Method existing = isClassMethod ? class_getClassMethod(cls, selector) : class_getInstanceMethod(cls, selector);
    if (!existing) {
        return NO;
    }

    const char *typeEncoding = method_getTypeEncoding(existing);
    if (!typeEncoding) {
        return NO;
    }

    IMP previous = method_getImplementation(existing);
    if (previous == replacement) {
        return YES;
    }

    if (isClassMethod) {
        if (!class_addMethod(object_getClass(cls), selector, replacement, typeEncoding)) {
            previous = method_setImplementation(existing, replacement);
        }
    } else {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        BOOL definedOnClass = NO;
        for (unsigned int index = 0; index < methodCount; index++) {
            if (method_getName(methods[index]) == selector) {
                definedOnClass = YES;
                break;
            }
        }
        free(methods);

        if (!definedOnClass) {
            if (!class_addMethod(cls, selector, replacement, typeEncoding)) {
                return NO;
            }
        } else {
            previous = method_setImplementation(existing, replacement);
        }
    }

    if (!previous || previous == replacement) {
        return NO;
    }
    *originalSlot = previous;
    return YES;
}

static void DYYYHideCollectionChromeView(UIView *view) {
    if (![view isKindOfClass:[UIView class]]) {
        return;
    }
    view.hidden = YES;
    view.alpha = 0.0;
    view.userInteractionEnabled = NO;
}

static void DYYYCollapseCollectionChromeView(UIView *view) {
    if (![view isKindOfClass:[UIView class]]) {
        return;
    }
    DYYYHideCollectionChromeView(view);
    CGRect frame = view.frame;
    if (frame.size.height > 0.0) {
        frame.size.height = 0.0;
        view.frame = frame;
    }

    UIView *superview = view.superview;
    if (superview && superview.subviews.count == 1) {
        DYYYCollapseCollectionChromeView(superview);
    }
}

static void DYYYClearCommentHeaderBarContainer(id container) {
    if (![container isKindOfClass:[UIView class]]) {
        return;
    }
    UIView *view = (UIView *)container;
    view.hidden = YES;
    view.alpha = 0.0;
    view.userInteractionEnabled = NO;
    for (UIView *subview in view.subviews) {
        DYYYCollapseCollectionChromeView(subview);
    }
    CGRect frame = view.frame;
    if (frame.size.height > 0.01) {
        frame.size.height = 0.0;
        view.frame = frame;
    }
}

static void DYYYApplyTemplateCollectionCountOnlyHeaderLayout(id holder) {
    if (!holder || !DYYYHideTemplateCollectionCommentHeaderEnabled()) {
        return;
    }

    @try {
        NSNumber *countLabelCenterY = [holder valueForKey:@"closeButtonCenterYOnlyCountLabelValue"];
        if ([countLabelCenterY isKindOfClass:[NSNumber class]]) {
            [holder setValue:countLabelCenterY forKey:@"closeButtonCenterY"];
        }

        id closeBar = nil;
        if ([holder respondsToSelector:@selector(closeBar)]) {
            closeBar = ((id (*)(id, SEL))objc_msgSend)(holder, @selector(closeBar));
        }
        if (!closeBar) {
            closeBar = [holder valueForKey:@"closeBar"];
        }
        if ([closeBar isKindOfClass:[UIView class]]) {
            ((UIView *)closeBar).hidden = NO;
            ((UIView *)closeBar).alpha = 1.0;
        }

        id line = [holder valueForKey:@"line"];
        if ([line isKindOfClass:[UIView class]]) {
            ((UIView *)line).hidden = YES;
            ((UIView *)line).alpha = 0.0;
        }
    } @catch (__unused NSException *exception) {
    }
}

static void DYYYApplyHiddenCommentViewsCountOnlyHeaderLayout(id holder) {
    if (!holder || !DYYYHideCommentViewsEnabled()) {
        return;
    }

    @try {
        NSNumber *countLabelCenterY = [holder valueForKey:@"closeButtonCenterYOnlyCountLabelValue"];
        if ([countLabelCenterY isKindOfClass:[NSNumber class]]) {
            [holder setValue:countLabelCenterY forKey:@"closeButtonCenterY"];
        }

        id countLabel = nil;
        if ([holder respondsToSelector:@selector(commentCountLabel)]) {
            countLabel = ((id (*)(id, SEL))objc_msgSend)(holder, @selector(commentCountLabel));
        }
        if (!countLabel) {
            countLabel = [holder valueForKey:@"commentCountLabel"];
        }
        if ([countLabel isKindOfClass:[UIView class]]) {
            UIView *labelView = (UIView *)countLabel;
            labelView.hidden = NO;
            labelView.alpha = 1.0;
        }

        id line = [holder valueForKey:@"line"];
        if ([line isKindOfClass:[UIView class]]) {
            ((UIView *)line).hidden = YES;
            ((UIView *)line).alpha = 0.0;
        }
    } @catch (__unused NSException *exception) {
    }
}

static NSString *DYYYTextFromNoticeBar(id bar) {
    if (!bar) {
        return nil;
    }

    @try {
        UILabel *tipsLabel = [bar valueForKey:@"tipsLabel"];
        if ([tipsLabel isKindOfClass:[UILabel class]]) {
            if (tipsLabel.text.length > 0) {
                return tipsLabel.text;
            }
            if (tipsLabel.attributedText.string.length > 0) {
                return tipsLabel.attributedText.string;
            }
        }
    } @catch (__unused NSException *exception) {
    }

    @try {
        NSAttributedString *attrTips = [bar valueForKey:@"attrTips"];
        if ([attrTips isKindOfClass:[NSAttributedString class]] && attrTips.string.length > 0) {
            return attrTips.string;
        }
    } @catch (__unused NSException *exception) {
    }

    @try {
        NSString *tips = [bar valueForKey:@"tips"];
        if ([tips isKindOfClass:[NSString class]] && tips.length > 0) {
            return tips;
        }
    } @catch (__unused NSException *exception) {
    }

    return nil;
}

static BOOL DYYYNoticeBarLooksLikeMixCollection(id bar) {
    NSString *text = DYYYTextFromNoticeBar(bar);
    if (text.length == 0) {
        return NO;
    }
    return [text containsString:@"合集"] || [text containsString:@"下一集"];
}

static BOOL DYYYViewHierarchyLooksLikeMixCollectionHost(UIView *view) {
    UIView *current = view;
    for (NSUInteger depth = 0; depth < 8 && current; depth++) {
        NSString *className = NSStringFromClass([current class]);
        if ([className containsString:@"MixVideo"] ||
            [className containsString:@"MixVideoInfo"] ||
            [className containsString:@"PlayInteractionMixVideo"]) {
            return YES;
        }
        current = current.superview;
    }
    return NO;
}

static BOOL DYYYShouldHideMixCollectionNoticeBar(id bar) {
    if (!DYYYHideTemplateVideoEnabled() || !bar) {
        return NO;
    }
    if (DYYYNoticeBarLooksLikeMixCollection(bar)) {
        return YES;
    }
    return DYYYViewHierarchyLooksLikeMixCollectionHost((UIView *)bar);
}

static void DYYYHideMixCollectionNoticeBarIfNeeded(id bar) {
    if (!DYYYShouldHideMixCollectionNoticeBar(bar)) {
        return;
    }
    DYYYCollapseCollectionChromeView((UIView *)bar);
}

static void DYYYHideMixVideoInfoBarOnOwner(id owner) {
    if (!DYYYHideTemplateVideoEnabled() || !owner) {
        return;
    }

    @try {
        id bar = [owner valueForKey:@"mixVideoInfoBarView"];
        if ([bar isKindOfClass:[UIView class]]) {
            DYYYCollapseCollectionChromeView((UIView *)bar);
        }
    } @catch (__unused NSException *exception) {
    }

    if ([owner respondsToSelector:@selector(bottomElementContainer)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIView *container = [owner performSelector:@selector(bottomElementContainer)];
#pragma clang diagnostic pop
        if ([container isKindOfClass:[UIView class]]) {
            DYYYCollapseCollectionChromeView(container);
        }
    }
}

#pragma mark - Replacements

static void DYYYAntiAddictedNoticeBarLayoutSubviews(id self, SEL _cmd) {
    if (gOrigAntiAddictedNoticeBarLayout) {
        gOrigAntiAddictedNoticeBarLayout(self, _cmd);
    }
    DYYYHideMixCollectionNoticeBarIfNeeded(self);
}

static double DYYYAntiAddictedNoticeBarSuggestedHeight(id self, SEL _cmd) {
    if (DYYYShouldHideMixCollectionNoticeBar(self)) {
        return 0.0;
    }
    if (gOrigAntiAddictedNoticeBarSuggestedHeight) {
        return gOrigAntiAddictedNoticeBarSuggestedHeight(self, _cmd);
    }
    return 0.0;
}

static void DYYYTemplatePlayletViewLayoutSubviews(id self, SEL _cmd) {
    if (DYYYHideTemplatePlayletEnabled()) {
        DYYYCollapseCollectionChromeView((UIView *)self);
        return;
    }
    if (gOrigTemplatePlayletViewLayout) {
        gOrigTemplatePlayletViewLayout(self, _cmd);
    }
}

static void DYYYMixVideoInfoElementUpdateBar(id self, SEL _cmd) {
    if (gOrigMixVideoInfoElementUpdateBar) {
        gOrigMixVideoInfoElementUpdateBar(self, _cmd);
    }
    DYYYHideMixVideoInfoBarOnOwner(self);
}

static BOOL DYYYObjectLooksLikeCommentHeaderCollectionComponent(id object) {
    if (!object) {
        return NO;
    }
    NSString *className = NSStringFromClass([object class]);
    if (DYYYHideTemplateVideoEnabled() &&
        ([className containsString:@"BizMediumComponent"] || [className containsString:@"BizTemplateComponent"])) {
        return YES;
    }
    if (DYYYHideTemplatePlayletEnabled() && [className containsString:@"BizPlayletComponent"]) {
        return YES;
    }
    return NO;
}

static id DYYYCommentHeaderBizComponentBuildVirtualView(id self, SEL _cmd, id context) {
    if (DYYYObjectLooksLikeCommentHeaderCollectionComponent(self)) {
        return nil;
    }

    NSString *className = NSStringFromClass(object_getClass(self));
    DYYYIdContextIMP orig = NULL;
    NSValue *origValue = gOrigCommentHeaderBuildVirtualViewIMPs[className];
    if (origValue) {
        orig = (DYYYIdContextIMP)[origValue pointerValue];
    }
    return orig ? orig(self, _cmd, context) : nil;
}

static NSArray *DYYYCommentHeaderFilterCollectionSubComponents(NSArray *original) {
    if (![original isKindOfClass:[NSArray class]] || original.count == 0) {
        return original;
    }
    if (!DYYYHideTemplateVideoEnabled() && !DYYYHideTemplatePlayletEnabled()) {
        return original;
    }

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:original.count];
    for (id item in original) {
        if (DYYYObjectLooksLikeCommentHeaderCollectionComponent(item)) {
            continue;
        }
        [filtered addObject:item];
    }
    return filtered.count == original.count ? original : [filtered copy];
}

static NSArray *DYYYCommentHeaderBuildSubComponents(id self, SEL _cmd) {
    NSString *key = NSStringFromClass([self class]);
    DYYYIdNoArgIMP orig = NULL;
    NSValue *origValue = gOrigCommentHeaderBuildSubComponentsIMPs[key];
    if (origValue) {
        orig = (DYYYIdNoArgIMP)[origValue pointerValue];
    }
    NSArray *original = orig ? orig(self, _cmd) : nil;
    return DYYYCommentHeaderFilterCollectionSubComponents(original);
}

static void DYYYCommentHeaderChangeBoundsToSize(id self, SEL _cmd, id container, CGSize size) {
    if (DYYYHideTemplateCollectionCommentHeaderEnabled()) {
        id component = nil;
        @try {
            component = [self valueForKey:@"component"];
        } @catch (__unused NSException *exception) {
        }
        if (DYYYObjectLooksLikeCommentHeaderCollectionComponent(component)) {
            size = CGSizeZero;
        }
    }
    if (gOrigCommentHeaderChangeBoundsToSize) {
        gOrigCommentHeaderChangeBoundsToSize(self, _cmd, container, size);
    }
}

static CGSize DYYYCommentHeaderInitialSize(id self, SEL _cmd) {
    if (DYYYHideTemplateCollectionCommentHeaderEnabled()) {
        id component = nil;
        @try {
            component = [self valueForKey:@"component"];
        } @catch (__unused NSException *exception) {
        }
        if (DYYYObjectLooksLikeCommentHeaderCollectionComponent(component)) {
            return CGSizeZero;
        }
    }
    if (gOrigCommentHeaderInitialSize) {
        return gOrigCommentHeaderInitialSize(self, _cmd);
    }
    return CGSizeZero;
}

static BOOL DYYYCommentHeaderModelComponentIsGatedCollection(id model) {
    if (!model) {
        return NO;
    }
    id component = nil;
    @try {
        component = [model valueForKey:@"component"];
    } @catch (__unused NSException *exception) {
    }
    return DYYYObjectLooksLikeCommentHeaderCollectionComponent(component);
}

static BOOL DYYYShowPlayletModuleServiceShouldShowPlayletCommentHeader(id self, SEL _cmd, id awemeModel, id referString) {
    if (DYYYHideTemplateCollectionCommentHeaderEnabled()) {
        return NO;
    }
    if (gOrigShowPlayletShouldShowCommentHeader) {
        return gOrigShowPlayletShouldShowCommentHeader(self, _cmd, awemeModel, referString);
    }
    return NO;
}

static void DYYYCommentVCHeaderBarManagerHandleAppear(id self,
                                                    SEL _cmd,
                                                    id context,
                                                    id bottomContainer,
                                                    id leftContainer,
                                                    BOOL isNew) {
    if (gOrigCommentVCHeaderBarAppear) {
        gOrigCommentVCHeaderBarAppear(self, _cmd, context, bottomContainer, leftContainer, isNew);
    }
    if (DYYYHideTemplateCollectionCommentHeaderEnabled()) {
        DYYYClearCommentHeaderBarContainer(leftContainer);
    }
}

static void DYYYCommentContainerInnerViewHolderSetup(id self, SEL _cmd) {
    if (gOrigCommentContainerInnerViewHolderSetup) {
        gOrigCommentContainerInnerViewHolderSetup(self, _cmd);
    }
    DYYYApplyHiddenCommentViewsCountOnlyHeaderLayout(self);
    DYYYApplyTemplateCollectionCountOnlyHeaderLayout(self);
}

static CGSize DYYYCommentHeaderSectionSizeForItem(id self,
                                                  SEL _cmd,
                                                  NSInteger index,
                                                  id model,
                                                  CGSize collectionViewSize) {
    CGSize originalSize = gOrigCommentHeaderSectionSizeForItem
                              ? gOrigCommentHeaderSectionSizeForItem(self, _cmd, index, model, collectionViewSize)
                              : CGSizeZero;
    if (DYYYCommentHeaderModelComponentIsGatedCollection(model)) {
        originalSize.height = 0.0;
    }
    return originalSize;
}

static double DYYYCommentHeaderSectionCurrentHeight(id self, SEL _cmd) {
    double originalHeight = gOrigCommentHeaderSectionCurrentHeight ? gOrigCommentHeaderSectionCurrentHeight(self, _cmd) : 0.0;

    id models = nil;
    @try {
        models = [self valueForKey:@"modelsArray"];
    } @catch (__unused NSException *exception) {
    }
    if (![models isKindOfClass:[NSArray class]] || [(NSArray *)models count] == 0) {
        return originalHeight;
    }

    BOOL shouldRecalculate = NO;
    for (id model in (NSArray *)models) {
        if (DYYYCommentHeaderModelComponentIsGatedCollection(model)) {
            shouldRecalculate = YES;
            break;
        }
    }
    if (!shouldRecalculate) {
        return originalHeight;
    }

    double totalHeight = 0.0;
    CGSize collectionViewSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, 0.0);
    NSInteger index = 0;
    SEL sizeSelector = @selector(sizeForItemAtIndex:model:collectionViewSize:);
    for (id model in (NSArray *)models) {
        CGSize itemSize = ((CGSize (*)(id, SEL, NSInteger, id, CGSize))objc_msgSend)(self,
                                                                                       sizeSelector,
                                                                                       index,
                                                                                       model,
                                                                                       collectionViewSize);
        totalHeight += itemSize.height;
        index++;
    }
    return totalHeight;
}

static void DYYYCommentHeaderSectionConfigCell(id self, SEL _cmd, id cell, NSInteger index, id model) {
    if (gOrigCommentHeaderSectionConfigCell) {
        gOrigCommentHeaderSectionConfigCell(self, _cmd, cell, index, model);
    }

    BOOL shouldCollapse = DYYYCommentHeaderModelComponentIsGatedCollection(model);
    BOOL wasCollapsed = [objc_getAssociatedObject(model, &kDYYYCommentHeaderTemplateCollapseModelKey) boolValue];
    objc_setAssociatedObject(model,
                             &kDYYYCommentHeaderTemplateCollapseModelKey,
                             @(shouldCollapse),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (shouldCollapse && [cell isKindOfClass:[UIView class]]) {
        DYYYCollapseCollectionChromeView((UIView *)cell);
    }
    if (shouldCollapse && !wasCollapsed) {
        id didUpdateHeight = nil;
        @try {
            didUpdateHeight = [self valueForKey:@"didUpdateHeight"];
        } @catch (__unused NSException *exception) {
        }
        if (didUpdateHeight) {
            ((void (^)(void))didUpdateHeight)();
        }
    }
}

#pragma mark - Install

static BOOL DYYYInstallLayoutSubviewsHook(Class cls,
                                           DYYYVoidLayoutIMP replacement,
                                           DYYYVoidLayoutIMP *originalSlot) {
    if (!cls || !replacement || !originalSlot) {
        return NO;
    }

    SEL selector = @selector(layoutSubviews);
    Method existing = class_getInstanceMethod(cls, selector);
    if (!existing) {
        return NO;
    }

    const char *typeEncoding = method_getTypeEncoding(existing);
    IMP existingIMP = method_getImplementation(existing);
    if (existingIMP == (IMP)replacement) {
        return *originalSlot != NULL;
    }

    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    BOOL methodDefinedOnClass = NO;
    for (unsigned int i = 0; i < methodCount; i++) {
        if (method_getName(methods[i]) == selector) {
            methodDefinedOnClass = YES;
            break;
        }
    }
    free(methods);

    if (!methodDefinedOnClass) {
        if (!class_addMethod(cls, selector, (IMP)replacement, typeEncoding)) {
            return NO;
        }
        *originalSlot = (DYYYVoidLayoutIMP)existingIMP;
        return YES;
    }

    IMP previous = method_getImplementation(existing);
    *originalSlot = (DYYYVoidLayoutIMP)previous;
    method_setImplementation(existing, (IMP)replacement);
    return YES;
}

static BOOL DYYYInstallInstanceIMPHook(Class cls,
                                       SEL selector,
                                       IMP replacement,
                                       IMP *originalSlot) {
    if (!cls || !replacement || !originalSlot) {
        return NO;
    }

    Method existing = class_getInstanceMethod(cls, selector);
    if (!existing) {
        return NO;
    }

    IMP previous = method_getImplementation(existing);
    if (previous == replacement) {
        return *originalSlot != NULL;
    }

    *originalSlot = previous;
    method_setImplementation(existing, replacement);
    return YES;
}

static BOOL DYYYInstallCommentHeaderBizComponentHook(NSString *className, NSString *mangledClassName) {
    Class cls = DYYYResolveSwiftClass(className, mangledClassName);
    if (!cls) {
        return NO;
    }

    NSString *key = NSStringFromClass(cls);
    if (gOrigCommentHeaderBuildVirtualViewIMPs[key]) {
        return YES;
    }

    Method buildVirtualViewMethod = class_getInstanceMethod(cls, @selector(buildVirtualView:));
    if (!buildVirtualViewMethod) {
        return NO;
    }

    IMP previous = method_getImplementation(buildVirtualViewMethod);
    if (previous == (IMP)DYYYCommentHeaderBizComponentBuildVirtualView) {
        return YES;
    }

    if (!gOrigCommentHeaderBuildVirtualViewIMPs) {
        gOrigCommentHeaderBuildVirtualViewIMPs = [NSMutableDictionary dictionary];
    }
    gOrigCommentHeaderBuildVirtualViewIMPs[key] = [NSValue valueWithPointer:previous];
    method_setImplementation(buildVirtualViewMethod, (IMP)DYYYCommentHeaderBizComponentBuildVirtualView);
    return YES;
}

static BOOL DYYYInstallCommentHeaderBuildSubComponentsHook(NSString *className, NSString *mangledClassName) {
    Class cls = NSClassFromString(className);
    if (!cls && mangledClassName.length > 0) {
        cls = objc_getClass(mangledClassName.UTF8String);
    }
    if (!cls) {
        return NO;
    }

    NSString *key = NSStringFromClass(cls);
    if (gOrigCommentHeaderBuildSubComponentsIMPs[key]) {
        return YES;
    }

    Method existing = class_getInstanceMethod(cls, @selector(buildSubComponents));
    if (!existing) {
        return NO;
    }

    IMP previous = method_getImplementation(existing);
    if (previous == (IMP)DYYYCommentHeaderBuildSubComponents) {
        return YES;
    }

    if (!gOrigCommentHeaderBuildSubComponentsIMPs) {
        gOrigCommentHeaderBuildSubComponentsIMPs = [NSMutableDictionary dictionary];
    }
    gOrigCommentHeaderBuildSubComponentsIMPs[key] = [NSValue valueWithPointer:previous];
    method_setImplementation(existing, (IMP)DYYYCommentHeaderBuildSubComponents);
    return YES;
}

void DYYYStartHideTemplateCollectionHooks(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYHideTemplateCollectionHooksStarted, &expected, true)) {
        return;
    }

    NSUInteger installed = 0;

    Class noticeBarClass = objc_getClass("AWEAntiAddictedNoticeBarView");
    if (noticeBarClass) {
        if (DYYYInstallLayoutSubviewsHook(noticeBarClass,
                                          DYYYAntiAddictedNoticeBarLayoutSubviews,
                                          &gOrigAntiAddictedNoticeBarLayout)) {
            installed += 1;
        }
        if (DYYYInstallInstanceIMPHook(noticeBarClass,
                                       @selector(suggestedHeight),
                                       (IMP)DYYYAntiAddictedNoticeBarSuggestedHeight,
                                       (IMP *)&gOrigAntiAddictedNoticeBarSuggestedHeight)) {
            installed += 1;
        }
    }

    Class playletViewClass = objc_getClass("AWETemplatePlayletView");
    if (playletViewClass &&
        DYYYInstallLayoutSubviewsHook(playletViewClass,
                                      DYYYTemplatePlayletViewLayoutSubviews,
                                      &gOrigTemplatePlayletViewLayout)) {
        installed += 1;
    }

    Class mixInfoElementClass = objc_getClass("AWEPlayInteractionMixVideoInfoElement");
    if (mixInfoElementClass &&
        DYYYInstallInstanceIMPHook(mixInfoElementClass,
                                   @selector(updateMixVideoInfoBarView),
                                   (IMP)DYYYMixVideoInfoElementUpdateBar,
                                   (IMP *)&gOrigMixVideoInfoElementUpdateBar)) {
        installed += 1;
    }

    static NSArray<NSDictionary *> *commentHeaderBizClasses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        commentHeaderBizClasses = @[
            @{
                @"module" : @"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderCellBizMediumComponent",
                @"mangled" : @"_TtC30AWECommentPanelHeaderSwiftImpl41CommentPanelHeaderCellBizMediumComponent",
            },
            @{
                @"module" : @"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderCellBizPlayletComponent",
                @"mangled" : @"_TtC30AWECommentPanelHeaderSwiftImpl41CommentPanelHeaderCellBizPlayletComponent",
            },
            @{
                @"module" : @"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderCellBizTemplateComponent",
                @"mangled" : @"_TtC30AWECommentPanelHeaderSwiftImpl43CommentPanelHeaderCellBizTemplateComponent",
            },
        ];
    });
    for (NSDictionary *entry in commentHeaderBizClasses) {
        if (DYYYInstallCommentHeaderBizComponentHook(entry[@"module"], entry[@"mangled"])) {
            installed += 1;
        }
    }

    if (DYYYInstallCommentHeaderBuildSubComponentsHook(
            @"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderCellBizHeaderComponent",
            @"_TtC30AWECommentPanelHeaderSwiftImpl40CommentPanelHeaderCellBizHeaderComponent")) {
        installed += 1;
    }
    if (DYYYInstallCommentHeaderBuildSubComponentsHook(
            @"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderCellContainerComponent",
            @"_TtC30AWECommentPanelHeaderSwiftImpl40CommentPanelHeaderCellContainerComponent")) {
        installed += 1;
    }

    Class viewModelClass = DYYYResolveSwiftClass(
        @"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderNewCellViewModel",
        @"_TtC30AWECommentPanelHeaderSwiftImpl34CommentPanelHeaderNewCellViewModel");
    if (viewModelClass) {
        if (DYYYInstallInstanceIMPHook(viewModelClass,
                                       @selector(componentContainer:changeBoundsToSize:),
                                       (IMP)DYYYCommentHeaderChangeBoundsToSize,
                                       (IMP *)&gOrigCommentHeaderChangeBoundsToSize)) {
            installed += 1;
        }
        if (DYYYInstallInstanceIMPHook(viewModelClass,
                                       @selector(initialSize),
                                       (IMP)DYYYCommentHeaderInitialSize,
                                       (IMP *)&gOrigCommentHeaderInitialSize)) {
            installed += 1;
        }
    }

    Class sectionControllerClass = DYYYResolveSwiftClass(
        @"AWECommentPanelHeaderSwiftImpl.CommentPanelHeaderSectionController",
        @"_TtC30AWECommentPanelHeaderSwiftImpl40CommentPanelHeaderSectionController");
    if (sectionControllerClass) {
        if (DYYYInstallInstanceIMPHook(sectionControllerClass,
                                       @selector(sizeForItemAtIndex:model:collectionViewSize:),
                                       (IMP)DYYYCommentHeaderSectionSizeForItem,
                                       (IMP *)&gOrigCommentHeaderSectionSizeForItem)) {
            installed += 1;
        }
        if (DYYYInstallInstanceIMPHook(sectionControllerClass,
                                       @selector(currentHeight),
                                       (IMP)DYYYCommentHeaderSectionCurrentHeight,
                                       (IMP *)&gOrigCommentHeaderSectionCurrentHeight)) {
            installed += 1;
        }
        if (DYYYInstallInstanceIMPHook(sectionControllerClass,
                                       @selector(configCell:index:model:),
                                       (IMP)DYYYCommentHeaderSectionConfigCell,
                                       (IMP *)&gOrigCommentHeaderSectionConfigCell)) {
            installed += 1;
        }
    }

    Class showPlayletServiceClass = objc_getClass(kDYYYShowPlayletModuleServiceClassName.UTF8String);
    if (showPlayletServiceClass &&
        DYYYInstallRuntimeHook(showPlayletServiceClass,
                               @selector(shouldShowPlayletCommentHeaderWithAwemeModel:referString:),
                               (IMP)DYYYShowPlayletModuleServiceShouldShowPlayletCommentHeader,
                               (IMP *)&gOrigShowPlayletShouldShowCommentHeader,
                               YES)) {
        installed += 1;
    }

    Class headerBarManagerClass = objc_getClass(kDYYYCommentVCHeaderBarManagerClassName.UTF8String);
    if (headerBarManagerClass &&
        DYYYInstallRuntimeHook(headerBarManagerClass,
                               @selector(handleCommentVCHeaderBarAppearByContext:bottomContainer:leftContainer:isNew:),
                               (IMP)DYYYCommentVCHeaderBarManagerHandleAppear,
                               (IMP *)&gOrigCommentVCHeaderBarAppear,
                               NO)) {
        installed += 1;
    }

    Class viewHolderClass = DYYYResolveSwiftClass(kDYYYCommentContainerInnerViewHolderClassName,
                                                  @"_TtC33AWECommentPanelContainerSwiftImpl31CommentContainerInnerViewHolder");
    if (viewHolderClass &&
        DYYYInstallRuntimeHook(viewHolderClass,
                               @selector(setupViewHolder),
                               (IMP)DYYYCommentContainerInnerViewHolderSetup,
                               (IMP *)&gOrigCommentContainerInnerViewHolderSetup,
                               NO)) {
        installed += 1;
    }

    NSLog(@"[DYYY][RuntimeHook][HideTemplateCollection] 安装完成，成功 %lu 个目标", (unsigned long)installed);
}
