ReactorWindow :: #import,file "window.jai";
ShaderManager :: #import,file "shader_manager.jai";

#import "Basic";
#import "Vulkan";

DEBUG :: true;

validation_layers_enabled := false;
validation_layers := (*u8).["VK_LAYER_KHRONOS_validation"];

debug_messenger : VkDebugUtilsMessengerEXT;

// Devices
physical_device : VkPhysicalDevice = VK_NULL_HANDLE; // Our seelcted GFX Card
logical_device : VkDevice = VK_NULL_HANDLE;

// Queue which we can enqueueu commands to and then submit to our device.
graphics_queue : VkQueue;

main :: () {
  window := ReactorWindow.create_window(window_name = "Hello Vulkan!");

  // Now lets initialize Vulkan.
  success , vk_instance := init_vulkan();
  print("Initialized Vulkan:%\n", success);

  physical_device = pick_physical_device(vk_instance);

  create_logical_device(vk_instance, physical_device, logical_device);

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

  // Destroy our Logical Device.
  vkDestroyDevice(logical_device, null);

  if validation_layers_enabled {
    // Cleanup our debug messenger.
    destroy_debug_utils_messenger_ext(instance, debug_messenger, null);
  }

  deinit_vulkan(instance);
}

// create_instance
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
    extensions: [..] *u8;

    #if OS == .WINDOWS { // We can load Windows Specific Vulkan Extensions here. These are the debug extensions.
      array_add(*extensions , VK_KHR_SURFACE_EXTENSION_NAME.data);
      array_add(*extensions , VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data);
      array_add(*extensions , VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data);
    }

    if validation_layers_enabled {
      array_add(*extensions, VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

  }


  // The contnet of these variables will vary based on OS and available extensions
  create_info.enabledExtensionCount = cast(u32) extensions.count;
  create_info.ppEnabledExtensionNames = extensions.data;
  
  debug_create_info : VkDebugUtilsMessengerCreateInfoEXT;
  if validation_layers_enabled {
    create_info.enabledLayerCount = cast(u32) validation_layers.count;
    create_info.ppEnabledLayerNames = validation_layers.data;
  
    populate_debug_messenger_create_info(*debug_create_info);
    create_info.pNext = cast(*VkDebugUtilsMessengerCreateInfoEXT) *debug_create_info;
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
  // print_available_vulkan_extensions();

  // Setup our debug messenger
  if validation_layers_enabled {
    create_debug_messenger : VkDebugUtilsMessengerCreateInfoEXT;

    populate_debug_messenger_create_info(*create_debug_messenger);

    if (create_debug_utils_messenger_ext(instance, *create_debug_messenger, null, *debug_messenger) != .VK_SUCCESS) {
      print("%\n", "failed to set up debug messenger!");      
    } else {
      print("%\n", "Created debug messenger!");    
    }
  }

  return vulkan_initialized, instance;
}

// Physical Devices
//TODO come back to this, persist a list of all physical devices and allow a user to choose?
pick_physical_device :: (vk_instance : VkInstance) -> VkPhysicalDevice{
  
  // Ask Vulkan how manyu GPU's it can see
  device_count : u32 = 0;
  vkEnumeratePhysicalDevices(vk_instance, *device_count, null);
  if device_count == 0 { print("failed to find GPUs with Vulkan support!\n"); return VK_NULL_HANDLE; }

  device_array := NewArray(device_count, VkPhysicalDevice);
  defer free(device_array.data);
  vkEnumeratePhysicalDevices(vk_instance, *device_count, device_array.data);

  suitable_devices : [..] VkPhysicalDevice;

  for device_array {
    if is_device_suitable(it) {
      array_add(*suitable_devices, it);
    }
  }

  if suitable_devices.count == 0 {
    print("No available devices meet this application's requirements.\n");
    return VK_NULL_HANDLE;
  }

  return suitable_devices[0];

}

is_device_suitable :: ( device : VkPhysicalDevice ) -> bool {
  indices := find_queue_famlilies(device);

  if indices.has_value {
    device_properties : VkPhysicalDeviceProperties;
    device_features   : VkPhysicalDeviceFeatures;

    vkGetPhysicalDeviceProperties(device, *device_properties);
    vkGetPhysicalDeviceFeatures(device, *device_features);

    // print("properties:%\nfeatures:%\n", device_properties, device_features);
    print("%\n", to_string(device_properties.deviceName));
  }

  return indices.has_value;

  // return device_properties.deviceType == .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU && device_features.geometryShader;
}

QueueFamilyIndices :: struct {
  graphics_family : u32;
  has_value := false;
}

find_queue_famlilies :: (device : VkPhysicalDevice) -> QueueFamilyIndices {
  // Get Queue families
  queue_family_count : u32 = 0;

  vkGetPhysicalDeviceQueueFamilyProperties(device, *queue_family_count, null);
  queue_family_array := NewArray(queue_family_count , VkQueueFamilyProperties);
  defer free(queue_family_array.data);
  vkGetPhysicalDeviceQueueFamilyProperties(device, *queue_family_count, queue_family_array.data);

  // Create a deafult struct instance to hold our indices.
  indices : QueueFamilyIndices = .{};

  // We are looking for a queue familiy which supports "GRAPHICS"
  for it, index : queue_family_array {
    if it.queueFlags & .VK_QUEUE_GRAPHICS_BIT {
      indices.graphics_family = xx index;
      indices.has_value = true;
      break;
    }
  }

  return indices;
}

// Logical Devices
create_logical_device :: (intsance : VkInstance, physical_device : VkPhysicalDevice, logical_device : VkDevice) {
  indices := find_queue_famlilies(physical_device);

  queue_create_info : VkDeviceQueueCreateInfo;
  queue_create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  queue_create_info.queueFamilyIndex = indices.graphics_family;
  queue_create_info.queueCount = 1;

  queue_priority : float = 1.0;
  queue_create_info.pQueuePriorities = *queue_priority;

  // Features of the Physical Device we are interested in Using.
  device_features : VkPhysicalDeviceFeatures = .{};

  create_info : VkDeviceCreateInfo = .{};
  create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  create_info.pQueueCreateInfos = *queue_create_info; // Link to above^
  create_info.queueCreateInfoCount = 1;

  create_info.pEnabledFeatures = *device_features;

  create_info.enabledExtensionCount = 0;
  if validation_layers_enabled {
    create_info.enabledLayerCount = cast(u32) validation_layers.count;
    create_info.ppEnabledLayerNames = validation_layers.data;
  } else {
    create_info.enabledLayerCount = 0;
  }

  if vkCreateDevice(physical_device, *create_info, null, *logical_device) != .VK_SUCCESS {
    print("failed to create logical device!\n");
  }

  vkGetDeviceQueue(logical_device, indices.graphics_family, 0, *graphics_queue);

}

populate_debug_messenger_create_info :: (p_create_info : *VkDebugUtilsMessengerCreateInfoEXT) {
  p_create_info.sType = .VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
  p_create_info.messageSeverity = .VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | VkDebugUtilsMessageSeverityFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
  p_create_info.messageType = VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | VkDebugUtilsMessageTypeFlagBitsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
  p_create_info.pfnUserCallback = debug_callback;
  // p_create_info.pUserData = nullptr; // Optional
}

debug_callback :: (messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: *VkDebugUtilsMessengerCallbackDataEXT, pUserData: *void) -> VkBool32 #c_call {
  new_context: Context;
  push_context new_context {
    if messageSeverity > .VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT { 
      print("validation layer:%\n", to_string(pCallbackData.pMessage));
    }
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