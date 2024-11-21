precision highp float;
#define M_PI 3.14159265358979323846
#define M_G 6.67430e-11
#define M_c 299792458.0
#define M_e 2.718281828459045

uniform vec2 u_resolution;
uniform vec3 u_cameraPos;
uniform vec3 u_focusPos;
uniform int u_frameCount;

uniform float u_time;
uniform vec3 u_seed;
uniform int u_rayBounces;

uniform sampler2D u_buffer;
uniform sampler2D u_space;

struct Ray {
    vec3 origin;
    vec3 dir;
};

uniform struct Material {
    vec3 col; 
    vec3 ilm; 
    float spc;
};

struct HitInfo {
    bool didHit;
    float dst;
    vec3 hitPoint;
    vec3 normal;
    Material material;
};

const float mass = 1e25;
const float bhR = 2.0 * (M_G * mass) / (M_c * M_c);
const float tstep = 0.005;

float Rand3D(vec3 seed) {
    return fract(sin(dot(seed, vec3(12.9898, 78.233, 54.53))) * 43758.5453);
}

float RandNmlDist(vec3 seed) {
    float theta = 2. * M_PI * Rand3D(seed.zyx);
    float rho = sqrt(-2. * log(Rand3D(seed.yzx)));
    return rho * cos(theta);
}

vec3 RandDir(vec3 seed) {
    float x = RandNmlDist(seed);
    float y = RandNmlDist(seed.yxz);
    float z = RandNmlDist(seed.xzy);
    return normalize(vec3(x, y, z));
}

vec3 RandHemisphereDir(vec3 normal, vec3 seed) {
    vec3 dir = RandDir(seed);
    return dir * sign(dot(normal, dir));
}

vec3 GetRayDirection(vec2 fragCoord, vec2 resolution, vec3 cameraPos, vec3 focusDir) {
    vec2 uv = (fragCoord + u_seed.zy) / resolution * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;
    vec3 forward = normalize(focusDir - cameraPos);
    vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(right, forward);
    return normalize(forward + uv.x * right + uv.y * up);
}

vec3 GetSpaceHDRI(Ray ray) {
    vec3 rayDir = normalize(ray.dir);
    float u = 0.5 + atan(rayDir.z, rayDir.x) * 0.15915494309;
    float v = 0.5 - asin(rayDir.y) * 0.31830988618;
    vec3 hdrColor = texture(u_space, vec2(u, v)).rgb;
    
    return hdrColor;
}

vec3 C2P(vec3 c){
    float r = length(c) ;
    float lat = acos(c.z / r);
    float lon = atan(c.y, c.x);
    return vec3(r, lat, lon);
}

vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
vec3 fade(vec3 t) {return t*t*t*(t*(t*6.0-15.0)+10.0);}
float cnoise(vec3 P){
    vec3 Pi0 = floor(P); // Integer part for indexing
    vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
    Pi0 = mod(Pi0, 289.0);
    Pi1 = mod(Pi1, 289.0);
    vec3 Pf0 = fract(P); // Fractional part for interpolation
    vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
    vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    vec4 iy = vec4(Pi0.yy, Pi1.yy);
    vec4 iz0 = Pi0.zzzz;
    vec4 iz1 = Pi1.zzzz;

    vec4 ixy = permute(permute(ix) + iy);
    vec4 ixy0 = permute(ixy + iz0);
    vec4 ixy1 = permute(ixy + iz1);

    vec4 gx0 = ixy0 / 7.0;
    vec4 gy0 = fract(floor(gx0) / 7.0) - 0.5;
    gx0 = fract(gx0);
    vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
    vec4 sz0 = step(gz0, vec4(0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);

    vec4 gx1 = ixy1 / 7.0;
    vec4 gy1 = fract(floor(gx1) / 7.0) - 0.5;
    gx1 = fract(gx1);
    vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
    vec4 sz1 = step(gz1, vec4(0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);

    vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
    vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
    vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
    vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
    vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
    vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
    vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
    vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

    vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;
    vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;

    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);

    vec3 fade_xyz = fade(Pf0);
    vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
    vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x); 
    return 2.2 * n_xyz;
}

vec3 RGBtoHSV(vec3 rgb) {
    float cmax = max(rgb.r, max(rgb.g, rgb.b));
    float cmin = min(rgb.r, min(rgb.g, rgb.b));
    float delta = cmax - cmin;

    float hue = 0.0;
    if (delta > 0.0) {
        if (cmax == rgb.r) {
            hue = mod((rgb.g - rgb.b) / delta, 6.0);
        } else if (cmax == rgb.g) {
            hue = (rgb.b - rgb.r) / delta + 2.0;
        } else {
            hue = (rgb.r - rgb.g) / delta + 4.0;
        }
        hue *= 60.0;
    }

    float saturation = cmax == 0.0 ? 0.0 : delta / cmax;
    return vec3(hue, saturation, cmax); // HSV: (Hue, Saturation, Value)
}
vec3 HSVtoRGB(vec3 hsv) {
    float c = hsv.z * hsv.y; // Chroma
    float x = c * (1.0 - abs(mod(hsv.x / 60.0, 2.0) - 1.0));
    float m = hsv.z - c;

    vec3 rgb = vec3(0.0);
    if (0.0 <= hsv.x && hsv.x < 60.0) {
        rgb = vec3(c, x, 0.0);
    } else if (60.0 <= hsv.x && hsv.x < 120.0) {
        rgb = vec3(x, c, 0.0);
    } else if (120.0 <= hsv.x && hsv.x < 180.0) {
        rgb = vec3(0.0, c, x);
    } else if (180.0 <= hsv.x && hsv.x < 240.0) {
        rgb = vec3(0.0, x, c);
    } else if (240.0 <= hsv.x && hsv.x < 300.0) {
        rgb = vec3(x, 0.0, c);
    } else if (300.0 <= hsv.x && hsv.x < 360.0) {
        rgb = vec3(c, 0.0, x);
    }

    return rgb + m;
}

