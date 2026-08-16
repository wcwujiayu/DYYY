#import "DYYYHideCommentAIAnalysisHooks.h"

#import "AwemeHeaders.h"
#import "DYYYRuntimeHookInstaller.h"
#import "DYYYUtils.h"

#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdatomic.h>

static NSString *const kDYYYHideCommentViewsKey = @"DYYYHideCommentViews";

static NSString *const kDYYYCommentDCFeedAIParseTabComponentClassName =
    @"AWECommentDCFeedSwiftImpl.CommentDCFeedAIParseTabComponent";
static NSString *const kDYYYCommentTemplatePOITabComponentClassName =
    @"AWECommentPOISwiftImpl.CommentTemplatePOITabComponent";
static NSString *const kDYYYCommentEvaluateTabComponentClassName =
    @"AWECommentCommerceSwiftImpl.CommentEvaluateTabComponent";
static NSString *const kDYYYCommentProductCommentTabComponentClassName =
    @"AWECommentCommerceSwiftImpl.CommentProductCommentTabComponent";
static NSString *const kDYYYCommentTabManagerClassName = @"AWECommentPanelTabSwiftImpl.CommentTabManager";
static NSString *const kDYYYCommentTabServiceClassName = @"AWECommentTabService";
static NSString *const kDYYYFeedDoubleColumnAITabUtilClassName = @"AWEFeedDoubleColumnAITabUtil";
static NSString *const kDYYYCommentTabModelClassName = @"AWECommentPanelTabSwiftImpl.CommentTabModel";
static NSString *const kDYYYCommentContainerTabModelClassName =
    @"AWECommentPanelContainerSwiftImpl.CommentTabModel";
static NSString *const kDYYYCommentAIParseViewControllerClassName =
    @"AWEFeedDoubleColumnCommentAIParseViewController";
static NSString *const kDYYYPOIRateListInCommentViewControllerClassName =
    @"AWEPOIUGCRateListInCommentViewController";
static NSString *const kDYYYLocalLifeCommentBizServiceClassName = @"IESLocalLifeCommentBizService";
static NSString *const kDYYYECModuleServiceClassName = @"AWEECModuleService";
static NSString *const kDYYYCommentPanelTabBasicParamsClassName = @"AWECommentPanelTabBasicParams";
static NSString *const kDYYYCommentContainerInnerViewControllerClassName =
    @"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController";

typedef BOOL (*DYYYBoolSceneIMP)(id, SEL, id);
typedef BOOL (*DYYYBoolAwemeIMP)(id, SEL, id);
typedef BOOL (*DYYYBoolAwemeEnterFromIMP)(id, SEL, id, id);
typedef BOOL (*DYYYBoolContextTypeIMP)(id, SEL, id, unsigned long long);
typedef BOOL (*DYYYBoolTypeIMP)(id, SEL, unsigned long long);
typedef BOOL (*DYYYBoolNoArgIMP)(id, SEL);
typedef id (*DYYYArrayTypesIMP)(id, SEL, id);
typedef id (*DYYYIdContextIMP)(id, SEL, id);
typedef id (*DYYYViewControllerForTypeIMP)(id, SEL, unsigned long long);
typedef void (*DYYYVoidConfigSegmentedControlIMP)(id, SEL, id);
typedef void (*DYYYSetNeedsUpdateIMP)(id, SEL, BOOL, id);
typedef void (*DYYYSetTitleIMP)(id, SEL, id);
typedef double (*DYYYDoubleNoArgIMP)(id, SEL);

static const char *const kDYYYBoolObjectEncodings[] = { "B24@0:8@16", "c24@0:8@16" };
static const char *const kDYYYBoolTwoObjectsEncodings[] = { "B32@0:8@16@24", "c32@0:8@16@24" };
static const char *const kDYYYBoolObjectTypeEncodings[] = { "B32@0:8@16Q24", "c32@0:8@16Q24" };
static const char *const kDYYYBoolTypeEncodings[] = { "B24@0:8Q16", "c24@0:8Q16" };
static const char *const kDYYYBoolNoArgEncodings[] = { "B16@0:8", "c16@0:8" };
static const char *const kDYYYObjectObjectEncodings[] = { "@24@0:8@16" };
static const char *const kDYYYObjectTypeEncodings[] = { "@24@0:8Q16" };
static const char *const kDYYYVoidObjectEncodings[] = { "v24@0:8@16" };
static const char *const kDYYYVoidBoolBlockEncodings[] = {
    "v28@0:8B16@?20",
    "v28@0:8c16@?20",
};
static const char *const kDYYYDoubleNoArgEncodings[] = { "d16@0:8" };

#define DYYY_ENCODING_COUNT(encodings) (sizeof(encodings) / sizeof((encodings)[0]))

static atomic_bool gDYYYHideCommentAIAnalysisHooksStarted = false;
static NSMutableSet<NSNumber *> *gHiddenCommentTabTypes = nil;
static NSMutableDictionary<NSString *, NSValue *> *gOrigCommentTabSetNeedsUpdateIMPs = nil;

typedef struct {
    const char *category;
    const char *identifier;
    const char *status;
    uint64_t elapsedTicks;
} DYYYCommentInstallMetric;

static DYYYCommentInstallMetric gDYYYCommentInstallMetrics[64];
static NSUInteger gDYYYCommentInstallMetricCount = 0;

