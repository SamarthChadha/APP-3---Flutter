#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uTime;
uniform float uBrightness;
uniform float uTemperature;
uniform sampler2D uTexture;

out vec4 fragColor;

vec3 kelvinToRGB(float kelvin) {
    float temp = kelvin / 100.0;
    vec3 color = vec3(1.0);

    // Simplified color temperature conversion
    if (temp <= 66.0) {
        color.r = 1.0;
        color.g = clamp(0.39 * log(temp) - 0.63, 0.0, 1.0);
    } else {
        color.r = clamp(1.29 * pow(temp - 60.0, -0.13), 0.0, 1.0);
        color.g = clamp(1.29 * pow(temp - 60.0, -0.08), 0.0, 1.0);
    }

    if (temp >= 66.0) {
        color.b = 1.0;
    } else if (temp <= 19.0) {
        color.b = 0.0;
    } else {
        color.b = clamp(0.54 * log(temp - 10.0) - 1.19, 0.0, 1.0);
    }

    return color;
}

void main() {
    // Get normalized screen coordinates
    vec2 screenUV = FlutterFragCoord().xy / uSize;

    // Transform screen coordinates to match lamp UV mapping
    // Center the coordinates and adjust for lamp geometry
    vec2 centeredUV = (screenUV - 0.5) * 2.0;

    // Create a mapping that follows the lamp's cylindrical/conical shape
    // Adjust these parameters to match your lamp model's UV layout
    float radius = length(centeredUV);
    float angle = atan(centeredUV.y, centeredUV.x);

    // Map to UV coordinates that correspond to the lamp model
    // This creates a cylindrical projection suitable for lamp geometry
    vec2 uv = vec2(
        (angle + 3.14159) / (2.0 * 3.14159), // Wrap angle to 0-1
        clamp(0.5 + centeredUV.y * 0.5, 0.0, 1.0) // Vertical mapping
    );

    // Alternative simpler approach - you can uncomment this and comment the above
    // if the cylindrical mapping doesn't work well:
    // vec2 uv = vec2(screenUV.x, 1.0 - screenUV.y); // Simple flip Y

    vec4 texColor = texture(uTexture, uv);

    // Use texture alpha and luminance as a mask to limit emission to model areas only
    float texLuminance = dot(texColor.rgb, vec3(0.299, 0.587, 0.114));
    float modelMask = texColor.a * step(0.1, texLuminance); // Only emit where texture has content

    // Early exit if we're outside the model area
    if (modelMask < 0.01) {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    float emissionMask = texLuminance;

    vec3 lightColor = kelvinToRGB(uTemperature);

    float emissionIntensity = emissionMask * uBrightness * modelMask;
    float pulse = 1.0 + 0.05 * sin(uTime * 2.0);
    emissionIntensity *= pulse;

    vec3 emission = lightColor * emissionIntensity;

    // Simple glow effect without loops - also masked to model areas
    vec2 offset1 = vec2(0.01, 0.0);
    vec2 offset2 = vec2(0.0, 0.01);
    vec2 offset3 = vec2(-0.01, 0.0);
    vec2 offset4 = vec2(0.0, -0.01);

    float glow = 0.0;
    glow += dot(texture(uTexture, uv + offset1).rgb, vec3(0.299, 0.587, 0.114)) * texture(uTexture, uv + offset1).a;
    glow += dot(texture(uTexture, uv + offset2).rgb, vec3(0.299, 0.587, 0.114)) * texture(uTexture, uv + offset2).a;
    glow += dot(texture(uTexture, uv + offset3).rgb, vec3(0.299, 0.587, 0.114)) * texture(uTexture, uv + offset3).a;
    glow += dot(texture(uTexture, uv + offset4).rgb, vec3(0.299, 0.587, 0.114)) * texture(uTexture, uv + offset4).a;
    glow *= 0.1 * uBrightness * modelMask;

    vec3 finalColor = emission + lightColor * glow;
    float alpha = max(emissionIntensity, glow * 0.5) * modelMask;

    fragColor = vec4(finalColor, alpha);
}