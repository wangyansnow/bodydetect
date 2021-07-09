precision mediump float;

varying highp vec2 varyingTexCoord;

uniform sampler2D samplerY;
uniform sampler2D samplerUV;
uniform mat3 colorConversionMatrix;

void main() {
    
    mediump vec3 yuv;
    lowp vec3 rgb;
    
    // Subtract constants to map the video range start at 0
    yuv.x = (texture2D(samplerY, varyingTexCoord).r);
    yuv.yz = (texture2D(samplerUV, varyingTexCoord).ra - vec2(0.5, 0.5));
    
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb, 1);
}
