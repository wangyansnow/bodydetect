//
//  WYOpenGLView.m
//  02-OpenGL视频播放
//
//  Created by 王俨 on 2018/5/14.
//  Copyright © 2018年 https://github.com/wangyansnow. All rights reserved.
//

#import "WYOpenGLView.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <AVFoundation/AVUtilities.h>
#import <GLKit/GLKit.h>


// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)
// BT.601, which is the standard for SDTV.
static const GLfloat wy_kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat wy_kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const GLfloat wy_kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

@interface WYOpenGLView()

@property (nonatomic, strong) EAGLContext *eaglContext;
@property (nonatomic, strong) CAEAGLLayer *eaglLayer;

@end

@implementation WYOpenGLView {
    GLuint _renderBuffer;
    GLuint _frameBuffer;
    
    GLuint _program;
    
    GLuint _positionSlot;
    GLuint _texCoordSlot;
    GLuint _samplerYSlot;
    GLuint _samplerUVSlot;
    GLuint _colorConversionMatrixSlot;
    GLuint _modelviewMatrixSlot;
    
    CVOpenGLESTextureCacheRef _videoTextureCache;
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    
    const GLfloat *_colorConversion;
    
    GLint _backingWidth;
    GLint _backingHeight;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self setupEAGL];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupEAGL];
    }
    return self;
}

- (void)setupEAGL {
    [self setupContextAndLayer];
    [self setupRenderAndFrameBuffer];
    _program = [self createProgramWithVertex:@"Vertex.glsl" fragment:@"Fragment.glsl"];
    
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.eaglContext, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"CVOpenGLESTextureCacheCreate error: %d", err);
            return;
        }
    }
    
    self.videoFx = [WYVideoFx new];
//    self.videoFx.isParticle = YES;
//    self.videoFx.touchePoint = CGPointMake(0.25, 0.25);
}

- (void)layoutSubviews {
//    [self setupEAGL];
    [self render];
}

- (void)render {
    glClearColor(0, 1, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CGFloat scale = [UIScreen mainScreen].scale;
    glViewport(0, 0, self.frame.size.width * scale, self.frame.size.height * scale);
    
    GLfloat vertices[] = {
        -0.5, 0.5, 0,
        -0.5, -0.5, 0,
        0.5, 0.5, 0,
        0.5, -0.5, 0,
    };
    
    GLuint positionSlot = glGetAttribLocation(_program, "position");
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 3, vertices);
    glEnableVertexAttribArray(positionSlot);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [self.eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (GLuint)createProgramWithVertex:(NSString *)vertex fragment:(NSString *)fragment {
    GLuint vertexShader = [self loadShader:vertex type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self loadShader:fragment type:GL_FRAGMENT_SHADER];
    
    if (vertexShader == -1 || fragmentShader == -1) {
        return -1;
    }
    
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    
    glLinkProgram(program);
    
    GLint linkSucc;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSucc);
    if (linkSucc == GL_FALSE) {
        GLchar msg[256];
        glGetProgramInfoLog(program, sizeof(msg), NULL, &msg[0]);
        NSAssert(false, @"link program: %d, error: %s\n", program, msg);
        return -1;
    }
    glUseProgram(program);
    
    _positionSlot = glGetAttribLocation(program, "position");
    _texCoordSlot = glGetAttribLocation(program, "texCoord");
    _samplerYSlot = glGetUniformLocation(program, "samplerY");
    _samplerUVSlot = glGetUniformLocation(program, "samplerUV");
    _colorConversionMatrixSlot = glGetUniformLocation(program, "colorConversionMatrix");
    _modelviewMatrixSlot = glGetUniformLocation(program, "modelviewMatrix");
    
    glUniform1i(_samplerYSlot, 0);
    glUniform1i(_samplerUVSlot, 1);

    return program;
}

- (GLuint)loadShader:(NSString *)shaderName type:(GLenum)type {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:shaderName ofType:nil];
    NSError *error;
    NSString *shaderStr = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    NSAssert(!error, @"compile shader:%@ error = %@", shaderName, error);
    
    GLuint shader = glCreateShader(type);
    const GLchar *shaderChar = [shaderStr UTF8String];
    glShaderSource(shader, 1, &shaderChar, NULL);
    glCompileShader(shader);
    
    GLint compileSucc;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSucc);
    if (compileSucc == GL_FALSE) {
        GLchar msg[256];
        glGetShaderInfoLog(shader, sizeof(msg), NULL, &msg[0]);
        NSAssert(false, @"compile shader: %@ error: %s\n", shaderName, msg);
        return -1;
    }
    
    return shader;
}

