#version 330 core

in vec2 textureCoord;

out vec4 FragColor;

uniform sampler2D texture1;
uniform sampler2D texture2;

void main()
{
    vec4 color1 = texture(texture1, textureCoord);
    vec4 color2 = texture(texture2, textureCoord);
    FragColor = color1 + color2;
}