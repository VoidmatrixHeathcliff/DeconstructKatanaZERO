#version 330 core

in vec2 textureCoord;

out vec4 FragColor;

uniform sampler2D texture1;

uniform float enhance;

void main()
{
    vec4 color = texture(texture1, textureCoord);
    FragColor = color * vec4(enhance, enhance, enhance, 1);
}