#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 启动时按当前开关状态挂载/拆除实时帧率浮窗（独立高层级 Window，覆盖宿主与 DYYY 设置）。
FOUNDATION_EXPORT void DYYYStartFPSOverlay(void);

/// 高帧率或帧率显示开关变化后刷新浮窗。
FOUNDATION_EXPORT void DYYYApplyFPSOverlaySettingChange(void);

NS_ASSUME_NONNULL_END
