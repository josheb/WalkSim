
// NOTE: Shader automatically converted from Godot Engine 4.0.stable's PanoramaSkyMaterial.

shader_type sky;
render_mode use_debanding;

uniform float rayleigh : hint_range(0, 64) = 2.0;
uniform vec4 rayleigh_color : source_color = vec4(0.3, 0.405, 0.6, 1.0);
uniform float mie : hint_range(0, 1) = 0.005;
uniform float mie_eccentricity : hint_range(-1, 1) = 0.8;
uniform vec4 mie_color : source_color = vec4(0.69, 0.729, 0.812, 1.0);

uniform float turbidity : hint_range(0, 1000) = 10.0;
uniform float sun_disk_scale : hint_range(0, 360) = 1.0;
uniform vec4 ground_color : source_color = vec4(0.1, 0.07, 0.034, 1.0);
uniform float exposure : hint_range(0, 128) = 1.0;

const vec3 UP = vec3( 0.0, 1.0, 0.0 );
const float rayleigh_zenith_size = 8.4e3;
const float mie_zenith_size = 1.25e3;

uniform sampler2D source_panorama : filter_linear, source_color, hint_default_black;
uniform sampler2D clouds_texture: filter_linear_mipmap;
uniform sampler2D clouds_distort_texture: filter_linear_mipmap;
uniform sampler2D clouds_noise_texture: filter_linear_mipmap;

uniform vec3 clouds_main_color: source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 clouds_edge_color: source_color = vec3(1.0, 1.0, 1.0);
uniform float clouds_speed: hint_range(0.0, 0.5, 0.01);
uniform float clouds_scale: hint_range(0.0, 1.0, 0.01);
uniform float clouds_cutoff: hint_range(0.0, 1.0, 0.01);
uniform float clouds_fuzziness: hint_range(0.0, 1.0, 0.01);

uniform vec3 moon_col: source_color = vec3(1.0);
uniform float moon_size: hint_range(0.01, 1.0) = 1.0;
uniform sampler2D moon_texture: filter_linear, source_color, hint_default_black;

float henyey_greenstein(float cos_theta, float g) {
	const float k = 0.0795774715459;
	return k * (1.0 - g * g) / (pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5));
}

// Image projection functions
// https://github.com/godotengine/godot-proposals/issues/3534

float map(float value, float inMin, float inMax, float outMin, float outMax) {
  return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}
 
mat3 rotation3dY(float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return mat3(
    vec3(c, 0.0, -s),
    vec3(0.0, 1.0, 0.0),
    vec3(s, 0.0, c)
  );
}
 
vec4 projImage(float _altitude, float _rot_x, float _viewVec_x, float _imageSize, sampler2D _image) {
    if(_rot_x > _altitude-_imageSize && _rot_x < _altitude+_imageSize){
  	  float xSizeFactor = 2.0*PI;
  	  if(_viewVec_x > -_imageSize*xSizeFactor && _viewVec_x < _imageSize*xSizeFactor){
  		  float v = map(_rot_x-_altitude, -_imageSize, _imageSize, 1.0, 0.0);
  		  float u = map(_viewVec_x, -_imageSize*xSizeFactor, _imageSize*xSizeFactor, 0.0, 1.0);
 
  		  return texture(_image, vec2(u, v));
  	  }
    }
    return vec4(0.0);
}
 
vec4 skyImageProj(vec3 viewVec, float _rotation, float _altitude, float _imageSize, sampler2D _imageSampler) {
    _altitude = fract(_altitude);
    vec3 _EYEDIR = rotation3dY(_rotation) * viewVec;
    //Since we applied the rotation directly to the viewVec we can just ingore it from now on.
 
    //float rot_z = atan(_EYEDIR.y, _EYEDIR.x)/(2.0*PI)+0.5;
    float rot_x = atan(_EYEDIR.y, _EYEDIR.z)/(2.0*PI)+0.5;
    //float rot_y = atan(_EYEDIR.z, _EYEDIR.x)/(2.0*PI)+0.5;
 
    vec4 result = projImage(_altitude, rot_x, _EYEDIR.x, _imageSize, _imageSampler);
 
    //make sure the image isn't clipped when altitude approaches the max/min values
	if(_altitude > 0.75) {
  	  result = max(result, projImage(_altitude-1.0, rot_x, _EYEDIR.x, _imageSize, _imageSampler));
    } else if (_altitude < 0.25) {
  	  result = max(result, projImage(_altitude+1.0, rot_x, _EYEDIR.x, _imageSize, _imageSampler));
    }
	
	//result = max(result, projImage(_altitude, rot_x, _EYEDIR.x, _imageSize, _imageSampler));

    return result;
}
// - End of image projection functions

