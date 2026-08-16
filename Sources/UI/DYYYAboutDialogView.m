#import "DYYYAboutDialogView.h"
#import "DYYYUtils.h"

static void DYYYApplyLinkForAllOccurrences(NSMutableAttributedString *attributedString, NSString *needle, NSString *url) {
    if (needle.length == 0 || url.length == 0) {
        return;
    }
    NSString *text = attributedString.string;
    NSRange searchRange = NSMakeRange(0, text.length);
    while (searchRange.length > 0) {
        NSRange found = [text rangeOfString:needle options:0 range:searchRange];
        if (found.location == NSNotFound) {
            break;
        }
        [attributedString addAttribute:NSLinkAttributeName value:url range:found];
        NSUInteger nextLocation = NSMaxRange(found);
        searchRange = NSMakeRange(nextLocation, text.length - nextLocation);
    }
}

@implementation DYYYAboutDialogView

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message {
    if (self = [super initWithFrame:UIScreen.mainScreen.bounds]) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];

        // 判断当前深色/浅色模式
        BOOL isDarkMode = [DYYYUtils isDarkMode];

        // 创建模糊效果视图 - 根据模式调整效果样式
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight]];
        self.blurView.frame = self.bounds;
        self.blurView.alpha = isDarkMode ? 0.3 : 0.2;
        [self addSubview:self.blurView];

        // 按实际排版宽度计算正文高度，让关于页可以一次展示完
        UIFont *messageFont = [UIFont systemFontOfSize:15];
        UIEdgeInsets messageInsets = UIEdgeInsetsMake(0, 2, 8, 2);
        CGFloat lineFragmentPadding = 5.0;
        CGFloat messageWidth = 260;
        CGFloat usableTextWidth = messageWidth - messageInsets.left - messageInsets.right - lineFragmentPadding * 2.0;
        CGSize constraintSize = CGSizeMake(usableTextWidth, CGFLOAT_MAX);
        NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:message attributes:@{NSFontAttributeName : messageFont}];
        CGRect textRect = [attributedMessage boundingRectWithSize:constraintSize options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];

        CGFloat textHeight = ceil(CGRectGetHeight(textRect)) + messageInsets.top + messageInsets.bottom;
        CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
        CGFloat titleHeight = 44;
        CGFloat buttonHeight = 58;
        CGFloat buttonPadding = 28;
        CGFloat maxTextHeight = MIN(520, MAX(360, screenHeight - 160 - titleHeight - buttonHeight - buttonPadding));
        CGFloat actualTextHeight = MIN(textHeight, maxTextHeight);
        CGFloat contentHeight = titleHeight + actualTextHeight + buttonHeight + buttonPadding;
        BOOL needsScrolling = textHeight > maxTextHeight;

        // 创建内容视图 - 根据模式选择背景色
        self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, contentHeight)];
        self.contentView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        self.contentView.backgroundColor = [DYYYUtils douyinPanelBackgroundColor];
        self.contentView.layer.cornerRadius = 12;
        self.contentView.layer.masksToBounds = YES;
        [self addSubview:self.contentView];

        // 标题 - 根据模式调整文本颜色
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 260, 24)];
        self.titleLabel.text = title;
        self.titleLabel.textColor =
            isDarkMode ? [UIColor colorWithRed:230 / 255.0 green:230 / 255.0 blue:235 / 255.0 alpha:1.0] : [UIColor colorWithRed:45 / 255.0 green:47 / 255.0 blue:56 / 255.0 alpha:1.0];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
        [self.contentView addSubview:self.titleLabel];

        // 消息内容 - 适配深色模式
        self.messageTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 54, 260, (contentHeight - buttonHeight - 54))];
        self.messageTextView.backgroundColor = self.contentView.backgroundColor;
        self.messageTextView.font = messageFont;
        self.messageTextView.editable = NO;
        self.messageTextView.scrollEnabled = needsScrolling;
        self.messageTextView.showsVerticalScrollIndicator = needsScrolling;
        self.messageTextView.dataDetectorTypes = UIDataDetectorTypeLink;
        self.messageTextView.selectable = YES;
        self.messageTextView.textContainerInset = messageInsets;
        self.messageTextView.textContainer.lineFragmentPadding = lineFragmentPadding;

        // 正文左对齐，便于阅读多行致谢与链接列表
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentLeft;
        self.messageTextView.textAlignment = NSTextAlignmentLeft;
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:message];
        [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, message.length)];
        [attributedString addAttribute:NSFontAttributeName
                                 value:messageFont  // 使用自定义的 messageFont
                                 range:NSMakeRange(0, message.length)];

        // 根据模式设置整体文本颜色
        UIColor *messageTextColor =
            isDarkMode ? [UIColor colorWithRed:180 / 255.0 green:180 / 255.0 blue:185 / 255.0 alpha:1.0] : [UIColor colorWithRed:124 / 255.0 green:124 / 255.0 blue:130 / 255.0 alpha:1.0];
        [attributedString addAttribute:NSForegroundColorAttributeName value:messageTextColor range:NSMakeRange(0, message.length)];

        DYYYApplyLinkForAllOccurrences(attributedString, @"@huamidev", @"https://t.me/huamidev");
        DYYYApplyLinkForAllOccurrences(attributedString, @"@vita_app", @"https://t.me/vita_app");
        DYYYApplyLinkForAllOccurrences(attributedString, @"@VexLabs1", @"https://t.me/VexLabs1");
        DYYYApplyLinkForAllOccurrences(attributedString, @"huami1314/DYYY", @"https://github.com/huami1314/DYYY");
        DYYYApplyLinkForAllOccurrences(attributedString, @"Wtrwx/DYYY", @"https://github.com/Wtrwx/DYYY");
        DYYYApplyLinkForAllOccurrences(attributedString, @"VexCove/DYYY", @"https://github.com/VexCove/DYYY");
        self.messageTextView.attributedText = attributedString;

        // 设置链接颜色
        self.messageTextView.linkTextAttributes = @{
            NSForegroundColorAttributeName : [UIColor colorWithRed:11 / 255.0 green:223 / 255.0 blue:154 / 255.0 alpha:1.0],  // #0BDF9A 链接颜色保持不变
            NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)
        };

        [self.contentView addSubview:self.messageTextView];

        // 添加内容和按钮之间的分割线，调整位置和颜色
        UIView *contentButtonSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, contentHeight - buttonHeight, 300, 0.5)];
        contentButtonSeparator.backgroundColor = [DYYYUtils douyinSeparatorColor];
        [self.contentView addSubview:contentButtonSeparator];

        // 确认按钮 - 根据模式调整颜色
        self.confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.confirmButton.frame = CGRectMake(0, contentHeight - buttonHeight + 0.5, 300, 53);
        self.confirmButton.backgroundColor = [UIColor clearColor];
        [self.confirmButton setTitle:@"确定" forState:UIControlStateNormal];
        UIColor *confirmButtonColor =
            isDarkMode ? [UIColor colorWithRed:230 / 255.0 green:230 / 255.0 blue:235 / 255.0 alpha:1.0] : [UIColor colorWithRed:45 / 255.0 green:47 / 255.0 blue:56 / 255.0 alpha:1.0];
        [self.confirmButton setTitleColor:confirmButtonColor forState:UIControlStateNormal];
        [self.confirmButton addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.confirmButton];
        [DYYYUtils prepareModalOverlayView:self contentView:self.contentView];
    }
    return self;
}

- (void)show {
    UIWindow *window = [DYYYUtils getActiveWindow];
    if (!window) {
        window = UIApplication.sharedApplication.windows.firstObject;
    }
    if (!window) {
        return;
    }
    [window addSubview:self];

    [DYYYUtils animateModalOverlayViewIn:self contentView:self.contentView completion:nil];
}

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

- (void)dismissWithCompletion:(void (^)(void))completion {
    [DYYYUtils animateModalOverlayViewOut:self
                             contentView:self.contentView
                              completion:^(__unused BOOL finished) {
                                [self removeFromSuperview];
                                if (completion) {
                                    completion();
                                }
                              }];
}

- (void)confirmTapped {
    void (^confirmAction)(void) = [self.onConfirm copy];
    [self dismissWithCompletion:^{
      if (confirmAction) {
          confirmAction();
      }
    }];
}

@end
