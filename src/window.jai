WindowCreation  :: #import "Window_Creation";

#import  "Basic";

#import "Input";
#if OS ==.WINDOWS {
  #import "Windows";
}

ReactorWindow :: struct {
  window_pointer : HWND;
  name : string;
  width : u32 = 640;
  height : u32 = 480;
  aspect_ratio : float = 1.3333;

  vysnc_enabled := false;
  fullscreen := false;

  quit := false;

  save_info : WindowCreation.Saved_Window_Info;
}


create_window :: (window_name := "Window Title", window_width : u32 = 640, window_height : u32 = 480, fullscreen : bool = false) -> ReactorWindow {
  // Use Window create to create this window on the screen.
    // Create window
  window_pointer := WindowCreation.create_window(xx window_width, xx window_height, window_name, window_x = 100, window_y = 100);
  window := ReactorWindow.{window_pointer, window_name, window_width, window_height, cast(float)window_width / cast(float)window_height, false, fullscreen, false, .{}};

  // Center the monitor on the screen.
  center_window_on_monitor(window);

  if window.fullscreen {
    // Create fullscreen window.
    window_info : WindowCreation.Saved_Window_Info;
    WindowCreation.toggle_fullscreen(window_pointer, true, *window_info);
  }

  return window;
}

vararg_1 :: (a: u8, b: u8) -> u8 {
  print("Adding a: % and b: % in vararg_1:\n", a, b);
  return a + b;
}

toggle_fullscreen :: (window : *ReactorWindow) {
  window.fullscreen = !window.fullscreen;
  WindowCreation.toggle_fullscreen(window.window_pointer, window.fullscreen, *window.save_info);
  if (window.fullscreen) {
    success, monitor_width, monitor_height := get_monitor_size(window);
    resize_window(window, xx monitor_width, xx monitor_height);
    print("Test 1\n");
  } else {
    resize_window(window, xx (window.save_info.rect.right - window.save_info.rect.left), xx (window.save_info.rect.bottom - window.save_info.rect.top));
    print("Test 2\n");
  }
}

poll_window_events :: (window : *ReactorWindow){
  update_window_events();

  quit := false;

  for events_this_frame {
    if it.type == .QUIT then window.quit = true;

    if it.type == .KEYBOARD && it.key_code == .ESCAPE then window.quit = true;
    if it.type == .KEYBOARD && it.key_code == .F11 && it.key_pressed == 1 then toggle_fullscreen(window);

    if it.type == .KEYBOARD
      set_key(xx it.key_code, it.key_pressed == 1);


    // print("%\n",it);

  }
}

is_close_requested :: (window : ReactorWindow) -> bool {
  return window.quit;
}

resize_window :: (window : *ReactorWindow, width : u32, height : u32) {
  window.width = width;
  window.height = height;
  window.aspect_ratio = cast(float)window.width / cast(float)window.height;
}

center_window_on_monitor :: (window : ReactorWindow) {
  success, monitor_width, monitor_height := get_monitor_size(window);
  if success {
    SetWindowPos(window.window_pointer, HWND_TOPMOST, cast(s32)((cast(u32)monitor_width - window.width) / 2), cast(s32)((cast(u32)monitor_height - window.height) / 2), xx window.width, xx window.height, SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  }
}

// move_window_on_monitor :: (window : ReactorWindow, x : u32, y : u32, centered := true) {
//   success, monitor_width, monitor_height := get_monitor_size(window);
//   if success {
    
//     delta_x := ifx centered then (monitor_width - cast(s32)window.width) / 2 else 0;
//     delta_y := ifx centered then (monitor_height - cast(s32)window.height) / 2 else 0;

//     SetWindowPos(window.window_pointer, HWND_TOPMOST, x + delta_x, y + delta_y, xx window.width, xx window.height, SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
//   }
// }

get_monitor_size :: (window : ReactorWindow) -> bool, s32, s32 {
  monitor := MonitorFromWindow(window.window_pointer, MONITOR_DEFAULTTONEAREST);
  info: MONITORINFO;
  info.cbSize = size_of(type_of(info));
  success := GetMonitorInfoW(monitor, *info);
  if success {

    x := info.rcMonitor.left;
    y := info.rcMonitor.top;
    monitor_width  := info.rcMonitor.right  - x;
    monitor_height := info.rcMonitor.bottom - y;

    return true, monitor_width, monitor_height;
  }
  return false, 0, 0;
}