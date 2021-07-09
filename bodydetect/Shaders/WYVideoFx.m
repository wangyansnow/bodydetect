//
//  WYVideoFx.m
//  customvideofx
//
//  Created by 王俨 on 2018/5/8.
//  Copyright © 2018年 cdv. All rights reserved.
//

#import "WYVideoFx.h"
#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

typedef struct {
    GLKVector2 wy_position;
    GLKVector3 wy_color;
    GLKVector2 wy_velocity;
    GLfloat    wy_flag;
    GLKVector2 wy_emissionTimeAndLife;
}WYParticle;

@implementation WYVideoFx {
    GLuint _program;
    
    GLuint _positionSlot;
    GLuint _texCoordinateSlot;
    GLuint _colorMapSlot;
    GLuint _flagSlot;
    GLuint _colorSlot;
    GLuint _currentTimeSlot;
    GLuint _emissionTimeAndLifeSlot;
    GLuint _velocitySlot;
    
    GLuint _wyTexture;
    GLuint _modelviewMatrixSlot;
    GLKMatrix4 _modelviewMatrix;
    
    NSMutableData *_particleData;
    
    CFAbsoluteTime _startTime;
    CFAbsoluteTime _endTime;
    
    GLfloat _elapsedTime;
    GLfloat _lastTime;
    GLfloat _lifeSpan;
    
    BOOL _isUpdate;
}

#pragma mark - 粒子效果
- (void)particleRender {
    
//    if (!_isParticle && (CFAbsoluteTimeGetCurrent() - _endTime) > _lifeSpan) {
//        NSLog(@"早就结束了");
//        return;
//    }
    
    if (![self prepareShaderProgram]) {
        return;
    }
    
    glUseProgram(_program);
    _elapsedTime = CFAbsoluteTimeGetCurrent() - _startTime;
    
    if (0.01 < (_elapsedTime - _lastTime) && _isParticle) {
        _lastTime = _elapsedTime;
        _lifeSpan = 1.0;
        
        for (int i = 0; i < 150; i++) {
            float randomXVelocity = (-0.5f + (float)random() / RAND_MAX) / 3.0f;
            float randomYVelocity = (-0.5f + (float)random() / RAND_MAX) / 3.0f;
            
            float r = (float)random() / RAND_MAX;
            float g = (float)random() / RAND_MAX;
            float b = (float)random() / RAND_MAX;
            
            WYParticle particle;
            particle.wy_position = GLKVector2Make(_touchePoint.x, _touchePoint.y);
            particle.wy_color = GLKVector3Make(r, g, b);
            particle.wy_flag = 0;
            particle.wy_emissionTimeAndLife = GLKVector2Make(_elapsedTime, _lifeSpan);
            particle.wy_velocity = GLKVector2Make(randomXVelocity, randomYVelocity);
            
            [self wy_addParticle:particle];
        }
    }
    GLubyte *pointer = (GLubyte *)[_particleData bytes];
    GLsizei stride = sizeof(WYParticle);
    // 1.位置
    glVertexAttribPointer(_positionSlot, 2, GL_FLOAT, GL_FALSE, stride, pointer + offsetof(WYParticle, wy_position));
    glEnableVertexAttribArray(_positionSlot);
    
    // 2.颜色
    glVertexAttribPointer(_colorSlot, 3, GL_FLOAT, GL_FALSE, stride, pointer + offsetof(WYParticle, wy_color));
    glEnableVertexAttribArray(_colorSlot);
    
    // 3.flag
    glVertexAttribPointer(_flagSlot, 1, GL_FLOAT, GL_FALSE, stride, pointer + offsetof(WYParticle, wy_flag));
    glEnableVertexAttribArray(_flagSlot);
    
    // 4.发射时间和时长
    glVertexAttribPointer(_emissionTimeAndLifeSlot, 2, GL_FLOAT, GL_FALSE, stride, pointer + offsetof(WYParticle, wy_emissionTimeAndLife));
    glEnableVertexAttribArray(_emissionTimeAndLifeSlot);
    
    // 5.速度
    glVertexAttribPointer(_velocitySlot, 2, GL_FLOAT, GL_FALSE, stride, pointer + offsetof(WYParticle, wy_velocity));
    glEnableVertexAttribArray(_velocitySlot);
    
    glUniform1fv(_currentTimeSlot, 1, &_elapsedTime);
    
    int count = (int)(_particleData.length / sizeof(WYParticle));
    glDrawArrays(GL_POINTS, 0, count);
    
    glDisableVertexAttribArray(_emissionTimeAndLifeSlot);
    glDisableVertexAttribArray(_velocitySlot);
    glDisableVertexAttribArray(_positionSlot);
    glDisableVertexAttribArray(_texCoordinateSlot);
    glDisableVertexAttribArray(_flagSlot);
}

- (void)wy_addParticle:(WYParticle)newParticle {
    
    NSUInteger count = _particleData.length / sizeof(WYParticle);
    BOOL isFind = NO;
    for (int i = 0; i < count; i++) {
        WYParticle *particles = [_particleData mutableBytes];
        WYParticle oldParticle = particles[i];
        if (_elapsedTime - oldParticle.wy_emissionTimeAndLife.x > oldParticle.wy_emissionTimeAndLife.y) { //生命已结束
            particles[i] = newParticle;
            isFind = YES;
            _isUpdate = YES;
            break;
        }
    }
    
    if (!isFind) {
        [_particleData appendBytes:&newParticle length:sizeof(newParticle)];
        _isUpdate = YES;
    }
}

