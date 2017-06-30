//
//  ModifiedCaptureImage.h
//  ReceiptCameraOpenCV
//
//  Created by koutalou on 2017/06/29.
//  Copyright © 2017年 koutalou. All rights reserved.
//

#ifdef __cplusplus
#import "opencv2/imgcodecs/ios.h"
#import <opencv2/opencv.hpp>
#endif

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ImageConvertType) {
    grey     = 0x0001,
    edge     = 0x0010,
    greyEdge = 0x0011,
};

@interface ModifiedCaptureImage: NSObject

+ (UIImage *)filterImage:(UIImage *)image;

@end
