//------------------------------------------- Defines -------------------------------------------

#define Pi 3.14159265

//------------------------------------- Top Level Variables -------------------------------------

// Top level variables can and have to be set at runtime

// Matrices for 3D perspective projection 
float4x4 View, Projection, World;
// Matrix for inverse transpose of world. Used for correct normals calculations.
float4x4 WorldInverseTranspose;

// Variables for ambient lighting.
float4 AmbientColor;
float AmbientIntensity;

// Variables for diffuse (Lambertian) lighting.
float3 LightSourceDirection;
float4 DiffuseColor;
// This intensity approaches the lighting as in the assignment.
float DiffuseIntensity = 0.5;

// Variables for specular (Blinn-Phong) lighting.
float4 SpecularColor;
float SpecularIntensity;
float SpecularPower;
float3 ViewVector;

//---------------------------------- Input / Output structures ----------------------------------

// Each member of the struct has to be given a "semantic", to indicate what kind of data should go in
// here and how it should be treated. Read more about the POSITION0 and the many other semantics in 
// the MSDN library
struct VertexShaderInput
{
	float4 Position3D : POSITION0;
	float4 Normal : NORMAL0;
};

// The output of the vertex shader. After being passed through the interpolator/rasterizer it is also 
// the input of the pixel shader. 
// Note 1: The values that you pass into this struct in the vertex shader are not the same as what 
// you get as input for the pixel shader. A vertex shader has a single vertex as input, the pixel 
// shader has 3 vertices as input, and lets you determine the color of each pixel in the triangle 
// defined by these three vertices. Therefore, all the values in the struct that you get as input for 
// the pixel shaders have been linearly interpolated between there three vertices!
// Note 2: You cannot use the data with the POSITION0 semantic in the pixel shader.
struct VertexShaderOutput
{
	float4 Position2D : POSITION0;
	float4 Color: COLOR0;
	float4 Normal : TEXCOORD0;
	// Storing the 3D position in TEXCOORD1, because the POSITION0 semantic cannot be used in the pixel shader.
	float4 Position3D : TEXCOORD1;
};

//------------------------------------------ Functions ------------------------------------------

// Implement the Coloring using normals assignment here
float4 NormalColor(float4 normal)
{
	// The output color is based on the normals. Alpha is set to 1.
	float4 color = float4(normal.x, normal.y, normal.z, 1);

	return color;
}

// Implement the Procedural texturing assignment here
float4 ProceduralColor(float4 normal, float4 position)
{
	float4 color;
	// The width of the stripes is adjustable. A value between 0.05 and 1.0 is recommended.
	// In case of a checkerboard pattern, this is the square size.
	float stripeWidth = 0.25f;
	// Use this line to create a vertical stripe pattern.
	//if (sin((Pi * position.x) / stripeWidth) > 0)
	// Use these lines to create a checkerboard pattern.
	int i = (int)(position.x / stripeWidth) + (int)(position.y / stripeWidth);
	if (fmod(i, 2) == 0)
	//if (((int)(2 * position.x) + (int)position.y) & 1 > 0)
		color = NormalColor(normal);
	else
		color = NormalColor(float4(-normal.x, -normal.y, -normal.z, -normal.w));
	return color;
}

//---------------------------------------- Technique: Simple ----------------------------------------

VertexShaderOutput SimpleVertexShader(VertexShaderInput input)
{
	// Allocate an empty output struct.
	VertexShaderOutput output = (VertexShaderOutput)0;

	// Do the matrix multiplications for perspective projection and the world transform.
	float4 worldPosition = mul(input.Position3D, World);
	float4 viewPosition = mul(worldPosition, View);
	output.Position2D = mul(viewPosition, Projection);

	// Relay the input normals.
	output.Normal = input.Normal;

	// Use these two lines for NormalColor and ProceduralColor, comment out otherwise.
	//output.Color = input.Normal;
	// Relay the POSITION0 information to the TEXCOORD1 semantic, for use in the pixel shader.
	//output.Position3D = input.Position3D;

	// Extract the top-left of the world matrix.
	float3x3 rotationAndScale = (float3x3) World;
	float3 normal = mul(input.Normal, rotationAndScale);
	//float3 normal = mul(input.Normal, WorldInverseTranspose);
	normal = normalize(normal);
	// The color is proportional to the angle between the surface normal and direction to the light source.
	// Surfaces pointing away from the light do not receive any light.
	float lightIntensity = max(0, dot(normal, -LightSourceDirection));
	// Take the diffuse color and intensity into account.
	output.Color = saturate(DiffuseColor * DiffuseIntensity * lightIntensity);

	return output;
}

float4 SimplePixelShader(VertexShaderOutput input) : COLOR0
{
	// Use these two for NormalColor and ProceduralColor, comment out otherwise.
	//float4 color = NormalColor(input.Normal);
	//float4 color = ProceduralColor(input.Normal, input.Position3D);

	// The ambient color is the same everywhere: a predefined color at a certain intensity.
	float4 ambient = AmbientColor * AmbientIntensity;

	// The light vector l is the direction from the location to the light.
	float3 l = normalize(-LightSourceDirection);
	// The normal vector n denotes the normal of the surface.
	float3 n = normalize(input.Normal);
	// Calculate the half vector, which is the bisector of the angle between the view vector v and light vector l.
	float3 h = normalize(l + ViewVector);
	float4 specular = SpecularColor * SpecularIntensity * pow(max(0, dot(n, h)), SpecularPower);
	/*
	???Failing code??? Deprecated
	float3 r = normalize(2 * dot(light, normal) * normal + light);
	float3 v = normalize(mul(normalize(ViewVector), World));

	float RdotV = dot(r, v);
	float4 specular = SpecularIntensity * SpecularColor * max(pow(abs(RdotV), SpecularPower), 0) * length(input.Color);
	*/

	// Add the ambient and specular light to the already calculated diffuse light.
	float4 color = saturate(input.Color + ambient + specular);

	return color;
}

technique Simple
{
	pass Pass0
	{
		VertexShader = compile vs_2_0 SimpleVertexShader();
		PixelShader = compile ps_2_0 SimplePixelShader();
	}
}