static void DYYYRecordCommentInstallMetric(const char *category,
                                           const char *identifier,
                                           const char *status,
                                           uint64_t startedAt) {
    if (gDYYYCommentInstallMetricCount >= sizeof(gDYYYCommentInstallMetrics) / sizeof(gDYYYCommentInstallMetrics[0])) {
        return;
    }
    gDYYYCommentInstallMetrics[gDYYYCommentInstallMetricCount++] = (DYYYCommentInstallMetric){
        .category = category,
        .identifier = identifier,
        .status = status,
        .elapsedTicks = mach_continuous_time() - startedAt,
    };
}

static double DYYYCommentInstallMilliseconds(uint64_t ticks) {
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      mach_timebase_info(&timebase);
    });
    return ((double)ticks * (double)timebase.numer / (double)timebase.denom) / 1000000.0;
}

static BOOL DYYYCommentVersionCapability(const char *identifier, NSString *minimumVersion) {
    uint64_t startedAt = mach_continuous_time();
    NSString *appVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    BOOL supported = appVersion.length == 0 ||
                     [DYYYUtils compareVersion:appVersion toVersion:minimumVersion] != NSOrderedAscending;
    DYYYRecordCommentInstallMetric("version-capability",
                                   identifier,
                                   supported ? "supported" : "unsupported",
                                   startedAt);
    return supported;
}

static void DYYYLogCommentInstallMetrics(void) {
    const NSUInteger metricsPerChunk = 6;
    NSUInteger chunkCount =
        (gDYYYCommentInstallMetricCount + metricsPerChunk - 1) / metricsPerChunk;
    for (NSUInteger chunk = 0; chunk < chunkCount; chunk++) {
        NSMutableString *payload = [NSMutableString string];
        NSUInteger firstMetric = chunk * metricsPerChunk;
        NSUInteger lastMetric = MIN(firstMetric + metricsPerChunk, gDYYYCommentInstallMetricCount);
        for (NSUInteger index = firstMetric; index < lastMetric; index++) {
            DYYYCommentInstallMetric metric = gDYYYCommentInstallMetrics[index];
            if (index > firstMetric) {
                [payload appendString:@";"];
            }
            [payload appendFormat:@"%s,%s,%s,%.3f",
                                  metric.category,
                                  metric.identifier,
                                  metric.status,
                                  DYYYCommentInstallMilliseconds(metric.elapsedTicks)];
        }
        NSLog(@"[DYYY][HookPerf][comment.extra-tabs] unit=ms chunk=%lu/%lu metrics=%@",
              (unsigned long)(chunk + 1),
              (unsigned long)chunkCount,
              payload);
    }
}

static BOOL DYYYRunMeasuredCommentInstaller(const char *identifier, BOOL (*installer)(void)) {
    uint64_t startedAt = mach_continuous_time();
    BOOL installed = installer();
    DYYYRecordCommentInstallMetric("installer-step",
                                   identifier,
                                   installed ? "installed" : "unavailable",
                                   startedAt);
    return installed;
}

static Class DYYYLookupCommentHookClass(const char *className,
                                        const char *category,
                                        const char *identifier) {
    uint64_t startedAt = mach_continuous_time();
    Class cls = className ? objc_lookUpClass(className) : Nil;
    DYYYRecordCommentInstallMetric(category,
                                   identifier,
                                   cls ? "present" : "missing",
                                   startedAt);
    return cls;
}

static Class DYYYResolveCommentHookClass(NSString *primaryName,
                                         const char *fallbackName,
                                         const char *identifier) {
    Class cls = DYYYLookupCommentHookClass(primaryName.UTF8String, "class-primary", identifier);
    if (!cls && fallbackName) {
        cls = DYYYLookupCommentHookClass(fallbackName, "class-fallback", identifier);
    }
    return cls;
}

static Class DYYYResolveCommentHookClassFallbackFirst(NSString *primaryName,
                                                      const char *fallbackName,
                                                      const char *identifier) {
    Class cls = DYYYLookupCommentHookClass(fallbackName, "class-fallback", identifier);
    if (!cls) {
        cls = DYYYLookupCommentHookClass(primaryName.UTF8String, "class-primary", identifier);
    }
    return cls;
}

static void DYYYCommentExtraTabSetNeedsUpdate(id self, SEL _cmd, BOOL needsUpdate, id completion);

static DYYYBoolSceneIMP gOrigShouldShowDCFeedAITabWithScene = NULL;
static DYYYBoolAwemeEnterFromIMP gOrigCurrentVideoShouldShowAITab = NULL;
static DYYYBoolSceneIMP gOrigCommentTabServiceMultiTabs = NULL;
static DYYYBoolContextTypeIMP gOrigCommentTabServiceContainsTab = NULL;
static DYYYBoolTypeIMP gOrigCommentTabManagerContainsTab = NULL;
static DYYYArrayTypesIMP gOrigCommentTabManagerComponentTypes = NULL;
static DYYYViewControllerForTypeIMP gOrigCommentTabManagerViewControllerForType = NULL;
static DYYYVoidConfigSegmentedControlIMP gOrigCommentTabManagerConfigSegmentedControl = NULL;
static DYYYIdContextIMP gOrigCommentPanelTabBasicParamsInit = NULL;
static DYYYBoolNoArgIMP gOrigCommentPanelTabBasicParamsNoTabScene = NULL;
static DYYYDoubleNoArgIMP gOrigCommentContainerHeightForSegmentedControl = NULL;
static DYYYSetTitleIMP gOrigCommentTabModelSetTitle = NULL;
static DYYYSetTitleIMP gOrigCommentContainerTabModelSetTitle = NULL;
static DYYYBoolAwemeIMP gOrigShouldShowRateTabInCommentWithAweme = NULL;
static DYYYBoolAwemeIMP gOrigShouldShowProductCommentWithAwemeModel = NULL;

