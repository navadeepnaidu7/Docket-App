#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uNight;
uniform float uDusk;
uniform float uRain;
uniform float uPull;
uniform float uPanelHeight;
uniform float uClouds;
uniform float uStorm;
uniform float uMotion;
uniform float uFog;
uniform float uSnow;
uniform float uSafeTop;
out vec4 fragColor;

float hash(vec2 p) {
  // Integer-valued arithmetic stays exactly representable in highp floats.
  // The previous fract/product hash was sensitive to mobile GPU contraction:
  // adjacent noise cells disagreed about shared corners, exposing the grid.
  vec2 cell = mod(floor(p), 289.0);
  float h = mod((cell.x * 34.0 + 1.0) * cell.x, 289.0);
  h += cell.y;
  h = mod((h * 34.0 + 1.0) * h, 289.0);
  return h / 289.0;
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
  for (int i = 0; i < 4; i++) {
    value += weight * noise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.3;
    weight *= 0.48;
  }
  return value;
}

float segmentDistance(vec2 p, vec2 a, vec2 b) {
  vec2 ab = b - a;
  float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
  return length(p - a - t * ab);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  // Coordinates remain fixed as the home surface uncovers the sky.
  uv.y = FlutterFragCoord().y / uPanelHeight;
  vec2 aspect = vec2(uSize.x / uPanelHeight, 1.0);
  // Place the entire celestial disc below the status icons/notch.
  vec2 light = vec2(0.82, max(0.30, (uSafeTop + 38.0) / uPanelHeight));
  vec2 toLight = (uv - light) * aspect;
  float distanceToLight = length(toLight);
  float overcast = smoothstep(0.58, 0.98, uClouds);
  vec3 top = mix(vec3(0.12, 0.34, 0.58), vec3(0.22, 0.29, 0.38), overcast);
  vec3 bottom = mix(vec3(0.34, 0.54, 0.69), vec3(0.33, 0.42, 0.49), overcast);
  top = mix(top, vec3(0.07, 0.105, 0.17), uStorm * 0.85);
  bottom = mix(bottom, vec3(0.17, 0.22, 0.30), uStorm * 0.75);
  top = mix(top, vec3(0.25, 0.25, 0.43), uDusk);
  bottom = mix(bottom, vec3(0.67, 0.43, 0.37), uDusk);
  top = mix(top, vec3(0.025, 0.06, 0.14), uNight);
  bottom = mix(bottom, vec3(0.12, 0.21, 0.33), uNight);
  vec3 color = mix(top, bottom, clamp(uv.y * 0.85, 0.0, 1.0));

  // Broad forward scattering and a small luminous core; no hard sun icon.
  vec3 sunlight = mix(vec3(1.0, 0.88, 0.64), vec3(1.0, 0.63, 0.37), uDusk);
  float atmosphere = 0.80 + 0.20 * noise(vec2(uTime * 0.26, 3.7));
  float glow = exp(-distanceToLight * 3.3) * 0.47 * atmosphere;
  glow += exp(-distanceToLight * distanceToLight * 500.0) * 0.52;
  float sunVisibility = (1.0 - overcast) * (1.0 - uNight);
  color += sunlight * glow * sunVisibility;

  // A shaded lunar sphere, with fixed surface detail and a quiet halo.
  // It is an illustrative gibbous moon, not an astronomical phase reading.
  float moonRadius = 0.052;
  float moonEdge = 1.0 - smoothstep(moonRadius - 0.003, moonRadius, distanceToLight);
  color += vec3(0.37, 0.48, 0.68) * exp(-distanceToLight * 17.0)
      * 0.07 * uNight * (1.0 - overcast);
  if (uNight > 0.001 && distanceToLight < moonRadius) {
    vec2 m = toLight / moonRadius;
    vec3 normal = vec3(m, sqrt(max(0.0, 1.0 - dot(m, m))));
    float illumination = max(0.0, dot(normal, normalize(vec3(-0.65, -0.40, 0.66))));
    float maria = smoothstep(0.32, 0.70, noise(m * 3.8 + 8.2));
    float craters = (1.0 - smoothstep(0.12, 0.25, length(m - vec2(-0.25, 0.2))))
        + (1.0 - smoothstep(0.08, 0.18, length(m - vec2(0.35, -0.15))))
        + (1.0 - smoothstep(0.04, 0.11, length(m - vec2(0.18, 0.52))));
    float texture = 0.88 - maria * 0.17 - craters * 0.13 + noise(m * 21.0) * 0.06;
    vec3 moon = vec3(0.72, 0.76, 0.80) * texture * (0.12 + illumination * 0.93);
    color = mix(color, moon, moonEdge * uNight);
  }
  vec2 starGrid = uv * vec2(145.0, 95.0);
  vec2 starCell = floor(starGrid);
  float starSeed = hash(starCell + 71.0);
  float star = (1.0 - smoothstep(0.02, 0.13, length(fract(starGrid) - 0.5)))
      * step(0.986, starSeed);
  color += vec3(0.58, 0.67, 0.78) * star * uNight * (1.0 - overcast) * 0.55;

  // Two independent scales of drifting density, lit from the upper right.
  vec2 farP = uv * vec2(2.0, 1.4) + vec2(8.1 - uTime * 0.018, 3.2);
  float wisps = noise(farP) * 0.7 + noise(farP * 2.3) * 0.3;
  float haze = smoothstep(0.42, 0.78, wisps) * (1.0 - smoothstep(0.0, 1.0, uv.y));
  color = mix(color, mix(vec3(0.74, 0.83, 0.90), vec3(0.16, 0.24, 0.38), uNight), haze * 0.22 * uClouds);
  vec2 p = uv * vec2(3.0, 2.2) + vec2(-uTime * 0.048, uTime * 0.007);
  float billow = noise(uv * 2.0 + vec2(uTime * 0.026, -uTime * 0.018));
  p += vec2(billow * (0.20 + uStorm * 0.18), billow * 0.12);
  float density = cloudNoise(p + vec2(2.7, 1.4));
  float towardLight = cloudNoise(p + vec2(2.76, 1.31));
  float bank = 0.13 * sin(uv.x * 4.0 + 0.9) + uv.y * 0.11;
  // Sparse wisps, broken cumulus and a continuous overcast bank have distinct
  // shapes; the scalar blends continuously when real conditions change.
  float threshold = mix(0.70, 0.25, uClouds);
  float edgeSoftness = mix(0.075, 0.22, overcast);
  float coverage = smoothstep(threshold, threshold + edgeSoftness, density + bank)
      * smoothstep(0.0, 0.20, uClouds);
  coverage = mix(coverage, max(coverage, 0.80 + density * 0.12), overcast * 0.80);
  // Leave a calm pocket behind the text, while clouds occupy the upper sky.
  coverage *= 1.0 - smoothstep(0.25, 0.85, uv.y) * (1.0 - uv.x) * mix(0.90, 0.38, overcast);
  float lighting = clamp(0.62 + (density - towardLight) * 4.0, 0.0, 1.0);
  vec3 shadow = mix(vec3(0.34, 0.46, 0.60), vec3(0.22, 0.29, 0.36), overcast);
  vec3 highlight = mix(vec3(0.93, 0.95, 0.95), vec3(0.62, 0.69, 0.73), overcast);
  shadow = mix(shadow, vec3(0.10, 0.14, 0.22), uStorm * 0.8);
  highlight = mix(highlight, vec3(0.35, 0.43, 0.54), uStorm * 0.7);
  shadow = mix(shadow, vec3(0.07, 0.12, 0.21), uNight);
  highlight = mix(highlight, vec3(0.34, 0.43, 0.58), uNight);
  highlight = mix(highlight, vec3(0.94, 0.72, 0.59), uDusk * 0.55);
  vec3 cloud = mix(shadow, highlight, lighting);
  float rim = pow(1.0 - coverage, 3.0) * coverage * exp(-distanceToLight * 2.0);
  cloud += sunlight * rim * 3.2 * atmosphere * sunVisibility;
  color = mix(color, cloud, coverage * 0.94);

  // Soft lens glare: a breathing bloom, oblique sheen and faint off-axis ghost.
  // No radial spokes. Movement follows both time and the user's pull.
  float lensAngle = 0.30 + sin(uTime * 0.17) * 0.13 + (1.0 - uPull) * 0.08;
  vec2 lens = mat2(cos(lensAngle), sin(lensAngle), -sin(lensAngle), cos(lensAngle)) * toLight;
  float sheen = exp(-lens.x * lens.x * 7.0 - lens.y * lens.y * 650.0);
  float bloom = exp(-distanceToLight * distanceToLight * (13.0 + 2.0 * sin(uTime * 0.31)));
  vec2 ghostCenter = mix(light, vec2(0.39, 0.65), 0.47 + sin(uTime * 0.16) * 0.025);
  float ghostDistance = length((uv - ghostCenter) * aspect);
  float ghostOffset = (ghostDistance - 0.095) * 32.0;
  // pow(x, 2) is undefined for negative x on GLSL, even for an integer power.
  float ghost = exp(-ghostOffset * ghostOffset);
  float exposure = atmosphere * sunVisibility * (1.0 - uNight) * (1.0 - coverage * 0.85);
  color += sunlight * (bloom * 0.14 + sheen * 0.11) * exposure;
  color += vec3(0.95, 0.64, 0.37) * ghost * 0.026 * exposure;

  // Three continuous rain fields; intensity fades layers in without resetting
  // their trajectories when a user interrupts a weather transition.
  float rain = 0.0;
  for (int layer = 0; layer < 3; layer++) {
    float depth = float(layer);
    float gust = sin(uTime * 0.37) * uRain * 1.7;
    vec2 q = vec2(uv.x * (110.0 - depth * 25.0) + uv.y * (3.0 + uRain * 7.0 + gust),
                  uv.y * (6.0 - depth * 1.4) - uTime * (2.7 + depth * 2.1));
    // Stagger each lane's phase and speed so drops never form horizontal rows.
    float lane = floor(q.x);
    float laneSeed = hash(vec2(lane, 37.0 + depth * 19.0));
    q.y += laneSeed * 8.0 - uTime * laneSeed * 0.6;
    vec2 cell = floor(q);
    vec2 f = fract(q);
    float seed = hash(vec2(cell.x, floor(cell.y * 0.25)));
    float pixelWidth = (110.0 - depth * 25.0) / uSize.x;
    float line = 1.0 - smoothstep(0.018, 0.065 + pixelWidth * 0.5 + depth * 0.018, abs(f.x - 0.5));
    float tail = smoothstep(0.0, 0.75, f.y) * (1.0 - smoothstep(0.82, 1.0, f.y));
    float amount = smoothstep(0.99 - uRain * 0.70, 1.0 - uRain * 0.25, seed);
    float layerOpacity = smoothstep(depth * 0.26, 0.25 + depth * 0.26, uRain);
    rain += line * tail * amount * layerOpacity * (0.17 + depth * 0.055);
  }
  color += vec3(0.69, 0.79, 0.87) * rain;
  float mist = noise(uv * vec2(3.0, 1.6) + vec2(-uTime * 0.04, 7.0));
  color = mix(color, vec3(0.46, 0.55, 0.62), mist * smoothstep(0.4, 1.2, uv.y) * uRain * 0.17);

  // Soft, staggered snowflakes. Independent lanes avoid obvious horizontal
  // bands; fixed coordinates keep the field anchored during overpull.
  float snow = 0.0;
  for (int layer = 0; layer < 3; layer++) {
    float depth = float(layer);
    vec2 q = uv * vec2(25.0 - depth * 5.0, 7.0 - depth);
    q.x += sin(uTime * 0.25 + depth) * 0.3;
    float lane = floor(q.x);
    q.y -= uTime * (0.26 + depth * 0.12);
    q.y += hash(vec2(lane, depth + 51.0)) * 8.0;
    vec2 cell = floor(q);
    vec2 flake = fract(q) - vec2(0.3 + hash(cell) * 0.4, 0.5);
    vec2 flakePixels = flake * vec2(uSize.x / (25.0 - depth * 5.0), uPanelHeight / (7.0 - depth));
    float radius = length(flakePixels);
    snow += (1.0 - smoothstep(0.45, 1.2 + depth * 0.35, radius))
      * step(0.40, hash(cell + 23.0)) * (0.20 + depth * 0.08);
  }
  color += vec3(0.80, 0.87, 0.94) * snow * uSnow;
  float fogDensity = (0.38 + mist * 0.22 + smoothstep(0.0, 1.2, uv.y) * 0.16) * uFog;
  color = mix(color, mix(vec3(0.44, 0.53, 0.61), vec3(0.13, 0.19, 0.28), uNight), fogDensity);

  // A single localized lightning event every ~12 seconds, with a soft cloud
  // bloom and short branching discharge. Reduced motion removes the event.
  float cycle = floor(uTime / 12.7);
  float phase = mod(uTime, 12.7);
  float strikeAt = 3.0 + hash(vec2(cycle, 17.0)) * 2.0;
  float flash = smoothstep(strikeAt, strikeAt + 0.12, phase)
      * (1.0 - smoothstep(strikeAt + 0.18, strikeAt + 0.80, phase)) * uStorm * uMotion;
  if (flash > 0.001) {
    vec2 origin = vec2(0.60 + hash(vec2(cycle, 8.0)) * 0.22, 0.06);
    float cloudLight = exp(-length((uv - origin) * vec2(2.0, 1.5)) * 4.0);
    color += vec3(0.39, 0.46, 0.65) * cloudLight * flash * (0.40 + coverage * 0.30);
    float boltDistance = 10.0;
    vec2 a = origin;
    for (int i = 0; i < 6; i++) {
      float stepIndex = float(i);
      vec2 b = origin + vec2((hash(vec2(stepIndex + cycle * 7.0, 6.0)) - 0.5) * 0.09,
                             (stepIndex + 1.0) * 0.065);
      boltDistance = min(boltDistance, segmentDistance(uv * aspect, a * aspect, b * aspect));
      if (i == 2) {
        vec2 branch = b + vec2(0.085, 0.11);
        boltDistance = min(boltDistance, segmentDistance(uv * aspect, b * aspect, branch * aspect) * 1.5);
      }
      a = b;
    }
    float bolt = exp(-boltDistance * 750.0) * 0.7 + exp(-boltDistance * 95.0) * 0.14;
    color += vec3(0.66, 0.76, 1.0) * bolt * flash;
  }

  // Low-contrast veil keeps white copy readable even as clouds move behind it.
  float veil = smoothstep(0.22, 0.88, uv.y) * (0.35 - uv.x * 0.08);
  color *= 1.0 - veil;
  color += (hash(FlutterFragCoord().xy) - 0.5) / 255.0;
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
