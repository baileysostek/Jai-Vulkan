#import "Math";
#import "Basic";
#import "Vulkan";

// Store the different ways that we could render a mesh in.
PrimitiveType :: enum u32 {
  POINTS          :: 0;

  LINES           :: 1;
  LINE_LOOP       :: 2;
  LINE_STRIP      :: 3;

  TRIANGLES       :: 4;
  TRIANGLE_STRIP  :: 5;
  TRIANGLE_FAN    :: 6;
}

Mesh :: struct {
  vertex_count : u32;
  vertices : [] Vector3;
  
  // Per Face
  normal     : [] Vector3;
  bitangent  : [] Vector3;
  tangent    : [] Vector3;

  index_count : u32;
  indices  : [] u32;

  primitive_type : PrimitiveType = .POINTS;
}

// Anything that is the same for each vertex independant of a face goes in here. 
// Position
// Texture Coordinate
// Vertex :: struct {
//   position  : Vector3; // Position of vertex
//   // texutre   : Vector2; // UV coordinates
//   normal    : Vector3; 

// }

// Mesh Loader.
load_mesh :: () -> Mesh {
  mesh : Mesh;

  mesh.vertices = NewArray(8, Vector3);
  mesh.vertices[0] = .{-0.5, -0.5, -0.5};
  mesh.vertices[1] = .{ 0.5, -0.5, -0.5};
  mesh.vertices[2] = .{ 0.5,  0.5, -0.5};
  mesh.vertices[3] = .{-0.5,  0.5, -0.5};
  mesh.vertices[4] = .{-0.5, -0.5,  0.5};
  mesh.vertices[5] = .{ 0.5, -0.5,  0.5};
  mesh.vertices[6] = .{ 0.5,  0.5,  0.5};
  mesh.vertices[7] = .{-0.5,  0.5,  0.5};

  mesh.indices = u32.[
    0, 1, 2, 2, 3, 0, // Front
    5, 4, 7, 7, 6, 5, // Back
    4, 0, 3, 3, 7, 4, // Left
    1, 5, 6, 6, 2, 1, // Right
    4, 5, 1, 1, 0, 4, // Top
    3, 2, 6, 6, 7, 3  // Bottom
  ];
  
  mesh.vertex_count = xx mesh.vertices.count;
  mesh.index_count  = xx mesh.indices.count;

  return mesh;
}

get_binding_description :: () -> VkVertexInputBindingDescription {
  binding_description : VkVertexInputBindingDescription;  
  binding_description.binding = 0; // Layout location?
  binding_description.stride = size_of(Vector3);
  binding_description.inputRate = .VK_VERTEX_INPUT_RATE_VERTEX; // One Vertex Per Vertex.
  return binding_description;
}

// The 2 here is because we have 2 in attributes to our shader.
get_attribute_descriptions :: () -> [2] VkVertexInputAttributeDescription {
  attribute_descriptions : [2] VkVertexInputAttributeDescription;

  attribute_descriptions[0].binding = 0;
  attribute_descriptions[0].location = 0;
  attribute_descriptions[0].format = .VK_FORMAT_R32G32B32_SFLOAT;
  attribute_descriptions[0].offset = 0;
  
  attribute_descriptions[1].binding = 0;
  attribute_descriptions[1].location = 1;
  attribute_descriptions[1].format = .VK_FORMAT_R32G32B32_SFLOAT;
  attribute_descriptions[1].offset = size_of(Vector3); // Offset by the size of 1 vec3.

  return attribute_descriptions;
}