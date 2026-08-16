#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 安装「隐藏分享提示」Runtime Hook。
/// 覆盖旧版 `AWEPlayInteractionStrongifyShareContentView` 与 V3 内容条。
/// 安装与开关无关；替换函数实时读取设置，关闭时透传原实现。
FOUNDATION_EXPORT void DYYYStartHideShareContentViewHooks(void);

NS_ASSUME_NONNULL_END