static BOOL DYYYHideCommentViewsEnabled(void) {
    return DYYYGetBool(kDYYYHideCommentViewsKey);
}

static NSValue *DYYYOriginalIMPValueForObject(NSDictionary<NSString *, NSValue *> *storage, id object) {
    for (Class cls = object_getClass(object); cls; cls = class_getSuperclass(cls)) {
        NSValue *value = storage[NSStringFromClass(cls)];
        if (value) {
            return value;
        }
    }
    return nil;
}

static NSString *DYYYNormalizedCommentTabTitle(NSString *text) {
    if (text.length == 0) {
        return @"";
    }
    return [[text stringByReplacingOccurrencesOfString:@" " withString:@""] lowercaseString];
}

static BOOL DYYYStringLooksLikePrimaryCommentTab(NSString *text) {
    if (text.length == 0) {
        return NO;
    }
    NSString *normalized = DYYYNormalizedCommentTabTitle(text);
    if ([normalized containsString:@"条评论"]) {
        return YES;
    }
    return [normalized isEqualToString:@"评论"];
}

static BOOL DYYYStringLooksLikeExtraCommentTab(NSString *text) {
    if (text.length == 0 || text.length > 16) {
        return NO;
    }
    if (DYYYStringLooksLikePrimaryCommentTab(text)) {
        return NO;
    }

    NSString *normalized = DYYYNormalizedCommentTabTitle(text);
    static NSArray<NSString *> *hiddenPatterns = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      hiddenPatterns = @[
          @"ai解析",
          @"门店评价",
          @"商品评价",
          @"种草评价",
          @"评价",
          @"看过",
          @"赞过",
          @"收藏",
          @"火焰",
          @"金币",
          @"游戏",
          @"娱乐",
      ];
    });

    for (NSString *pattern in hiddenPatterns) {
        if ([normalized containsString:pattern]) {
            return YES;
        }
    }
    return NO;
}

static void DYYYCacheHiddenCommentTabTypeIfNeeded(unsigned long long tabType, NSString *title) {
    if (tabType == 0 || title.length == 0) {
        return;
    }
    if (!DYYYStringLooksLikeExtraCommentTab(title)) {
        return;
    }
    if (!gHiddenCommentTabTypes) {
        gHiddenCommentTabTypes = [NSMutableSet set];
    }
    [gHiddenCommentTabTypes addObject:@(tabType)];
}

static BOOL DYYYIsHiddenCommentTabType(unsigned long long tabType) {
    return tabType != 0 && [gHiddenCommentTabTypes containsObject:@(tabType)];
}

static BOOL DYYYShouldHideExtraCommentTabTypeString(NSString *typeString) {
    if (typeString.length == 0) {
        return NO;
    }
    if ([typeString isEqualToString:@"Comment"] || [typeString isEqualToString:@"CommentLike"]) {
        return NO;
    }

    static NSArray<NSString *> *hiddenTypePatterns = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      hiddenTypePatterns = @[
          @"CommentAIParse",
          @"CommentDCFeedAIParse",
          @"CommentTemplatePOI",
          @"CommentEvaluate",
          @"CommentProductComment",
          @"CommentViewer",
          @"CommentFavorite",
          @"CommentGoldLike",
          @"CommentHTSFlame",
          @"CommentSendGoldCollect",
          @"CommentADComment",
          @"CommentGameCP",
          @"CommentTemplateEntertainment",
          @"CommentTemplateGameCP",
      ];
    });

    for (NSString *pattern in hiddenTypePatterns) {
        if ([typeString containsString:pattern]) {
            return YES;
        }
    }
    return NO;
}

static BOOL DYYYObjectIsCommentAIParseViewController(id object) {
    if (!object) {
        return NO;
    }
    Class aiParseVCClass = NSClassFromString(kDYYYCommentAIParseViewControllerClassName);
    return aiParseVCClass && [object isKindOfClass:aiParseVCClass];
}

static BOOL DYYYObjectIsExtraCommentTabViewController(id object) {
    if (!object) {
        return NO;
    }
    if (DYYYObjectIsCommentAIParseViewController(object)) {
        return YES;
    }

    Class rateVCClass = NSClassFromString(kDYYYPOIRateListInCommentViewControllerClassName);
    if (rateVCClass && [object isKindOfClass:rateVCClass]) {
        return YES;
    }

    NSString *className = NSStringFromClass([object class]);
    if ([className containsString:@"ProductEvaluation"] || [className containsString:@"RateListInComment"] ||
        [className containsString:@"CommentAIParse"]) {
        return YES;
    }
    return NO;
}

