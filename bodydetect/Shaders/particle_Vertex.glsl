attribute vec2 position;
attribute vec4 inputTextureCoordinate;

attribute lowp float flag;
attribute vec4 color;

// 粒子效果所需参数
attribute vec2 velocity; // 速度
attribute vec2 emissionTimeAndLife; // 发射时间和生命
uniform highp float currentTime;  // 当前时间
uniform lowp float single; // 是否是单一颜色

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
        
        lowp float deltaDistance = sqrt(deltaP.x * deltaP.x + deltaP.y * deltaP.y);
        
        gl_Position =  vec4(wy_position, 0.0, 1.0);
        lowp float opacity = max(((emissionTimeAndLife.y - elapsedTime) / emissionTimeAndLife.y), 0.0);
        
        if (single == 1.0) {
            outColor = vec4(86.0/255.0, 177.0/255.0, 255.0/255.0, 1.0);
        } else {
            if (deltaDistance < 0.08) {
                outColor = vec4(253.0/255.0, 122.0/255.0, 1.0, 1.0);
            } else if (deltaDistance < 0.20) {
                outColor = vec4(1.0, 160.0/255.0, 108.0/255.0, 1.0);
            } else if (deltaDistance < 0.30) {
                outColor = vec4(1.0, 66.0/255.0, 195.0/255.0, 1.0);
            } else {
                outColor = vec4(66.0/255.0, 1.0, 239.0/255.0, 1.0);
            }
        }
        
        if (opacity < 0.5) {
            opacity = 0.5;
        }
        
        gl_PointSize = 24.0 * opacity;
        
    } else {
        
        gl_Position = vec4(position, 0.0, 1.0);
        
    }
}