- (void)wy_render {
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _wyTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    
    static int i = 0;
    
    CGImageRef imgRef;
    if (i % 3 == 0) {
        imgRef = [UIImage imageNamed:@"face.png"].CGImage;
    } else {
        imgRef = [UIImage imageNamed:@"for_test.png"].CGImage;
    }
    i++;
    
    size_t width = CGImageGetWidth(imgRef);
    size_t height = CGImageGetHeight(imgRef);
    
    GLbyte *data = malloc(sizeof(GLbyte) * width * height * 4);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imgRef);
    
    CGContextRef contextRef = CGBitmapContextCreate(data, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imgRef);
    CGContextRelease(contextRef);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    free(data);
    
    GLfloat vertices2[] = {
        -0.25, 0.25,   0, 0,     0.0,  // 左上
        -0.25, -0.25,  0, 1,     0.0,  // 左下
        0.25, 0.25,    1, 0,     0.0,  // 右上
        0.25, -0.25,   1, 1,     0.0,  // 右下
    };
    
    const GLbyte *pointer2 = (const GLbyte*)vertices2;
    
    glVertexAttribPointer(_positionSlot, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, pointer2);
    glEnableVertexAttribArray(_positionSlot);
    glVertexAttribPointer(_texCoordinateSlot, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, pointer2 + sizeof(GLfloat) * 2);
    glEnableVertexAttribArray(_texCoordinateSlot);
    glVertexAttribPointer(_flagSlot, 1, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, pointer2 + sizeof(GLfloat) * 4);
    glEnableVertexAttribArray(_flagSlot);
    
    glUniformMatrix4fv(_modelviewMatrixSlot, 1, GL_FALSE, _modelviewMatrix.m);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

#pragma mark - Program
- (void)loadTexture {
    CGImageRef imgRef = [UIImage imageNamed:@"for_test.png"].CGImage;
    size_t width = CGImageGetWidth(imgRef);
    size_t height = CGImageGetHeight(imgRef);
    
    GLbyte *data = malloc(sizeof(GLbyte) * width * height * 4);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imgRef);
    
    CGContextRef contextRef = CGBitmapContextCreate(data, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imgRef);
    CGContextRelease(contextRef);
    
    
    glGenTextures(1, &_wyTexture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _wyTexture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    free(data);
}


- (BOOL)prepareShaderProgram {
    if (_program) return YES;
    
    _program = [self createProgramWithVertex:@"particle_Vertex.glsl" fragment:@"particle_Fragment.glsl"];
    
    return YES;
}

- (GLuint)createProgramWithVertex:(NSString *)vertex fragment:(NSString *)fragment {
    GLuint vertexShader = [self loadShader:vertex type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self loadShader:fragment type:GL_FRAGMENT_SHADER];
    
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
        NSLog(@"link program: %d error: %s \n", program, msg);
        exit(1);
    }
    
    glUseProgram(program);
    
    _positionSlot = glGetAttribLocation(program, "position");
    _texCoordinateSlot = glGetAttribLocation(program, "texCoordinate");
    _colorMapSlot = glGetUniformLocation(program, "colorMap");
    _flagSlot = glGetAttribLocation(program, "flag");
    _modelviewMatrixSlot = glGetUniformLocation(program, "modelviewMatrix");
    _modelviewMatrix = GLKMatrix4MakeTranslation(0, 0, 0);
    _colorSlot = glGetAttribLocation(program, "color");
    _currentTimeSlot = glGetUniformLocation(program, "currentTime");
    _emissionTimeAndLifeSlot = glGetAttribLocation(program, "emissionTimeAndLife");
    _velocitySlot = glGetAttribLocation(program, "velocity");
    
    [self loadTexture];
    
    GLuint wyTextureSlot = glGetUniformLocation(program, "wyTexture");
    glUniform1i(_colorMapSlot, 0);
    glUniform1i(wyTextureSlot, 1);
    
    _startTime = CFAbsoluteTimeGetCurrent();
    _particleData = [NSMutableData new];
    
    return program;
}

- (GLuint)loadShader:(NSString *)shaderName type:(GLenum)type {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:shaderName ofType:nil];
    NSString *shaderStr = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    GLuint shader = glCreateShader(type);
    const char *shaderStrChar = [shaderStr UTF8String];
    glShaderSource(shader, 1, &shaderStrChar, NULL);
    glCompileShader(shader);
    
    GLint compileSucc;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSucc);
    if (compileSucc == GL_FALSE) {
        GLchar msg[256];
        glGetShaderInfoLog(shader, sizeof(msg), NULL, &msg[0]);
        NSLog(@"compile shader: %@, error: %s \n", shaderName, msg);
        exit(1);
    }
    
    return shader;
}

#pragma mark - setter
- (void)setTranslateX:(CGFloat)translateX {
    _translateX = translateX;
    
    _modelviewMatrix = GLKMatrix4Translate(_modelviewMatrix, translateX, 0, 0);
}

- (void)setTranslateY:(CGFloat)translateY {
    _translateY = translateY;
    
    _modelviewMatrix = GLKMatrix4Translate(_modelviewMatrix, 0, translateY, 0);
}

- (void)setIsParticle:(BOOL)isParticle {
    _isParticle = isParticle;
    
    if (!isParticle) {
        _endTime = CFAbsoluteTimeGetCurrent();
    }
}

@end
