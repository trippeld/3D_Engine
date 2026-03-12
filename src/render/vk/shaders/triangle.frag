#version 450

layout(push_constant) uniform PushConstants {
    mat4 view_proj;
    mat4 model;
    vec4 camera_pos;
    vec4 base_color;
    vec4 material_params;
    vec4 light_pos;
    vec4 light_color;
} pc;

layout(location = 0) in vec3 frag_normal;
layout(location = 1) in vec3 frag_world_pos;

layout(location = 0) out vec4 out_color;

void main() {
    float specular_strength = pc.material_params.x;
    float shininess = pc.material_params.y;
    float unlit = pc.material_params.z;

    if (unlit > 0.5) {
        out_color = vec4(pc.base_color.xyz, 1.0);
        return;
    }

    vec3 normal = normalize(frag_normal);

    vec3 light_vector = pc.light_pos.xyz - frag_world_pos;
    float light_distance = length(light_vector);
    vec3 light_dir = normalize(light_vector);

    vec3 view_dir = normalize(pc.camera_pos.xyz - frag_world_pos);
    vec3 half_dir = normalize(light_dir + view_dir);

    float ndotl = max(dot(normal, light_dir), 0.0);

    float attenuation = 1.0 / (1.0 + 0.09 * light_distance + 0.032 * light_distance * light_distance);

    // Hemisphere ambient
    vec3 sky_color = vec3(0.35, 0.40, 0.50);
    vec3 ground_color = vec3(0.18, 0.16, 0.14);
    float hemi_factor = normal.y * 0.5 + 0.5;
    vec3 hemi_ambient = mix(ground_color, sky_color, hemi_factor) * 0.35;

    float diffuse = ndotl * attenuation;

    float specular = 0.0;
    if (ndotl > 0.0) {
        specular = pow(max(dot(normal, half_dir), 0.0), shininess) * attenuation;
    }

    vec3 light_tint = pc.light_color.xyz;

    vec3 ambient = pc.base_color.xyz * hemi_ambient;
    vec3 direct = pc.base_color.xyz * diffuse * light_tint;
    vec3 spec = light_tint * (specular * specular_strength);

    out_color = vec4(ambient + direct + spec, 1.0);
}
