#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 开启最高可用帧率：解锁 iPhone ProMotion 门闩，并调用抖音自带
/// `AWEProMotionFPSBooster` / 关闭 `AWEDisplayLinkDegradeManager` 降帧。
FOUNDATION_EXPORT void DYYYStartHighFPSHooks(void);

/// 设置开关变化时立即应用 / 撤销。
FOUNDATION_EXPORT void DYYYApplyHighFPSSettingChange(BOOL enabled);

NS_ASSUME_NONNULL_END
