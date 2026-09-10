#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uNight;
uniform float uDusk;
uniform float uRain;
uniform float uPull;
uniform float uPanelHeight;
out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
             mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float cloudNoise(vec2 p) {
  float value = 0.0;
  float weight = 0.55;
  for (int i = 0; i < 5; i++) {
    value += weight * noise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.3;
    weight *= 0.48;
  }
  return value;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  // Coordinates remain fixed as the home surface uncovers the sky.
  uv.y = FlutterFragCoord().y / uPanelHeight;
  vec2 aspect = vec2(uSize.x / uPanelHeight, 1.0);
  vec2 light = vec2(0.84, 0.10);
  vec2 toLight = (uv - light) * aspect;
  float distanceToLight = length(toLight);
  vec3 top = mix(vec3(0.12, 0.34, 0.58), vec3(0.22, 0.29, 0.38), uRain);
  vec3 bottom = mix(vec3(0.34, 0.54, 0.69), vec3(0.33, 0.42, 0.49), uRain);
  top = mix(top, vec3(0.25, 0.25, 0.43), uDusk);
  bottom = mix(bottom, vec3(0.67, 0.43, 0.37), uDusk);
  top = mix(top, vec3(0.025, 0.06, 0.14), uNight);
  bottom = mix(bottom, vec3(0.12, 0.21, 0.33), uNight);
  vec3 color = mix(top, bottom, clamp(uv.y * 0.85, 0.0, 1.0));

  // Broad forward scattering and a small luminous core; no hard sun icon.
  vec3 sunlight = mix(vec3(1.0, 0.88, 0.64), vec3(1.0, 0.63, 0.37), uDusk);
  sunlight = mix(sunlight, vec3(0.64, 0.77, 1.0), uNight);
  float atmosphere = 0.91 + 0.09 * noise(vec2(uTime * 0.22, 3.7));
  float glow = exp(-distanceToLight * 3.3) * 0.47 * atmosphere;
  glow += exp(-distanceToLight * distanceToLight * 500.0) * 0.52;
  color += sunlight * glow * (1.0 - uRain * 0.88) * (1.0 - uNight * 0.65);

  // Two independent scales of drifting density, lit from the upper right.
  vec2 farP = uv * vec2(2.0, 1.4) + vec2(8.1 - uTime * 0.018, 3.2);
  float wisps = noise(farP) * 0.7 + noise(farP * 2.3) * 0.3;
  float haze = smoothstep(0.42, 0.78, wisps) * (1.0 - smoothstep(0.0, 1.0, uv.y));
  color = mix(color, mix(vec3(0.74, 0.83, 0.90), vec3(0.16, 0.24, 0.38), uNight), haze * 0.22);
  vec2 p = uv * vec2(3.0, 2.2) + vec2(-uTime * 0.048, uTime * 0.007);
  float billow = noise(uv * 2.0 + vec2(uTime * 0.026, -uTime * 0.018));
  p += vec2(billow * 0.20, billow * 0.12);
  p.y += (1.0 - uPull) * 0.07;
  float density = cloudNoise(p + vec2(2.7, 1.4));
  float towardLight = cloudNoise(p + vec2(2.76, 1.31));
  float bank = 0.13 * sin(uv.x * 4.0 + 0.9) + uv.y * 0.11;
  float coverage = smoothstep(0.46 - uRain * 0.12, 0.72, density + bank);
  // Leave a calm pocket behind the text, while clouds occupy the upper sky.
  coverage *= 1.0 - smoothstep(0.25, 0.85, uv.y) * (1.0 - uv.x) * 0.90;
  float lighting = clamp(0.62 + (density - towardLight) * 4.0, 0.0, 1.0);
  vec3 shadow = mix(vec3(0.34, 0.46, 0.60), vec3(0.22, 0.29, 0.36), uRain);
  vec3 highlight = mix(vec3(0.93, 0.95, 0.95), vec3(0.62, 0.69, 0.73), uRain);
  shadow = mix(shadow, vec3(0.07, 0.12, 0.21), uNight);
  highlight = mix(highlight, vec3(0.34, 0.43, 0.58), uNight);
  highlight = mix(highlight, vec3(0.94, 0.72, 0.59), uDusk * 0.55);
  vec3 cloud = mix(shadow, highlight, lighting);
  float rim = pow(1.0 - coverage, 3.0) * coverage * exp(-distanceToLight * 2.0);
  cloud += sunlight * rim * 3.2 * atmosphere * (1.0 - uRain);
  color = mix(color, cloud, coverage * 0.94);

  // Gentle crepuscular shafts vary with the moving cloud field.
  float angle = atan(toLight.x, toLight.y);
  float openings = noise(vec2(angle * 3.0 + 5.0, uTime * 0.12));
  float shaft = pow(0.5 + 0.5 * sin(angle * 9.0 + openings * 2.0 + uTime * 0.12), 4.0);
  color += sunlight * shaft * 0.12 * atmosphere * exp(-distanceToLight * 1.4)
      * smoothstep(0.12, 0.40, distanceToLight)
      * (1.0 - coverage) * (1.0 - uRain) * (1.0 - uNight);

  // Fine drizzle at two depths, with staggered speeds and long soft tails.
  float rain = 0.0;
  for (int layer = 0; layer < 2; layer++) {
    float depth = float(layer);
    vec2 q = vec2(uv.x * (95.0 + depth * 55.0) + uv.y * 5.0,
                  uv.y * (5.0 + depth * 3.0) - uTime * (2.6 + depth * 1.3));
    vec2 cell = floor(q);
    vec2 f = fract(q);
    float seed = hash(vec2(cell.x, floor(cell.y * 0.25)));
    float line = 1.0 - smoothstep(0.015, 0.08, abs(f.x - 0.5));
    float tail = smoothstep(0.0, 0.75, f.y) * (1.0 - smoothstep(0.82, 1.0, f.y));
    rain += line * tail * step(0.87, seed) * (0.12 - depth * 0.04);
  }
  color += vec3(0.69, 0.79, 0.87) * rain * uRain;

  // Low-contrast veil keeps white copy readable even as clouds move behind it.
  float veil = smoothstep(0.22, 0.88, uv.y) * (0.35 - uv.x * 0.08);
  color *= 1.0 - veil;
  color += (hash(FlutterFragCoord().xy) - 0.5) / 255.0;
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
