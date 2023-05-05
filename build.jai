#load "src/reactor.jai";

#run {
  Compiler :: #import "Compiler";
  Compiler.set_build_options_dc(.{output_path="build", output_executable_name="reactor"});
}