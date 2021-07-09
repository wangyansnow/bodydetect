
varying mediump vec2 varyTexCoordinate;
varying lowp float renderFlag;
varying lowp vec4 outColor;

uniform sampler2D colorMap;
uniform sampler2D wyTexture;

void main() {
    
    if (renderFlag == 1.0) {
        gl_FragColor = texture2D(colorMap, varyTexCoordinate);
    } else {
        gl_FragColor = outColor;
    }
}
