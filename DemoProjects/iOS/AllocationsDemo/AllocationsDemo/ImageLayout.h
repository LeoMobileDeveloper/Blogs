//
//  ImageLayout.h
//  TimeProfilerDemo
//
//  Created by Leo on 2018/6/20.
//  Copyright © 2018年 Leo Huang. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ImageLayoutDelegate<NSObject>

- (CGSize)imageSizeForItemAtIndex:(NSIndexPath *)indexPath;

@end

@interface ImageLayout : UICollectionViewLayout

@property (weak, nonatomic) id<ImageLayoutDelegate> delegate;

@property (assign, nonatomic) CGFloat itemWidth;

@end
