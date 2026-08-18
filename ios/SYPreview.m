#import "SYPreview.h"

@interface SYPreviewController () <UIScrollViewDelegate>
@property (nonatomic, copy) NSArray<UIImage *> *images;
@property (nonatomic, assign) NSInteger startIndex;
@property (nonatomic, strong) UIScrollView *pager;
@property (nonatomic, strong) UILabel *indexLabel;
@property (nonatomic, assign) CGSize lastPagerSize;
@end

@implementation SYPreviewController

- (instancetype)initWithImages:(NSArray<UIImage *> *)images
                    startIndex:(NSInteger)startIndex {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _images = [images copy] ?: @[];
        NSInteger last = (NSInteger)_images.count - 1;
        _startIndex = last < 0 ? 0 : MIN(MAX(startIndex, 0), last);
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    UIScrollView *pager = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    pager.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    pager.pagingEnabled = YES;
    pager.showsHorizontalScrollIndicator = NO;
    pager.delegate = self;
    pager.backgroundColor = UIColor.blackColor;
    if (@available(iOS 11.0, *)) {
        pager.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:pager];
    self.pager = pager;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:close];

    UILabel *indexLabel = [[UILabel alloc] init];
    indexLabel.textColor = UIColor.whiteColor;
    indexLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    indexLabel.textAlignment = NSTextAlignmentCenter;
    indexLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:indexLabel];
    self.indexLabel = indexLabel;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [close.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [close.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [indexLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [indexLabel.centerYAnchor constraintEqualToAnchor:close.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(closeTapped)];
    [self.view addGestureRecognizer:tap];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (CGSizeEqualToSize(self.pager.bounds.size, self.lastPagerSize)) {
        return;
    }
    self.lastPagerSize = self.pager.bounds.size;
    [self rebuildPages];
}

- (void)rebuildPages {
    for (UIView *child in [self.pager.subviews copy]) {
        [child removeFromSuperview];
    }

    CGSize size = self.pager.bounds.size;
    if (size.width <= 0 || size.height <= 0) {
        return;
    }

    self.pager.contentSize = CGSizeMake(size.width * self.images.count, size.height);
    [self.images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {
        UIImageView *page = [[UIImageView alloc] initWithFrame:CGRectMake(size.width * idx, 0, size.width, size.height)];
        page.contentMode = UIViewContentModeScaleAspectFit;
        page.image = image;
        page.userInteractionEnabled = YES;
        [self.pager addSubview:page];
    }];

    self.pager.contentOffset = CGPointMake(size.width * self.startIndex, 0);
    [self refreshIndexLabel];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self refreshIndexLabel];
}

- (void)refreshIndexLabel {
    if (self.images.count == 0) {
        self.indexLabel.text = @"";
        return;
    }
    CGFloat width = self.pager.bounds.size.width;
    NSInteger page = width > 0 ? (NSInteger)llround(self.pager.contentOffset.x / width) : self.startIndex;
    page = MIN(MAX(page, 0), (NSInteger)self.images.count - 1);
    self.indexLabel.text = [NSString stringWithFormat:@"%ld / %lu", (long)(page + 1), (unsigned long)self.images.count];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
