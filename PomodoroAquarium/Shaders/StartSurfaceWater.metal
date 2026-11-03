#include <metal_stdlib>
using namespace metal;

struct StartWaterUniforms {
    float2 resolution;
    float seconds;
};

vertex float4 startSurfaceVertex(uint id [[vertex_id]]) {
    const float2 corners[] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
    return float4(corners[id], 0, 1);
}

// 採用 water_motion.cikernel / .frag の逆参照式を移植。
// Metalの画面座標・Textureは上原点なので、計算前とサンプル時に双方を反転する。
fragment float4 startSurfaceFragment(float4 position [[position]],
                                     constant StartWaterUniforms &u [[buffer(0)]],
                                     texture2d<float> water [[texture(0)]]) {
    constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);
    float t = fmod(u.seconds, 180.0);
    float theta = 6.28318530718 * t / 180.0;
    float outputScale = u.resolution.x / 1440.0;
    float2 pivot = float2(990.9495896834701 * outputScale,
                         u.resolution.y - 301.1713665943601 * outputScale);
    float2 destination = float2(position.x, u.resolution.y - position.y);
    float2 d = (destination - pivot) / outputScale;
    float2 q = float2(cos(theta)*d.x + sin(theta)*d.y,
                     -sin(theta)*d.x + cos(theta)*d.y) / 7168.0;
    float2 k1 = float2(28.0,14.0);
    float2 k2 = float2(-16.0,39.0);
    float2 k3 = float2(33.0,-27.0);
    float2 flow = 0.0018 * normalize(float2(k1.y,-k1.x)) * sin(dot(k1,q) + 6.28318530718*t/18.0 + 0.4)
                + 0.0011 * normalize(float2(k2.y,-k2.x)) * sin(dot(k2,q) + 6.28318530718*t/30.0 + 2.1)
                + 0.0008 * normalize(float2(k3.y,-k3.x)) * sin(dot(k3,q) + 6.28318530718*t/45.0 + 4.7);
    float anchor = smoothstep(0.012,0.065,length(q));
    float depth = 0.35 + 0.65 * exp(-dot(q,q)/0.10);
    float2 uv = float2(0.5) + q + flow * anchor * depth;
    // sRGBをそのまま補間する。入力/出力に自動のlinear変換を重ねない。
    return water.sample(linearClamp, float2(uv.x, 1.0 - uv.y));
}
