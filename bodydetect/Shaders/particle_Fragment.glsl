varying mediump vec2 textureCoordinate;
uniform sampler2D inputImageTexture;
uniform sampler2D startTexture;

varying lowp float renderFlag;
varying lowp vec4 outColor;
varying highp float elapsedTime;
varying highp float life;

void main() {
    
    if (renderFlag == 1.0) {
        if (elapsedTime > life) {
            discard;
        }
        
        gl_FragColor = outColor * texture2D(startTexture, gl_PointCoord);;
    } else {
        gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
    }
    
}


