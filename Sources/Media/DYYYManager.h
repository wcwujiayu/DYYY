#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"

// 主题管理类（外部类声明）
@interface AWEUIThemeManager : NSObject
@property(nonatomic, assign) BOOL isLightTheme;
@end

/** DYYY 主管理器：UI、媒体下载、保存与视频合成。 */
@interface DYYYManager : NSObject

#pragma mark - 属性和基础方法
// 存储文件类型
@property(nonatomic, strong) NSMutableDictionary *fileLinks;

/** 获取单例实例 */
+ (instancetype)shared;

#pragma mark - UI相关方法

#pragma mark - 相册说明文字
/**
 * 记录当前作品，之后保存到相册的媒体会带上作者、作者 ID、主页 URL、作品文案、作品 URL 和发布时间说明。
 * 主页和作品 URL 只保留精简网页地址的协议、域名和路径，不写入分享查询参数。
 * 在弹出下载菜单前调用即可；传 nil 表示本次保存不写说明。
 */
+ (void)setAlbumDescriptionContextWithAwemeModel:(AWEAwemeModel *)awemeModel;

/** 按当前作品生成说明文字，取不到任何字段时返回 nil。 */
+ (NSString *)albumDescriptionForAwemeModel:(AWEAwemeModel *)awemeModel;

#pragma mark - 媒体保存方法
/** 保存媒体文件到相册 */
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(BOOL success))completion;

/** 保存媒体文件到相册，并把说明文字写进文件元数据 */
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType albumDescription:(NSString *)albumDescription completion:(void (^)(BOOL success))completion;

/** 保存实况照片 */
- (void)saveLivePhoto:(NSString *)imageSourcePath videoUrl:(NSString *)videoSourcePath;

#pragma mark - 媒体下载方法
/** 下载媒体文件 */
+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType audio:(NSURL *)audioURL completion:(void (^)(BOOL success))completion;

/** 带进度的媒体下载 */
+ (void)downloadMediaWithProgress:(NSURL *)url
                        mediaType:(MediaType)mediaType
                            audio:(NSURL *)audioURL
                         progress:(void (^)(float progress))progressBlock
                       completion:(void (^)(BOOL success, NSURL *fileURL))completion;

/** 下载实况照片 */
+ (void)downloadLivePhoto:(NSURL *)imageURL videoURL:(NSURL *)videoURL completion:(void (^)(void))completion;

/** 批量下载实况照片 */
+ (void)downloadAllLivePhotos:(NSArray<NSDictionary *> *)livePhotos;

/** 带进度的批量实况照片下载 */
+ (void)downloadAllLivePhotosWithProgress:(NSArray<NSDictionary *> *)livePhotos
                                 progress:(void (^)(NSInteger current, NSInteger total))progressBlock
                               completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion;

/**
 * 保存评论区图片（支持普通图片和实况照片）。
 * @param imageModels AWECommentImageModel 数组
 * @param currentIndex 当前图片索引，-1 表示保存全部
 */
+ (void)saveCommentImages:(NSArray *)imageModels
             currentIndex:(NSInteger)currentIndex
               completion:(void (^)(NSInteger successCount, NSInteger livePhotoCount, NSInteger failedCount))completion;

/**
 * 下载并分享评论区语音。
 * @param audioContent 语音内容 JSON 字符串
 * @param createTime 评论创建时间（NSNumber，秒级时间戳）
 */
+ (void)downloadAndShareCommentAudio:(NSString *)audioContent
                            userName:(NSString *)userName
                          createTime:(NSNumber *)createTime;
/** 批量下载图片 */
+ (void)downloadAllImages:(NSMutableArray *)imageURLs;

/** 带进度的批量图片下载 */
+ (void)downloadAllImagesWithProgress:(NSMutableArray *)imageURLs
                             progress:(void (^)(NSInteger current, NSInteger total))progressBlock
                           completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion;

/** 取消所有下载任务 */
+ (void)cancelAllDownloads;

#pragma mark - 视频处理方法
/** 解析分享链接并下载视频 */
+ (void)parseAndDownloadVideoWithShareLink:(NSString *)shareLink apiKey:(NSString *)apiKey;

/** 批量下载视频和图片资源 */
+ (void)batchDownloadResources:(NSArray *)videos images:(NSArray *)images;

/**
 * 从多种媒体源创建视频。
 * @param livePhotos 实况照片数组，每项包含图片和视频URL
 */
+ (void)createVideoFromMedia:(NSArray<NSString *> *)imageURLs
                  livePhotos:(NSArray<NSDictionary *> *)livePhotos
                      bgmURL:(NSString *)bgmURL
                    progress:(void (^)(NSInteger current, NSInteger total, NSString *status))progressBlock
                  completion:(void (^)(BOOL success, NSString *message))completion;

// 动画贴纸和GIF相关方法
+ (void)saveAnimatedSticker:(YYAnimatedImageView *)targetStickerView;

@end
