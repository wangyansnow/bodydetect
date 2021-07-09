//
//  WYOpenGLView.h
//  02-OpenGL视频播放
//
//  Created by 王俨 on 2018/5/14.
//  Copyright © 2018年 https://github.com/wangyansnow. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WYVideoFx.h"

@interface WYOpenGLView : UIView

@property (nonatomic, assign) BOOL isFullYUVRange;
@property (nonatomic, strong) WYVideoFx *videoFx;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
