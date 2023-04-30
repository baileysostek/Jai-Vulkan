#import "File";
#import "Basic";

load_shader :: (file_path : string) -> bool , int {
  file_contents, success := read_entire_file(file_path);
  if !success then return false, -1; // Could not load shader

  // We loaded a file
  print("loaded:%, content_size:%\n", file_path, file_contents.count);
  
  shader_id := -1;
  defer delete_shader(shader_id);
  defer free(file_contents);
  return true, shader_id;
}

delete_shader :: (shader_id : int) {

}

create_program :: (vertex_shader_id : int, fragment_shader_id : int) -> bool, int {
  return false, -1;
}