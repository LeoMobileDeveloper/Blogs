//
//  ImageLayout.m
//  TimeProfilerDemo
//
//  Created by Leo on 2018/6/20.
//  Copyright © 2018年 Leo Huang. All rights reserved.
//

#import "ImageLayout.h"

@interface ImageLayout()

@property (assign, nonatomic) NSInteger columnCount;

@property (assign, nonatomic) UIEdgeInsets sectionInset;

@property (assign, nonatomic) CGFloat rowSpace;

@property (assign, nonatomic) CGFloat columnSpace;

@property (strong, nonatomic) NSMutableDictionary<NSNumber *,NSNumber *> * maxYDic;

@property (strong, nonatomic) NSMutableArray<UICollectionViewLayoutAttributes *> * attributes;

@end

@implementation ImageLayout

- (instancetype)init{
    if (self = [super init]) {
        _columnCount = 3;
        _sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
        _rowSpace = 2.0;
        _columnSpace = 2.0;
        _maxYDic = [[NSMutableDictionary alloc] init];
        _attributes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)prepareLayout{
    [super prepareLayout];
    [self.maxYDic removeAllObjects];
    [self.attributes removeAllObjects];
    for (NSInteger i = 0; i < self.columnCount; i ++) {
        [self.maxYDic setObject:@(self.sectionInset.top) forKey:@(i)];
    }
    NSInteger count = [self.collectionView numberOfItemsInSection:0];
    for (NSInteger i = 0; i < count; i++) {
        NSIndexPath * indexPath = [NSIndexPath indexPathForItem:i inSection:0];
        UICollectionViewLayoutAttributes * attribtue = [self layoutAttributesForItemAtIndexPath:indexPath];
        [self.attributes addObject:attribtue];
    }
}

- (CGSize)collectionViewContentSize{
    return CGSizeMake(CGRectGetWidth(self.collectionView.frame),
                      [self maxYCollected] + self.sectionInset.bottom);
}

- (NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect{
    return self.attributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat width = [self itemWidth];
    __block CGFloat minY = CGFLOAT_MAX;
    __block NSInteger column = -1;
    [self.maxYDic enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.floatValue < minY) {
            minY = obj.floatValue;
            column = key.integerValue;
        }
    }];
    CGFloat x = column * width + self.rowSpace * column + self.sectionInset.left;
    CGFloat y = minY;
    CGSize imageSize = [self.delegate imageSizeForItemAtIndex:indexPath];
    CGFloat height = imageSize.height / imageSize.width * width;
    UICollectionViewLayoutAttributes * attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.frame = CGRectMake(x, y, width, height);
    [self.maxYDic setObject:@(y+height+self.columnSpace) forKey:@(column)];
    return attributes;
}

#pragma mark - Util

- (CGFloat)itemWidth{
    return (CGRectGetWidth(self.collectionView.frame)
            - self.sectionInset.left
            - self.sectionInset.right
            - self.rowSpace * (self.columnCount - 1)
            ) / self.columnCount;
}

- (CGFloat)maxYCollected{
    __block CGFloat result = CGFLOAT_MIN;
    [self.maxYDic enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.floatValue > result) {
            result = obj.floatValue;
        }
    }];
    return result;
}

@end
