precision highp float;
#define M_PI 3.14159265358979323846
#define M_G 6.67430e-11
#define M_c 299792458.0

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

uniform struct Sphere {
    vec3 pos;
    float r;
    Material material;
};

uniform struct Disk {
    vec3 pos;
    vec3 normal;
    float outerRadius;
    float innerRadius;
    Material material;
};

struct HitInfo {
    bool didHit;
    float dst;
    vec3 hitPoint;
    vec3 normal;
    Material material;
};

uniform int u_numSpheres;
uniform Sphere u_spheres[1];

const float mass = 1e25;
const float bhR = 2.0 * (M_G * mass) / (M_c * M_c);

Disk disk = Disk( vec3(0), vec3(0., 1., 0.), .9, .15, 
                  Material(vec3(1,1,1), vec3(1., .4, 0.), 1.));

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

float DiskDensity(vec3 point, vec3 center, float innerRadius, float outerRadius) {
    vec3 direction = point - center;
    float distanceFromCenter = length(direction);

    if (distanceFromCenter < innerRadius || distanceFromCenter > outerRadius) {
        return 0.0;
    }

    float normalizedDistance = (distanceFromCenter - innerRadius) / (outerRadius - innerRadius);
    float noiseFactor = smoothstep(0.0, 1.0, normalizedDistance);
    float noiseValue = noiseFactor * fract(sin(dot(point.xy, vec2(12.9898,78.233))) * 43758.5453);

    return smoothstep(0.2, 0.8, noiseValue) * noiseFactor;
}


HitInfo RayHitSphere(Ray ray, Sphere sphere) {
    HitInfo hitInfo;
    hitInfo.didHit = false;
    vec3 oc = ray.origin - sphere.pos;
    float b = dot(oc, ray.dir);
    float c = dot(oc, oc) - sphere.r * sphere.r;
    float h = b * b - c;
    if (h > 0.0){
        float sqrt_h = sqrt(h);
        float dst = -b - sqrt_h;
        float dstOut = -b + sqrt_h;

        if (dst >= 0.0) {
            hitInfo.didHit = true;
            hitInfo.dst = dst;
            hitInfo.hitPoint = ray.origin + ray.dir * dst; 
            hitInfo.normal = normalize(hitInfo.hitPoint - sphere.pos);
            hitInfo.material = sphere.material;
        }
    }
    return hitInfo;
}

HitInfo CalRayHitShpere(Ray ray) {
    HitInfo closestHit;
    closestHit.dst = 3.;

    for(int i = 0; i < u_numSpheres; i++) {
        Sphere sphere = u_spheres[i];
        HitInfo hitInfo = RayHitSphere(ray, sphere);

        if(hitInfo.didHit && hitInfo.dst < closestHit.dst) {
            closestHit = hitInfo;
            closestHit.material = sphere.material;
        }
    }
    return closestHit;
}

// HitInfo CalRayHitTriangle(Ray ray) {
//     HitInfo closestHit;
//     closestHit.dst = 1e5;

//     for (int i = 0; i < u_numTriangles; i++) {
//         Triangle tri = u_triangles[i];
//         HitInfo hitInfo = RayHitTriangle(ray, tri);

//         if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
//             closestHit = hitInfo;
//             closestHit.material = tri.material;
//         }
//     }
//     return closestHit;
// }
// vec3 CalculateForce(vec3 position, vec3 center, float mass) {
//     vec3 direction = position - center;
//     float distanceSquared = dot(direction, direction);
//     return normalize(direction) * (-mass / distanceSquared);
// }
// vec3 CalculateForceOptimized(vec3 direction, float distanceSquared, float mass) {
//     return // Avoids normalize by dividing directly
// }


HitInfo RayHitDisk(Ray ray, Disk disk) {
    HitInfo hitInfo;
    hitInfo.didHit = false;
    float r = .01 / length(disk.pos - ray.origin);
    float rng = (Rand3D(u_seed + gl_FragCoord.xyz) - .5) * r;
    float denom = dot(ray.dir, disk.normal);
    if (abs(denom) > 1e-6) { 
        float t = dot(disk.pos + rng - ray.origin, disk.normal) / denom  ; 
        if (t >= 0.) { 
            vec3 hitPoint = ray.origin + t * ray.dir;
            vec3 hitVec = hitPoint - disk.pos;
            float dist2 = dot(hitVec, hitVec); 

            if (dist2 <= disk.outerRadius * disk.outerRadius && dist2 >= disk.innerRadius * disk.innerRadius) {
                hitInfo.didHit = true;
                hitInfo.dst = t;
                hitInfo.hitPoint = hitPoint;
                hitInfo.normal = disk.normal;
                hitInfo.material = disk.material;
            }
        }
    }

    return hitInfo;
}

HitInfo CalRayHit(Ray ray) {
    HitInfo closestHit;
    closestHit.didHit = false;
    closestHit.dst = 0.01;
    // for (int i = 0; i < u_numDisks; i++) {
        // Disk disk = u_disks[i];
        HitInfo hitInfo = RayHitDisk(ray, disk);

        if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
            closestHit = hitInfo;
        }
    // }

    // for (int i = 0; i < u_numSpheres; i++) {
    //     Sphere sphere = u_spheres[i];
    //     HitInfo hitInfo = RayHitSphere(ray, sphere);

    //     if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
    //         closestHit = hitInfo;
    //     }
    // }

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
    float step = 0.01;
    float tMax = 3.0;

    for (int i = 0; i <= u_rayBounces; i++) {
        float t = 0.0;

        while (t < tMax) {
            ray = bendingLight(ray, bhR, step);
            // ray.origin += ray.dir * step;
            if (length(ray.origin) < bhR) break;
            
            HitInfo hitInfo = CalRayHit(ray);

            if (hitInfo.didHit) {
                float density = .8 / length(hitInfo.hitPoint) - 1. ;
                if(Rand3D(seed) + density < .9) continue;
                Material mat = hitInfo.material;
                ray.origin = hitInfo.hitPoint;
                ray.dir = normalize(hitInfo.normal + RandDir(seed) * mat.spc);

                incomingLight += mat.ilm * rayColour * (density + .3);
                rayColour *= mat.col * density;
                break;
            }
            t += step;
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

    // if(u_frameCount < 24){
        curr = Trace(ray, vec3(uv.x, uv.y, 0) + u_seed );
    // }else{
    //     curr = prev.rgb;
    // }
        // int nRay = 10;
        // vec3 light = vec3(0.0);
        // for(int i = 0; i < nRay; i++) {
        //     light += Trace(ray,  vec3(uv.x, uv.y, 0) + u_seed + float(i));
        // }
        // curr = light / float(nRay);

    vec4 renderColor = vec4((prev.rgb * float(u_frameCount) + curr) / float(u_frameCount + 1), 1.);
    gl_FragColor = renderColor;

}