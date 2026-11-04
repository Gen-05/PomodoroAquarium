#include <metal_stdlib>
using namespace metal;

struct TitleBubbleVertex {
    float4 position [[position]];
    float2 local;
    float radius;
    float lineWidth;
    float opacity;
    uint isDot [[flat]];
};

// Four small quads share the existing water render pass; no fullscreen blur or extra texture.
vertex TitleBubbleVertex startTitleBubbleVertex(uint vertexID [[vertex_id]], uint instanceID [[instance_id]],
    constant float4 *particles [[buffer(0)]], constant float4 &viewport [[buffer(1)]]) {
    const float2 corners[6] = {float2(-1,-1),float2(1,-1),float2(-1,1),
                              float2(-1,1),float2(1,-1),float2(1,1)};
    float4 p = particles[instanceID]; // center in drawable pixels, radius, opacity
    float extent = p.z + viewport.z + 1;
    TitleBubbleVertex out;
    float2 point = p.xy + corners[vertexID] * extent;
    out.position = p.w > 0 && p.z > 0
        ? float4(2 * point.x / viewport.x - 1, 1 - 2 * point.y / viewport.y, 0, 1)
        : float4(-2,-2,0,1);
    out.local = corners[vertexID] * extent / max(p.z, 0.001f);
    out.radius = p.z;
    out.lineWidth = viewport.z;
    out.opacity = p.w;
    out.isDot = instanceID == 3;
    return out;
}

fragment float4 startTitleBubbleFragment(TitleBubbleVertex in [[stage_in]]) {
    float distance = length(in.local);
    float aa = max(fwidth(distance), 0.001f);
    float fill = 1 - smoothstep(1 - aa, 1 + aa, distance);
    if (in.isDot) { return float4(1) * (fill * in.opacity); }
    float halfLine = in.lineWidth / max(2 * in.radius, 0.001f);
    float ring = 1 - smoothstep(max(0.0f, halfLine - aa), halfLine + aa, abs(distance - 1));
    float highlightDistance = length(in.local - float2(-0.275f,-0.375f));
    float highlight = 1 - smoothstep(0.175f - aa, 0.175f + aa, highlightDistance);
    float fillAlpha = fill * 0.10f, ringAlpha = ring * 0.92f, highlightAlpha = highlight * 0.85f;
    float3 rgb = float3(0.8f,0.97f,1) * fillAlpha;
    float alpha = fillAlpha;
    rgb = float3(0.9f,1,1) * ringAlpha + rgb * (1 - ringAlpha);
    alpha = ringAlpha + alpha * (1 - ringAlpha);
    rgb = float3(1) * highlightAlpha + rgb * (1 - highlightAlpha);
    alpha = highlightAlpha + alpha * (1 - highlightAlpha);
    return float4(rgb, alpha) * in.opacity;
}
