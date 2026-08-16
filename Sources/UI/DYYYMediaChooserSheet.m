#import "DYYYMediaChooserSheet.h"
#import "DYYYUtils.h"

static const CGFloat kDYYYChooserRowHeight = 56.0;
static const CGFloat kDYYYChooserCancelHeight = 56.0;
/** 条目区与「取消」之间的分隔带，卡片内部的一条浅色横条。 */
static const CGFloat kDYYYChooserDividerHeight = 8.0;
static const CGFloat kDYYYChooserCornerRadius = 12.0;
/** 卡片高度上限占窗口高度的比例，超出后条目区域改为滚动。 */
static const CGFloat kDYYYChooserMaxHeightRatio = 0.5;

@implementation DYYYMediaChooserItem

+ (instancetype)itemWithTitle:(NSString *)title handler:(void (^)(void))handler {
    DYYYMediaChooserItem *item = [[DYYYMediaChooserItem alloc] init];
    if (item) {
        item->_title = [title copy];
        item->_handler = [handler copy];
    }
    return item;
}

@end

@interface DYYYMediaChooserSheet () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) UIView *dimmingView;
@property(nonatomic, strong) UIView *cardView;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIView *dividerView;
@property(nonatomic, strong) UIButton *cancelButton;
@property(nonatomic, copy) NSArray<DYYYMediaChooserItem *> *items;
@property(nonatomic, assign) BOOL dismissing;

@end

@implementation DYYYMediaChooserSheet

+ (void)showWithItems:(NSArray<DYYYMediaChooserItem *> *)items {
    if (items.count == 0) {
        return;
    }

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self showWithItems:items];
        });
        return;
    }

    UIWindow *window = [DYYYUtils getActiveWindow] ?: UIApplication.sharedApplication.windows.firstObject;
    if (!window) {
        return;
    }

    DYYYMediaChooserSheet *sheet = [[DYYYMediaChooserSheet alloc] initWithItems:items];
    sheet.frame = window.bounds;
    [window addSubview:sheet];
    [sheet layoutIfNeeded];
    [sheet presentAnimated];
}

- (instancetype)initWithItems:(NSArray<DYYYMediaChooserItem *> *)items {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _items = [items copy];
        self.backgroundColor = [UIColor clearColor];
        [self buildSubviews];
        [self applyThemeColors];
    }
    return self;
}

- (void)buildSubviews {
    _dimmingView = [[UIView alloc] init];
    _dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    _dimmingView.alpha = 0.0;
    [self addSubview:_dimmingView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDimmingTap)];
    [_dimmingView addGestureRecognizer:tap];

    // 一张卡片从条目区一直盖到屏幕底部，安全区那段由卡片自己的底色填上，
    // 不再让视频从缝里透出来。
    _cardView = [[UIView alloc] init];
    _cardView.layer.cornerRadius = kDYYYChooserCornerRadius;
    _cardView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    _cardView.clipsToBounds = YES;
    [self addSubview:_cardView];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = kDYYYChooserRowHeight;
    _tableView.separatorInset = UIEdgeInsetsZero;
    _tableView.tableFooterView = [[UIView alloc] init];
    _tableView.showsVerticalScrollIndicator = NO;
    _tableView.alwaysBounceVertical = NO;
    if (@available(iOS 11.0, *)) {
        // 卡片自己处理安全区，交给系统调整会在条目区上下多出空白。
        _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    if (@available(iOS 15.0, *)) {
        _tableView.sectionHeaderTopPadding = 0.0;
    }
    [_cardView addSubview:_tableView];

    _dividerView = [[UIView alloc] init];
    [_cardView addSubview:_dividerView];

    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    _cancelButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
    [_cancelButton addTarget:self action:@selector(handleCancelTap) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_cancelButton];
}

- (void)applyThemeColors {
    UIColor *cardColor = [DYYYUtils douyinPanelBackgroundColor];
    UIColor *textColor = [DYYYUtils isDarkMode] ? [UIColor whiteColor] : [UIColor blackColor];

    self.cardView.backgroundColor = cardColor;
    self.tableView.backgroundColor = cardColor;
    self.tableView.separatorColor = [DYYYUtils douyinSeparatorColor];
    // 分隔带是半透明覆盖色，压在卡片不透明底色上就得到那条浅色横条。
    self.dividerView.backgroundColor = [DYYYUtils douyinInteractiveControlBackgroundColor];
    [self.cancelButton setTitleColor:textColor forState:UIControlStateNormal];
    [self.tableView reloadData];
}