static BOOL DYYYShouldHideCommentTab(unsigned long long tabType, id viewController, NSString *title) {
    if (!DYYYHideCommentViewsEnabled()) {
        return NO;
    }
    if (DYYYIsHiddenCommentTabType(tabType)) {
        return YES;
    }
    if (DYYYObjectIsExtraCommentTabViewController(viewController)) {
        if (tabType != 0) {
            if (!gHiddenCommentTabTypes) {
                gHiddenCommentTabTypes = [NSMutableSet set];
            }
            [gHiddenCommentTabTypes addObject:@(tabType)];
        }
        return YES;
    }
    if (title.length > 0 && DYYYStringLooksLikeExtraCommentTab(title)) {
        if (tabType != 0) {
            DYYYCacheHiddenCommentTabTypeIfNeeded(tabType, title);
        }
        return YES;
    }
    return NO;
}

static void DYYYHideCommentPanelSegmentedControlView(UIView *segmentedControl) {
    if (!segmentedControl || ![segmentedControl isKindOfClass:[UIView class]]) {
        return;
    }
    segmentedControl.hidden = YES;
    segmentedControl.alpha = 0.0;
    segmentedControl.userInteractionEnabled = NO;
}

static NSArray *DYYYFilterExtraCommentTabTypes(NSArray *types) {
    if (!DYYYHideCommentViewsEnabled() || types.count == 0) {
        return types;
    }

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:types.count];
    for (id item in types) {
        if ([item isKindOfClass:[NSNumber class]]) {
            unsigned long long value = [(NSNumber *)item unsignedLongLongValue];
            if (DYYYIsHiddenCommentTabType(value)) {
                continue;
            }
        } else if ([item isKindOfClass:[NSString class]]) {
            if (DYYYShouldHideExtraCommentTabTypeString((NSString *)item)) {
                continue;
            }
        }
        [filtered addObject:item];
    }
    return filtered.count == types.count ? types : [filtered copy];
}

#pragma mark - Shared installer

static const char *DYYYCommentHookInstallStatusName(DYYYRuntimeHookInstallResult result) {
    if (result.status == DYYYRuntimeHookInstallStatusInstalled && result.methodWasInherited) {
        return "installed-inherited";
    }
    switch (result.status) {
        case DYYYRuntimeHookInstallStatusInstalled: return "installed";
        case DYYYRuntimeHookInstallStatusAlreadyInstalled: return "already-installed";
        case DYYYRuntimeHookInstallStatusTargetClassMissing: return "class-missing";
        case DYYYRuntimeHookInstallStatusTargetMethodMissing: return "method-missing";
        case DYYYRuntimeHookInstallStatusTypeEncodingMismatch: return "encoding-mismatch";
        case DYYYRuntimeHookInstallStatusReplacementMissing: return "replacement-missing";
        case DYYYRuntimeHookInstallStatusReplacementSelfReference: return "replacement-self-reference";
        case DYYYRuntimeHookInstallStatusConflict: return "conflict";
    }
    return "unknown";
}

static BOOL DYYYInstallCommentRuntimeHook(const char *identifier,
                                          Class cls,
                                          SEL selector,
                                          BOOL classMethod,
                                          IMP replacement,
                                          IMP *originalSlot,
                                          const char *const *allowedTypeEncodings,
                                          NSUInteger allowedTypeEncodingCount) {
    uint64_t startedAt = mach_continuous_time();
    DYYYRuntimeHookInstallResult result = DYYYInstallRuntimeHook((DYYYRuntimeHookRequest){
        .identifier = identifier,
        .targetClass = cls,
        .selector = selector,
        .classMethod = classMethod,
        .replacement = replacement,
        .allowedTypeEncodings = allowedTypeEncodings,
        .allowedTypeEncodingCount = allowedTypeEncodingCount,
        .originalImplementation = originalSlot,
    });
    DYYYRecordCommentInstallMetric("hook-install",
                                   identifier,
                                   DYYYCommentHookInstallStatusName(result),
                                   startedAt);
    return result.status == DYYYRuntimeHookInstallStatusInstalled ||
           result.status == DYYYRuntimeHookInstallStatusAlreadyInstalled;
}

static BOOL DYYYInstallSetNeedsUpdateHookForClassName(NSString *className,
                                                       const char *mangledClassName,
                                                       const char *identifier) {
    Class cls = DYYYResolveCommentHookClass(className, mangledClassName, identifier);
    if (!cls) {
        return NO;
    }

    NSString *key = NSStringFromClass(cls);
    if (gOrigCommentTabSetNeedsUpdateIMPs[key]) {
        return YES;
    }

    IMP original = NULL;
    BOOL installed = DYYYInstallCommentRuntimeHook(identifier,
                                                   cls,
                                                   @selector(setNeedsUpdate:completion:),
                                                   NO,
                                                   (IMP)DYYYCommentExtraTabSetNeedsUpdate,
                                                   &original,
                                                   kDYYYVoidBoolBlockEncodings,
                                                   DYYY_ENCODING_COUNT(kDYYYVoidBoolBlockEncodings));
    if (!installed || !original) {
        return NO;
    }
    if (!gOrigCommentTabSetNeedsUpdateIMPs) {
        gOrigCommentTabSetNeedsUpdateIMPs = [NSMutableDictionary dictionary];
    }
    gOrigCommentTabSetNeedsUpdateIMPs[key] = [NSValue valueWithPointer:original];
    return YES;
}

#pragma mark - AWEFeedDoubleColumnAITabUtil

static BOOL DYYYShouldShowDCFeedAITabWithScene(id self, SEL _cmd, id scene) {
    if (DYYYHideCommentViewsEnabled()) {
        return NO;
    }
    if (gOrigShouldShowDCFeedAITabWithScene) {
        return gOrigShouldShowDCFeedAITabWithScene(self, _cmd, scene);
    }
    return YES;
}

