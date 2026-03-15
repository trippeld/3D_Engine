#version 450

layout(push_constant) uniform PushConstants {
    mat4 view_proj;
    mat4 model;
    vec3 camera_pos;
    float _padding0;
    vec3 base_color;
    float _padding1;
} pc;

layout(location = 0) in vec3 in_pos;
layout(location = 1) in vec3 in_normal;

layout(location = 0) out vec3 frag_normal;
layout(location = 1) out vec3 frag_world_pos;

void main() {
    vec4 world_pos = pc.model * vec4(in_pos, 1.0);
    frag_world_pos = world_pos.xyz;

    mat3 normal_matrix = transpose(inverse(mat3(pc.model)));
    frag_normal = normalize(normal_matrix * in_normal);

    gl_Position = pc.view_proj * world_pos;
}
