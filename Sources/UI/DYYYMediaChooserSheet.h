#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** 底部选项弹窗的单个条目。 */
@interface DYYYMediaChooserItem : NSObject

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) void (^handler)(void);

+ (instancetype)itemWithTitle:(NSString *)title handler:(void (^)(void))handler;

@end

/**
 * 可滚动的底部选项弹窗。
 *
 * 抖音自带的 AWEUserActionSheetView 会把所有行一次铺开，行数多时（图集可达上百张）
 * 顶部条目会被推出屏幕且无法滚动。这里用 UITableView 承载条目：行少时高度自适应，
 * 超出上限后固定为窗口高度的一半并可滚动，「取消」固定在底部不参与滚动。
 *
 * 整体是一张卡片，从条目区一直盖到屏幕底部，条目区与「取消」之间只有一条浅色
 * 分隔带，中间与底部都不留缝。
 */
@interface DYYYMediaChooserSheet : UIView

/** 条目为空时不展示。 */
+ (void)showWithItems:(NSArray<DYYYMediaChooserItem *> *)items;

@end

NS_ASSUME_NONNULL_END
