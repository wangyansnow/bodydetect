precision mediump float;

varying highp vec2 varyingTexCoord;

uniform sampler2D samplerY;
uniform sampler2D samplerUV;
uniform mat3 colorConversionMatrix;
const highp vec3 W = vec3(0.299,0.587,0.114);
vec2 blurCoordinates[20];

float hardLight(float color)
{
    if(color <= 0.5)
        color = color * color * 2.0;
    else
        color = 1.0 - ((1.0 - color)*(1.0 - color) * 2.0);
    return color;
}
void main(){
    vec2 singleStepOffset = vec2(1.0/720.0, 1.0/1280.0);
    
    lowp vec3 rgb;
    rgb = texture2D(samplerY, varyingTexCoord).rgb;
    rgb = vec4(rgb.b, rgb.g, rgb.r, 1).rgb;
    vec3 centralColor = rgb;
    
    blurCoordinates[0] = varyingTexCoord.xy + singleStepOffset * vec2(0.0, -10.0);
    blurCoordinates[1] = varyingTexCoord.xy + singleStepOffset * vec2(0.0, 10.0);
    blurCoordinates[2] = varyingTexCoord.xy + singleStepOffset * vec2(-10.0, 0.0);
    blurCoordinates[3] = varyingTexCoord.xy + singleStepOffset * vec2(10.0, 0.0);
    blurCoordinates[4] = varyingTexCoord.xy + singleStepOffset * vec2(5.0, -8.0);
    blurCoordinates[5] = varyingTexCoord.xy + singleStepOffset * vec2(5.0, 8.0);
    blurCoordinates[6] = varyingTexCoord.xy + singleStepOffset * vec2(-5.0, 8.0);
    blurCoordinates[7] = varyingTexCoord.xy + singleStepOffset * vec2(-5.0, -8.0);
    blurCoordinates[8] = varyingTexCoord.xy + singleStepOffset * vec2(8.0, -5.0);
    blurCoordinates[9] = varyingTexCoord.xy + singleStepOffset * vec2(8.0, 5.0);
    blurCoordinates[10] = varyingTexCoord.xy + singleStepOffset * vec2(-8.0, 5.0);
    blurCoordinates[11] = varyingTexCoord.xy + singleStepOffset * vec2(-8.0, -5.0);
    blurCoordinates[12] = varyingTexCoord.xy + singleStepOffset * vec2(0.0, -6.0);
    blurCoordinates[13] = varyingTexCoord.xy + singleStepOffset * vec2(0.0, 6.0);
    blurCoordinates[14] = varyingTexCoord.xy + singleStepOffset * vec2(6.0, 0.0);
    blurCoordinates[15] = varyingTexCoord.xy + singleStepOffset * vec2(-6.0, 0.0);
    blurCoordinates[16] = varyingTexCoord.xy + singleStepOffset * vec2(-4.0, -4.0);
    blurCoordinates[17] = varyingTexCoord.xy + singleStepOffset * vec2(-4.0, 4.0);
    blurCoordinates[18] = varyingTexCoord.xy + singleStepOffset * vec2(4.0, -4.0);
    blurCoordinates[19] = varyingTexCoord.xy + singleStepOffset * vec2(4.0, 4.0);
    float sampleColor = centralColor.g * 20.0;
    sampleColor += texture2D(samplerY, blurCoordinates[0]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[1]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[2]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[3]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[4]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[5]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[6]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[7]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[8]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[9]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[10]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[11]).g;
    sampleColor += texture2D(samplerY, blurCoordinates[12]).g * 2.0;
    sampleColor += texture2D(samplerY, blurCoordinates[13]).g * 2.0;
    sampleColor += texture2D(samplerY, blurCoordinates[14]).g * 2.0;
    sampleColor += texture2D(samplerY, blurCoordinates[15]).g * 2.0;
    sampleColor += texture2D(samplerY, blurCoordinates[16]).g * 2.0;
    sampleColor += texture2D(samplerY, blurCoordinates[17]).g * 2.0;
    sampleColor += texture2D(samplerY, blurCoordinates[18]).g * 2.0;
    sampleColor += texture2D(samplerY, blurCoordinates[19]).g * 2.0;
    sampleColor = sampleColor / 48.0;
    float highPass = centralColor.g - sampleColor + 0.5;
    for(int i = 0; i < 5;i++)
    {
        highPass = hardLight(highPass);
    }
    float luminance = dot(centralColor, W);
    float alpha = pow(luminance, 0.8); // 修改0.3调整磨皮效果
    vec3 smoothColor = centralColor + (centralColor-vec3(highPass))*alpha*0.1;
    
    if (gl_FragCoord.x < 540.0) { // 左边部分
        gl_FragColor = gl_FragColor = vec4(mix(smoothColor.rgb, max(smoothColor, centralColor), alpha), 1.0);
    } else { // 右边部分
        gl_FragColor = vec4(centralColor, 1);
    }
    
    gl_FragColor = gl_FragColor = vec4(mix(smoothColor.rgb, max(smoothColor, centralColor), alpha), 1.0);
    
}