static BOOL DYYYCurrentVideoShouldShowAITab(id self, SEL _cmd, id aweme, id enterFrom) {
    if (DYYYHideCommentViewsEnabled()) {
        return NO;
    }
    if (gOrigCurrentVideoShouldShowAITab) {
        return gOrigCurrentVideoShouldShowAITab(self, _cmd, aweme, enterFrom);
    }
    return YES;
}

static BOOL DYYYInstallFeedDoubleColumnAITabUtilHooks(void) {
    Class cls = DYYYResolveCommentHookClass(kDYYYFeedDoubleColumnAITabUtilClassName,
                                            NULL,
                                            "feed-ai-util");
    if (!cls) {
        return NO;
    }

    BOOL sceneOK = DYYYInstallCommentRuntimeHook("feed-ai-util.should-show-scene",
                                                 cls,
                                                 @selector(shouldShowDCFeedAITabWithScene:),
                                                 YES,
                                                 (IMP)DYYYShouldShowDCFeedAITabWithScene,
                                                 (IMP *)&gOrigShouldShowDCFeedAITabWithScene,
                                                 kDYYYBoolObjectEncodings,
                                                 DYYY_ENCODING_COUNT(kDYYYBoolObjectEncodings));
    BOOL videoOK = DYYYInstallCommentRuntimeHook("feed-ai-util.current-video",
                                                 cls,
                                                 @selector(currentVideoShouldShowAITab:enterFrom:),
                                                 YES,
                                                 (IMP)DYYYCurrentVideoShouldShowAITab,
                                                 (IMP *)&gOrigCurrentVideoShouldShowAITab,
                                                 kDYYYBoolTwoObjectsEncodings,
                                                 DYYY_ENCODING_COUNT(kDYYYBoolTwoObjectsEncodings));
    return sceneOK || videoOK;
}

#pragma mark - POI / Commerce tab visibility

static BOOL DYYYShouldShowRateTabInCommentWithAweme(id self, SEL _cmd, id aweme) {
    if (DYYYHideCommentViewsEnabled()) {
        return NO;
    }
    if (gOrigShouldShowRateTabInCommentWithAweme) {
        return gOrigShouldShowRateTabInCommentWithAweme(self, _cmd, aweme);
    }
    return YES;
}

static BOOL DYYYShouldShowProductCommentWithAwemeModel(id self, SEL _cmd, id aweme) {
    if (DYYYHideCommentViewsEnabled()) {
        return NO;
    }
    if (gOrigShouldShowProductCommentWithAwemeModel) {
        return gOrigShouldShowProductCommentWithAwemeModel(self, _cmd, aweme);
    }
    return YES;
}

static BOOL DYYYInstallLocalLifeCommentBizServiceHooks(void) {
    Class cls = DYYYResolveCommentHookClass(kDYYYLocalLifeCommentBizServiceClassName,
                                            NULL,
                                            "local-life");
    if (!cls) {
        return NO;
    }
    return DYYYInstallCommentRuntimeHook("local-life.should-show-rate",
                                         cls,
                                         @selector(shouldShowRateTabInCommentWithAweme:),
                                         NO,
                                         (IMP)DYYYShouldShowRateTabInCommentWithAweme,
                                         (IMP *)&gOrigShouldShowRateTabInCommentWithAweme,
                                         kDYYYBoolObjectEncodings,
                                         DYYY_ENCODING_COUNT(kDYYYBoolObjectEncodings));
}

static BOOL DYYYInstallECModuleServiceHooks(void) {
    Class cls = DYYYResolveCommentHookClass(kDYYYECModuleServiceClassName,
                                            NULL,
                                            "ecommerce");
    if (!cls) {
        return NO;
    }
    return DYYYInstallCommentRuntimeHook("ecommerce.should-show-product",
                                         cls,
                                         @selector(shouldShowProductCommentWithAwemeModel:),
                                         NO,
                                         (IMP)DYYYShouldShowProductCommentWithAwemeModel,
                                         (IMP *)&gOrigShouldShowProductCommentWithAwemeModel,
                                         kDYYYBoolObjectEncodings,
                                         DYYY_ENCODING_COUNT(kDYYYBoolObjectEncodings));
}

#pragma mark - AWECommentTabService / CommentTabManager

static BOOL DYYYCommentTabServiceMultiTabs(id self, SEL _cmd, id context) {
    if (DYYYHideCommentViewsEnabled()) {
        return NO;
    }
    if (gOrigCommentTabServiceMultiTabs) {
        return gOrigCommentTabServiceMultiTabs(self, _cmd, context);
    }
    return YES;
}

static BOOL DYYYCommentTabServiceContainsTab(id self, SEL _cmd, id context, unsigned long long type) {
    if (DYYYShouldHideCommentTab(type, nil, nil)) {
        return NO;
    }
    if (gOrigCommentTabServiceContainsTab) {
        return gOrigCommentTabServiceContainsTab(self, _cmd, context, type);
    }
    return YES;
}

