//
//  ViewController.m
//  wyliehu
//
//  Created by 王俨 on 2018/7/3.
//  Copyright © 2018年 https://github.com/wangyansnow. All rights reserved.
//

#import "ViewController.h"
#import "algo.h"

#define DET_FREQUENCY 3

@interface ViewController ()

@property (nonatomic, weak) UIImageView *imageView;

@end

@implementation ViewController {
    AlgoHumanKeypoints *_humanKeyPoint;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString* strRFCN = [[NSBundle mainBundle] pathForResource:@"facehandbody_c63a.iml" ofType:@"mobile"];
    NSString* strPAF = [[NSBundle mainBundle] pathForResource:@"humankeypoint_3efb.iml" ofType:@"mobile"];
    _humanKeyPoint = [[AlgoHumanKeypoints alloc] initWithModel:strRFCN openposeModel:strPAF frequency:DET_FREQUENCY];
}


@end