- (void)setupRenderAndFrameBuffer {
    [self destoryRenderAndFrameBuffer];
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    [self.eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
}

- (void)destoryRenderAndFrameBuffer {
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
    
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }
}

- (void)setupContextAndLayer {
    self.eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.eaglContext];
    
    self.eaglLayer = (CAEAGLLayer *)self.layer;
    self.eaglLayer.opaque = YES;
    self.eaglLayer.drawableProperties = @{kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8, kEAGLDrawablePropertyRetainedBacking: @YES};
    self.eaglLayer.contentsScale = [UIScreen mainScreen].scale;
}

#pragma mark - Display pixelBuffer
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) return;
    if (!_videoTextureCache) {
        NSLog(@"videoTextureCache not exist");
        return;
    }
    
    int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    [self cleanUpTextures];
    
    // Use the color attachment of the pixel buffer to determine the appropriate color conversion matrix
    CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
        _colorConversion = self.isFullYUVRange ? wy_kColorConversion601FullRange : wy_kColorConversion601;
    } else {
        _colorConversion = wy_kColorConversion709;
    }
    
    // CVOpenGLESTextureCacheCreateTextureFromImage will create GLES texture optimally from CVPixelBufferRef.
    // Create Y and UV textures from pixel buffer. These textures will drawn on the frame buffer Y-plane.
    CVReturn err;
    glActiveTexture(GL_TEXTURE0);
    
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _videoTextureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, frameWidth, frameHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &_lumaTexture);
    
    if (err) {
        NSLog(@"Y - CVOpenGLESTextureCacheCreateTextureFromImage error:%d", err);
        return;
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    // UV-plane
    glActiveTexture(GL_TEXTURE1);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _videoTextureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, frameWidth * 0.5, frameHeight * 0.5, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &_chromaTexture);
    if (err) {
        NSLog(@"UV - CVOpenGLESTextureCacheCreateTextureFromImage error:%d", err);
        return;
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    glClearColor(1, 1, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(_program);
    
    glUniformMatrix3fv(_colorConversionMatrixSlot, 1, GL_FALSE, _colorConversion);
    
    // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
    CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(_backingWidth, _backingHeight), self.layer.bounds);
    
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(0.0, 0.0);
    CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/self.layer.bounds.size.width, vertexSamplingRect.size.height/self.layer.bounds.size.height);
    
    // Normalize the quad vertices.
    if (cropScaleAmount.width > cropScaleAmount.height) {
        normalizedSamplingSize.width = 1.0;
        normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
    }
    else {
        normalizedSamplingSize.width = 1.0;
        normalizedSamplingSize.height = cropScaleAmount.width/cropScaleAmount.height;
    }
    
    /*
     The quad vertex data defines the region of 2D plane onto which we draw our pixel buffers.
     Vertex data formed using (-1,-1) and (1,1) as the bottom left and top right coordinates respectively, covers the entire screen.
     */
    GLfloat quadVertexData [] = {
        -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
        normalizedSamplingSize.width, normalizedSamplingSize.height,
    };
    
    // 更新顶点数据
    glVertexAttribPointer(_positionSlot, 2, GL_FLOAT, 0, 0, quadVertexData);
    glEnableVertexAttribArray(_positionSlot);
    
    GLfloat quadTextureData[] =  { // 正常坐标
        0, 0,
        1, 0,
        0, 1,
        1, 1
    };
    
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, 0, 0, quadTextureData);
    glEnableVertexAttribArray(_texCoordSlot);
    
    GLKMatrix4 modelviewMatrix = GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(-90));
    glUniformMatrix4fv(_modelviewMatrixSlot, 1, GL_FALSE, modelviewMatrix.m);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [self.videoFx particleRender];
    
    [self.eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)cleanUpTextures {
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    // Periodic texture cache flush every time
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

@end
