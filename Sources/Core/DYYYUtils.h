#import <Photos/Photos.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"
#import "CityManager.h"

NS_ASSUME_NONNULL_BEGIN

@class YYAnimatedImageView;
@class AVAssetTrack;

@interface DYYYUtils : NSObject

#pragma mark - Public Model Filtering Utilities (公共模型过滤工具)

/** 使用抖音模型自身的广告判定及明确广告字段识别广告作品。 */
+ (BOOL)isAdvertisementAwemeModel:(id)model;

/** 识别作品模型或搜索结果包装模型中的广告。 */
+ (BOOL)isAdvertisementContainerModel:(id)model;

/** 从列表中移除广告模型；未启用屏蔽广告时原样返回。 */
+ (NSArray *)arrayByRemovingAdvertisements:(id)array;

/** 在作品模型字段尚未完成映射时，从原始响应中识别明确广告标记。 */
+ (BOOL)isAdvertisementRawData:(id)rawData;

/**
 * 更新 UILabel 显示 IP 属地：国内直接解析，国外走 API 并缓存，内部已 dispatch 回主线程。
 * 国外查询是异步的，颜色需在回调内随文本一起应用，故由本函数接收 colorHexString。
 */
+ (void)processAndApplyIPLocationToLabel:(UILabel *)label forModel:(AWEAwemeModel *)model withLabelColor:(NSString *)colorHexString;

#pragma mark - Public UI/Window/Controller Utilities (公共 UI/窗口/控制器 工具)

/** 获取当前活动窗口 */
+ (UIWindow *)getActiveWindow;

/** 获取当前显示的顶层视图控制器 */
+ (UIViewController *)topView;

/* 在视图控制器层级中查找指定类的控制器 */
+ (UIViewController *)firstAvailableViewControllerFromView:(UIView *)view;
+ (UIViewController *)findViewControllerOfClass:(Class)targetClass inViewController:(UIViewController *)vc;

+ (UIResponder *)findAncestorResponderOfClass:(Class)targetClass fromView:(UIView *)view;

/** 查找容器（控制器或视图）层级中所有属于 targetClass 的视图；无匹配返回空数组。 */
+ (NSArray<__kindof UIView *> *)findAllSubviewsOfClass:(Class)targetClass inContainer:(id)container;

/** 查找容器层级中首个属于 targetClass 的视图；无匹配返回 nil。 */
+ (__kindof UIView *)findSubviewOfClass:(Class)targetClass inContainer:(id)container;

/** 计算多个视图的最近公共父视图；数组为空或无公共父视图返回 nil。 */
+ (__kindof UIView *)nearestCommonSuperviewOfViews:(NSArray<UIView *> *)views;

/** 容器层级中是否存在属于 targetClass 的视图。 */
+ (BOOL)containsSubviewOfClass:(Class)targetClass inContainer:(id)container;

+ (void)applyBlurEffectToView:(UIView *)view transparency:(float)userTransparency blurViewTag:(NSInteger)tag;
+ (void)clearBackgroundRecursivelyInView:(UIView *)view;

/** 显示提示信息 */
+ (void)showToast:(NSString *)text;

/** 检查当前是否为暗黑模式 */
+ (BOOL)isDarkMode;

/** 检查当前抖音背景设置是否为浅色 */
+ (BOOL)usesDouyinLightBackground;

/** 调用抖音 AWEUIColor 主题接口获取动态颜色；接口不可用或返回异常时使用 fallbackColor。 */
+ (UIColor *)douyinColorNamed:(NSString *)colorName fallbackColor:(UIColor *)fallbackColor;

/** 抖音原生设置页 colorStyle=2 使用的中性页面背景色。 */
+ (UIColor *)douyinSettingsPageBackgroundColor;

/** 抖音原生设置卡片的最终不透明显示色：BGCard2 按原生规则合成到 BGDoubleRow，避免半透明 token 直接赋给自定义控件。 */
+ (UIColor *)douyinOpaqueSettingsCardBackgroundColor;

/** 抖音原生输入/交互控件的最终不透明显示色：BGInput2 按原生规则合成到 BGPanelTint，保持自定义输入框 alpha=1。 */
+ (UIColor *)douyinOpaqueInputBackgroundColor;

/** 抖音原生过滤、关键词等交互控件的最终不透明显示色：BGCard2 合成到 BGPanelTint，避免半透明 token 叠在视频上穿底。 */
+ (UIColor *)douyinOpaqueInteractiveControlBackgroundColor;

