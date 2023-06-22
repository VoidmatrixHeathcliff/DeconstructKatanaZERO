#version 330 core

in vec2 textureCoord;

out vec4 FragColor;

uniform sampler2D textureSrc;

const float threshold_min = 0.059;
const float threshold_max = 0.3333;

void main()
{
    vec4 srcColor = texture(textureSrc, textureCoord);
    float max_val = max(max(srcColor.r, srcColor.g), srcColor.b);
    float alpha_val = 0;
    if (max_val <= threshold_min)
        alpha_val = 1;
    else if (max_val >= threshold_max)
        alpha_val = 0;
    else
        alpha_val = (pow(threshold_max, 2) - pow(max_val, 2)) / (pow(threshold_max, 2) - pow(threshold_min, 2));
    FragColor = vec4(srcColor.rgb, alpha_val);
}