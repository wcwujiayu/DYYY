#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 安装「隐藏视频合集 / 隐藏短剧合集」相关 Runtime Hook。
/// 安装与开关无关；替换函数实时读取设置，关闭时透传原实现。
FOUNDATION_EXPORT void DYYYStartHideTemplateCollectionHooks(void);

NS_ASSUME_NONNULL_END
