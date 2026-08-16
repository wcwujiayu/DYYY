#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Loader 阶段只编排不访问 UIKit 对象的 Domain 安装入口。
FOUNDATION_EXPORT void DYYYHookManagerStartLoaderSafePhase(void);

/// 必须在历史登录核心组完成安装后调用，保持现有 IMP 链顺序。
FOUNDATION_EXPORT void DYYYHookManagerStartAfterLoginCorePhase(void);

/// 用户协议通过后安装需要完整业务环境的 Runtime Domain。
FOUNDATION_EXPORT void DYYYHookManagerStartAfterAgreementPhase(void);

NS_ASSUME_NONNULL_END
