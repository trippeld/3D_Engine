#version 450

layout(push_constant) uniform PushConstants {
    mat4 view_proj;
    mat4 model;
    vec3 camera_pos;
    float _padding0;
    vec3 base_color;
    float _padding1;
} pc;

layout(location = 0) in vec3 frag_normal;
layout(location = 1) in vec3 frag_world_pos;

layout(location = 0) out vec4 out_color;

void main() {
    vec3 normal = normalize(frag_normal);
    vec3 light_dir = normalize(vec3(0.6, 0.8, 0.4));
    vec3 view_dir = normalize(pc.camera_pos - frag_world_pos);
    vec3 half_dir = normalize(light_dir + view_dir);

    float ndotl = max(dot(normal, light_dir), 0.0);

    float ambient = 0.12;
    float diffuse = ndotl;

    float specular = 0.0;
    if (ndotl > 0.0) {
        specular = pow(max(dot(normal, half_dir), 0.0), 24.0);
    }

    vec3 base = pc.base_color * (ambient + diffuse * 0.88);
    vec3 spec = vec3(1.0) * (specular * 0.22);

    out_color = vec4(base + spec, 1.0);
}
