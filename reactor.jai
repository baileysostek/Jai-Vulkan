ReactorWindow :: #import,file "window.jai";
ShaderManager :: #import,file "shader_manager.jai";

#import "Basic";
#import "Vulkan";

DEBUG :: true;

main :: () {
  window := ReactorWindow.create_window(window_name = "Hello Vulkan!");

  // Now lets initialize Vulkan.
  success , vk_instance := init_vulkan();

  print("Initialized Vulkan:%\n", success);

  vert_success, vert_id := ShaderManager.load_shader("./res/shaders/simple_shader.vert.spv");
  frag_success, frag_id := ShaderManager.load_shader("./res/shaders/simple_shader.frag.spv");

  while !ReactorWindow.is_close_requested(window) {
    ReactorWindow.poll_window_events(*window);


    // // Handle Resize
    // for get_window_resizes() {
    //   if it.window == window {
    //     should_reinit := (it.width != window_width) || (it.height != window_height);
        
    //     window_width  = it.width;
    //     window_height = it.height;

    //     if should_reinit {
    //       print("%,%,%\n", should_reinit, window_width, window_height);
    //       reinit_swapchain();
    //     }
    //   }
    // }

    // draw_frame();
  }
}

init_vulkan :: () -> bool, VkInstance {

  // Application Info
  app_info: VkApplicationInfo;
  app_info.sType              = .APPLICATION_INFO;
  app_info.pApplicationName   = "Vulkan example";
  app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
  app_info.pEngineName        = "No Engine";
  app_info.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
  app_info.apiVersion         = VK_API_VERSION_1_0;

  /*
    This next struct is not optional and tells the Vulkan driver which global extensions and validation
    layers we want to use. Global here means that they apply to the entire program and not a specific
    device, which will become clear in the next few chapters.
  */
  create_info : VkInstanceCreateInfo;
  create_info.sType = .INSTANCE_CREATE_INFO;
  create_info.pApplicationInfo = *app_info; // Pass a pointer to our other struct.

  #if !DEBUG {
    extensions: [2] *u8;
    extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
    // @ToDo: Non-Windows version
    extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
  } else {
    #if OS == .WINDOWS { // We can load Windows Specific Vulkan Extensions here. These ar ethe debug extensions.
      extensions: [3] *u8;
      extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
      extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
      extensions[2] = VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data;
    } else {
      extensions: [0] *u8;
      // @ToDo: Non-Windows version
      #assert(false);
    }
  }

  // The contnet of these variables will vary based on OS and available extensions
  create_info.enabledExtensionCount = extensions.count;
  create_info.ppEnabledExtensionNames = extensions.data;
  
  // TODO address later
  create_info.enabledLayerCount = 0;

  // Now that we have specified eveyrthing we can issue a create call.
  instance : VkInstance;
  result : VkResult = vkCreateInstance(*create_info, null, *instance);
  // VkResult is an abstraction of a boolean... or an enum representing an error code.

  vulkan_initialized := (result == .SUCCESS);

  if vulkan_initialized then print_available_vulkan_extensions();

  return vulkan_initialized, instance;
}

print_available_vulkan_extensions :: () {
  extension_count: u32;
  vkEnumerateInstanceExtensionProperties(null, *extension_count, null);
  extension_array := NewArray(extension_count, VkExtensionProperties);
  defer free(extension_array.data);
  vkEnumerateInstanceExtensionProperties(null, *extension_count, extension_array.data);
  print("Available extensions:\n");
  for extension_array print("    % (%)\n", to_string(it.extensionName.data), it.specVersion);
}

deinit_vulkan :: () {
  vkDestroyInstance(instance, null);
}

// Now we need to work on creating a vulkan device. 