/** 抖音原生过滤、关键词等交互控件背景色。 */
+ (UIColor *)douyinInteractiveControlBackgroundColor;

/** 抖音原生浮层/面板背景色。 */
+ (UIColor *)douyinPanelBackgroundColor;

/** 抖音原生分隔线颜色。 */
+ (UIColor *)douyinSeparatorColor;

/** 抖音原生高对比度交互区域分割线颜色。 */
+ (UIColor *)douyinInteractiveSeparatorColor;

/** 准备全屏模态浮层的初始状态。调用方完成视图组装后、添加到窗口前调用。 */
+ (void)prepareModalOverlayView:(UIView *)overlayView contentView:(UIView *)contentView;

/** 以统一的淡入和轻微弹性缩放显示全屏模态浮层。 */
+ (void)animateModalOverlayViewIn:(UIView *)overlayView
                      contentView:(UIView *)contentView
                       completion:(void (^_Nullable)(BOOL finished))completion;

/** 以统一的淡出和轻微位移动画关闭全屏模态浮层。 */
+ (void)animateModalOverlayViewOut:(UIView *)overlayView
                       contentView:(UIView *)contentView
                        completion:(void (^_Nullable)(BOOL finished))completion;

/** 以指定时长关闭全屏模态浮层，适合关闭后需要立即呈现系统控制器的场景。 */
+ (void)animateModalOverlayViewOut:(UIView *)overlayView
                       contentView:(UIView *)contentView
                          duration:(NSTimeInterval)duration
                        completion:(void (^_Nullable)(BOOL finished))completion;

#pragma mark - Public File Management (公共文件管理)

/** 将字节数格式化为易读字符串，例如 "1.5 MB"。 */
+ (NSString *)formattedSize:(unsigned long long)size;

/** 递归统计目录大小 */
+ (unsigned long long)directorySizeAtPath:(NSString *)directoryPath;
/** 递归删除目录下所有内容 */
+ (void)removeAllContentsAtPath:(NSString *)directoryPath;

/** 返回插件缓存目录路径，默认为 tmp/DYYY */
+ (NSString *)cacheDirectory;

/** 清理插件缓存目录 */
+ (void)clearCacheDirectory;

/** 在缓存目录下生成指定文件名的完整路径 */
+ (NSString *)cachePathForFilename:(NSString *)filename;

#pragma mark - Public Media Helper Methods (公共媒体工具方法)

/** 根据文件头判断媒体格式（webp/heic/heif/gif/png/jpeg） */
+ (NSString *)detectFileFormat:(NSURL *)fileURL;

/** 媒体类型文案 */
+ (NSString *)mediaTypeDescription:(MediaType)mediaType;

/** 缩放图片到指定尺寸 */
+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size;

/** 计算图片在容器内按比例居中的绘制区域 */
+ (CGRect)rectForImageAspectFit:(CGSize)imageSize inSize:(CGSize)containerSize;

/** 计算视频轨道在目标尺寸下的等比变换 */
+ (CGAffineTransform)transformForAssetTrack:(AVAssetTrack *)track targetSize:(CGSize)targetSize;

/** 计算图片在目标尺寸下的等比变换 */
+ (CGAffineTransform)transformForImage:(UIImage *)image targetSize:(CGSize)targetSize;

/** 获取抖音图片对象对应的原始网络资源 */
+ (nullable NSURL *)sourceURLForAnimatedImage:(UIImage *)image;

/** 从动画图片对象提取帧数组 */
+ (NSArray *)getImagesFromAnimatedImage:(UIImage *)image;

/** 获取动画图片总时长 */
+ (CGFloat)getDurationFromAnimatedImage:(UIImage *)image;

/** 使用 YYImage 解码动图数据，返回帧图像和总时长 */
+ (BOOL)framesFromAnimatedData:(NSData *)data
                         scale:(CGFloat)scale
                        images:(NSArray<UIImage *> *_Nullable *)images
                 totalDuration:(CGFloat *_Nullable)totalDuration;

/** 根据帧数组生成 GIF 文件 */
+ (BOOL)createGIFWithImages:(NSArray *)images duration:(CGFloat)duration path:(NSString *)path progress:(void (^)(float progress))progressBlock;

/** 保存 GIF 到相册并清理临时文件 */
+ (void)saveGIFToPhotoLibrary:(NSString *)path completion:(void (^)(BOOL success, NSError *error))completion;

/** 保存 GIF(URL) 到相册并删除源文件 */
+ (void)saveGifToPhotoLibrary:(NSURL *)gifURL completion:(void (^)(BOOL success))completion;

