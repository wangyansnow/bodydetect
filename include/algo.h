#ifndef _NATIVE_LIB_H_
#define _NATIVE_LIB_H_

#import <UIKit/UIKit.h>

#define FACE_POINT_NUM       106
#define HUMAN_KEYPOINTS_NUM       14

const static char* gestureText[] = {"handheart", "blowkiss", "rock", "thumb", "fist","palm", "victory", "up", "gongshou", "paishou", "heshi", "OK", "bixin", "shenshou", "down", "left", "right", "xiachui", "nohand"};

typedef enum {
    VideoType_Album = 0,
    VideoType_YUV_NV12 = 1,
    VideoType_BGRA = 2,
} videoType;

//-------------------structure---------------------
@interface HumanRect : NSObject
@property (nonatomic)float  x1;
@property (nonatomic)float  x2;
@property (nonatomic)float  y1;
@property (nonatomic)float  y2;
@property (nonatomic)int    type;
@property (nonatomic)float  score;
- (void)scale:(float)ratio;
- (void)rotation:(int)rotation isMirror:(BOOL)isMirror width:(float)width height:(float)height;
@end

@interface FacePoints : HumanRect 
{
    float _position[4];
    float _pointX[FACE_POINT_NUM];
    float _pointY[FACE_POINT_NUM];
}
- (float*)position;
- (float*)pointX;
- (float*)pointY;

- (void)scale:(float)ratio;
- (void)rotation:(int)rotation isMirror:(BOOL)isMirror width:(float)width height:(float)height;
@end

@interface FaceFeature : NSObject
@property (nonatomic, strong) HumanRect* faceRect1;
@property (nonatomic, strong) HumanRect* faceRect2;
@property (nonatomic) float roll;
@property (nonatomic) float yaw;
@property (nonatomic) float pitch;
@property (nonatomic, strong) NSMutableArray *feature;
@end

static const int limb_seq[] = {13, 12, 13, 0, 0, 1, 1, 2, 13, 3, 3, 4, 4, 5, 13, 6, 6, 7, 7, 8, 13, 9, 9, 10, 10, 11};
@interface Human : HumanRect
{
    float _keyPointsX[HUMAN_KEYPOINTS_NUM];
    float _keyPointsY[HUMAN_KEYPOINTS_NUM];
}
- (float*)keyPointsX;
- (float*)keyPointsY;
- (void)scale:(float)ratio;
- (void)rotation:(int)rotation isMirror:(BOOL)isMirror width:(float)width height:(float)height;

@end

//--------------------Algo-------------------------
@interface AlgoGesture : NSObject

- (id)initWithModel:(NSString*)rfcnModel gestureModel:(NSString*)gestureModel;

- (NSMutableArray*)classify:(const char*)data width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow rotation:(int)rotation videoType:(videoType)type; 

- (NSMutableArray*)classifyUIImage:(UIImage*)image;

@end

@interface AlgoFaceKeypoints : NSObject

- (id)initWithModel:(NSString*)rfcnModel modelM:(NSString*)strModelM modelE:(NSString*)strModelE modelN:(NSString*)strModelN;

- (NSMutableArray*)facekeypoint:(const char*)data width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow rotation:(int)rotation videoType:(videoType)type;

@end

@interface AlgoFaceVerify : NSObject

- (id)initWithModel:(NSString*)rfcnModel keyPointModel:(NSString*)keyPointModel resnetModel:(NSString*)resnetModel;
- (FaceFeature*)extract:(UIImage*)image rotation:(int)rotation;

+ (double)distance:(NSArray*)arr1 oldarr:(NSArray*)arr2;

@end

@interface AlgoHumanKeypoints : NSObject

- (id)initWithModel:(NSString*)rfcnModel openposeModel:(NSString*)openposeModel frequency:(int)frequency;

- (NSMutableArray*)regress:(const char*)data width:(int)width height:(int)height bytesPerRow:(int)bytesPerRow rotation:(int)rotation videoType:(videoType)type;

@end

#endif //_NATIVE_LIB_H_
