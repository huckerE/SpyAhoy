// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// modified to include cloud layers

Shader "Skybox/ProceduralPlusClouds" {
    Properties {
        [KeywordEnum(None, Simple, High Quality)] _SunDisk ("Sun", Int) = 2
        _SunSize ("Sun Size", Range(0,1)) = 0.04
        _SunSizeConvergence("Sun Size Convergence", Range(1,10)) = 5
    
        _AtmosphereThickness ("Atmosphere Thickness", Range(0,5)) = 1.0
        _SkyTint ("Sky Tint", Color) = (.5, .5, .5, 1)
        _GroundColor ("Ground", Color) = (.369, .349, .341, 1)
    
        _Exposure("Exposure", Range(0, 8)) = 1.3

        _OverheadCloudColor("Overhead Cloud Color", Color) = (1, 1, 1, 0.5)
        _OverheadCloudAltitude("Overhead Cloud Altitude", Float) = 1000
        _OverheadCloudSize("Overhead Cloud Size", Float) = 10
        _OverheadCloudAnimationSpeed("Overhead Cloud Animation Speed", Float) = 100
        _OverheadCloudFlowDirectionX("Overhead Cloud Flow X", Float) = 1
        _OverheadCloudFlowDirectionZ("Overhead Cloud Flow X", Float) = 1
        _OverheadCloudRemapMin("Overhead Cloud Remap Min", Float) = -0.5
        _OverheadCloudRemapMax("Overhead Cloud Remap Max", Float) = 1.5
    }
    
    SubShader {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off ZWrite Off
    
        Pass {
    
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
    
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
    
            #pragma multi_compile_local _SUNDISK_NONE _SUNDISK_SIMPLE _SUNDISK_HIGH_QUALITY
    
            uniform half _Exposure;     // HDR exposure
            uniform half3 _GroundColor;
            uniform half _SunSize;
            uniform half _SunSizeConvergence;
            uniform half3 _SkyTint;
            uniform half _AtmosphereThickness;
            uniform fixed4 _OverheadCloudColor;
            uniform fixed _OverheadCloudAltitude;
            uniform fixed _OverheadCloudSize;
            uniform fixed _OverheadCloudAnimationSpeed;
            uniform fixed _OverheadCloudFlowDirectionX;
            uniform fixed _OverheadCloudFlowDirectionZ;
            uniform fixed _OverheadCloudRemapMin;
            uniform fixed _OverheadCloudRemapMax;
    
        #if defined(UNITY_COLORSPACE_GAMMA)
            #define GAMMA 2
            #define COLOR_2_GAMMA(color) color
            #define COLOR_2_LINEAR(color) color*color
            #define LINEAR_2_OUTPUT(color) sqrt(color)
        #else
            #define GAMMA 2.2
            // HACK: to get gfx-tests in Gamma mode to agree until UNITY_ACTIVE_COLORSPACE_IS_GAMMA is working properly
            #define COLOR_2_GAMMA(color) ((unity_ColorSpaceDouble.r>2.0) ? pow(color,1.0/GAMMA) : color)
            #define COLOR_2_LINEAR(color) color
            #define LINEAR_2_LINEAR(color) color
        #endif
    
            // RGB wavelengths
            // .35 (.62=158), .43 (.68=174), .525 (.75=190)
            static const float3 kDefaultScatteringWavelength = float3(.65, .57, .475);
            static const float3 kVariableRangeForScatteringWavelength = float3(.15, .15, .15);
    
            #define OUTER_RADIUS 1.025
            static const float kOuterRadius = OUTER_RADIUS;
            static const float kOuterRadius2 = OUTER_RADIUS*OUTER_RADIUS;
            static const float kInnerRadius = 1.0;
            static const float kInnerRadius2 = 1.0;
    
            static const float kCameraHeight = 0.0001;
    
            #define kRAYLEIGH (lerp(0.0, 0.0025, pow(_AtmosphereThickness,2.5)))      // Rayleigh constant
            #define kMIE 0.0010             // Mie constant
            #define kSUN_BRIGHTNESS 20.0    // Sun brightness
    
            #define kMAX_SCATTER 50.0 // Maximum scattering value, to prevent math overflows on Adrenos
    
            static const half kHDSundiskIntensityFactor = 15.0;
            static const half kSimpleSundiskIntensityFactor = 27.0;
    
            static const half kSunScale = 400.0 * kSUN_BRIGHTNESS;
            static const float kKmESun = kMIE * kSUN_BRIGHTNESS;
            static const float kKm4PI = kMIE * 4.0 * 3.14159265;
            static const float kScale = 1.0 / (OUTER_RADIUS - 1.0);
            static const float kScaleDepth = 0.25;
            static const float kScaleOverScaleDepth = (1.0 / (OUTER_RADIUS - 1.0)) / 0.25;
            static const float kSamples = 2.0; // THIS IS UNROLLED MANUALLY, DON'T TOUCH
    
            #define MIE_G (-0.990)
            #define MIE_G2 0.9801
    
            #define SKY_GROUND_THRESHOLD 0.02
    
            // fine tuning of performance. You can override defines here if you want some specific setup
            // or keep as is and allow later code to set it according to target api
    
            // if set vprog will output color in final color space (instead of linear always)
            // in case of rendering in gamma mode that means that we will do lerps in gamma mode too, so there will be tiny difference around horizon
            // #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 0
    
        #ifndef SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
            #if defined(SHADER_API_MOBILE)
                #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 1
            #else
                #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 0
            #endif
        #endif
    
            // Calculates the Rayleigh phase function
            half getRayleighPhase(half eyeCos2)
            {
                return 0.75 + 0.75*eyeCos2;
            }
            half getRayleighPhase(half3 light, half3 ray)
            {
                half eyeCos = dot(light, ray);
                return getRayleighPhase(eyeCos * eyeCos);
            }
    
    
            struct appdata_t
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
    
            struct v2f
            {
                float4  pos             : SV_POSITION;
    
                // for HQ sun disk, we need vertex itself to calculate ray-dir per-pixel
                float3  vertex          : TEXCOORD0;
    
                // calculate sky colors in vprog
                half3   groundColor     : TEXCOORD1;
                half3   skyColor        : TEXCOORD2;
                half3   sunColor        : TEXCOORD3;
    
                UNITY_VERTEX_OUTPUT_STEREO
            };
    
    
            float scale(float inCos)
            {
                float x = 1.0 - inCos;
                return 0.25 * exp(-0.00287 + x*(0.459 + x*(3.83 + x*(-6.80 + x*5.25))));
            }
    
            v2f vert (appdata_t v)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                OUT.pos = UnityObjectToClipPos(v.vertex);
    
                float3 kSkyTintInGammaSpace = COLOR_2_GAMMA(_SkyTint); // convert tint from Linear back to Gamma
                float3 kScatteringWavelength = lerp (
                    kDefaultScatteringWavelength-kVariableRangeForScatteringWavelength,
                    kDefaultScatteringWavelength+kVariableRangeForScatteringWavelength,
                    half3(1,1,1) - kSkyTintInGammaSpace); // using Tint in sRGB gamma allows for more visually linear interpolation and to keep (.5) at (128, gray in sRGB) point
                float3 kInvWavelength = 1.0 / pow(kScatteringWavelength, 4);
    
                float kKrESun = kRAYLEIGH * kSUN_BRIGHTNESS;
                float kKr4PI = kRAYLEIGH * 4.0 * 3.14159265;
    
                float3 cameraPos = float3(0,kInnerRadius + kCameraHeight,0);    // The camera's current position
    
                // Get the ray from the camera to the vertex and its length (which is the far point of the ray passing through the atmosphere)
                float3 eyeRay = normalize(mul((float3x3)unity_ObjectToWorld, v.vertex.xyz));
    
                float far = 0.0;
                half3 cIn, cOut;
    
                if(eyeRay.y >= 0.0)
                {
                    // Sky
                    // Calculate the length of the "atmosphere"
                    far = sqrt(kOuterRadius2 + kInnerRadius2 * eyeRay.y * eyeRay.y - kInnerRadius2) - kInnerRadius * eyeRay.y;
    
                    float3 pos = cameraPos + far * eyeRay;
    
                    // Calculate the ray's starting position, then calculate its scattering offset
                    float height = kInnerRadius + kCameraHeight;
                    float depth = exp(kScaleOverScaleDepth * (-kCameraHeight));
                    float startAngle = dot(eyeRay, cameraPos) / height;
                    float startOffset = depth*scale(startAngle);
    
    
                    // Initialize the scattering loop variables
                    float sampleLength = far / kSamples;
                    float scaledLength = sampleLength * kScale;
                    float3 sampleRay = eyeRay * sampleLength;
                    float3 samplePoint = cameraPos + sampleRay * 0.5;
    
                    // Now loop through the sample rays
                    float3 frontColor = float3(0.0, 0.0, 0.0);
                    // Weird workaround: WP8 and desktop FL_9_3 do not like the for loop here
                    // (but an almost identical loop is perfectly fine in the ground calculations below)
                    // Just unrolling this manually seems to make everything fine again.
    //              for(int i=0; i<int(kSamples); i++)
                    {
                        float height = length(samplePoint);
                        float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                        float lightAngle = dot(_WorldSpaceLightPos0.xyz, samplePoint) / height;
                        float cameraAngle = dot(eyeRay, samplePoint) / height;
                        float scatter = (startOffset + depth*(scale(lightAngle) - scale(cameraAngle)));
                        float3 attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
    
                        frontColor += attenuate * (depth * scaledLength);
                        samplePoint += sampleRay;
                    }
                    {
                        float height = length(samplePoint);
                        float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                        float lightAngle = dot(_WorldSpaceLightPos0.xyz, samplePoint) / height;
                        float cameraAngle = dot(eyeRay, samplePoint) / height;
                        float scatter = (startOffset + depth*(scale(lightAngle) - scale(cameraAngle)));
                        float3 attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
    
                        frontColor += attenuate * (depth * scaledLength);
                        samplePoint += sampleRay;
                    }
    
    
    
                    // Finally, scale the Mie and Rayleigh colors and set up the varying variables for the pixel shader
                    cIn = frontColor * (kInvWavelength * kKrESun);
                    cOut = frontColor * kKmESun;
                }
                else
                {
                    // Ground
                    far = (-kCameraHeight) / (min(-0.001, eyeRay.y));
    
                    float3 pos = cameraPos + far * eyeRay;
    
                    // Calculate the ray's starting position, then calculate its scattering offset
                    float depth = exp((-kCameraHeight) * (1.0/kScaleDepth));
                    float cameraAngle = dot(-eyeRay, pos);
                    float lightAngle = dot(_WorldSpaceLightPos0.xyz, pos);
                    float cameraScale = scale(cameraAngle);
                    float lightScale = scale(lightAngle);
                    float cameraOffset = depth*cameraScale;
                    float temp = (lightScale + cameraScale);
    
                    // Initialize the scattering loop variables
                    float sampleLength = far / kSamples;
                    float scaledLength = sampleLength * kScale;
                    float3 sampleRay = eyeRay * sampleLength;
                    float3 samplePoint = cameraPos + sampleRay * 0.5;
    
                    // Now loop through the sample rays
                    float3 frontColor = float3(0.0, 0.0, 0.0);
                    float3 attenuate;
    //              for(int i=0; i<int(kSamples); i++) // Loop removed because we kept hitting SM2.0 temp variable limits. Doesn't affect the image too much.
                    {
                        float height = length(samplePoint);
                        float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                        float scatter = depth*temp - cameraOffset;
                        attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
                        frontColor += attenuate * (depth * scaledLength);
                        samplePoint += sampleRay;
                    }
    
                    cIn = frontColor * (kInvWavelength * kKrESun + kKmESun);
                    cOut = clamp(attenuate, 0.0, 1.0);
                }
    
                OUT.vertex          = -eyeRay;
    
                // if we want to calculate color in vprog:
                // 1. in case of linear: multiply by _Exposure in here (even in case of lerp it will be common multiplier, so we can skip mul in fshader)
                // 2. in case of gamma and SKYBOX_COLOR_IN_TARGET_COLOR_SPACE: do sqrt right away instead of doing that in fshader
    
                OUT.groundColor = _Exposure * (cIn + COLOR_2_LINEAR(_GroundColor) * cOut);
                OUT.skyColor    = _Exposure * (cIn * getRayleighPhase(_WorldSpaceLightPos0.xyz, -eyeRay));
    
                // The sun should have a stable intensity in its course in the sky. Moreover it should match the highlight of a purely specular material.
                // This matching was done using the standard shader BRDF1 on the 5/31/2017
                // Finally we want the sun to be always bright even in LDR thus the normalization of the lightColor for low intensity.
                half lightColorIntensity = clamp(length(_LightColor0.xyz), 0.25, 1);
                OUT.sunColor    = kHDSundiskIntensityFactor * saturate(cOut) * _LightColor0.xyz / lightColorIntensity;
    
            #if defined(UNITY_COLORSPACE_GAMMA) && SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
                OUT.groundColor = sqrt(OUT.groundColor);
                OUT.skyColor    = sqrt(OUT.skyColor);
                #if SKYBOX_SUNDISK != SKYBOX_SUNDISK_NONE
                    OUT.sunColor= sqrt(OUT.sunColor);
                #endif
            #endif
    
                return OUT;
            }
    
    
            // Calculates the Mie phase function
            half getMiePhase(half eyeCos, half eyeCos2)
            {
                half temp = 1.0 + MIE_G2 - 2.0 * MIE_G * eyeCos;
                temp = pow(temp, pow(_SunSize,0.65) * 10);
                temp = max(temp,1.0e-4); // prevent division by zero, esp. in half precision
                temp = 1.5 * ((1.0 - MIE_G2) / (2.0 + MIE_G2)) * (1.0 + eyeCos2) / temp;
                #if defined(UNITY_COLORSPACE_GAMMA) && SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
                    temp = pow(temp, .454545);
                #endif
                return temp;
            }
    
            // Calculates the sun shape
            half calcSunAttenuation(half3 lightPos, half3 ray)
            {
                half focusedEyeCos = pow(saturate(dot(lightPos, ray)), _SunSizeConvergence);
                return getMiePhase(-focusedEyeCos, focusedEyeCos * focusedEyeCos);
            }

            // Graph Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Hashes.hlsl"
            
            // Graph Functions
            
            float Unity_SimpleNoise_ValueNoise_Deterministic_float (float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0; Hash_Tchou_2_1_float(c0, r0);
                float r1; Hash_Tchou_2_1_float(c1, r1);
                float r2; Hash_Tchou_2_1_float(c2, r2);
                float r3; Hash_Tchou_2_1_float(c3, r3);
                float bottomOfGrid = lerp(r0, r1, f.x);
                float topOfGrid = lerp(r2, r3, f.x);
                float t = lerp(bottomOfGrid, topOfGrid, f.y);
                return t;
            }
            
            void Unity_SimpleNoise_Deterministic_float(float2 UV, float Scale, out float Out)
            {
                float freq, amp;
                Out = 0.0f;
                freq = pow(2.0, float(0));
                amp = pow(0.5, float(3-0));
                Out += Unity_SimpleNoise_ValueNoise_Deterministic_float(float2(UV.xy*(Scale/freq)))*amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3-1));
                Out += Unity_SimpleNoise_ValueNoise_Deterministic_float(float2(UV.xy*(Scale/freq)))*amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3-2));
                Out += Unity_SimpleNoise_ValueNoise_Deterministic_float(float2(UV.xy*(Scale/freq)))*amp;
            }
    
            void CalculateOverheadCloudColor(fixed4 viewDir, fixed4 cloudColor,
                                             fixed cloudAltitude, fixed cloudSize,
                                             fixed animationSpeed, fixed flowX, fixed flowZ,
                                             fixed remapMin, fixed remapMax, out fixed4 color)
            {
                fixed3 rayDir = viewDir;
                float3 cloudPlaneOrigin = float3(0, cloudAltitude, 0);
                float3 cloudPlaneNormal = float3(0, 1, 0);

                float rayLength = cloudAltitude / dot(rayDir, cloudPlaneNormal); //potential div by zero;
                float3 intersectionPoint = rayDir * rayLength;
                fixed noise = 0;
                fixed sample = 0;
                fixed noiseSize = cloudSize * 1000;
                fixed noiseAmp = 1;
                fixed2 span = fixed2(flowX, flowZ) * animationSpeed * _Time.y * 0.0001;
                for (fixed i = 0; i < 4; ++i)
                {
                    Unity_SimpleNoise_Deterministic_float((intersectionPoint.xz) / noiseSize + span, 1, sample); //potential div by zero
                    sample *= noiseAmp; 
                    noise += sample;
                    noiseSize *= 0.5;
                    noiseAmp *= 0.5;
                }
                noise = noise * 0.5 + 0.5;
                noise = noise * cloudColor.a;
                noise = pow(noise, 4);
                noise = lerp(remapMin, remapMax, noise);
                noise = saturate(noise);

                color = fixed4(cloudColor.rgb, noise);
            }

            half4 frag (v2f IN) : SV_Target
            {
                half3 col = half3(0.0, 0.0, 0.0);
    
            // if y > 1 [eyeRay.y < -SKY_GROUND_THRESHOLD] - ground
            // if y >= 0 and < 1 [eyeRay.y <= 0 and > -SKY_GROUND_THRESHOLD] - horizon
            // if y < 0 [eyeRay.y > 0] - sky
            half3 ray = normalize(IN.vertex.xyz);
            half y = ray.y / SKY_GROUND_THRESHOLD;
    
            // if we did precalculate color in vprog: just do lerp between them
            col = lerp(IN.skyColor, IN.groundColor, saturate(y));

            if(y < 0.0)
            {
                col += IN.sunColor * calcSunAttenuation(_WorldSpaceLightPos0.xyz, -ray);
            }

            // Clouds
            fixed4 localPos = fixed4(IN.vertex.xyz, 1);
            fixed4 viewDir = fixed4(normalize(localPos.xyz), 1);
            fixed4 overheadCloudColor;
            CalculateOverheadCloudColor(
              viewDir,
              _OverheadCloudColor,
              _OverheadCloudAltitude,
              _OverheadCloudSize,
              _OverheadCloudAnimationSpeed,
              _OverheadCloudFlowDirectionX,
              _OverheadCloudFlowDirectionZ,
              _OverheadCloudRemapMin,
              _OverheadCloudRemapMax,
              overheadCloudColor);
            fixed4 clear = fixed4(0, 0, 0, 0);
            overheadCloudColor = lerp(clear, overheadCloudColor, smoothstep(0, -1, y)); 
            col += overheadCloudColor * overheadCloudColor.a;
    
            #if defined(UNITY_COLORSPACE_GAMMA) && !SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
                col = LINEAR_2_OUTPUT(col);
            #endif
    
                return half4(col,1.0);
    
            }
            ENDCG
        }
    }
    
    
    Fallback Off
    CustomEditor "SkyboxProceduralShaderGUI"
    }
    