// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "RED_SIM/Water/Surface Uber Caustics"
{
	Properties
	{
		[Header(Color Settings)]_Color("Color", Color) = (1,1,1,0)
		_Tint("Tint", Color) = (0,0,0,0)
		_ColorFar("Color Far", Color) = (0.1058824,0.5686275,0.7568628,0)
		_ColorClose("Color Close", Color) = (0,0.2196079,0.2627451,0)
		_GradientRadiusFar("Gradient Radius Far", Range( 0 , 2)) = 1.2
		_GradientRadiusClose("Gradient Radius Close", Range( 0 , 1)) = 0.3
		_WaterGradientContrast("Water Gradient Contrast", Range( 0 , 1)) = 0
		_ColorSaturation("Color Saturation", Range( 0 , 2)) = 1
		_ColorContrast("Color Contrast", Range( 0 , 3)) = 1
		[Header(Normal Settings)]_Normal("Normal", 2D) = "bump" {}
		_Normal2nd("Normal 2nd", 2D) = "bump" {}
		_Smoothness("Smoothness", Range( 0 , 1)) = 0.8
		_NormalPower("Normal Power", Range( 0 , 1)) = 1
		_NormalPower2nd("Normal Power 2nd", Range( 0 , 1)) = 0.5
		_Refraction("Refraction", Range( 0 , 1)) = 0.01
		_Refraction2nd("Refraction 2nd", Range( 0 , 1)) = 0.01
		_RefractionDistanceFade("Refraction Distance Fade", Range( 0 , 1)) = 0.6
		[Header(Animation Settings)]_RipplesSpeed("Ripples Speed", Float) = 1
		_RipplesSpeed2nd("Ripples Speed 2nd", Float) = 1
		_SpeedX("Speed X", Float) = 0
		_SpeedY("Speed Y", Float) = 0
		[Header(Depth Settings)]_Depth("Depth", Float) = 0.5
		_DepthColorGradation("Depth Color Gradation", Range( 0 , 2)) = 1
		_DepthSaturation("Depth Saturation", Range( 0 , 1)) = 0
		[Header(Visual Fixes)]_DepthSmoothing("Depth Smoothing", Range( 0 , 1)) = 0.5
		_IntersectionSmoothing("Intersection Smoothing", Range( 0 , 0.1)) = 0.02
		[IntRange]_EdgeMaskShiftpx("Edge Mask Shift (px)", Range( 0 , 3)) = 2
		[Toggle]_FixUnderwaterEdges("Fix Underwater Edges", Float) = 1
		[Toggle]_ZWrite("ZWrite", Float) = 1
		[Header(Caustics)]_CausticsPower("Caustics Power", Range( 0 , 5)) = 0
		_CausticsSize("Caustics Size", Float) = 20
		_CausticsSpeed("Caustics Speed", Float) = 1
		_CausticsDispersion("Caustics Dispersion", Range( 0 , 1)) = 0.25
		_CausticsRefractionSize("Caustics Refraction Size", Range( 0 , 1)) = 1
		_CausticsRefractionPower("Caustics Refraction Power", Range( 0 , 1)) = 0.5
		[NoScaleOffset]_CausticsRefractionNormal("Caustics Refraction Normal", 2D) = "bump" {}
		_CausticsDarknessLimit("Caustics Darkness Limit", Range( 0 , 1)) = 0
		_CausticsBrightnessGradation("Caustics Brightness Gradation", Range( 0 , 1)) = 0
		_CausticsDirection("Caustics Direction", Vector) = (0,0,0,0)
		[Toggle]_MatchCausticsDirectionWithLightSource("Match Caustics Direction With Light Source", Float) = 0
		[Header(Foam)]_FoamColor("Foam Color", Color) = (0,0,0,0)
		_FoamSmoothness("Foam Smoothness", Range( 0 , 1)) = 0.5
		_FoamMaskDistortionPower("Foam Mask Distortion Power", Range( 0 , 2)) = 1
		_FoamDistortionPower("Foam Distortion Power", Range( 0 , 2)) = 1
		_FoamTexture("Foam Texture", 2D) = "white" {}
		_FoamMaskSize("Foam Mask Size", Float) = 0.05
		_FoamGradation("Foam Gradation", Range( 0 , 15)) = 6
		_FoamTexture2nd("Foam Texture 2nd", 2D) = "white" {}
		_FoamSize2nd("Foam Size 2nd", Float) = 0.15
		_FoamGradation2nd("Foam Gradation 2nd", Range( 0 , 15)) = 15
		_RoatationAnimationRadius("Roatation Animation Radius", Float) = 0.2
		_RotationAnimationSpeed("Rotation Animation Speed", Float) = 1
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
		[Header(Forward Rendering Options)]
		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[ToggleOff] _GlossyReflections("Reflections", Float) = 1.0
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+2" "IgnoreProjector" = "True" "IsEmissive" = "true"  }
		Cull Back
		ZWrite [_ZWrite]
		GrabPass{ }
		GrabPass{ "_GrabWater" }
		CGPROGRAM
		#include "UnityStandardUtils.cginc"
		#include "UnityShaderVariables.cginc"
		#include "UnityCG.cginc"
		#pragma target 5.0
		#pragma shader_feature _SPECULARHIGHLIGHTS_OFF
		#pragma shader_feature _GLOSSYREFLECTIONS_OFF
		#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
		#define ASE_DECLARE_SCREENSPACE_TEXTURE(tex) UNITY_DECLARE_SCREENSPACE_TEXTURE(tex);
		#else
		#define ASE_DECLARE_SCREENSPACE_TEXTURE(tex) UNITY_DECLARE_SCREENSPACE_TEXTURE(tex)
		#endif
		#pragma surface surf Standard keepalpha noshadow exclude_path:deferred vertex:vert alpha:fade
		struct Input
		{
			float2 uv_texcoord;
			float4 screenPos;
			float3 worldPos;
			float3 worldNormal;
    		float3 myColor;
			INTERNAL_DATA
		};

		#include "../../../../krajsy/NoiseFunctions.cginc"
		sampler2D _WaterState;

		float3 GetNormal(float3 worldPos, float epsilon)
		{
			// Current height
			float h = gnoise(worldPos.xz / 2.0 + _Time.x * 4.0);

			// Sample neighbors
			float hRight = gnoise((worldPos.xz + float2(epsilon, 0)) / 2.0 + _Time.x * 4.0);
			float hForward = gnoise((worldPos.xz + float2(0, epsilon)) / 2.0 + _Time.x * 4.0);

			// Compute gradient
			float dx = hRight - h;
			float dz = hForward - h;

			// Construct normal
			float3 normal = normalize(float3(-dx, 1.0, -dz));

			return normal;
		} 


		struct appdata
		{
			float4 vertex     : POSITION;
			float3 normal     : NORMAL;
			float4 tangent    : TANGENT;
			float4 texcoord   : TEXCOORD0;
			float4 texcoord1  : TEXCOORD1;
			float4 texcoord2  : TEXCOORD2;
			float4 texcoord3  : TEXCOORD3;
			float4 color      : COLOR;
			uint vertexID : SV_VertexID;
		};

		void vert(inout appdata v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			uint2 dim = 192;
			
			uint2 uv = uint2(v.vertexID % dim.x, v.vertexID / dim.x);
			float4 state = tex2Dlod(_WaterState, float4(float2(uv) / float2(dim), 0, 0));
			float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

			float waterSurfaceLevel = v.vertex.y - gnoise(worldPos.xz / 2 + _Time.x * 4) * 0.4 - 1 + state.x;

			v.vertex.y = waterSurfaceLevel;
			v.normal = GetNormal(worldPos, 0.1);
			o.myColor = float3(state.x, 0, 0);
		}

		uniform sampler2D _Normal;
		uniform float _NormalPower;
		uniform float _RipplesSpeed;
		uniform float4 _Normal_ST;
		uniform sampler2D _Sampler0409;
		uniform float _SpeedX;
		uniform float _SpeedY;
		uniform sampler2D _Normal2nd;
		uniform float _NormalPower2nd;
		uniform float _RipplesSpeed2nd;
		uniform float4 _Normal2nd_ST;
		uniform sampler2D _Sampler0410;
		uniform float4 _Tint;
		UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
		uniform float4 _CameraDepthTexture_TexelSize;
		uniform float _IntersectionSmoothing;
		ASE_DECLARE_SCREENSPACE_TEXTURE( _GrabWater )
		uniform float _ColorContrast;
		uniform float _FixUnderwaterEdges;
		uniform float _Refraction;
		uniform float _RefractionDistanceFade;
		uniform float _Refraction2nd;
		uniform float _DepthSmoothing;
		uniform float _EdgeMaskShiftpx;
		uniform float _Depth;
		uniform float _DepthColorGradation;
		uniform float _DepthSaturation;
		uniform float4 _Color;
		uniform float _CausticsSpeed;
		uniform float _CausticsSize;
		uniform float _MatchCausticsDirectionWithLightSource;
		uniform float3 _CausticsDirection;
		uniform float _CausticsRefractionPower;
		uniform sampler2D _CausticsRefractionNormal;
		uniform float _CausticsRefractionSize;
		uniform float _CausticsDispersion;
		uniform float _CausticsDarknessLimit;
		uniform float _CausticsBrightnessGradation;
		uniform float _CausticsPower;
		uniform float4 _ColorFar;
		uniform float4 _ColorClose;
		uniform float _WaterGradientContrast;
		uniform float _GradientRadiusFar;
		uniform float _GradientRadiusClose;
		uniform float _ColorSaturation;
		uniform float4 _FoamColor;
		uniform sampler2D _FoamTexture2nd;
		uniform float4 _FoamTexture2nd_ST;
		uniform float _FoamDistortionPower;
		uniform float _RoatationAnimationRadius;
		uniform float _RotationAnimationSpeed;
		uniform float _FoamMaskDistortionPower;
		uniform float _FoamSize2nd;
		uniform float _FoamGradation2nd;
		uniform sampler2D _FoamTexture;
		uniform float4 _FoamTexture_ST;
		uniform float _FoamMaskSize;
		uniform float _FoamGradation;
		uniform float _Smoothness;
		uniform float _FoamSmoothness;
		uniform float _ZWrite;


		inline float4 ASE_ComputeGrabScreenPos( float4 pos )
		{
			#if UNITY_UV_STARTS_AT_TOP
			float scale = -1.0;
			#else
			float scale = 1.0;
			#endif
			float4 o = pos;
			o.y = pos.w * 0.5f;
			o.y = ( pos.y - o.y ) * _ProjectionParams.x * scale + o.y;
			return o;
		}


		float3 HSVToRGB( float3 c )
		{
			float4 K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
			float3 p = abs( frac( c.xxx + K.xyz ) * 6.0 - K.www );
			return c.z * lerp( K.xxx, saturate( p - K.xxx ), c.y );
		}


		float3 RGBToHSV(float3 c)
		{
			float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			float4 p = lerp( float4( c.bg, K.wz ), float4( c.gb, K.xy ), step( c.b, c.g ) );
			float4 q = lerp( float4( p.xyw, c.r ), float4( c.r, p.yzx ), step( p.x, c.r ) );
			float d = q.x - min( q.w, q.y );
			float e = 1.0e-10;
			return float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
		}

		float2 voronoihash763( float2 p )
		{
			p = p - 1000 * floor( p / 1000 );
			p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
			return frac( sin( p ) *43758.5453);
		}


		float voronoi763( float2 v, float time, inout float2 id, float smoothness )
		{
			float2 n = floor( v );
			float2 f = frac( v );
			float F1 = 8.0;
			float F2 = 8.0; float2 mr = 0; float2 mg = 0;
			for ( int j = -1; j <= 1; j++ )
			{
				for ( int i = -1; i <= 1; i++ )
			 	{
			 		float2 g = float2( i, j );
			 		float2 o = voronoihash763( n + g );
					o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = g - f + o;
					float d = 0.5 * dot( r, r );
			 		if( d<F1 ) {
			 			F2 = F1;
			 			F1 = d; mg = g; mr = r; id = o;
			 		} else if( d<F2 ) {
			 			F2 = d;
			 		}
			 	}
			}
			return (F2 + F1) * 0.5;
		}


		float2 UnStereo( float2 UV )
		{
			#if UNITY_SINGLE_PASS_STEREO
			float4 scaleOffset = unity_StereoScaleOffset[ unity_StereoEyeIndex ];
			UV.xy = (UV.xy - scaleOffset.zw) / scaleOffset.xy;
			#endif
			return UV;
		}


		float2 voronoihash776( float2 p )
		{
			p = p - 1000 * floor( p / 1000 );
			p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
			return frac( sin( p ) *43758.5453);
		}


		float voronoi776( float2 v, float time, inout float2 id, float smoothness )
		{
			float2 n = floor( v );
			float2 f = frac( v );
			float F1 = 8.0;
			float F2 = 8.0; float2 mr = 0; float2 mg = 0;
			for ( int j = -1; j <= 1; j++ )
			{
				for ( int i = -1; i <= 1; i++ )
			 	{
			 		float2 g = float2( i, j );
			 		float2 o = voronoihash776( n + g );
					o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = g - f + o;
					float d = 0.5 * dot( r, r );
			 		if( d<F1 ) {
			 			F2 = F1;
			 			F1 = d; mg = g; mr = r; id = o;
			 		} else if( d<F2 ) {
			 			F2 = d;
			 		}
			 	}
			}
			return (F2 + F1) * 0.5;
		}


		float2 voronoihash780( float2 p )
		{
			p = p - 1000 * floor( p / 1000 );
			p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
			return frac( sin( p ) *43758.5453);
		}


		float voronoi780( float2 v, float time, inout float2 id, float smoothness )
		{
			float2 n = floor( v );
			float2 f = frac( v );
			float F1 = 8.0;
			float F2 = 8.0; float2 mr = 0; float2 mg = 0;
			for ( int j = -1; j <= 1; j++ )
			{
				for ( int i = -1; i <= 1; i++ )
			 	{
			 		float2 g = float2( i, j );
			 		float2 o = voronoihash780( n + g );
					o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = g - f + o;
					float d = 0.5 * dot( r, r );
			 		if( d<F1 ) {
			 			F2 = F1;
			 			F1 = d; mg = g; mr = r; id = o;
			 		} else if( d<F2 ) {
			 			F2 = d;
			 		}
			 	}
			}
			return (F2 + F1) * 0.5;
		}


		float4 CalculateContrast( float contrastValue, float4 colorTarget )
		{
			float t = 0.5 * ( 1.0 - contrastValue );
			return mul( float4x4( contrastValue,0,0,t, 0,contrastValue,0,t, 0,0,contrastValue,t, 0,0,0,1 ), colorTarget );
		}

		void surf( Input i , inout SurfaceOutputStandard o )
		{
			i.uv_texcoord = i.worldPos.xz * 0.04;

			float mulTime187 = _Time.y * _RipplesSpeed;
			float2 uv0_Normal = i.uv_texcoord * _Normal_ST.xy + _Normal_ST.zw;
			float2 panner22 = ( mulTime187 * float2( -0.04,0 ) + uv0_Normal);
			float mulTime395 = _Time.y * ( _SpeedX / (_Normal_ST.xy).x );
			float mulTime403 = _Time.y * ( _SpeedY / (_Normal_ST.xy).y );
			float2 appendResult402 = (float2(mulTime395 , mulTime403));
			float2 temp_output_422_0 = ( _Normal_ST.xy * appendResult402 );
			float2 panner19 = ( mulTime187 * float2( 0.03,0.03 ) + uv0_Normal);
			float3 temp_output_24_0 = BlendNormals( UnpackScaleNormal( tex2D( _Normal, ( panner22 + temp_output_422_0 ) ), _NormalPower ) , UnpackScaleNormal( tex2D( _Normal, ( panner19 + temp_output_422_0 ) ), _NormalPower ) );
			float mulTime323 = _Time.y * _RipplesSpeed2nd;
			float2 uv0_Normal2nd = i.uv_texcoord * _Normal2nd_ST.xy + _Normal2nd_ST.zw;
			float2 temp_output_397_0 = ( uv0_Normal2nd + float2( 0,0 ) );
			float2 panner320 = ( mulTime323 * float2( 0.03,0.03 ) + temp_output_397_0);
			float2 temp_output_423_0 = ( appendResult402 * _Normal2nd_ST.xy );
			float2 panner321 = ( mulTime323 * float2( -0.04,0 ) + temp_output_397_0);
			float3 temp_output_325_0 = BlendNormals( UnpackScaleNormal( tex2D( _Normal2nd, ( panner320 + temp_output_423_0 ) ), _NormalPower2nd ) , UnpackScaleNormal( tex2D( _Normal2nd, ( panner321 + temp_output_423_0 ) ), _NormalPower2nd ) );
			float3 NormalWater315 = BlendNormals( temp_output_24_0 , temp_output_325_0 );
			o.Normal = NormalWater315;

			#ifdef SHADER_API_MOBILE
			o.Albedo = _ColorClose;
			o.Alpha =  0.9;
			#else
			float4 ase_screenPos = float4( i.screenPos.xyz , i.screenPos.w + 0.00000000001 );
			float4 ase_screenPosNorm = ase_screenPos / ase_screenPos.w;
			ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
			float eyeDepth167 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_screenPosNorm.xy ));
			float temp_output_168_0 = ( eyeDepth167 - ase_screenPos.w );
			float smoothstepResult1050 = smoothstep( 0.0 , 1.0 , (0.0 + (temp_output_168_0 - 0.0) * (1.0 - 0.0) / (_IntersectionSmoothing - 0.0)));
			float IntersectSmoothing1052 = smoothstepResult1050;
			float4 lerpResult1045 = lerp( float4( 0,0,0,0 ) , _Tint , IntersectSmoothing1052);
			o.Albedo = lerpResult1045.rgb;
			float4 ase_grabScreenPos = ASE_ComputeGrabScreenPos( ase_screenPos );
			float4 screenColor1033 = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabWater,ase_grabScreenPos.xy/ase_grabScreenPos.w);
			float4 ase_grabScreenPosNorm = ase_grabScreenPos / ase_grabScreenPos.w;
			float temp_output_654_0 = ( _Refraction + 0.0001 );
			float3 ase_worldPos = i.worldPos;
			float CameraVertexDistance713 = pow( distance( _WorldSpaceCameraPos , ase_worldPos ) , _RefractionDistanceFade );
			float clampResult684 = clamp( ( pow( saturate( temp_output_654_0 ) , 2.0 ) / CameraVertexDistance713 ) , 0.0 , temp_output_654_0 );
			float RefractionPower682 = clampResult684;
			float temp_output_688_0 = ( _Refraction2nd + 0.0001 );
			float clampResult696 = clamp( ( pow( saturate( temp_output_688_0 ) , 2.0 ) / CameraVertexDistance713 ) , 0.0 , temp_output_688_0 );
			float RefractionPower2nd697 = clampResult696;
			float3 lerpResult710 = lerp( ( RefractionPower682 * temp_output_24_0 ) , ( temp_output_325_0 * RefractionPower2nd697 ) , float3( 0.5,0.5,0.5 ));
			float DepthSmoothing679 = saturate( (0.0 + (temp_output_168_0 - 0.0) * (1.0 - 0.0) / (_DepthSmoothing - 0.0)) );
			float2 appendResult742 = (float2((0.0 + (( 1.0 / ( atan( ( 1.0 / unity_CameraProjection[0].x ) ) * 2.0 ) ) - 0.0) * (1.0 - 0.0) / (UNITY_PI - 0.0)) , (0.0 + (( 1.0 / ( atan( ( 1.0 / unity_CameraProjection[1].y ) ) * 2.0 ) ) - 0.0) * (1.0 - 0.0) / (UNITY_PI - 0.0))));
			float2 FovFactor730 = appendResult742;
			float3 NormalShift237 = ( lerpResult710 * DepthSmoothing679 * float3( FovFactor730 ,  0.0 ) );
			float4 temp_output_214_0 = ( ase_grabScreenPosNorm + float4( NormalShift237 , 0.0 ) );
			float temp_output_436_0 = ( 1.0 / _ScreenParams.y );
			float2 appendResult251 = (float2(0.0 , -temp_output_436_0));
			float2 ShiftDown257 = ( appendResult251 * _EdgeMaskShiftpx );
			float eyeDepth472 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftDown257, 0.0 , 0.0 ) ).xy ));
			float DepthMaskDepth477 = _Depth;
			float2 appendResult254 = (float2(0.0 , temp_output_436_0));
			float2 ShiftUp258 = ( appendResult254 * _EdgeMaskShiftpx );
			float eyeDepth485 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftUp258, 0.0 , 0.0 ) ).xy ));
			float temp_output_435_0 = ( 1.0 / _ScreenParams.x );
			float2 appendResult255 = (float2(-temp_output_435_0 , 0.0));
			float2 ShiftLeft259 = ( appendResult255 * _EdgeMaskShiftpx );
			float eyeDepth491 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftLeft259, 0.0 , 0.0 ) ).xy ));
			float2 appendResult256 = (float2(temp_output_435_0 , 0.0));
			float2 ShiftRight260 = ( appendResult256 * _EdgeMaskShiftpx );
			float eyeDepth497 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftRight260, 0.0 , 0.0 ) ).xy ));
			float temp_output_505_0 = ( saturate( sign( ( 1.0 - (0.0 + (( eyeDepth472 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (DepthMaskDepth477 - 0.0)) ) ) ) * saturate( sign( ( 1.0 - (0.0 + (( eyeDepth485 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (DepthMaskDepth477 - 0.0)) ) ) ) * saturate( sign( ( 1.0 - (0.0 + (( eyeDepth491 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (DepthMaskDepth477 - 0.0)) ) ) ) * saturate( sign( ( 1.0 - (0.0 + (( eyeDepth497 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (DepthMaskDepth477 - 0.0)) ) ) ) );
			float eyeDepth554 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_grabScreenPosNorm.xy ));
			float DepthMaskUnderwater506 = (( _FixUnderwaterEdges )?( ( temp_output_505_0 - saturate( ( 1.0 - sign( ( 1.0 - (0.0 + (( eyeDepth554 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (DepthMaskDepth477 - 0.0)) ) ) ) ) ) ):( temp_output_505_0 ));
			float eyeDepth455 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_screenPosNorm.xy ));
			float eyeDepth440 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( ase_screenPosNorm + float4( NormalShift237 , 0.0 ) ).xy ));
			float eyeDepth212 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftDown257, 0.0 , 0.0 ) ).xy ));
			float eyeDepth271 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftUp258, 0.0 , 0.0 ) ).xy ));
			float eyeDepth275 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftLeft259, 0.0 , 0.0 ) ).xy ));
			float eyeDepth279 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( temp_output_214_0 + float4( ShiftRight260, 0.0 , 0.0 ) ).xy ));
			float DepthMask188 = ( 1.0 - saturate( ( ( 1.0 - saturate( (0.0 + (( eyeDepth212 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (1E-05 - 0.0)) ) ) + ( 1.0 - saturate( (0.0 + (( eyeDepth271 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (1E-05 - 0.0)) ) ) + ( 1.0 - saturate( (0.0 + (( eyeDepth275 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (1E-05 - 0.0)) ) ) + ( 1.0 - saturate( (0.0 + (( eyeDepth279 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (1E-05 - 0.0)) ) ) ) ) );
			float lerpResult453 = lerp( saturate( (0.0 + (( eyeDepth455 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (DepthMaskDepth477 - 0.0)) ) , saturate( (0.0 + (( eyeDepth440 - ase_grabScreenPos.a ) - 0.0) * (1.0 - 0.0) / (DepthMaskDepth477 - 0.0)) ) , DepthMask188);
			float smoothstepResult524 = smoothstep( 0.0 , 1.0 , pow( ( 1.0 - ( DepthMaskUnderwater506 * ( 1.0 - lerpResult453 ) ) ) , _DepthColorGradation ));
			float DepthHeightMap527 = smoothstepResult524;
			float lerpResult665 = lerp( 1.0 , _ColorContrast , DepthHeightMap527);
			float4 screenColor223 = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabWater,ase_grabScreenPos.xy/ase_grabScreenPos.w);
			float4 screenColor65 = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabWater,( float3( (ase_grabScreenPosNorm).xy ,  0.0 ) + NormalShift237 ).xy);
			float4 lerpResult224 = lerp( screenColor223 , screenColor65 , DepthMask188);
			float4 GrabbedColorCorrected956 = lerpResult224;
			float3 hsvTorgb574 = RGBToHSV( GrabbedColorCorrected956.rgb );
			float lerpResult578 = lerp( hsvTorgb574.y , ( hsvTorgb574.y * _DepthSaturation ) , DepthHeightMap527);
			float3 hsvTorgb575 = HSVToRGB( float3(hsvTorgb574.x,lerpResult578,hsvTorgb574.z) );
			float CausticsSpeed817 = _CausticsSpeed;
			float mulTime766 = _Time.y * CausticsSpeed817;
			float time763 = mulTime766;
			float3 temp_output_1_0_g87 = float3( 1,0,0 );
			float3 break3_g80 = radians( _CausticsDirection );
			float temp_output_4_0_g80 = cos( break3_g80.x );
			float3 appendResult10_g80 = (float3(( temp_output_4_0_g80 * cos( break3_g80.y ) ) , ( temp_output_4_0_g80 * sin( break3_g80.y ) ) , sin( break3_g80.x )));
			float3 temp_output_2_0_g87 = appendResult10_g80;
			float dotResult3_g87 = dot( temp_output_1_0_g87 , temp_output_2_0_g87 );
			float3 break19_g87 = cross( temp_output_1_0_g87 , temp_output_2_0_g87 );
			float4 appendResult23_g87 = (float4(break19_g87.x , break19_g87.y , break19_g87.z , ( dotResult3_g87 + 1.0 )));
			float4 normalizeResult24_g87 = normalize( appendResult23_g87 );
			float4 ifLocalVar25_g87 = 0;
			if( dotResult3_g87 <= 0.999999 )
				ifLocalVar25_g87 = normalizeResult24_g87;
			else
				ifLocalVar25_g87 = float4(0,0,0,1);
			float temp_output_4_0_g88 = ( UNITY_PI / 2.0 );
			float3 temp_output_8_0_g87 = cross( float3(1,0,0) , temp_output_1_0_g87 );
			float3 ifLocalVar10_g87 = 0;
			if( length( temp_output_8_0_g87 ) >= 1E-06 )
				ifLocalVar10_g87 = temp_output_8_0_g87;
			else
				ifLocalVar10_g87 = cross( float3(0,1,0) , temp_output_1_0_g87 );
			float3 normalizeResult13_g87 = normalize( ifLocalVar10_g87 );
			float3 break10_g88 = ( sin( temp_output_4_0_g88 ) * normalizeResult13_g87 );
			float4 appendResult8_g88 = (float4(break10_g88.x , break10_g88.y , break10_g88.z , cos( temp_output_4_0_g88 )));
			float4 ifLocalVar4_g87 = 0;
			if( dotResult3_g87 >= -0.999999 )
				ifLocalVar4_g87 = ifLocalVar25_g87;
			else
				ifLocalVar4_g87 = appendResult8_g88;
			float3 temp_output_1_0_g85 = float3( 0,1,0 );
			#if defined(LIGHTMAP_ON) && UNITY_VERSION < 560 //aseld
			float3 ase_worldlightDir = 0;
			#else //aseld
			float3 ase_worldlightDir = Unity_SafeNormalize( UnityWorldSpaceLightDir( ase_worldPos ) );
			#endif //aseld
			float3 appendResult912 = (float3(ase_worldlightDir.x , -ase_worldlightDir.y , ase_worldlightDir.z));
			float3 temp_output_2_0_g85 = appendResult912;
			float dotResult3_g85 = dot( temp_output_1_0_g85 , temp_output_2_0_g85 );
			float3 break19_g85 = cross( temp_output_1_0_g85 , temp_output_2_0_g85 );
			float4 appendResult23_g85 = (float4(break19_g85.x , break19_g85.y , break19_g85.z , ( dotResult3_g85 + 1.0 )));
			float4 normalizeResult24_g85 = normalize( appendResult23_g85 );
			float4 ifLocalVar25_g85 = 0;
			if( dotResult3_g85 <= 0.999999 )
				ifLocalVar25_g85 = normalizeResult24_g85;
			else
				ifLocalVar25_g85 = float4(0,0,0,1);
			float temp_output_4_0_g86 = ( UNITY_PI / 2.0 );
			float3 temp_output_8_0_g85 = cross( float3(1,0,0) , temp_output_1_0_g85 );
			float3 ifLocalVar10_g85 = 0;
			if( length( temp_output_8_0_g85 ) >= 1E-06 )
				ifLocalVar10_g85 = temp_output_8_0_g85;
			else
				ifLocalVar10_g85 = cross( float3(0,1,0) , temp_output_1_0_g85 );
			float3 normalizeResult13_g85 = normalize( ifLocalVar10_g85 );
			float3 break10_g86 = ( sin( temp_output_4_0_g86 ) * normalizeResult13_g85 );
			float4 appendResult8_g86 = (float4(break10_g86.x , break10_g86.y , break10_g86.z , cos( temp_output_4_0_g86 )));
			float4 ifLocalVar4_g85 = 0;
			if( dotResult3_g85 >= -0.999999 )
				ifLocalVar4_g85 = ifLocalVar25_g85;
			else
				ifLocalVar4_g85 = appendResult8_g86;
			float4 temp_output_2_0_g97 = (( _MatchCausticsDirectionWithLightSource )?( ifLocalVar4_g85 ):( ifLocalVar4_g87 ));
			float4 temp_output_1_0_g98 = temp_output_2_0_g97;
			float3 temp_output_7_0_g98 = (temp_output_1_0_g98).xyz;
			float4 temp_output_72_0_g95 = ( ase_grabScreenPosNorm + float4( NormalShift237 , 0.0 ) );
			float2 UV22_g96 = temp_output_72_0_g95.xy;
			float2 localUnStereo22_g96 = UnStereo( UV22_g96 );
			float2 break64_g95 = localUnStereo22_g96;
			float eyeDepth68_g95 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ase_screenPosNorm.xy ));
			float4 tex2DNode36_g95 = tex2D( _CameraDepthTexture, ( temp_output_72_0_g95 + ( eyeDepth68_g95 * 0.0 ) ).xy );
			#ifdef UNITY_REVERSED_Z
				float4 staticSwitch38_g95 = ( 1.0 - tex2DNode36_g95 );
			#else
				float4 staticSwitch38_g95 = tex2DNode36_g95;
			#endif
			float3 appendResult39_g95 = (float3(break64_g95.x , break64_g95.y , staticSwitch38_g95.r));
			float4 appendResult42_g95 = (float4((appendResult39_g95*2.0 + -1.0) , 1.0));
			float4 temp_output_43_0_g95 = mul( unity_CameraInvProjection, appendResult42_g95 );
			float4 appendResult49_g95 = (float4(( ( (temp_output_43_0_g95).xyz / (temp_output_43_0_g95).w ) * float3( 1,1,-1 ) ) , 1.0));
			float3 break8_g97 = mul( unity_CameraToWorld, appendResult49_g95 ).xyz;
			float4 appendResult9_g97 = (float4(break8_g97.x , break8_g97.y , break8_g97.z , 0.0));
			float4 temp_output_1_0_g99 = appendResult9_g97;
			float3 temp_output_7_0_g99 = (temp_output_1_0_g99).xyz;
			float4 temp_output_2_0_g99 = ( temp_output_2_0_g97 * float4(-1,-1,-1,1) );
			float temp_output_10_0_g99 = (temp_output_2_0_g99).w;
			float3 temp_output_3_0_g99 = (temp_output_2_0_g99).xyz;
			float temp_output_11_0_g99 = (temp_output_1_0_g99).w;
			float3 break17_g99 = ( ( temp_output_7_0_g99 * temp_output_10_0_g99 ) + cross( temp_output_1_0_g99.xyz , temp_output_2_0_g99.xyz ) + ( temp_output_3_0_g99 * temp_output_11_0_g99 ) );
			float dotResult16_g99 = dot( temp_output_7_0_g99 , temp_output_3_0_g99 );
			float4 appendResult18_g99 = (float4(break17_g99.x , break17_g99.y , break17_g99.z , ( ( temp_output_11_0_g99 * temp_output_10_0_g99 ) - dotResult16_g99 )));
			float4 temp_output_2_0_g98 = appendResult18_g99;
			float temp_output_10_0_g98 = (temp_output_2_0_g98).w;
			float3 temp_output_3_0_g98 = (temp_output_2_0_g98).xyz;
			float temp_output_11_0_g98 = (temp_output_1_0_g98).w;
			float3 break17_g98 = ( ( temp_output_7_0_g98 * temp_output_10_0_g98 ) + cross( temp_output_1_0_g98.xyz , temp_output_2_0_g98.xyz ) + ( temp_output_3_0_g98 * temp_output_11_0_g98 ) );
			float dotResult16_g98 = dot( temp_output_7_0_g98 , temp_output_3_0_g98 );
			float4 appendResult18_g98 = (float4(break17_g98.x , break17_g98.y , break17_g98.z , ( ( temp_output_11_0_g98 * temp_output_10_0_g98 ) - dotResult16_g98 )));
			float3 break753 = (appendResult18_g98).xyz;
			float2 appendResult755 = (float2(break753.x , break753.z));
			float2 OverlayUV799 = appendResult755;
			float mulTime806 = _Time.y * CausticsSpeed817;
			float2 panner808 = ( mulTime806 * float2( 0.03,0.03 ) + OverlayUV799);
			float2 panner807 = ( mulTime806 * float2( -0.04,0 ) + OverlayUV799);
			float2 CausticsNormalShift819 = (BlendNormals( UnpackScaleNormal( tex2D( _CausticsRefractionNormal, ( _CausticsRefractionSize * ( panner808 + float2( 0,0 ) ) ) ), _CausticsRefractionPower ) , UnpackScaleNormal( tex2D( _CausticsRefractionNormal, ( _CausticsRefractionSize * ( panner807 + float2( 0,0 ) ) ) ), _CausticsRefractionPower ) )).xy;
			float2 CausticsUV825 = (( ( _CausticsSize * ( OverlayUV799 + CausticsNormalShift819 ) ) + float2( 0,0 ) )).xy;
			float2 coords763 = CausticsUV825 * 1.0;
			float2 id763 = 0;
			float voroi763 = voronoi763( coords763, time763,id763, 0 );
			float time776 = ( mulTime766 + _CausticsDispersion );
			float2 coords776 = CausticsUV825 * 1.0;
			float2 id776 = 0;
			float voroi776 = voronoi776( coords776, time776,id776, 0 );
			float time780 = ( mulTime766 + ( _CausticsDispersion * 2.0 ) );
			float2 coords780 = CausticsUV825 * 1.0;
			float2 id780 = 0;
			float voroi780 = voronoi780( coords780, time780,id780, 0 );
			float3 appendResult777 = (float3(voroi763 , voroi776 , voroi780));
			float3 smoothstepResult770 = smoothstep( float3( 0,0,0 ) , float3( 1,1,1 ) , appendResult777);
			float3 hsvTorgb929 = RGBToHSV( GrabbedColorCorrected956.rgb );
			float3 Caustics791 = ( smoothstepResult770 * DepthSmoothing679 * saturate( (0.0 + (hsvTorgb929.z - _CausticsDarknessLimit) * (1.0 - 0.0) / (( _CausticsDarknessLimit + _CausticsBrightnessGradation ) - _CausticsDarknessLimit)) ) * _CausticsPower );
			float3 normalizeResult629 = normalize( NormalWater315 );
			float3 lerpResult632 = lerp( float3( 0,0,1 ) , normalizeResult629 , _WaterGradientContrast);
			float3 ase_worldViewDir = Unity_SafeNormalize( UnityWorldSpaceViewDir( ase_worldPos ) );
			float3 ase_worldNormal = WorldNormalVector( i, float3( 0, 0, 1 ) );
			float3 ase_worldTangent = WorldNormalVector( i, float3( 1, 0, 0 ) );
			float3 ase_worldBitangent = WorldNormalVector( i, float3( 0, 1, 0 ) );
			float3x3 ase_worldToTangent = float3x3( ase_worldTangent, ase_worldBitangent, ase_worldNormal );
			float3 ase_tanViewDir = mul( ase_worldToTangent, ase_worldViewDir );
			float dotResult627 = dot( lerpResult632 , ase_tanViewDir );
			float temp_output_537_0 = ( 1.0 - _GradientRadiusFar );
			float smoothstepResult536 = smoothstep( 0.0 , 1.0 , saturate( (0.0 + (dotResult627 - temp_output_537_0) * (1.0 - 0.0) / (( temp_output_537_0 + ( 1.0 - _GradientRadiusClose ) ) - temp_output_537_0)) ));
			float WaterSurfaceGradientMask540 = smoothstepResult536;
			float4 lerpResult542 = lerp( _ColorFar , _ColorClose , WaterSurfaceGradientMask540);
			float4 lerpResult448 = lerp( ( ( float4( hsvTorgb575 , 0.0 ) * _Color ) + float4( Caustics791 , 0.0 ) ) , lerpResult542 , DepthHeightMap527);
			float3 hsvTorgb656 = RGBToHSV( lerpResult448.rgb );
			float lerpResult666 = lerp( 1.0 , _ColorSaturation , DepthHeightMap527);
			float3 hsvTorgb657 = HSVToRGB( float3(hsvTorgb656.x,( hsvTorgb656.y * lerpResult666 ),hsvTorgb656.z) );
			float2 uv0_FoamTexture2nd = i.uv_texcoord * _FoamTexture2nd_ST.xy + _FoamTexture2nd_ST.zw;
			float3 NormalShiftSource982 = lerpResult710;
			float3 FoamUVShift992 = ( _FoamDistortionPower * NormalShiftSource982 );
			float mulTime1017 = _Time.y * _RotationAnimationSpeed;
			float2 appendResult1023 = (float2(( _RoatationAnimationRadius * cos( mulTime1017 ) ) , ( _RoatationAnimationRadius * sin( mulTime1017 ) )));
			float eyeDepth963 = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, ( float4( ( NormalShiftSource982 * float3( ( _FoamMaskDistortionPower * FovFactor730 ) ,  0.0 ) ) , 0.0 ) + ase_screenPosNorm ).xy ));
			float temp_output_977_0 = abs( ( eyeDepth963 - ase_screenPos.w ) );
			float smoothstepResult999 = smoothstep( 1.0 , 0.0 , pow( (0.0 + (temp_output_977_0 - 0.0) * (1.0 - 0.0) / (_FoamSize2nd - 0.0)) , _FoamGradation2nd ));
			float FoamMask2nd1000 = smoothstepResult999;
			float2 uv0_FoamTexture = i.uv_texcoord * _FoamTexture_ST.xy + _FoamTexture_ST.zw;
			float smoothstepResult976 = smoothstep( 1.0 , 0.0 , pow( (0.0 + (temp_output_977_0 - 0.0) * (1.0 - 0.0) / (_FoamMaskSize - 0.0)) , _FoamGradation ));
			float FoamMask984 = smoothstepResult976;
			float lerpResult1005 = lerp( ( tex2D( _FoamTexture2nd, ( float3( uv0_FoamTexture2nd ,  0.0 ) + FoamUVShift992 + float3( appendResult1023 ,  0.0 ) ).xy ).r * FoamMask2nd1000 ) , tex2D( _FoamTexture, ( float3( uv0_FoamTexture ,  0.0 ) + FoamUVShift992 + float3( appendResult1023 ,  0.0 ) ).xy ).r , FoamMask984);
			float FoamFinal1013 = lerpResult1005;
			float4 lerpResult987 = lerp( CalculateContrast(lerpResult665,float4( hsvTorgb657 , 0.0 )) , _FoamColor , ( _FoamColor.a * FoamFinal1013 ));
			float4 lerpResult1041 = lerp( screenColor1033 , lerpResult987 , lerp(0, IntersectSmoothing1052, i.myColor.x));


			half nl = max(0.3, dot(float3(0,1,0), _WorldSpaceLightPos0.xyz));
			float4 diff = nl * (_LightColor0 * 0.9 + 0.1);

			o.Emission = lerpResult1041.rgb * diff.rgb;
			float lerpResult1024 = lerp( _Smoothness , _FoamSmoothness , FoamFinal1013);
			float lerpResult1047 = lerp( 1.0 , ( lerpResult1024 + ( _ZWrite * 0.0 ) ) , IntersectSmoothing1052);
			o.Smoothness = lerpResult1047 * i.myColor.x;
			o.Occlusion = IntersectSmoothing1052;
			o.Alpha =  i.myColor.x;
			#endif
		}

		ENDCG
	}
}