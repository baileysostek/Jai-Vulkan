#import "Math";
#import "Basic";
#import "Vulkan";
#import "Hash_Table";
#import "Hash";
#import "String";

// Store a Cache of Models
cached_models := Table(string, Mesh);

UNIT_CUBE :: #run generate_unit_cube();

// has_mesh :: (name : string) -> bool {
//   return table_contains(*cached_models, name);
// }

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
  // Bones data?

  // Animation Data?

  // Preferred Material Data?

  // Per Vertex
  vertex_count : u32;
  vertices : [] Vector3;
  
  // Indices list
  index_count : u32;
  indices  : [] u32; // Refactor to vec3i index_vertex, index_normal|tangent|bitangent, index_uv

  // Per Index
  normal     : [] Vector3;
  bitangent  : [] Vector3;
  tangent    : [] Vector3;

  // The rendering strategy we should use for this mesh.
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

// Prebuilt Meshes:
generate_unit_cube :: () -> Mesh {
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

// Mesh Loader.
load_mesh :: (file_path : string) -> bool, Mesh {

  // Try to load the file.
  file_contents, success := read_entire_file(file_path);
  if !success then return false, UNIT_CUBE; // Could not load mesh
  defer free(file_contents);

  // We loaded a file, lets see
  print("loaded:%, content_size:%\n", file_path, file_contents.count);

  // Now we need to determine the file extension
  file_extension_index := find_index_from_right(file_path, ".");
  file_extension := slice(file_path, file_extension_index, (file_path.count - file_extension_index));
  print("Extension: %\n", file_extension);

  // Placeholder mesh
  mesh := UNIT_CUBE;

  // Determine if we have a loader for this kind of file extension.
  if file_extension == {
    case ".obj";
      mesh = load_obj(file_contents);
    case;
      print("No loader defiend for file extension:%\n", file_extension);
  }

  return true, mesh;
}

load_obj :: (file_data : string) -> Mesh {
  // This is the mesh we are building uyp in this loader.
  mesh := Mesh.{};

  // First we will determine how many vertices we have in this file.
  lines := split(file_data, "\n");
  normal_count  : s32 = 0;
  uv_count      : s32 = 0;
  face_count    : s32 = 0;

  // First pass is just counting all of the various components.
  for lines {
    line := it;
    data_type_index := find_index_from_left(line, " ");
    if data_type_index < 0 continue;
    data_type := slice(line, 0, data_type_index);
    if data_type == {
      case "v";   // Vertex
        mesh.vertex_count += 1;
      case "vt";  // Vertex Texture Coordinate
        uv_count += 1;
      case "vn";  // Vertex Normal
        normal_count += 1;
      case "vp";  // Parameter space vertices in (u, [v, w]) form; free form geometry statement
        continue;
      case "f";  // Vertex Normal
        // These might not be triangles so we need to check.
        face_data := slice(line, data_type_index + 1, (line.count - (data_type_index + 1)));
        tringles_in_face : u32 = xx (split(face_data, " ").count - 2);
        face_count += xx tringles_in_face;
    }
  }

  print("Vertices:%\n", mesh.vertex_count);
  print("Normals:%\n", normal_count);
  print("Texture Coords:%\n", uv_count);
  print("Faces:%\n", face_count);

  // Define an array for our normals
  normals := NewArray(normal_count, Vector3);
  defer free(normals.data);

  // Now we can allocate arrays of the correct size.
  mesh.vertices = NewArray(mesh.vertex_count, Vector3);

  // Compute the indices
  mesh.index_count = xx (face_count * 3); // 3 indices per triangle.
  mesh.indices = NewArray(mesh.index_count, u32);

  // Indices used to index into the arrays correctly.
  vertex_index := 0;
  texture_index := 0;
  normal_index := 0;
  face_index := 0;
  
  // Second iteration through the data, this time we can build our mesh.
  for lines {
    line := it;
    data_type_index := find_index_from_left(line, " ");
    if data_type_index < 0 continue;
    data_type := slice(line, 0, data_type_index);
    line_data := split(slice(line, data_type_index + 1, (line.count - (data_type_index + 1))), " ");
    if data_type == {
      case "v";   // Vertex
        // Populate our vertex data with the correct value.
        mesh.vertices[vertex_index].x = -parse_float(*line_data[0]);
        mesh.vertices[vertex_index].y = -parse_float(*line_data[1]);
        mesh.vertices[vertex_index].z = -parse_float(*line_data[2]);
        // Dont forget to increment the index for the next vertex.
        vertex_index += 1;
      case "vt";  // Vertex Texture Coordinate
        // TODO
        texture_index += 1;
      case "vn";  // Vertex Normal
        normals[normal_index].x = parse_float(*line_data[0]);
        normals[normal_index].y = parse_float(*line_data[1]);
        normals[normal_index].z = parse_float(*line_data[2]);
        normal_index += 1;
      case "vp";  // Parameter space vertices in (u, [v, w]) form; free form geometry statement

      case "f";  // Construct the face.
        face_arguments := NewArray(line_data.count, []string);
        for item,index : line_data {
          face_arguments[index] = split(line_data[index], "/");
        }
        // For each triangle within this face.
        triangles_in_face := (line_data.count - 2);
        for 0 .. triangles_in_face - 1 {
          // Should use it here, we will have one iteration per face.
          mesh.indices[(face_index + it) * 3 + 0] = xx (parse_int(*face_arguments[0][0]) - 1); // Face data is 1 indexed, make it 0 indexed. 
          mesh.indices[(face_index + it) * 3 + 1] = xx (parse_int(*face_arguments[1][0]) - 1);
          mesh.indices[(face_index + it) * 3 + 2] = xx (parse_int(*face_arguments[2][0]) - 1);
          // TODO implement normal.
        }

        // Increment the face_index by the number of triangles in this face.
        face_index += triangles_in_face;
      case;
        continue; // If we dont know what this is, dont increment
    }
  }

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