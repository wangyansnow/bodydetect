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
#import "algo.h"

#define DET_FREQUENCY 3

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoDataOutput;

@property (nonatomic, weak) WYOpenGLView *glView;

@property (nonatomic, weak) UIView *faceView;
@property (nonatomic, assign) BOOL isTouch;


@end

@implementation ViewController {
    dispatch_queue_t _videoQueue;
    
    AVCaptureDevicePosition devicePosition;
    AlgoHumanKeypoints* _humanKeyPoint;
    CGFloat _previewImageWidth;
    CGFloat _previewImageHeight;
    CGFloat _imageOnPreviewScale;
    pthread_mutex_t mutex;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
    [self setupCaptureSession];
    [self initFaceDetect];
}

- (void)initFaceDetect {
    NSString* strRFCN = [[NSBundle mainBundle] pathForResource:@"facehandbody_b387.iml" ofType:@"mobile"];
    NSString* strPAF = [[NSBundle mainBundle] pathForResource:@"humankeypoint_473d.iml" ofType:@"mobile"];
    _humanKeyPoint = [[AlgoHumanKeypoints alloc] initWithModel:strRFCN openposeModel:strPAF frequency:DET_FREQUENCY];
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
    
    devicePosition = AVCaptureDevicePositionFront;
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
    
    CGFloat imageWidth = 720;
    CGFloat imageHeight = 1280;
    self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    
    CGFloat previewWidth = self.glView.frame.size.width;
    CGFloat previewHeight = self.glView.frame.size.height;
    
    _imageOnPreviewScale = MAX(previewHeight/imageHeight, previewWidth/imageWidth);
    _previewImageWidth = imageWidth * _imageOnPreviewScale;
    _previewImageHeight = imageHeight * _imageOnPreviewScale;
    
    [self.captureSession startRunning];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    NSLog(@"[Wing] point = %@", NSStringFromCGPoint(point));
    self.glView.videoFx.isParticle = YES;
    self.isTouch = YES;
    point = [self glPoint:point];
    self.glView.videoFx.leftHandPoint = point;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    NSLog(@"[Wing] point = %@", NSStringFromCGPoint(point));
    point = [self glPoint:point];
    self.glView.videoFx.leftHandPoint = point;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.glView.videoFx.isParticle = NO;
    self.isTouch = NO;
}

- (CGPoint)glPoint:(CGPoint)point {
    
    CGFloat screenW = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat screenH = CGRectGetHeight([UIScreen mainScreen].bounds);
    return CGPointMake(point.x * (720 / screenW), point.y * (1280 / screenH));
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CFRetain(sampleBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        [self.glView displayPixelBuffer:pixelBuffer];
        CFRelease(sampleBuffer);
    });
    if (self.isTouch) return;
    [self displaySampleBuffer:sampleBuffer];
}

- (void)displaySampleBuffer:(CMSampleBufferRef)sampleBuffer {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);

        void *baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t iBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        size_t iHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        size_t iWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);

        size_t iTop , iBottom , iLeft , iRight;
        CVPixelBufferGetExtendedPixels(pixelBuffer, &iLeft, &iRight, &iTop, &iBottom);
        iWidth = iWidth + (int)iLeft + (int)iRight;
        iHeight = iHeight + (int)iTop + (int)iBottom;
        
        UIDeviceOrientation iDeviceOrientation = [[UIDevice currentDevice]orientation];
        BOOL isMirror = YES;
        int rotationtype = 0;
        switch (iDeviceOrientation) {
            case UIDeviceOrientationPortrait:
                rotationtype = 1;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                rotationtype = 3;
                break;
            case UIDeviceOrientationLandscapeLeft:
                rotationtype = isMirror ? 2:0;
                break;
            case UIDeviceOrientationLandscapeRight:
                rotationtype = isMirror ? 0:2;
                break;
            default:
                rotationtype = 1;
                break;
        }
        
        NSMutableArray* points = [_humanKeyPoint regress:baseAddress width:(int)iWidth height:(int)iHeight bytesPerRow:(int)iBytesPerRow rotation:rotationtype videoType:VideoType_YUV_NV12];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    if (points.count > 0) {
            Human *human = points[0];
            [human rotation:rotationtype isMirror:YES width:iWidth height:iHeight];

            static const int pose[] = {12, 13,
                3, 4, 5,
                0, 1, 2,
                9, 10, 11,
                6, 7, 8,
            };

            points = [NSMutableArray array];
            for (int i = 0; i < 14; i++) {
                int sv_i = pose[i];

                [points addObject:[NSNumber numberWithFloat:human.keyPointsX[sv_i]]];
                [points addObject:[NSNumber numberWithFloat:human.keyPointsY[sv_i]]];
            }
        }
        
        if (points.count > 0) {
            self.glView.videoFx.isParticle = YES;
            CGFloat leftX = [points[8] floatValue];
            CGFloat leftY = [points[9] floatValue];

            CGFloat rightX = [points[14] floatValue];
            CGFloat rightY = [points[15] floatValue];
            
            if (leftX > 0 && leftY > 0) {
                self.glView.videoFx.leftHandPoint = CGPointMake(leftX, leftY);
            }
            if (rightX > 0 && rightY > 0) {
                self.glView.videoFx.rightHandPoint = CGPointMake(rightX, rightY);
            }
        } else {
            if (!self.isTouch) {
                self.glView.videoFx.isParticle = NO;
            }
        }
}

@end

