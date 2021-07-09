//
//  WYVideoFx.h
//  customvideofx
//
//  Created by 王俨 on 2018/5/8.
//  Copyright © 2018年 cdv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import <UIKit/UIKit.h>

@interface WYVideoFx : NSObject

@property (nonatomic, assign) CGFloat translateX;
@property (nonatomic, assign) CGFloat translateY;

@property (nonatomic, assign) CGPoint touchePoint;
@property (nonatomic, assign) BOOL isParticle;


- (void)particleRender ;

@end
