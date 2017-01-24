
#include "ShadersCommon.h"

using namespace metal;

struct Vertex
{
    float4 position;
    float4 normal;
    float4 tangent;
    float4 bitangent;
    float2 texCoord;
    
    float3 diffuseColor;
    float3 ambientColor;
    float3 specularColor;
    float2 specularPowerDisolve;
};

struct ProjectedVertex
{
    float4 position [[position]];
    float3 eye;
    float3 normal;
    float3 tangent;
    float3 bitangent;
    float2 texCoord;
    
    float3 diffuseColor;
    float3 ambientColor;
    float3 specularColor;
    float specularPower;
    float dissolve [[flat]];
    
    float4 shadowPosition;
};

vertex ProjectedVertex vertex_tex_materialed_tangent(device Vertex *vertices [[buffer(0)]],
                                                     constant ModelUniforms &uniforms [[buffer(1)]],
                                                     constant LightVertexUniforms &lightCast [[buffer(2)]],
                                                     uint vid [[vertex_id]])
{
    ProjectedVertex outVert;
    outVert.position = uniforms.modelViewProjectionMatrix * vertices[vid].position;
    outVert.eye =  -(uniforms.modelViewMatrix * vertices[vid].position).xyz;
    outVert.normal = uniforms.normalMatrix * vertices[vid].normal.xyz;
    outVert.tangent = uniforms.normalMatrix * (vertices[vid].tangent.xyz);
    outVert.bitangent = uniforms.normalMatrix * (vertices[vid].bitangent.xyz);
    outVert.texCoord = vertices[vid].texCoord;
    
    outVert.ambientColor = vertices[vid].ambientColor;
    outVert.diffuseColor = vertices[vid].diffuseColor;
    outVert.specularColor = vertices[vid].specularColor;
    outVert.specularPower = vertices[vid].specularPowerDisolve.x;
    outVert.dissolve = vertices[vid].specularPowerDisolve.y;
    
    outVert.shadowPosition = lightCast.lightCastMatrix[0] * vertices[vid].position;
    
    return outVert;
}



static VertexFragmentCharacters vertex_characters(ProjectedVertex vert);
static float3 bumpped_normal(float3 normal, float3 tangent, float3 bitangent, float3 bumpNormal);



/**
 *  shaders that generate shadow-map texture from the light view point
 */

vertex PositionSimple vertex_shadow_tex_materialed_bump(device Vertex *vertices [[buffer(0)]],
                                                        constant ModelUniforms &uniforms [[buffer(1)]],
                                                        uint vid [[vertex_id]])
{
    PositionSimple outShadow;
    outShadow.position = uniforms.modelViewProjectionMatrix * vertices[vid].position;
    return outShadow;
}




fragment float4 fragment_tex_a_materialed_bump(ProjectedVertex vert [[stage_in]],
                                               constant LightUniform &lighting [[buffer(0)]],
                                               texture2d<float> shadowMap [[texture(0)]],
                                               texture2d<float> diffuseTexture [[texture(1)]],
                                               texture2d<float> bumpTexture [[texture(2)]],
                                               sampler depthSamplr [[sampler(0)]],
                                               sampler samplr [[sampler(1)]])
{
    VertexFragmentCharacters outVert = vertex_characters(vert);
    
    float4 diffuseTexel = diffuseTexture.sample(samplr, vert.texCoord);
    diffuseTexel = float4(diffuseTexel.rgb / diffuseTexel.a, diffuseTexel.a);
    
    float4 bumpNormal = bumpTexture.sample(samplr, vert.texCoord);
    float3 normal = bumpped_normal(vert.normal, vert.tangent, vert.bitangent, bumpNormal.xyz);
    
    return fragment_light_tex_materialed_common(outVert, normal, lighting, diffuseTexel,
                                                shadowMap, depthSamplr);
}


fragment float4 fragment_tex_materialed_bump(ProjectedVertex vert [[stage_in]],
                                             constant LightUniform &lighting [[buffer(0)]],
                                             texture2d<float> shadowMap [[texture(0)]],
                                             texture2d<float> diffuseTexture [[texture(1)]],
                                             texture2d<float> bumpTexture [[texture(2)]],
                                             sampler depthSamplr [[sampler(0)]],
                                             sampler samplr [[sampler(1)]])
{
    VertexFragmentCharacters outVert = vertex_characters(vert);
    
    float4 diffuseTexel = diffuseTexture.sample(samplr, vert.texCoord);
    if (diffuseTexel.a < 1e-9)
        diffuseTexel.rgb = float3(1.0);
    else
        diffuseTexel = diffuseTexel / diffuseTexel.a;
    
    diffuseTexel.a = 1.0;
    float4 bumpNormal = bumpTexture.sample(samplr, vert.texCoord);
    float3 normal = bumpped_normal(vert.normal, vert.tangent, vert.bitangent, bumpNormal.xyz);
    
    return fragment_light_tex_materialed_common(outVert, normal, lighting, diffuseTexel,
                                                shadowMap, depthSamplr);
}


fragment float4 fragment_tex_materialed_tex_opacity_bump(ProjectedVertex vert [[stage_in]],
                                                         constant LightUniform &lighting [[buffer(0)]],
                                                         texture2d<float> shadowMap [[texture(0)]],
                                                         texture2d<float> diffuseTexture [[texture(1)]],
                                                         texture2d<float> opacityTexture [[texture(2)]],
                                                         texture2d<float> bumpTexture [[texture(3)]],
                                                         sampler depthSamplr [[sampler(0)]],
                                                         sampler samplr [[sampler(1)]])
{
    VertexFragmentCharacters outVert = vertex_characters(vert);
    
    float4 diffuseTexel = diffuseTexture.sample(samplr, vert.texCoord);
    float4 opacityTexel = opacityTexture.sample(samplr, vert.texCoord);
    diffuseTexel = diffuseTexel / diffuseTexel.a;
    diffuseTexel.a = opacityTexel.a;
    
    float4 bumpNormal = bumpTexture.sample(samplr, vert.texCoord);
    float3 normal = bumpped_normal(vert.normal, vert.tangent, vert.bitangent, bumpNormal.xyz);
    
    return fragment_light_tex_materialed_common(outVert, normal, lighting, diffuseTexel,
                                                shadowMap, depthSamplr);
}


VertexFragmentCharacters vertex_characters(ProjectedVertex vert)
{
    VertexFragmentCharacters outVert;
    
    outVert.eye = vert.eye;
    outVert.diffuseColor = vert.diffuseColor;
    outVert.ambientColor = vert.ambientColor;
    outVert.specularColor = vert.specularColor;
    outVert.specularPower = vert.specularPower;
    outVert.opacity = vert.dissolve;
    outVert.shadowPosition = vert.shadowPosition;
    
    return outVert;
}



float3 bumpped_normal(float3 normal, float3 tangent, float3 bitangent, float3 bumpNormal)
{
    bumpNormal = normalize((bumpNormal * 2. - float3(1.)));
    bumpNormal.y =  -bumpNormal.y;
    
    tangent = normalize(tangent);
    bitangent = normalize(bitangent);
    normal = normalize(normal);
    float3x3 m = { tangent, bitangent , normal };
    
    return normalize(m * bumpNormal);
}


