#ifndef DYYYConstants_h
#define DYYYConstants_h

#define DYYY_NAME @"DYYY"
#define DYYY_SETTINGS_NAME @"DYYY设置"

#define DYYY_VERSION @"2.3-0"

// 默认的远程 ABTest 配置地址
#define DYYY_DEFAULT_ABTEST_URL @"https://github.com/Nathalie-Annis/AWEABTestDataPatch/releases/latest/download/ABTestDataPatch_A.json"

// 是否使用远程配置的偏好键
#define DYYY_REMOTE_CONFIG_FLAG_KEY @"DYYYUseRemoteConfig"

// 远程配置状态改变的通知名
#define DYYY_REMOTE_CONFIG_CHANGED_NOTIFICATION @"DYYYRemoteConfigStateChanged"

// 配置应用方式中的远程模式名称
#define DYYY_REMOTE_MODE_STRING @"远程模式：启动时自动检查更新"

#define DYYYGeonamesErrorDomain @"com.dyyy.geonames.api.error"
#define DYYYGeonamesStatusUserInfoKey @"com.dyyy.geonames.api.status"

#define DYYY_DISABLE_FEED_NOW_PLAYING_INFO_KEY @"DYYYDisableFeedNowPlayingInfo"

// 互动数超过一万时显示完整整数，关闭后恢复宿主的万字缩写
#define DYYY_SHOW_EXACT_INTERACTION_COUNTS_KEY @"DYYYShowExactInteractionCounts"

// 开启设备最高可用帧率（ProMotion 门闩 + 抖音 AWEProMotionFPSBooster / 关闭 DisplayLink 降帧；负载过重时自动降档）
#define DYYY_ENABLE_HIGH_FPS_KEY @"DYYYEnableHighFPS"

// 实时帧率浮窗（依赖 DYYYEnableHighFPS）
#define DYYY_SHOW_FPS_OVERLAY_KEY @"DYYYShowFPSOverlay"

// 保存媒体到相册时是否写入作者、作品链接、文案和发布时间
#define DYYY_ALBUM_MEDIA_DESCRIPTION_KEY @"DYYYAlbumMediaDescription"

// 快捷倍速 / 一键清屏按钮：开启后才按四边固定边距贴边拖动；默认关闭
#define DYYY_SPEED_BUTTON_STICK_TO_EDGE_KEY @"DYYYSpeedButtonStickToEdge"
#define DYYY_CLEAR_BUTTON_STICK_TO_EDGE_KEY @"DYYYClearButtonStickToEdge"
#define DYYY_RESET_SPEED_BUTTON_POSITION_KEY @"DYYYResetSpeedButtonPosition"
#define DYYY_RESET_CLEAR_BUTTON_POSITION_KEY @"DYYYResetClearButtonPosition"

#ifdef __cplusplus
extern "C" {
#endif
void DYYYApplyFeedNowPlayingSettingChange(BOOL disableNowPlayingInfo);
#ifdef __cplusplus
}
#endif

#endif
