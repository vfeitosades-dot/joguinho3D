shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform sampler2D mirror_tex : source_color, filter_linear, repeat_disable;
uniform vec3 plane_point;
uniform vec3 plane_normal = vec3(1.0,0.0,0.0);
uniform float strength = 0.6;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex(){
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment(){
	float plane_delta = abs(dot(world_pos-plane_point,plane_normal));
	float face = dot(normalize(world_normal),plane_normal);
	float mask = (1.0-smoothstep(0.045,0.14,plane_delta))*smoothstep(0.55,0.88,face);
	if(mask < 0.005){discard;}
	vec4 reflected = texture(mirror_tex,vec2(1.0-SCREEN_UV.x,SCREEN_UV.y));
	float fresnel = pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),2.0);
	ALBEDO = reflected.rgb*vec3(0.84,0.92,1.0);
	ALPHA = reflected.a*mask*strength*mix(0.44,0.92,fresnel);
}