#pragma mark - 布局

- (void)layoutSubviews {
    [super layoutSubviews];

    self.dimmingView.frame = self.bounds;

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat bottomInset = 0.0;
    if (@available(iOS 11.0, *)) {
        bottomInset = self.safeAreaInsets.bottom;
    }

    // 高度按窗口比例算、底部留安全区，各机型自动适配，无需按屏幕尺寸分支。
    CGFloat reservedHeight = kDYYYChooserDividerHeight + kDYYYChooserCancelHeight + bottomInset;
    CGFloat maxCardHeight = height * kDYYYChooserMaxHeightRatio;
    CGFloat maxTableHeight = MAX(kDYYYChooserRowHeight, maxCardHeight - reservedHeight);
    CGFloat naturalTableHeight = kDYYYChooserRowHeight * (CGFloat)self.items.count;
    CGFloat tableHeight = MIN(naturalTableHeight, maxTableHeight);
    self.tableView.scrollEnabled = (naturalTableHeight > tableHeight + 0.5);

    CGFloat cardHeight = tableHeight + reservedHeight;
    CGRect cardFrame = CGRectMake(0.0, height - cardHeight, width, cardHeight);

    // 转场途中卡片带着 transform。此时直接改 frame，UIKit 会按 transform 反推 center，
    // 卡片会先弹回原位再继续动，看起来就是闪一下。先复位再落 frame，最后把 transform 放回去。
    CGAffineTransform activeTransform = self.cardView.transform;
    self.cardView.transform = CGAffineTransformIdentity;
    self.cardView.frame = cardFrame;
    self.cardView.transform = activeTransform;

    self.tableView.frame = CGRectMake(0.0, 0.0, width, tableHeight);
    self.dividerView.frame = CGRectMake(0.0, tableHeight, width, kDYYYChooserDividerHeight);
    self.cancelButton.frame = CGRectMake(0.0, tableHeight + kDYYYChooserDividerHeight, width, kDYYYChooserCancelHeight);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    // 移出窗口时也会走到这里，收起途中重绘会闪一下，所以只在仍然在屏上时才换色。
    if (!self.window || self.dismissing) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self applyThemeColors];
        }
    }
}

#pragma mark - 转场

- (CGFloat)slideOffset {
    return MAX(CGRectGetHeight(self.cardView.bounds), 1.0);
}

- (void)presentAnimated {
    self.cardView.transform = CGAffineTransformMakeTranslation(0.0, [self slideOffset]);

    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.28;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       self.dimmingView.alpha = 1.0;
                       self.cardView.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
}

- (void)dismissAnimatedWithCompletion:(void (^)(void))completion {
    if (self.dismissing) {
        return;
    }
    self.dismissing = YES;
    // 收起过程中不再接受点击，避免连点触发两次下载。
    self.userInteractionEnabled = NO;

    CGFloat offset = [self slideOffset];
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.12 : 0.22;
    [UIView animateWithDuration:duration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          self.dimmingView.alpha = 0.0;
          self.cardView.transform = CGAffineTransformMakeTranslation(0.0, offset);
        }
        completion:^(BOOL finished) {
          [self removeFromSuperview];
          if (completion) {
              completion();
          }
        }];
}

- (void)handleDimmingTap {
    [self dismissAnimatedWithCompletion:nil];
}

- (void)handleCancelTap {
    [self dismissAnimatedWithCompletion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const cellIdentifier = @"DYYYMediaChooserCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }

    DYYYMediaChooserItem *item = self.items[(NSUInteger)indexPath.row];
    cell.textLabel.text = item.title;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.font = [UIFont systemFontOfSize:16.0];
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.textLabel.textColor = [DYYYUtils isDarkMode] ? [UIColor whiteColor] : [UIColor blackColor];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    if ((NSUInteger)indexPath.row >= self.items.count) {
        return;
    }
    void (^handler)(void) = self.items[(NSUInteger)indexPath.row].handler;

    // 先收起弹窗再执行，避免下载进度浮层被弹窗遮住。
    [self dismissAnimatedWithCompletion:^{
      if (handler) {
          handler();
      }
    }];
}

@end
