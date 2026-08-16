#import "DYYYHookManager.h"

#import "DYYYFeedTagHooks.h"
#import "DYYYFPSOverlay.h"
#import "DYYYHideCommentAIAnalysisHooks.h"
#import "DYYYHideMessageAndMinePageHooks.h"
#import "DYYYHideMusicButtonHooks.h"
#import "DYYYHideShareContentViewHooks.h"
#import "DYYYHideTemplateCollectionHooks.h"
#import "DYYYHighFPSHooks.h"
#import "DYYYExactInteractionCountHooks.h"
#import "DYYYLoginRepairHooks.h"
#import "DYYYMiniProgramRewardBypass.h"
#import "DYYYSearchKeyboardVoiceHooks.h"

#import <mach/mach_time.h>
#import <stdatomic.h>

typedef NS_ENUM(NSUInteger, DYYYHookPhase) {
    DYYYHookPhaseLoaderSafe,
    DYYYHookPhaseAfterLoginCore,
    DYYYHookPhaseAfterAgreement,
};

typedef void (*DYYYHookInstaller)(void);

typedef struct {
    const char *identifier;
    DYYYHookPhase phase;
    DYYYHookInstaller installer;
} DYYYHookDescriptor;

static const DYYYHookDescriptor kDYYYHookDescriptors[] = {
    { "performance.high-fps", DYYYHookPhaseLoaderSafe, DYYYStartHighFPSHooks },
    { "feed.tags", DYYYHookPhaseLoaderSafe, DYYYStartFeedTagHooks },
    { "share.prompt", DYYYHookPhaseLoaderSafe, DYYYStartHideShareContentViewHooks },
    { "login.repair", DYYYHookPhaseAfterLoginCore, DYYYLoginRepairInstallHooks },
    { "mini-program.reward", DYYYHookPhaseAfterAgreement, DYYYStartMiniProgramRewardBypassInstaller },
    { "feed.music-button", DYYYHookPhaseAfterAgreement, DYYYStartHideMusicButtonHooks },
    { "tabs.message-mine", DYYYHookPhaseAfterAgreement, DYYYStartHideMessageAndMinePageHooks },
    { "comment.extra-tabs", DYYYHookPhaseAfterAgreement, DYYYStartHideCommentAIAnalysisHooks },
    { "feed.template", DYYYHookPhaseAfterAgreement, DYYYStartHideTemplateCollectionHooks },
    { "search.keyboard-voice", DYYYHookPhaseAfterAgreement, DYYYStartSearchKeyboardVoiceHooks },
    { "performance.fps-overlay", DYYYHookPhaseAfterAgreement, DYYYStartFPSOverlay },
    { "interaction-counts.exact", DYYYHookPhaseAfterAgreement, DYYYStartExactInteractionCountHooks },
};

static atomic_bool gDYYYLoaderSafePhaseStarted = false;
static atomic_bool gDYYYAfterLoginCorePhaseStarted = false;
static atomic_bool gDYYYAfterAgreementPhaseStarted = false;

static double DYYYMillisecondsBetween(uint64_t start, uint64_t end) {
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });
    return ((double)(end - start) * (double)timebase.numer / (double)timebase.denom) / 1.0e6;
}

static void DYYYStartHookPhase(DYYYHookPhase phase, atomic_bool *started) {
    bool expected = false;
    if (!atomic_compare_exchange_strong_explicit(started,
                                                  &expected,
                                                  true,
                                                  memory_order_acq_rel,
                                                  memory_order_acquire)) {
        return;
    }

    uint64_t phaseStart = mach_continuous_time();
    NSUInteger installedCount = 0;
    for (NSUInteger index = 0; index < sizeof(kDYYYHookDescriptors) / sizeof(kDYYYHookDescriptors[0]); index++) {
        const DYYYHookDescriptor descriptor = kDYYYHookDescriptors[index];
        if (descriptor.phase != phase || !descriptor.installer) {
            continue;
        }
        uint64_t installStart = mach_continuous_time();
        descriptor.installer();
        double duration = DYYYMillisecondsBetween(installStart, mach_continuous_time());
        installedCount++;
        if (duration >= 8.0) {
            NSLog(@"[DYYY][HookManager] slow installer=%s phase=%lu duration_ms=%.2f",
                  descriptor.identifier,
                  (unsigned long)phase,
                  duration);
        }
    }
    NSLog(@"[DYYY][HookManager] phase=%lu installers=%lu duration_ms=%.2f",
          (unsigned long)phase,
          (unsigned long)installedCount,
          DYYYMillisecondsBetween(phaseStart, mach_continuous_time()));
}

void DYYYHookManagerStartLoaderSafePhase(void) {
    DYYYStartHookPhase(DYYYHookPhaseLoaderSafe, &gDYYYLoaderSafePhaseStarted);
}

void DYYYHookManagerStartAfterLoginCorePhase(void) {
    DYYYStartHookPhase(DYYYHookPhaseAfterLoginCore, &gDYYYAfterLoginCorePhaseStarted);
}

void DYYYHookManagerStartAfterAgreementPhase(void) {
    DYYYStartHookPhase(DYYYHookPhaseAfterAgreement, &gDYYYAfterAgreementPhaseStarted);
}