static id DYYYCommentTabManagerViewControllerForType(id self, SEL _cmd, unsigned long long type) {
    if (DYYYShouldHideCommentTab(type, nil, nil)) {
        return nil;
    }
    id viewController = nil;
    if (gOrigCommentTabManagerViewControllerForType) {
        viewController = gOrigCommentTabManagerViewControllerForType(self, _cmd, type);
    }
    if (DYYYShouldHideCommentTab(type, viewController, nil)) {
        return nil;
    }
    return viewController;
}

static BOOL DYYYCommentTabManagerContainsTab(id self, SEL _cmd, unsigned long long type) {
    if (DYYYShouldHideCommentTab(type, nil, nil)) {
        return NO;
    }
    if (gOrigCommentTabManagerViewControllerForType) {
        id viewController = gOrigCommentTabManagerViewControllerForType(self, @selector(viewControllerForType:), type);
        if (DYYYShouldHideCommentTab(type, viewController, nil)) {
            return NO;
        }
    }
    if (gOrigCommentTabManagerContainsTab) {
        return gOrigCommentTabManagerContainsTab(self, _cmd, type);
    }
    return YES;
}

static NSArray *DYYYCommentTabManagerComponentTypes(id self, SEL _cmd, NSArray *types) {
    NSArray *originalTypes = types;
    if (gOrigCommentTabManagerComponentTypes) {
        originalTypes = gOrigCommentTabManagerComponentTypes(self, _cmd, types);
    }
    return DYYYFilterExtraCommentTabTypes(originalTypes);
}

static void DYYYCommentTabManagerConfigSegmentedControl(id self, SEL _cmd, id segmentedControl) {
    if (gOrigCommentTabManagerConfigSegmentedControl) {
        gOrigCommentTabManagerConfigSegmentedControl(self, _cmd, segmentedControl);
    }
    if (DYYYHideCommentViewsEnabled()) {
        DYYYHideCommentPanelSegmentedControlView((UIView *)segmentedControl);
    }
}

static BOOL DYYYInstallCommentTabServiceHooks(void) {
    Class cls = DYYYResolveCommentHookClass(kDYYYCommentTabServiceClassName,
                                            NULL,
                                            "tab-service");
    if (!cls) {
        return NO;
    }

    BOOL multiTabsOK = DYYYInstallCommentRuntimeHook("tab-service.multi-tabs",
                                                     cls,
                                                     @selector(multiTabs:),
                                                     NO,
                                                     (IMP)DYYYCommentTabServiceMultiTabs,
                                                     (IMP *)&gOrigCommentTabServiceMultiTabs,
                                                     kDYYYBoolObjectEncodings,
                                                     DYYY_ENCODING_COUNT(kDYYYBoolObjectEncodings));
    BOOL containsOK = DYYYInstallCommentRuntimeHook("tab-service.contains-tab",
                                                    cls,
                                                    @selector(containsTab:type:),
                                                    NO,
                                                    (IMP)DYYYCommentTabServiceContainsTab,
                                                    (IMP *)&gOrigCommentTabServiceContainsTab,
                                                    kDYYYBoolObjectTypeEncodings,
                                                    DYYY_ENCODING_COUNT(kDYYYBoolObjectTypeEncodings));
    return multiTabsOK || containsOK;
}

static BOOL DYYYInstallCommentTabManagerHooks(void) {
    Class cls = DYYYResolveCommentHookClass(kDYYYCommentTabManagerClassName,
                                            "_TtC27AWECommentPanelTabSwiftImpl17CommentTabManager",
                                            "tab-manager");
    if (!cls) {
        return NO;
    }

    BOOL containsOK = DYYYInstallCommentRuntimeHook("tab-manager.contains-tab",
                                                    cls,
                                                    @selector(containsTab:),
                                                    NO,
                                                    (IMP)DYYYCommentTabManagerContainsTab,
                                                    (IMP *)&gOrigCommentTabManagerContainsTab,
                                                    kDYYYBoolTypeEncodings,
                                                    DYYY_ENCODING_COUNT(kDYYYBoolTypeEncodings));
    BOOL typesOK = DYYYInstallCommentRuntimeHook("tab-manager.component-types",
                                                 cls,
                                                 @selector(componentTypes:),
                                                 NO,
                                                 (IMP)DYYYCommentTabManagerComponentTypes,
                                                 (IMP *)&gOrigCommentTabManagerComponentTypes,
                                                 kDYYYObjectObjectEncodings,
                                                 DYYY_ENCODING_COUNT(kDYYYObjectObjectEncodings));
    BOOL viewControllerOK = DYYYInstallCommentRuntimeHook("tab-manager.view-controller",
                                                          cls,
                                                          @selector(viewControllerForType:),
                                                          NO,
                                                          (IMP)DYYYCommentTabManagerViewControllerForType,
                                                          (IMP *)&gOrigCommentTabManagerViewControllerForType,
                                                          kDYYYObjectTypeEncodings,
                                                          DYYY_ENCODING_COUNT(kDYYYObjectTypeEncodings));
    BOOL segmentedOK = DYYYInstallCommentRuntimeHook("tab-manager.segmented-control",
                                                     cls,
                                                     @selector(configSegmentedControl:),
                                                     NO,
                                                     (IMP)DYYYCommentTabManagerConfigSegmentedControl,
                                                     (IMP *)&gOrigCommentTabManagerConfigSegmentedControl,
                                                     kDYYYVoidObjectEncodings,
                                                     DYYY_ENCODING_COUNT(kDYYYVoidObjectEncodings));
    return containsOK || typesOK || viewControllerOK || segmentedOK;
}

