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

typedef enum {
    OUTPUT_240p = 0,
    OUTPUT_288p = 1,
    OUTPUT_480p = 2,
    OUTPUT_540p = 3,
    OUTPUT_720p = 4,
    OUTPUT_1080p = 5,
} OutputPresent;
static OutputPresent defaultOutPresent = OUTPUT_1080p;

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoDataOutput;

@property (nonatomic, weak) WYOpenGLView *glView;

@property (nonatomic, weak) UIView *faceView;


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
    
    OutputPresent outPresent = OUTPUT_720p;
    if(outPresent > OUTPUT_720p && AVCaptureDevicePositionFront == devicePosition) {
        outPresent = OUTPUT_720p;
    }
    CGFloat imageWidth = 1080;
    CGFloat imageHeight = 1920;
    switch(outPresent)
    {
        case OUTPUT_480p:
        {
            self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
            imageWidth = 480;
            imageHeight = 640;
            break;
        }
        case OUTPUT_720p:
        {
            self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
            imageWidth = 720;
            imageHeight = 1280;
            break;
        }
        case OUTPUT_1080p:
        {
            self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
            imageWidth = 1080;
            imageHeight = 1920;
            break;
        }
    }
    
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
    self.glView.videoFx.touchePoint = point;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    NSLog(@"[Wing] point = %@", NSStringFromCGPoint(point));
    point = [self glPoint:point];
    self.glView.videoFx.touchePoint = point;
}

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
            CGFloat leftX = [points[4 * 2] floatValue];
            CGFloat leftY = [points[4 * 2 + 1] floatValue];

    //        CGFloat rightX = [points[KEWLBodyPointRightHand * 2] floatValue];
    //        CGFloat rightY = [points[KEWLBodyPointRightHand * 2 + 1] floatValue];
    //        particleFilter.leftHandPoint = CGPointMake(leftX, leftY);
    //        particleFilter.rightHandPoint = CGPointMake(rightX, rightY);
            self.glView.videoFx.touchePoint = [self convertDanceOffPoint:CGPointMake(leftX, leftY)];
        } else {
            self.glView.videoFx.isParticle = NO;
        }

}

- (CGPoint)convertDanceOffPoint:(CGPoint)point {
    CGFloat x =  point.x;
    CGFloat y =  point.y;
    
//    CGFloat halfW = SCREEN_WIDTH * 0.5;
//    CGFloat halfH = SCREEN_HEIGHT * 0.5;
    
    CGFloat halfW = 720 * 0.5;
    CGFloat halfH = 1280 * 0.5;
    
    CGFloat normalX = (x - halfW) / halfW;
    CGFloat normalY = (halfH - y) / halfH;
    
    CGPoint glPoint = CGPointMake(normalX, normalY);
    
    return glPoint;
}

@end

