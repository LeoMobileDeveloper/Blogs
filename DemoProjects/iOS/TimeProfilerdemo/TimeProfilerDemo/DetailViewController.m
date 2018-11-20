//
//  DetailViewController.m
//  TimeProfilerDemo
//
//  Created by Leo on 2018/6/20.
//  Copyright © 2018年 Leo Huang. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController ()

@property (strong, nonatomic) UIImageView * imageView;

@property (strong, nonatomic) UIImage * image;

@property (strong, nonatomic) UIImage * filterImage;

@end

@implementation DetailViewController

- (instancetype)initWithImage:(UIImage *)image{
    if (self = [super init]) {
        _image = image;
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Detail";
    self.view.backgroundColor = [UIColor whiteColor];
    self.imageView.frame = self.view.bounds;
    [self.view addSubview:self.imageView];
    self.imageView.image = self.image;
}

- (UIImageView *)imageView{
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _imageView;
}

@end
