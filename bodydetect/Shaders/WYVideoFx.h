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

@property (nonatomic, assign) CGPoint leftHandPoint;
@property (nonatomic, assign) CGPoint rightHandPoint;
@property (nonatomic, assign) BOOL isParticle;

- (void)particleRender ;

@end
