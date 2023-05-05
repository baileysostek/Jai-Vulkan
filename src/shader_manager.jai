#import "File";
#import "Basic";

load_shader :: (file_path : string) -> bool , string {
  file_contents, success := read_entire_file(file_path);
  if !success then return false, ""; // Could not load shader

  // We loaded a file
  print("loaded:%, content_size:%\n", file_path, file_contents.count);
  
  return true, file_contents;
}

delete_shader :: (shader_id : int) {

}

create_program :: (vertex_shader_id : int, fragment_shader_id : int) -> bool, int {
  return false, -1;
}