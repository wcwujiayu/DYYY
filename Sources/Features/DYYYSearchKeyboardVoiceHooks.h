#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 安装搜索页 AI / 语音入口的 Runtime Hook（设置 key: `DYYYHideKeyboardAI`）。
/// 覆盖：键盘语音入口、旧版 `AWESearchKeyboardAISearchElement`、
/// 以及综合搜索结果页右下角 `AWEGeneralSearchAIBallButton` / `AWEGeneralSearchAIModeButton`
///（由 `AWEGeneralSearchAIModeManager` 管理，文案可为「继续追问」等）。
/// 不扫描 UIKit 文案，不隐藏扫一扫等非 AI 入口，也不影响设置页或系统键盘。
FOUNDATION_EXPORT void DYYYStartSearchKeyboardVoiceHooks(void);

NS_ASSUME_NONNULL_END