#pragma mark - AWECommentPanelTabBasicParams / CommentContainerInner

static id DYYYCommentPanelTabBasicParamsInit(id self, SEL _cmd, id preNode) {
    id params = nil;
    if (gOrigCommentPanelTabBasicParamsInit) {
        params = gOrigCommentPanelTabBasicParamsInit(self, _cmd, preNode);
    }
    if (DYYYHideCommentViewsEnabled() && params) {
        [params setValue:@YES forKey:@"noTabScene"];
    }
    return params;
}

static BOOL DYYYCommentPanelTabBasicParamsNoTabScene(id self, SEL _cmd) {
    if (DYYYHideCommentViewsEnabled()) {
        return YES;
    }
    if (gOrigCommentPanelTabBasicParamsNoTabScene) {
        return gOrigCommentPanelTabBasicParamsNoTabScene(self, _cmd);
    }
    return NO;
}

static double DYYYCommentContainerHeightForSegmentedControl(id self, SEL _cmd) {
    if (DYYYHideCommentViewsEnabled()) {
        return 0.0;
    }
    if (gOrigCommentContainerHeightForSegmentedControl) {
        return gOrigCommentContainerHeightForSegmentedControl(self, _cmd);
    }
    return 0.0;
}

static BOOL DYYYInstallCommentPanelTabBasicParamsHooks(void) {
    Class cls = DYYYResolveCommentHookClass(kDYYYCommentPanelTabBasicParamsClassName,
                                            NULL,
                                            "basic-params");
    if (!cls) {
        return NO;
    }

    BOOL initOK = DYYYInstallCommentRuntimeHook("basic-params.init",
                                                cls,
                                                @selector(initWithPreNode:),
                                                NO,
                                                (IMP)DYYYCommentPanelTabBasicParamsInit,
                                                (IMP *)&gOrigCommentPanelTabBasicParamsInit,
                                                kDYYYObjectObjectEncodings,
                                                DYYY_ENCODING_COUNT(kDYYYObjectObjectEncodings));
    BOOL sceneOK = DYYYInstallCommentRuntimeHook("basic-params.no-tab-scene",
                                                 cls,
                                                 @selector(noTabScene),
                                                 NO,
                                                 (IMP)DYYYCommentPanelTabBasicParamsNoTabScene,
                                                 (IMP *)&gOrigCommentPanelTabBasicParamsNoTabScene,
                                                 kDYYYBoolNoArgEncodings,
                                                 DYYY_ENCODING_COUNT(kDYYYBoolNoArgEncodings));
    return initOK || sceneOK;
}

static BOOL DYYYInstallCommentContainerInnerHooks(void) {
    BOOL installed = NO;

    Class viewControllerClass =
        DYYYResolveCommentHookClass(kDYYYCommentContainerInnerViewControllerClassName,
                                    "_TtC33AWECommentPanelContainerSwiftImpl35CommentContainerInnerViewController",
                                    "container-inner");
    if (viewControllerClass) {
        installed |= DYYYInstallCommentRuntimeHook("container-inner.height",
                                                   viewControllerClass,
                                                   @selector(heightForSegmentedControl),
                                                   NO,
                                                   (IMP)DYYYCommentContainerHeightForSegmentedControl,
                                                   (IMP *)&gOrigCommentContainerHeightForSegmentedControl,
                                                   kDYYYDoubleNoArgEncodings,
                                                   DYYY_ENCODING_COUNT(kDYYYDoubleNoArgEncodings));
    }

    return installed;
}

#pragma mark - Extra comment tab components

static void DYYYCommentExtraTabSetNeedsUpdate(id self, SEL _cmd, BOOL needsUpdate, id completion) {
    if (DYYYHideCommentViewsEnabled()) {
        if (completion) {
            ((void (^)(void))completion)();
        }
        return;
    }

    NSValue *origValue = DYYYOriginalIMPValueForObject(gOrigCommentTabSetNeedsUpdateIMPs, self);
    DYYYSetNeedsUpdateIMP orig = origValue ? (DYYYSetNeedsUpdateIMP)origValue.pointerValue : NULL;
    if (orig) {
        orig(self, _cmd, needsUpdate, completion);
    }
}

static BOOL DYYYInstallExtraCommentTabComponentHooks(void) {
    BOOL installed = NO;
    if (DYYYCommentVersionCapability("component.ai-parse", @"38.6.1")) {
        installed |= DYYYInstallSetNeedsUpdateHookForClassName(
            kDYYYCommentDCFeedAIParseTabComponentClassName,
            "_TtC25AWECommentDCFeedSwiftImpl32CommentDCFeedAIParseTabComponent",
            "component.ai-parse");
    }
    installed |= DYYYInstallSetNeedsUpdateHookForClassName(kDYYYCommentTemplatePOITabComponentClassName,
                                                           "_TtC22AWECommentPOISwiftImpl30CommentTemplatePOITabComponent",
                                                           "component.poi");
    installed |= DYYYInstallSetNeedsUpdateHookForClassName(kDYYYCommentEvaluateTabComponentClassName,
                                                           "_TtC27AWECommentCommerceSwiftImpl27CommentEvaluateTabComponent",
                                                           "component.evaluate");
    installed |= DYYYInstallSetNeedsUpdateHookForClassName(kDYYYCommentProductCommentTabComponentClassName,
                                                           "_TtC27AWECommentCommerceSwiftImpl33CommentProductCommentTabComponent",
                                                           "component.product");
    return installed;
}

