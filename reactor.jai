ReactorWindow :: #import,file "window.jai";
ShaderManager :: #import,file "shader_manager.jai";

#import "Basic";
#import "Vulkan";

DEBUG :: true;


validation_layers_enabled := false;
validation_layers := (*u8).["VK_LAYER_KHRONOS_validation"];

debug_messenger : VkDebugUtilsMessengerEXT;

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

  cleanup(vk_instance);
}

cleanup :: (instance : VkInstance) {

  if validation_layers_enabled {
    // Cleanup our debug messenger.
    destroy_debug_utils_messenger_ext(instance, debug_messenger, null);
  }

  deinit_vulkan(instance);
}

init_vulkan :: () -> bool, VkInstance {

  // First we will check that all of our validation layers are supported.
  validation_layers_enabled = check_validiation_layer_support();
  if DEBUG && !validation_layers_enabled {
    print("Error: Some validation layers are not supported.");
    return false, null;
  }

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
    #if OS == .WINDOWS { // We can load Windows Specific Vulkan Extensions here. These are the debug extensions.

      extensions: [..] *u8;
      array_add(*extensions , VK_KHR_SURFACE_EXTENSION_NAME.data);
      array_add(*extensions , VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data);
      array_add(*extensions , VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data);

      if validation_layers_enabled {
        array_add(*extensions, VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
      }

    } else {
      extensions: [0] *u8;
      // @ToDo: Non-Windows version
      #assert(false);
    }
  }


  // The contnet of these variables will vary based on OS and available extensions
  create_info.enabledExtensionCount = cast(u32) extensions.count;
  create_info.ppEnabledExtensionNames = extensions.data;
  
  if validation_layers_enabled {
    create_info.enabledLayerCount = cast(u32) validation_layers.count;
    create_info.ppEnabledLayerNames = validation_layers.data;
    // print("Test:%,%\n", create_info.enabledLayerCount, to_string(&create_info.ppEnabledLayerNames));
  } else {
    create_info.enabledLayerCount = 0;
  }
  

  // Now that we have specified eveyrthing we can issue a create call.
  instance : VkInstance;
  result : VkResult = vkCreateInstance(*create_info, null, *instance);
  // VkResult is an abstraction of a boolean... or an enum representing an error code.

  vulkan_initialized := (result == .SUCCESS);
  if !vulkan_initialized then return false, null;

  // Print the available extentions
  print_available_vulkan_extensions();

  // Setup our debug messenger
  if validation_layers_enabled {
    create_debug_messenger : VkDebugUtilsMessengerCreateInfoEXT;
    create_debug_messenger.sType = .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    create_debug_messenger.messageSeverity = .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    create_debug_messenger.messageType = VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    create_debug_messenger.pfnUserCallback = debug_callback;
    // createInfo.pUserData = nullptr; // Optional

    if (create_debug_utils_messenger_ext(instance, *create_debug_messenger, null, *debug_messenger) != .VK_SUCCESS) {
      print("%\n", "failed to set up debug messenger!");      
    } else {
      print("%\n", "Created debug messenger!");    
    }
  }

  return vulkan_initialized, instance;
}

debug_callback :: (messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: *VkDebugUtilsMessengerCallbackDataEXT, pUserData: *void) -> VkBool32 #c_call {
  new_context: Context;
  push_context new_context {
    print("validation layer:%\n", to_string(pCallbackData.pMessage));
  }
  return VK_FALSE;
}

create_debug_utils_messenger_ext :: (instance : VkInstance, p_create_info : *VkDebugUtilsMessengerCreateInfoEXT, p_allocator : *VkAllocationCallbacks, p_debug_messenger : *VkDebugUtilsMessengerEXT) -> VkResult {
  func := cast(PFN_vkCreateDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
  if func {
    return func(instance, p_create_info, p_allocator, p_debug_messenger);
  } else {
    return .VK_ERROR_EXTENSION_NOT_PRESENT;
  }
}

destroy_debug_utils_messenger_ext :: (instance : VkInstance, debug_messenger : VkDebugUtilsMessengerEXT, p_allocator : *VkAllocationCallbacks) {
  func := cast(PFN_vkDestroyDebugUtilsMessengerEXT) vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
  if func {
    func(instance, debug_messenger, p_allocator);
  }
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

deinit_vulkan :: (instance : VkInstance) {
  vkDestroyInstance(instance, null);
}

check_validiation_layer_support :: () -> bool {
  layer_count: u32;
  vkEnumerateInstanceLayerProperties(*layer_count, null);
  available_layers := NewArray(layer_count, VkLayerProperties);
  defer free(available_layers.data);
  vkEnumerateInstanceLayerProperties(*layer_count, available_layers.data);

  // Check that every validation layer is supported.
  for validation_layers {
    validation_layer := to_string(it);

    // Try to find this layer in our layers
    found_layer := false;

    // Search for our layer
    for available_layers {
      available_layer := to_string(it.layerName.data);
      // print("% == % ? % \n", validation_layer, available_layer, validation_layer == available_layer);
      if validation_layer == available_layer {
        found_layer = true;
        break;
      }
    }

    if !found_layer return false;
  }

  return true;
}

setup_debug_messenger :: () {
  // create_info : VkDebugUtilsMessengerCreateInfoEXT;
  // create_info.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
  // create_info.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
  // create_info.messageType = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
  // create_info.pfnUserCallback = debugCallback;

  // if (CreateDebugUtilsMessengerEXT(instance, &createInfo, nullptr, &debugMessenger) != VK_SUCCESS) {
  //   print("failed to set up debug messenger!");
  // }
}