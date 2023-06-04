#version 330 core

in vec2 textureCoord;

out vec4 FragColor;

uniform sampler2D textureMask;  // 光照蒙版纹理

uniform vec3 color;             // 环境光颜色
uniform float strength;         // 环境光强度

void main()
{
    vec4 maskColor = texture(textureMask, textureCoord);
    FragColor = vec4(maskColor.a * color * strength, maskColor.a);
}