void sky() {
	vec2 sky_uv = EYEDIR.xz / EYEDIR.y;
	float day_amount = clamp(LIGHT0_DIRECTION.y, 0.0, 1.0);
	float night_amount = clamp(1.0 - day_amount, 0.0, 1.0);
	
	float clouds_movement = TIME * clouds_speed * 0.5;
	float clouds_base_noise = texture(clouds_texture, (sky_uv + clouds_movement ) * clouds_scale).r;
	float noise1 = texture(clouds_distort_texture, (sky_uv + clouds_base_noise + (clouds_movement * 0.75)) * clouds_scale).r;
	float noise2 = texture(clouds_noise_texture, (sky_uv + noise1 + (clouds_movement * 0.25)) * clouds_scale).r;
	
	float clouds_noise_value = clamp(noise1 * noise2, 0.0, 1.0) * clamp(EYEDIR.y, 0.0, 1.0);
	
	float clouds_value = clamp(smoothstep(clouds_cutoff, clouds_cutoff + clouds_fuzziness, clouds_noise_value), 0.0, 1.0);
	
	vec3 clouds = mix(clouds_edge_color,  clouds_main_color , clouds_value) * clouds_value;
	
	float clouds_negative = 1.0 - clouds_value;

	float zenith_angle = clamp( dot(UP, normalize(LIGHT0_DIRECTION)), -1.0, 1.0 );
	float sun_energy = max(0.0, 1.0 - exp(-((PI * 0.5) - acos(zenith_angle)))) * LIGHT0_ENERGY;
	float sun_fade = 1.0 - clamp(1.0 - exp(LIGHT0_DIRECTION.y), 0.0, 1.0);

	// Rayleigh coefficients.
	float rayleigh_coefficient = rayleigh - ( 1.0 * ( 1.0 - sun_fade ) );
	vec3 rayleigh_beta = rayleigh_coefficient * rayleigh_color.rgb * 0.0001;
	// mie coefficients from Preetham
	vec3 mie_beta = turbidity * mie * mie_color.rgb * 0.000434;

	// Optical length.
	float zenith = acos(max(0.0, dot(UP, EYEDIR)));
	float optical_mass = 1.0 / (cos(zenith) + 0.15 * pow(93.885 - degrees(zenith), -1.253));
	float rayleigh_scatter = rayleigh_zenith_size * optical_mass;
	float mie_scatter = mie_zenith_size * optical_mass;

	// Light extinction based on thickness of atmosphere.
	vec3 extinction = exp(-(rayleigh_beta * rayleigh_scatter + mie_beta * mie_scatter));

	// In scattering.
	float cos_theta = dot(EYEDIR, normalize(LIGHT0_DIRECTION));

	float rayleigh_phase = (3.0 / (16.0 * PI)) * (1.0 + pow(cos_theta * 0.5 + 0.5, 2.0));
	vec3 betaRTheta = rayleigh_beta * rayleigh_phase;

	float mie_phase = henyey_greenstein(cos_theta, mie_eccentricity);
	vec3 betaMTheta = mie_beta * mie_phase;

	vec3 Lin = pow(sun_energy * ((betaRTheta + betaMTheta) / (rayleigh_beta + mie_beta)) * (1.0 - extinction), vec3(1.5));
	// Hack from https://github.com/mrdoob/three.js/blob/master/examples/jsm/objects/Sky.js
	Lin *= mix(vec3(1.0), pow(sun_energy * ((betaRTheta + betaMTheta) / (rayleigh_beta + mie_beta)) * extinction, vec3(0.5)), clamp(pow(1.0 - zenith_angle, 5.0), 0.0, 1.0));

	// Hack in the ground color.
	Lin  *= mix(ground_color.rgb, vec3(1.0), smoothstep(-0.1, 0.1, dot(UP, EYEDIR)));

	// Solar disk and out-scattering.
	float sunAngularDiameterCos = cos(LIGHT0_SIZE * sun_disk_scale);
	float sunAngularDiameterCos2 = cos(LIGHT0_SIZE * sun_disk_scale*0.5);
	float sundisk = smoothstep(sunAngularDiameterCos, sunAngularDiameterCos2, cos_theta);
	vec3 L0 = (sun_energy * extinction) * sundisk * LIGHT0_COLOR;

	float moon_distance = distance(EYEDIR.xyz, -LIGHT0_DIRECTION);
	float moon_power = 1.0 - clamp(moon_distance / moon_size, 0.0, 1.0);
	float moon_disc = clamp(moon_power / 0.01, moon_power, 1.0);
	
	vec2 moon_uv = vec2(1.0 * moon_disc, 1.0 * moon_disc);
	
	vec3 moon = clamp( (moon_col * moon_disc), 0.0 , 1.0);
	vec3 panorama = texture(source_panorama, SKY_COORDS).rgb * clamp(night_amount - 0.4, 0.0, 1.0);
	
	if(moon.r > 0.0 || moon.g > 0.0 || moon.b > 0.0) {
		moon = texture(moon_texture, moon_uv).rgb;
		moon = ((moon.rgb * 0.5) + (clouds.rgb * 0.5) - panorama);
	}

	// altitude appears to be 0.0-1.0
	
	vec4 imp = skyImageProj(EYEDIR, LIGHT0_DIRECTION.x, degrees(LIGHT0_DIRECTION.y) * 0.0027777, 0.02, moon_texture);
	vec3 color = Lin + L0;
	COLOR = pow(color, vec3(1.0 / (1.2 + (1.2 * sun_fade)))) * exposure;
	COLOR += panorama + moon + clouds + imp.rgb;
	//COLOR += (texture(source_panorama, SKY_COORDS).rgb * night_amount) + clouds;
}
