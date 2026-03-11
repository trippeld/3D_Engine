#version 450

layout(push_constant) uniform PushConstants {
    mat4 view_proj;
    mat4 model;
} pc;

layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec3 in_color;

layout(location = 0) out vec3 frag_color;

void main() {
    frag_color = in_color;
    gl_Position = pc.view_proj * pc.model * vec4(in_pos, 1.0);
}