/** 判断视频是否包含音频轨道 */
+ (BOOL)videoHasAudio:(NSURL *)videoURL;

/** 下载音频并合并到视频 */
+ (void)downloadAudioAndMergeWithVideo:(NSURL *)videoURL
                              audioURL:(NSURL *)audioURL
                            completion:(void (^)(BOOL success, NSURL *mergedURL))completion;

/** 合并视频和音频 */
+ (void)mergeVideo:(NSURL *)videoURL
         withAudio:(NSURL *)audioURL
        completion:(void (^)(BOOL success, NSURL *mergedURL))completion;

/** 将 WebP 转换为 GIF */
+ (void)convertWebpToGifSafely:(NSURL *)webpURL completion:(void (^)(NSURL *gifURL, BOOL success))completion;

/** 将 HEIC/HEIF 转换为 GIF */
+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion;

#pragma mark - Public Color Scheme Methods (公共颜色方案方法)

/**
 * 递归为视图及其所有子视图中的 UILabel 和 UIButton 应用文本颜色。
 * @param excludeBlock 返回 YES 的视图跳过，可为 nil。
 */
+ (void)applyTextColorRecursively:(UIColor *)color inView:(UIView *)view shouldExcludeViewBlock:(BOOL (^)(UIView *subview))excludeBlock;

/**
 * 通过修改 attributedText 将颜色方案应用到 UILabel，实现像素级渐变。
 * @param colorHexString 方案字符串（均可带 # 前缀）：
 *        - rainbow: 七色彩虹固定渐变（红橙黄绿青蓝紫）
 *        - rainbow_rotating: 七色彩虹，每次调用旋转起始色
 *        - random_gradient: 每次调用随机生成三色渐变
 *        - random: 每次调用随机单色
 *        - HEX1,HEX2,...: 任意数量十六进制色的多色渐变
 *        - HEX: 单色
 */
+ (void)applyColorSettingsToLabel:(UILabel *)label colorHexString:(NSString *)colorHexString;
+ (void)applyStrokeToLabel:(UILabel *)label strokeColor:(UIColor *)strokeColor strokeWidth:(CGFloat)strokeWidth;
+ (void)applyShadowToLabel:(UILabel *)label shadow:(NSShadow *)shadow;

/**
 * 按颜色方案返回 UIColor，用于 UILabel.textColor 等需要 UIColor 的场景；方案用法见 applyColorSettingsToLabel。
 * 单色/随机色直接返回；渐变色渲染成 1px 高、targetWidth 宽的图案图。解析失败返回白色。
 */
+ (UIColor *)colorFromSchemeHexString:(NSString *)hexString targetWidth:(CGFloat)targetWidth;

/**
 * 按颜色方案返回 CALayer，可作 mask 或直接作子层；方案用法见 applyColorSettingsToLabel。
 * 纯色/随机色返回已设置 backgroundColor 的 CALayer，渐变色返回 CAGradientLayer；解析失败或 frame 无效返回 nil。
 */
+ (CALayer *)layerFromSchemeHexString:(NSString *)hexString frame:(CGRect)frame;

#pragma mark - Debug Utilities (调试工具)

/**
 * 递归 dump 所有 UIWindow 视图树到 filePath（后台线程写入），沙盒环境自动 fallback 到 Documents。
 * 输出类名、地址、frame、alpha、hidden、userInteractionEnabled、accessibilityLabel、tag、UILabel.text，便于定位未知视图。
 */
+ (void)dumpAllWindowsViewTreeToFile:(NSString *)filePath;

#pragma mark - Version Utilities

/** 按点分格式比较版本号（如 36.5.0），返回 NSOrderedAscending / NSOrderedDescending / NSOrderedSame。 */
+ (NSComparisonResult)compareVersion:(NSString *)lhs toVersion:(NSString *)rhs;

@end

#pragma mark - External C Functions (外部 C 函数)

#ifdef __cplusplus
extern "C" {
#endif

/** 清除分享URL中的查询参数 */
NSString *_Nullable cleanShareURL(NSString *_Nullable url);

/** 获取当前显示的顶层视图控制器 */
UIViewController *_Nullable topView(void);

/** 在视图控制器层级中查找指定类的控制器 */
UIViewController *_Nullable findViewControllerOfClass(UIViewController *_Nullable rootVC, Class _Nullable targetClass);

/** 根据设置应用顶栏透明度 */
void applyTopBarTransparency(UIView *_Nullable topBar);

/** 递归将任意对象转换为 JSON 可序列化对象 */
id DYYYJSONSafeObject(id _Nullable obj);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
