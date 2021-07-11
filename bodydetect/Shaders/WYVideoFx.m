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
    GLKVector2 wy_position; // 点的位置
    GLKVector3 wy_color;    // 点的颜色
    GLKVector2 wy_velocity; // 点在x和y方向上的移动速度
    GLfloat    wy_flag;     // 标记是粒子特效的点
    GLKVector2 wy_emissionTimeAndLife; // 粒子发射时间和存活时间
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
    
    GLuint _modelviewMatrixSlot;
    GLKMatrix4 _modelviewMatrix;
    
    NSMutableData *_particleData;
    
    CFAbsoluteTime _startTime;
    CFAbsoluteTime _endTime;
    
    GLfloat _elapsedTime;
    GLfloat _lastTime;
    GLfloat _lifeSpan;
    
    BOOL _isUpdate;
    
    CGPoint _preLeftHandPoint;
    CGPoint _preRightHandPoint;
    
    NSMutableArray *_drawPoints;
    int _frames;
}

#pragma mark - 粒子效果
- (void)particleRender {
    
    if (!_isParticle && (CFAbsoluteTimeGetCurrent() - _endTime) > _lifeSpan) {
//        NSLog(@"早就结束了");
        return;
    }
    
    if (![self prepareShaderProgram]) {
        return;
    }
    
    glUseProgram(_program);
    _elapsedTime = CFAbsoluteTimeGetCurrent() - _startTime;
        
    if (_isParticle) {
        _lastTime = _elapsedTime;
        _lifeSpan = 1.0;
        NSArray *tempArr = [self wy_points];
        for (NSValue *value in tempArr) {
            CGPoint point = [value CGPointValue];
            int count = 10;
            
            for (int i = 0; i < count; i++) {
                float randomXVelocity = (-0.5f + (float)random() / RAND_MAX);
                float randomYVelocity = (-0.5f + (float)random() / RAND_MAX);
                
                CGFloat lifeSpan = _lifeSpan;
                if (i > 2) {
                    randomXVelocity = randomXVelocity / 5.0;
                    randomYVelocity = randomYVelocity / 5.0;
                    lifeSpan = lifeSpan * 0.8;
                }
                
                float r = (float)random() / RAND_MAX;
                float g = (float)random() / RAND_MAX;
                float b = (float)random() / RAND_MAX;
                
                WYParticle particle;
                particle.wy_position = GLKVector2Make(point.x, point.y);
                particle.wy_color = GLKVector3Make(r, g, b);
                particle.wy_flag = 1;
                particle.wy_emissionTimeAndLife = GLKVector2Make(_elapsedTime, lifeSpan);
                particle.wy_velocity = GLKVector2Make(randomXVelocity, randomYVelocity);
                
                [self wy_addParticle:particle];
            }
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

#pragma mark - Program
- (BOOL)prepareShaderProgram {
    if (_program) return YES;
    
    _drawPoints = [NSMutableArray array];
    _particleData = [NSMutableData new];
    _startTime = CFAbsoluteTimeGetCurrent();
    _preLeftHandPoint = CGPointMake(-100, -100);
    _preRightHandPoint = _preLeftHandPoint;
    
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
        NSAssert(false, @"link program: %d error: %s \n", program, msg);
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
    glUniform1i(_colorMapSlot, 0);
    
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
        NSAssert(false, @"compile shader: %@, error: %s \n", shaderName, msg);
    }
    
    return shader;
}

#pragma mark - setter

- (void)setIsParticle:(BOOL)isParticle {
    _isParticle = isParticle;
    
    if (!isParticle) {
        _endTime = CFAbsoluteTimeGetCurrent();
        _preLeftHandPoint = CGPointMake(-100, -100);
        _preRightHandPoint = _preLeftHandPoint;
    }
}

- (NSMutableArray<NSValue*> *)generatePoints:(CGPoint)prePoint currentPoint:(CGPoint)currenPoint arr:(NSMutableArray *)arrM {
    
    if (prePoint.x == -100) {
        [arrM addObject:@(currenPoint)];
        return arrM;
    };
    
    CGFloat leftX = currenPoint.x;
    CGFloat leftY = currenPoint.y;
    CGFloat preX = prePoint.x;
    CGFloat preY = prePoint.y;
    
    CGFloat screenW = 720;
    CGFloat screenH = 1280;
    
    CGFloat pointW =  10;
    CGFloat caculate = sqrtf((pointW / screenW) * (pointW / screenW) + (pointW / screenH) * (pointW / screenH));
    CGFloat deltaX = leftX - preX;
    CGFloat deltaY = leftY - preY;

    // 两点之间的距离
    CGFloat distance = sqrtf(deltaX * deltaX + deltaY * deltaY);
    int count = ceilf(distance / caculate);
    
    if (count < 3) {
        [arrM addObject:@(currenPoint)];
        return arrM;
    };
    
    CGFloat addX = 0;
    CGFloat addY = 0;
    for (int i = 0; i < count; i++) {
        addX = preX + (CGFloat)i * deltaX / count;
        addY = preY + (CGFloat)i * deltaY / count;
        CGPoint point = CGPointMake(addX, addY);
        [arrM addObject:@(point)];
    }
    [arrM addObject:@(currenPoint)];
    
    return arrM;
}

- (NSArray<NSValue *> *)wy_points {
    
    NSMutableArray<NSValue *> *arrM = [NSMutableArray arrayWithCapacity:20];
    
    [self generatePoints:_preLeftHandPoint currentPoint:_leftHandPoint arr:arrM];
    [self generatePoints:_preRightHandPoint currentPoint:_rightHandPoint arr:arrM];
    
    _preLeftHandPoint = _leftHandPoint;
    _preRightHandPoint = _rightHandPoint;
    
    return arrM;
}

- (void)setLeftHandPoint:(CGPoint)leftHandPoint {
    _leftHandPoint = [self convertOpenGLPoint:leftHandPoint];
}

- (void)setRightHandPoint:(CGPoint)rightHandPoint {
    _rightHandPoint = [self convertOpenGLPoint:rightHandPoint];
}

- (CGPoint)convertOpenGLPoint:(CGPoint)point {
    CGFloat x =  point.x;
    CGFloat y =  point.y;
    
    CGFloat halfW = 720 * 0.5;
    CGFloat halfH = 1280 * 0.5;
    
    CGFloat normalX = (x - halfW) / halfW;
    CGFloat normalY = (halfH - y) / halfH;
    
    CGPoint glPoint = CGPointMake(normalX, normalY);
    
    return glPoint;
}

@end
