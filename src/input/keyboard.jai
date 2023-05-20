#import "Math";
#import "Basic";
#import "Input";

// Hold onto our keyboard state.
keyboard : ReactorKeyboardState = .{};

KeyCode :: enum u8 {
  ALT           ::   18;
  ARROW_DOWN    ::   40;
  ARROW_LEFT    ::   37;
  ARROW_RIGHT   ::   39;
  ARROW_UP      ::   38;
  BACKSPACE     ::    8;
  CAPS_LOCK     ::   20;
  CTRL          ::   17;
  DELETE        ::   46;
  END           ::   35;
  ENTER         ::   13;
  ESCAPE        ::   27;
  F1            ::  112;
  F2            ::  113;
  F3            ::  114;
  F4            ::  115;
  F5            ::  116;
  F6            ::  117;
  F7            ::  118;
  F8            ::  119;
  F9            ::  120;
  F10           ::  121;
  F11           ::  122;
  F12           ::  123;
  HOME          ::   36;
  INSERT        ::   45;
  NUM_LOCK      ::  144;
  // NUMPAD_MI  NU  S
  // NUMPAD_MU  LT  IPLY
  // NUMPAD_PE  RI  OD
  // NUMPAD_DI  VI  DE
  NUMPAD_0      ::   96;
  NUMPAD_1      ::   97;
  NUMPAD_2      ::   98;
  NUMPAD_3      ::   99;
  NUMPAD_4      ::  100;
  NUMPAD_5      ::  101;
  NUMPAD_6      ::  102;
  NUMPAD_7      ::  103;
  NUMPAD_8      ::  104;
  NUMPAD_9      ::  105;
  PAGE_DOWN     ::   34;
  PAGE_UP       ::   33;
  PRINT_SCREEN  ::   44;
  SCROLL_LOCK   ::  145;
  SHIFT         ::   16;
  SPACE         ::   32;
  TAB           ::    9;
  A             ::   65;
  B             ::   66;
  C             ::   67;
  D             ::   68;
  E             ::   69;
  F             ::   70;
  G             ::   71;
  H             ::   72;
  I             ::   73;
  J             ::   74;
  K             ::   75;
  L             ::   76;
  M             ::   77;
  N             ::   78;
  O             ::   79;
  P             ::   80;
  Q             ::   81;
  R             ::   82;
  S             ::   83;
  T             ::   84;
  U             ::   85;
  V             ::   86;
  W             ::   87;
  X             ::   88;
  Y             ::   89;
  Z             ::   90;
  ONE           ::   49;
  TWO           ::   50;
  THREE         ::   51;
  FOUR          ::   52;
  FIVE          ::   53;
  SIX           ::   54;
  SEVEN         ::   55;
  EIGHT         ::   56;
  NINE          ::   57;
  ZERO          ::   58;
  GRAVE         ::  222;
  MINUS         ::  189;
  COMMA         ::  188;
  PERIOD        ::  190;
  FORWARD_SLASH ::  191;
  SEMI_COLON    ::  186;
  RIGHT_BRACKET ::  219;
  BACK_SLASH    ::  220;
  LEFT_BRACKET  ::  221;
  APOSTRAPHE    ::  192;
  EQUAL         ::  187;
}

ReactorKeyboardState :: struct {
  keys : [U8_MAX] bool;
}

set_key :: (key : KeyCode, state : bool) {
  keyboard.keys[key] = state;
}

is_key_pressed :: (key : .. KeyCode) -> bool {
  for key {
    if keyboard.keys[it] {
      return true;
    }
  }
  return false;
}