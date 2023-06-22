#version 330 core

in vec2 textureCoord;

out vec4 FragColor;

uniform sampler2D textureSrc;

const float threshold = 0.5;

void main()
{
    vec4 srcColor = texture(textureSrc, textureCoord);
    float max_val = max(max(srcColor.r, srcColor.g), srcColor.b);
    float alpha_val = srcColor.a;
    if (max_val >= threshold)
        alpha_val = 0;
    else
        alpha_val = 1 - max_val * (1 / threshold);
    FragColor = vec4(srcColor.rgb, alpha_val);
}