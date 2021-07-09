//
//  ViewController.m
//  02-OpenGL视频播放
//
//  Created by 王俨 on 2018/5/13.
//  Copyright © 2018年 https://github.com/wangyansnow. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "WYOpenGLView.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoDataOutput;

@property (nonatomic, weak) WYOpenGLView *glView;

@property (nonatomic, weak) UIView *faceView;

@end

@implementation ViewController {
    dispatch_queue_t _videoQueue;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self setupCaptureSession];
}

- (void)setupUI {
    
    WYOpenGLView *glView = [[WYOpenGLView alloc] initWithFrame:self.view.bounds];
    [self.view insertSubview:glView atIndex:0];
    self.glView = glView;
    
    UIView *faceView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    faceView.layer.borderWidth = 1;
    faceView.layer.borderColor = [UIColor redColor].CGColor;
    [self.view addSubview:faceView];
    
    self.faceView = faceView;
}

- (void)setupCaptureSession {
    self.captureSession = [AVCaptureSession new];
    self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *videoInputDevice;
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            videoInputDevice= device;
            break;
        }
    }
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoInputDevice error:nil];
    
    if ([self.captureSession canAddInput:self.captureDeviceInput]) {
        [self.captureSession addInput:self.captureDeviceInput];
    }
    
    self.captureVideoDataOutput = [AVCaptureVideoDataOutput new];
    self.captureVideoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    
    self.captureVideoDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    _videoQueue = dispatch_queue_create("video process", DISPATCH_QUEUE_SERIAL);
    [self.captureVideoDataOutput setSampleBufferDelegate:self queue:_videoQueue];
    
    if ([self.captureSession canAddOutput:self.captureVideoDataOutput]) {
        [self.captureSession addOutput:self.captureVideoDataOutput];
    }
    
    // 10.实时人脸检测
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    if ([_captureSession canAddOutput:metadataOutput]) {
        [_captureSession addOutput:metadataOutput];
    }
    metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];

    
    [self.captureSession startRunning];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    NSLog(@"[Wing] point = %@", NSStringFromCGPoint(point));
    self.glView.videoFx.touchePoint = point;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    NSLog(@"[Wing] point = %@", NSStringFromCGPoint(point));
    point = [self glPoint:point];
    self.glView.videoFx.touchePoint = point;
}

#pragma mark - AVCaptureMetadataObjectOutputDelegate
//- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
//
//    if (metadataObjects.count == 0) return;
//
//    AVMetadataObject *metadata = metadataObjects[0];
//
//    CGFloat SCREEN_W = self.view.bounds.size.width;
//    CGFloat SCREEN_H = self.view.bounds.size.height;
//
//    CGFloat x = metadata.bounds.origin.x;
//    CGFloat y = metadata.bounds.origin.y;
//    CGFloat w = metadata.bounds.size.width;
//    CGFloat h = metadata.bounds.size.height;
//
//    x = SCREEN_W * x;
//    y = SCREEN_H * y;
//    w = SCREEN_W * w;
//    h = SCREEN_H * h;
//
//    self.faceView.frame = CGRectMake(x, y, w, h);
//
//    CGPoint point = [self glPoint:CGPointMake(x + 0.5 * w, y + 0.5 * h)];
//    self.glView.videoFx.touchePoint = point;
//}

- (CGPoint)glPoint:(CGPoint)point {
    CGFloat halfW = self.view.bounds.size.width * 0.5;
    CGFloat halfH = self.view.bounds.size.height * 0.5;
    
    CGFloat newX = (point.x - halfW) / halfW;
    CGFloat newY = (halfH - point.y) / halfH;
    
    return CGPointMake(newX, newY);
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CFRetain(sampleBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        [self.glView displayPixelBuffer:pixelBuffer];
        CFRelease(sampleBuffer);
    });
}

@end

