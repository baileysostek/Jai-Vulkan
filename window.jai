WindowCreation :: #import "Window_Creation";

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
}

create_window :: (window_name := "Window Title", window_width : u32 = 640, window_height : u32 = 480) -> ReactorWindow {
  // Use Window create to create this window on the screen.
    // Create window
  window_pointer := WindowCreation.create_window(xx window_width, xx window_height, window_name, window_x = 100, window_y = 100);
  window := ReactorWindow.{window_pointer, window_name, window_width, window_height, cast(float)window_width / cast(float)window_height, false, false, false};

  // Center the monitor on the screen.
  center_window_on_monitor(window);

  return window;
}

poll_window_events :: (window : *ReactorWindow){
  update_window_events();

  quit := false;

  for events_this_frame {
    if it.type == .QUIT then window.quit = true;
    if it.type == .KEYBOARD && it.key_code == .ESCAPE then window.quit = true;

    print("%\n", it);
  }
}

is_close_requested :: (window : ReactorWindow) -> bool {
  return window.quit;
}

resize_window :: (window : *ReactorWindow, width : u32, height : u32) {
  window.width = width;
  window.height = height;
  window.aspect_ratio =cast(float)width / cast(float)height;
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