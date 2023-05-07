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
  vertices : [] Vertex;
  index_count : u32;
  indices  : [] u32;

  // Optional?
  primitive_type : PrimitiveType = .POINTS;
}

Vertex :: struct {
  position  : Vector3; // Position of vertex
  
  normal    : Vector3; // TBN Matrix information for Normal Mapping later.
  // bitangent : Vector3;
  // tangent   : Vector3;

  // texutre   : Vector2; // UV coordinates

  // TODO bone weights and indices.
}

// Mesh Loader.
load_mesh :: () -> Mesh {
  mesh : Mesh;

  mesh.vertices = NewArray(4, Vertex);
  mesh.vertices[0] = .{.{-0.5, -0.5, 0.0}, .{1.0, 0.0, 0.0}};
  mesh.vertices[1] = .{.{ 0.5, -0.5, 0.0}, .{0.0, 1.0, 0.0}};
  mesh.vertices[2] = .{.{ 0.5,  0.5, 0.0}, .{0.0, 0.0, 1.0}};
  mesh.vertices[3] = .{.{-0.5,  0.5, 0.0}, .{1.0, 1.0, 1.0}};

  mesh.indices = u32.[0, 1, 2, 2, 3, 0];
  
  mesh.vertex_count = xx mesh.vertices.count;
  mesh.index_count = xx mesh.indices.count;

  return mesh;
}

get_binding_description :: () -> VkVertexInputBindingDescription {
  binding_description : VkVertexInputBindingDescription;  
  binding_description.binding = 0; // Layout location?
  binding_description.stride = size_of(Vertex);
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