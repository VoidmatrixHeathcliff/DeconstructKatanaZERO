#version 330 core

in vec2 textureCoord;

out vec4 FragColor;

uniform sampler2D textureBackgound; // 背景图片纹理
uniform sampler2D textureLight;     // 光照贴图纹理
uniform sampler2D textureNormal;    // 背景法线纹理

uniform vec3 ambientColor;			// 环境光颜色
uniform float ambientStrength;		// 环境光强度

void main()
{
    vec4 backgorundColor = texture(textureBackgound, textureCoord);
    vec4 lightColor = texture(textureLight, textureCoord);
    vec4 normalColor = texture(textureNormal, textureCoord);
    vec4 afterAmbientColor = vec4(backgorundColor.rgb * ambientColor * ambientStrength, 1);
    FragColor = afterAmbientColor + vec4(lightColor.rgb * lightColor.a * (1 - normalColor.a), 1);
}