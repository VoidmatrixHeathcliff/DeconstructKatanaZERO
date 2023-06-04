#version 330 core

in vec2 textureCoord;

out vec4 FragColor;

uniform sampler2D texture1;

uniform vec3 color;
uniform float alpha;

void main()
{
    vec4 textureColor = texture(texture1, textureCoord);
    if (textureColor.a == 0)
        FragColor = vec4(0, 0, 0, 0);
    else
        FragColor = vec4(color, alpha);
}