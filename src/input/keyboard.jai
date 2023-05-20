#import "Math";
#import "Basic";
#import "Input";

ReactorKeyboardState :: struct {
  keys : [U8_MAX] bool;
}

set_key :: (keyboard : *ReactorKeyboardState, key : Key_Code, state : bool) {
  keyboard.keys[key] = state;
  print("Set% = %\n", key, is_key_pressed(keyboard, key));
  // print("%\n", *keyboard.keys);
}

is_key_pressed :: (keyboard : *ReactorKeyboardState, key : .. Key_Code) -> bool {
  for key {
    if keyboard.keys[it] {
      return true;
    }
  }
  return false;
}

//TODO keycodes.