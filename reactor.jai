#if OS == .WINDOWS {
  #import "Windows";
}

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
present_queue : VkQueue;

// Create a surface
surface : VkSurfaceKHR;

main :: () {
  // First we create a window.
  window := ReactorWindow.create_window(window_name = "Hello Vulkan!");

  // Now lets initialize Vulkan.
  success , vk_instance := init_vulkan();
  print("Initialized Vulkan:%\n", success);

  // Setup our surface
  init_surface(vk_instance, window);

  // Query physical devices and choose one. 
  physical_device = pick_physical_device(vk_instance);
  create_logical_device(vk_instance, physical_device);

  // Now we setup our surface


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

  vkDestroySurfaceKHR(instance, surface, null);
  vkDestroyInstance(instance, null);
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

  // Determine which extensions we want to use.
  extensions: [..] *u8;
  defer free(extensions.data);

  // We want to render to a surface so we will use this extension
  array_add(*extensions , VK_KHR_SURFACE_EXTENSION_NAME.data);

  #if OS == .WINDOWS { // We can load Windows Specific Vulkan Extensions here. These are the debug extensions.
    array_add(*extensions , VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data);
  }

  if validation_layers_enabled {
    array_add(*extensions , VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data);
    array_add(*extensions, VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
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
  defer free(suitable_devices.data);

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

  has_indices := QueueFamilyIndices.isComplete(indices);

  if has_indices {
    device_properties : VkPhysicalDeviceProperties;
    device_features   : VkPhysicalDeviceFeatures;

    vkGetPhysicalDeviceProperties(device, *device_properties);
    vkGetPhysicalDeviceFeatures(device, *device_features);

    // print("properties:%\nfeatures:%\n", device_properties, device_features);
    print("%\n", to_string(device_properties.deviceName));
  }

  return has_indices;

  // return device_properties.deviceType == .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU && device_features.geometryShader;
}

NullableU32 :: struct {
  value : u32;
  has_value := false;
  set :: (instance : *NullableU32, value : u32) {
    instance.value = value;
    instance.has_value = true;
  }
}

QueueFamilyIndices :: struct {
  graphics_family : NullableU32 = .{};
  present_family  : NullableU32 = .{};

  isComplete :: (queue : QueueFamilyIndices) -> bool {
    return queue.graphics_family.has_value && queue.present_family.has_value;
  }
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

  // We are looking for a queue familiy which supports "GRAPHICS" and "Presentation"
  present_supported : VkBool32 = VK_FALSE;
  for it, index : queue_family_array {
    if it.queueFlags & .VK_QUEUE_GRAPHICS_BIT {
      NullableU32.set(*indices.graphics_family, xx index);
    }

    vkGetPhysicalDeviceSurfaceSupportKHR(device, xx index, surface, *present_supported);
    if (present_supported) {
      NullableU32.set(*indices.present_family, xx index);
    }
  }

  return indices;
}

// Logical Devices
create_logical_device :: (intsance : VkInstance, physical_device : VkPhysicalDevice) {
  indices := find_queue_famlilies(physical_device);

  // TODO some kind of reflection on the struct.
  unique_queue_famlilies : [2] u32;
  unique_queue_famlilies[0] = indices.graphics_family.value;
  unique_queue_famlilies[1] = indices.present_family.value;

  queue_create_infos : [..] VkDeviceQueueCreateInfo;
  defer free(queue_create_infos.data);

  queue_priority : float = 1.0;
  for unique_queue_famlilies {
    queue_create_info : VkDeviceQueueCreateInfo;
    queue_create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_create_info.queueFamilyIndex = it;
    queue_create_info.queueCount = 1;
    queue_create_info.pQueuePriorities = *queue_priority;
    array_add(*queue_create_infos, queue_create_info);
  }

  // Features of the Physical Device we are interested in Using.
  device_features : VkPhysicalDeviceFeatures = .{};

  create_info : VkDeviceCreateInfo = .{};
  create_info.sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  create_info.queueCreateInfoCount = cast(u32) queue_create_infos.count;
  create_info.pQueueCreateInfos = queue_create_infos.data;

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

  vkGetDeviceQueue(logical_device, indices.graphics_family.value, 0, *graphics_queue);
  vkGetDeviceQueue(logical_device, indices.present_family.value, 0, *present_queue);
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

init_surface :: (instance : VkInstance, window : ReactorWindow.ReactorWindow) -> bool {
  #if OS == .WINDOWS {
    surfaceCreateInfo: VkWin32SurfaceCreateInfoKHR; 
    surfaceCreateInfo.sType     = .WIN32_SURFACE_CREATE_INFO_KHR;
    surfaceCreateInfo.hinstance = GetModuleHandleW(null);
    surfaceCreateInfo.hwnd      = window.window_pointer;
    result := vkCreateWin32SurfaceKHR(instance, *surfaceCreateInfo, null, *surface);
    return result == .SUCCESS;
  } else {
    // @ToDo
    #assert(false);
    return false;
  }
}