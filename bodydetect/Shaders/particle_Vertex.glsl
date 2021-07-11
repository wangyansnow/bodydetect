attribute vec2 position;
attribute vec4 inputTextureCoordinate;

attribute lowp float flag;
attribute vec4 color;

// 粒子效果所需参数
attribute vec2 velocity; // 速度
attribute vec2 emissionTimeAndLife; // 发射时间和生命
uniform highp float currentTime;  // 当前时间

varying vec2 textureCoordinate;
varying lowp float renderFlag;
varying vec4 outColor;
varying highp float elapsedTime;
varying highp float life;

void main() {
    
    renderFlag = flag;
    textureCoordinate = inputTextureCoordinate.xy;
    
    if (renderFlag == 1.0) { // 自定的点
        elapsedTime = currentTime - emissionTimeAndLife.x; // 流逝时间
        life = emissionTimeAndLife.y;
        
        vec2 deltaP = elapsedTime * velocity;
        vec2 wy_position = position + deltaP;
                
        gl_Position =  vec4(wy_position, 0.0, 1.0);
        lowp float opacity = max(((emissionTimeAndLife.y - elapsedTime) / emissionTimeAndLife.y), 0.0);
        
        outColor = color;
        gl_PointSize = 20.0 * opacity;
        
    } else {
        
        gl_Position = vec4(position, 0.0, 1.0);
        
    }
}
