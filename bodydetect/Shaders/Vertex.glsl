
attribute vec4 position;
attribute vec2 texCoord;
uniform mat4 modelviewMatrix;

varying vec2 varyingTexCoord;

void main() {
    gl_Position = modelviewMatrix * position;
    varyingTexCoord = texCoord;
}
