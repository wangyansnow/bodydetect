precision highp float;

attribute vec2 position;
attribute vec2 texCoordinate;
attribute lowp float flag;
attribute vec4 color;

// 粒子效果所需参数
attribute vec2 velocity; // 速度
attribute vec2 emissionTimeAndLife; // 发射时间和生命
uniform highp float currentTime;  // 当前时间

varying vec2 varyTexCoordinate;
varying lowp float renderFlag;
varying vec4 outColor;

uniform mat4 modelviewMatrix;

void main() {

    renderFlag = flag;
    varyTexCoordinate = texCoordinate;
    
    if (renderFlag == 1.0) { // 美摄的点，不用动
        gl_Position = vec4(position, 0.0, 1.0);
    } else {

        highp float elapsedTime = currentTime - emissionTimeAndLife.x; // 流逝时间
        vec2 wy_position = position + velocity * elapsedTime;
        
        gl_Position =  vec4(wy_position, 0.0, 1.0);
        lowp float opacity = max(((emissionTimeAndLife.y - elapsedTime) / emissionTimeAndLife.y), 0.0);
        
        outColor = color;
        gl_PointSize = opacity * 10.0;
        
    }
}