vec3 ShiftHue(vec3 rgb, float s) {
    vec3 hsv = RGBtoHSV(rgb);
    hsv.x = mod(hsv.x + s, 360.0); // Adjust hue and wrap around 360
    hsv.z += s / 50.;
    hsv.y += s / 10.;
    return HSVtoRGB(hsv);
}

HitInfo RayHitDisk(Ray ray) {
    HitInfo hitInfo;
    hitInfo.didHit = false;

    float len = length(ray.origin.xyz);
    vec2 uv = gl_FragCoord.xy / u_resolution;
    if (abs(ray.origin.y) < 0.01 * Rand3D(u_seed + uv.xyx) && len < 2.) {
        hitInfo.didHit = true;
        hitInfo.dst = tstep;
        hitInfo.hitPoint = ray.origin + tstep * ray.dir;
        hitInfo.normal = vec3(0);
        hitInfo.material = Material(vec3(1), vec3(1), 1.);
    }
    return hitInfo;
}

HitInfo CalRayHit(Ray ray) {
    HitInfo closestHit;
    closestHit.didHit = false;
    closestHit.dst = tstep;
    HitInfo hitInfo = RayHitDisk(ray);

    if (hitInfo.didHit && hitInfo.dst <= closestHit.dst) {
        closestHit = hitInfo;
    }

    return closestHit;
}

Ray bendingLight(Ray rayIn, float strength, float step) {
    Ray ray = rayIn;
    vec3 direction = ray.origin;
    float distanceSquared = dot(direction, direction);
    float invDistanceCubed = 1.0 / (distanceSquared * sqrt(distanceSquared));
    vec3 deltaDir = direction * (-strength * invDistanceCubed);
    
    ray.dir = normalize(ray.dir + deltaDir * step);
    ray.origin += ray.dir * step;
    return ray;
}


vec3 Trace(Ray ray, vec3 seed) {
    vec3 incomingLight = vec3(0.0);
    vec3 rayColour = vec3(1.0);
    vec3 accrediskCol = vec3(1, .8, .6);

    float tMax = 2.0;

    for (int i = 0; i <= u_rayBounces; i++) {
        float t = 0.0;

        while (t < tMax) {
            ray = bendingLight(ray, bhR, tstep); // Apply Gravitational lensing
            if (length(ray.origin) < bhR) break; // Fill black
            HitInfo hitInfo = CalRayHit(ray); 

            if (hitInfo.didHit) {
                float hitPointLen = length(hitInfo.hitPoint);
                float f = pow(M_e, -2. * hitPointLen + .4); // Fade, Cutoff
                float s = cross(hitInfo.hitPoint, ray.dir).y * (.5 / (hitPointLen*hitPointLen)); // Random math by me
                vec3 pol = C2P(vec3(hitInfo.hitPoint.x, hitInfo.hitPoint.y + 0.5, hitInfo.hitPoint.z) * 90.);
                pol.y = u_time; // Blend 
                float noise = cnoise(pol);
                if(((Rand3D(seed) + noise) * f < .5) || pol.x < 45.5) continue; // Random hit depends on density
               
                vec3 shiftedLight = ShiftHue(accrediskCol, s);

                Material mat = hitInfo.material;
                ray.origin = hitInfo.hitPoint;
                ray.dir = normalize(hitInfo.normal + RandDir(seed));

                incomingLight += f / 2. * rayColour * shiftedLight;
                rayColour *= mat.col;
                break;
            }
            t += tstep;
        }
        if (t >= tMax) {
            incomingLight += GetSpaceHDRI(ray) * rayColour;
            break;
        }
    }
    return max(incomingLight, 0.0);
}

void main() {
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 uv = fragCoord / u_resolution;
    vec4 prev = texture2D(u_buffer, uv);
    vec3 curr;
    Ray ray;
    ray.origin = u_cameraPos;
    ray.dir = GetRayDirection(fragCoord, u_resolution, u_cameraPos, u_focusPos);
    
    if(u_frameCount >= 64){ // Frame limiter
        gl_FragColor = prev;
        return;
    }

    curr = Trace(ray, vec3(uv.x, uv.y, 0) + u_seed );
    vec4 renderColor = vec4((prev.rgb * float(u_frameCount) + curr) / float(u_frameCount + 1), 1.);
    gl_FragColor = renderColor;

    // int nRay = 10; 
    // vec3 light = vec3(0.0);
    // for(int i = 0; i < nRay; i++) {
    //     light += Trace(ray,  vec3(uv.x, uv.y, 0) + u_seed + float(i));
    // }
    // curr = light / float(nRay);

    // vec4 renderColor = vec4((prev.rgb * float(u_frameCount) + curr) / float(u_frameCount + 1), 1.);
    // gl_FragColor = renderColor;
}