#pragma mark - CommentTabModel title cache

static void DYYYCommentTabModelSetTitle(id self, SEL _cmd, NSString *title) {
    if (gOrigCommentTabModelSetTitle) {
        gOrigCommentTabModelSetTitle(self, _cmd, title);
    }
    if (!DYYYStringLooksLikeExtraCommentTab(title)) {
        return;
    }
    if ([self respondsToSelector:@selector(tab)]) {
        unsigned long long tabType = ((unsigned long long (*)(id, SEL))objc_msgSend)(self, @selector(tab));
        DYYYCacheHiddenCommentTabTypeIfNeeded(tabType, title);
    }
}

static void DYYYCommentContainerTabModelSetTitle(id self, SEL _cmd, NSString *title) {
    if (gOrigCommentContainerTabModelSetTitle) {
        gOrigCommentContainerTabModelSetTitle(self, _cmd, title);
    }
    if (!DYYYStringLooksLikeExtraCommentTab(title)) {
        return;
    }
    if ([self respondsToSelector:@selector(tab)]) {
        unsigned long long tabType = ((unsigned long long (*)(id, SEL))objc_msgSend)(self, @selector(tab));
        DYYYCacheHiddenCommentTabTypeIfNeeded(tabType, title);
    }
}

static BOOL DYYYInstallCommentTabModelHooks(void) {
    BOOL installed = NO;

    if (!DYYYCommentVersionCapability("tab-model-path", @"39.5.0")) {
        return NO;
    }

    Class containerTabModelClass =
        DYYYLookupCommentHookClass(kDYYYCommentContainerTabModelClassName.UTF8String,
                                   "class-capability",
                                   "tab-model-path");
    if (!containerTabModelClass) {
        return NO;
    }

    Class tabModelClass =
        DYYYResolveCommentHookClassFallbackFirst(
            kDYYYCommentTabModelClassName,
            "_TtC27AWECommentPanelTabSwiftImplP33_63C657C2E18159D394914B02AA302F2B15CommentTabModel",
            "tab-model");
    if (tabModelClass) {
        installed |= DYYYInstallCommentRuntimeHook("tab-model.set-title",
                                                   tabModelClass,
                                                   @selector(setTitle:),
                                                   NO,
                                                   (IMP)DYYYCommentTabModelSetTitle,
                                                   (IMP *)&gOrigCommentTabModelSetTitle,
                                                   kDYYYVoidObjectEncodings,
                                                   DYYY_ENCODING_COUNT(kDYYYVoidObjectEncodings));
    }

    installed |= DYYYInstallCommentRuntimeHook("container-tab-model.set-title",
                                               containerTabModelClass,
                                               @selector(setTitle:),
                                               NO,
                                               (IMP)DYYYCommentContainerTabModelSetTitle,
                                               (IMP *)&gOrigCommentContainerTabModelSetTitle,
                                               kDYYYVoidObjectEncodings,
                                               DYYY_ENCODING_COUNT(kDYYYVoidObjectEncodings));

    return installed;
}

void DYYYStartHideCommentAIAnalysisHooks(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gDYYYHideCommentAIAnalysisHooksStarted, &expected, true)) {
        return;
    }

    BOOL utilHooked =
        DYYYRunMeasuredCommentInstaller("feed-ai-util", DYYYInstallFeedDoubleColumnAITabUtilHooks);
    BOOL localLifeHooked =
        DYYYRunMeasuredCommentInstaller("local-life", DYYYInstallLocalLifeCommentBizServiceHooks);
    BOOL ecomHooked = DYYYRunMeasuredCommentInstaller("ecommerce", DYYYInstallECModuleServiceHooks);
    BOOL basicParamsHooked =
        DYYYRunMeasuredCommentInstaller("basic-params", DYYYInstallCommentPanelTabBasicParamsHooks);
    BOOL containerHooked =
        DYYYRunMeasuredCommentInstaller("container-inner", DYYYInstallCommentContainerInnerHooks);
    BOOL serviceHooked =
        DYYYRunMeasuredCommentInstaller("tab-service", DYYYInstallCommentTabServiceHooks);
    BOOL managerHooked =
        DYYYRunMeasuredCommentInstaller("tab-manager", DYYYInstallCommentTabManagerHooks);
    BOOL componentHooked =
        DYYYRunMeasuredCommentInstaller("extra-components", DYYYInstallExtraCommentTabComponentHooks);
    BOOL modelHooked = DYYYRunMeasuredCommentInstaller("tab-models", DYYYInstallCommentTabModelHooks);

    DYYYLogCommentInstallMetrics();

    NSLog(@"[DYYY][RuntimeHook][HideCommentExtraTabs] 安装完成 util=%@ localLife=%@ ecom=%@ basicParams=%@ container=%@ service=%@ manager=%@ component=%@ model=%@",
          utilHooked ? @"YES" : @"NO",
          localLifeHooked ? @"YES" : @"NO",
          ecomHooked ? @"YES" : @"NO",
          basicParamsHooked ? @"YES" : @"NO",
          containerHooked ? @"YES" : @"NO",
          serviceHooked ? @"YES" : @"NO",
          managerHooked ? @"YES" : @"NO",
          componentHooked ? @"YES" : @"NO",
          modelHooked ? @"YES" : @"NO");
}
