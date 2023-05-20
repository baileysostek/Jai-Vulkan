#if OS == .WINDOWS {
  #import "Windows";
}

#load "window.jai";
#load "shader_manager.jai";
#load "camera/camera_manager.jai";

#load "input/keyboard.jai";

#load "mesh/mesh.jai";
#load "entity/entity.jai";

#import "Basic";
#import "Vulkan";
#import "String";
#import "Math";
#import "Input";

DEBUG :: true;

// Hold onto our keyboard state.
keyboard : ReactorKeyboardState = .{};

// Refrence to our window
window : ReactorWindow;
window_changed_sizes := false;

// Vulkan configuration stuff.
validation_layers_enabled := false;
validation_layers := (*u8).["VK_LAYER_KHRONOS_validation"];
required_device_extensions := (*u8).[VK_KHR_SWAPCHAIN_EXTENSION_NAME.data]; // How the device can interact with other hardware.

// Our Debug message callbacks
debug_messenger : VkDebugUtilsMessengerEXT;

// Devices
physical_device : VkPhysicalDevice = VK_NULL_HANDLE; // Our seelcted GFX Card
device : VkDevice = VK_NULL_HANDLE;

// Queue which we can enqueueu commands to and then submit to our device.
graphics_queue : VkQueue;
present_queue : VkQueue;

// Create a surface
surface : VkSurfaceKHR;

// Our Swapchain
swap_chain : VkSwapchainKHR;
swap_chain_images : [] VkImage;
swap_chain_image_format : VkFormat;
swap_chain_extent : VkExtent2D;

// Swapchain Image Views
swap_chain_image_views : [] VkImageView;
swap_chain_frame_buffers : [] VkFramebuffer;

// Graphics Pipeline
render_pass : VkRenderPass;
// Uniforms / UBO
UBO_MVP :: struct {
  model      : Matrix4 = Matrix4_Identity;
  view       : Matrix4 = Matrix4_Identity;
  projection : Matrix4 = Matrix4_Identity;
  aspect_ratio : float = 1.0;
}
ubo : UBO_MVP;

descriptor_set_layout : VkDescriptorSetLayout;
pipeline_layout : VkPipelineLayout;
graphics_pipeline : VkPipeline;

// Command Pool
command_pool : VkCommandPool;

// How many frames in flight we allow at a time.
MAX_FRAMES_IN_FLIGHT :: 3;

// Keep track of the frame index
frame_index : u32 = 0;

// Properties used for each frame
command_buffers             : [MAX_FRAMES_IN_FLIGHT] VkCommandBuffer;
image_available_semaphores  : [MAX_FRAMES_IN_FLIGHT] VkSemaphore;
render_finished_semaphores  : [MAX_FRAMES_IN_FLIGHT] VkSemaphore;
in_flight_fences            : [MAX_FRAMES_IN_FLIGHT] VkFence;

// Vertex Buffer info
vertex_buffer : VkBuffer;
vertex_buffer_memory : VkDeviceMemory;
index_buffer : VkBuffer;
index_buffer_memory : VkDeviceMemory;

// UBO data.
uniform_buffers         : [MAX_FRAMES_IN_FLIGHT] VkBuffer;
uniform_buffers_memory  : [MAX_FRAMES_IN_FLIGHT] VkDeviceMemory;
uniform_buffers_mapped  : [MAX_FRAMES_IN_FLIGHT] *void;

descriptor_pool : VkDescriptorPool;
descriptor_sets : [MAX_FRAMES_IN_FLIGHT] VkDescriptorSet;

// Meshes
first_mesh : Mesh;

active_camera : Camera;

rotation : float = 0.0;

main :: () {
  // Mesh?
  first_mesh = load_mesh();
  get_binding_description();
  get_attribute_descriptions();

  // First we create a window.
  window = create_window(window_name = "Reactor Engine");

  // Camera
  active_camera = PerspectiveCamera.{};

  // Now lets initialize Vulkan.
  success , vk_instance := init_vulkan();
  print("Initialized Vulkan:%\n", success);

  // Setup our surface
  create_surface(vk_instance, window);
  // Query physical devices and choose one. 
  physical_device = pick_physical_device(vk_instance);
  create_logical_device(vk_instance, physical_device);
  create_swap_chain();
  create_image_views();
  create_render_pass();
  create_descriptor_set_layout(); // Layout locations of Attributes.
  create_graphics_pipeline();
  create_frame_buffers();
  create_command_pool();
  create_vertex_buffer();
  create_index_buffer();
  create_uniform_buffers(); // Layout locations of Uniforms.
  create_descriptor_pool();
  create_descriptor_sets();
  create_command_buffers();
  create_sync_objects();

  // Compute Frame times.
  last_update_time := current_time_monotonic();
  running_delta : float = 0.0;
  frames : u32 = 0;

  while !is_close_requested(window) {

    // Compute frame times
    now := current_time_monotonic();

    delta := now - last_update_time;
    ns := to_nanoseconds(delta);
    delta_time : float64 = (ns / 1_000_000_000.0);
    running_delta += ns;

    if running_delta >= 1_000_000_000 { // We know a second has passed
      running_delta -= 1_000_000_000;
      print("fps:%,%\n", frames, delta_time);
      frames = 0;
    }


    poll_window_events(*keyboard, *window);

    draw_frame(delta_time);
    // // Handle Resize
    for get_window_resizes() {
      if it.window == window.window_pointer {
        should_reinit := (it.width != xx window.width) || (it.height != xx window.height);
        
        resize_window(*window, xx it.width, xx it.height);
        
        if should_reinit {
          window_changed_sizes = true; // Reinit swapchain.
          print("Explict Resize\n");
        }
      }
    }

    // set the last frame time.
    last_update_time = now;
    frames += 1;
  }

  // Wait for the device to be idle
  vkDeviceWaitIdle(device);

  cleanup(vk_instance);
}

find_memory_type :: (type_filter: u32, properties : VkMemoryPropertyFlags) -> u32 {
  mem_properties : VkPhysicalDeviceMemoryProperties;
  vkGetPhysicalDeviceMemoryProperties(physical_device, *mem_properties);

  for 0 .. mem_properties.memoryTypeCount - 1 {
    if (type_filter & (1 << it)) && (mem_properties.memoryTypes[it].propertyFlags & properties) == properties {
      return it;
    }
  }

  print("failed to find suitable memory type!");
  return U32_MAX;
}

cleanup :: (instance : VkInstance) {
  // Cleanup our swapchain
  cleanup_swap_chain();

  vkDestroyPipeline(device, graphics_pipeline, null);
  vkDestroyPipelineLayout(device, pipeline_layout, null);
  vkDestroyRenderPass(device, render_pass, null);

  for 0 .. MAX_FRAMES_IN_FLIGHT - 1 {
    vkDestroyBuffer(device, uniform_buffers[it], null);
    vkFreeMemory(device, uniform_buffers_memory[it], null);
  }

  vkDestroyDescriptorPool(device, descriptor_pool, null);

  vkDestroyDescriptorSetLayout(device, descriptor_set_layout, null);

  vkDestroyBuffer(device, index_buffer, null);
  vkFreeMemory(device, index_buffer_memory, null);

  vkDestroyBuffer(device, vertex_buffer, null);
  vkFreeMemory(device, vertex_buffer_memory, null);

  // Destroy our semaphores and fence
  for 0 .. (MAX_FRAMES_IN_FLIGHT - 1) {
    vkDestroySemaphore(device, image_available_semaphores[it], null);
    vkDestroySemaphore(device, render_finished_semaphores[it], null);
    vkDestroyFence(device, in_flight_fences[it], null);
  }
  
  // Destoroy our Command Pool
  vkDestroyCommandPool(device, command_pool, null);

  // Destroy our Logical Device.
  vkDestroyDevice(device, null);

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
      print("failed to set up debug messenger!\n");      
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

  // Check if required extensions are available on this device
  device_supports_required_extensions := check_device_extension_support(device);
  if device_supports_required_extensions {
    print("Device supports all extensions.\n");
  }

  // Check if the physical device has a supported format and presentation mode.
  device_supports_format_and_presentation_mode := false;
  if device_supports_required_extensions {
    swap_chain_support := query_swap_chain_support_details(device, surface);
    device_supports_format_and_presentation_mode = swap_chain_support.formats.count > 0 && swap_chain_support.present_modes.count > 0;
  }
  if device_supports_format_and_presentation_mode {
    print("Device supports presentation and format.\n");
  }

  return has_indices && device_supports_required_extensions && device_supports_format_and_presentation_mode;

  // return device_properties.deviceType == .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU && device_features.geometryShader;
}

check_device_extension_support :: (device : VkPhysicalDevice) -> bool {
  extension_count : u32;
  vkEnumerateDeviceExtensionProperties(device, null, *extension_count, null);
  available_extensions := NewArray(extension_count , VkExtensionProperties);
  defer free(available_extensions.data);
  vkEnumerateDeviceExtensionProperties(device, null, *extension_count, available_extensions.data);
  
  // TODO replace this with a set.
  for required_device_extensions {
    required_extension : string = to_string(it);
    found_extension := false;
    for available_extensions {
      available_extension : string = stop_at_any(to_string(it.extensionName), "\0");
      found_extension = compare(available_extension, required_extension) == 0;
      if found_extension then break;
    }
    if !found_extension then return false;
  }

  return true;
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

// Swapchain stuff.
// Querying Details of swap chain support
SwapChainSupportDetails :: struct {
  capabilities : VkSurfaceCapabilitiesKHR;
  // TODO defer free of these resources
  formats : [] VkSurfaceFormatKHR;
  present_modes : [] VkPresentModeKHR;
};

query_swap_chain_support_details :: (device : VkPhysicalDevice, surface : VkSurfaceKHR) -> SwapChainSupportDetails {
  details : SwapChainSupportDetails;

  vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, *(details.capabilities));

  // Query supported surface formats.
  format_count : u32;
  vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, *format_count, null);
  if format_count != 0 {
    details.formats = NewArray(format_count , VkSurfaceFormatKHR);
    defer free(details.formats.data);
    vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, *format_count, details.formats.data);
  }

  // Query supported presentation modes
  presentation_mode_count : u32;
  vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, *presentation_mode_count, null);
  if presentation_mode_count != 0{
    details.present_modes = NewArray(presentation_mode_count, VkPresentModeKHR);
    defer free(details.present_modes.data);
    vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, *presentation_mode_count, details.present_modes.data);
  }

  return details;
}

create_swap_chain :: () {
  swap_chain_support := query_swap_chain_support_details(physical_device, surface);

  surface_format := choose_swap_surface_format(swap_chain_support.formats);
  present_mode := choose_swap_present_mode(swap_chain_support.present_modes);
  extent := choose_swap_extent(swap_chain_support.capabilities, window);

  // Request 1 more than the min images in the swapchain. Clamp to max
  image_count : u32 = swap_chain_support.capabilities.minImageCount + 1;
  if swap_chain_support.capabilities.maxImageCount > 0 && image_count > swap_chain_support.capabilities.maxImageCount {
    image_count = swap_chain_support.capabilities.maxImageCount;
  }

  create_info : VkSwapchainCreateInfoKHR;
  create_info.sType = .VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  create_info.surface = surface;

  create_info.minImageCount = image_count;
  create_info.imageFormat = surface_format.format;
  create_info.imageColorSpace = surface_format.colorSpace;
  create_info.imageExtent = extent;
  create_info.imageArrayLayers = 1;
  create_info.imageUsage = .VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

  indices := find_queue_famlilies(physical_device);

  // TODO some kind of reflection on the struct.
  queue_family_indices : [2] u32;
  queue_family_indices[0] = indices.graphics_family.value;
  queue_family_indices[1] = indices.present_family.value;

  if indices.graphics_family.value != indices.present_family.value {
    create_info.imageSharingMode = .VK_SHARING_MODE_CONCURRENT;
    create_info.queueFamilyIndexCount = 2;
    create_info.pQueueFamilyIndices = queue_family_indices.data;
  } else {
    create_info.imageSharingMode = .VK_SHARING_MODE_EXCLUSIVE;
    create_info.queueFamilyIndexCount = 0;
    create_info.pQueueFamilyIndices = null;
  }

  create_info.preTransform = swap_chain_support.capabilities.currentTransform; // Rotate images in the swapchain
  create_info.compositeAlpha = .VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR; // Blending with other windows.

  create_info.presentMode = present_mode;
  create_info.clipped = VK_TRUE;

  create_info.oldSwapchain = VK_NULL_HANDLE; // TODO Rebuild the swapchiain in the future

  if vkCreateSwapchainKHR(device, *create_info, null, *swap_chain) != .VK_SUCCESS {
    print("failed to create swap chain!\n");
  }

  // Resize and Populate our swap_chain_images buffer
  swap_chain_image_count : u32;
  vkGetSwapchainImagesKHR(device, swap_chain, *swap_chain_image_count, null);
  swap_chain_images = NewArray(swap_chain_image_count, VkImage);
  vkGetSwapchainImagesKHR(device, swap_chain, *swap_chain_image_count, swap_chain_images.data);

  // Store the format and extent we are using in this swap_chain.
  swap_chain_image_format = surface_format.format;
  swap_chain_extent = extent;
}

cleanup_swap_chain :: () {
  // Destory our framebuffers
  for swap_chain_frame_buffers {
    vkDestroyFramebuffer(device, it, null);
  }

  // Destroy our Image views
  for swap_chain_image_views {
    vkDestroyImageView(device, it, null);
  }

  // Free our images
  free(swap_chain_images.data);

  // Destroy our Swapchain
  vkDestroySwapchainKHR(device, swap_chain, null);
}

recreate_swap_chain :: () {
  vkDeviceWaitIdle(device);

  cleanup_swap_chain();

  create_swap_chain();
  create_image_views();
  create_frame_buffers();
}

choose_swap_surface_format :: (available_formats : [] VkSurfaceFormatKHR) -> VkSurfaceFormatKHR {
  //TODO ranking thse based on how good they are.
  for available_formats {
    if it.format == .VK_FORMAT_B8G8R8A8_SRGB && it.colorSpace == .VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
      return it;
    }
  }

  return available_formats[0];
}

choose_swap_present_mode :: (available_present_modes : [] VkPresentModeKHR) -> VkPresentModeKHR {
  // Try to pick VK_PRESENT_MODE_MAILBOX_KHR;
  for available_present_modes {
    if it == .VK_PRESENT_MODE_MAILBOX_KHR {
      return it;
    }
  }

  return .VK_PRESENT_MODE_FIFO_KHR;
}

choose_swap_extent :: (capabilities : VkSurfaceCapabilitiesKHR, window : ReactorWindow) -> VkExtent2D {
  if capabilities.currentExtent.width != U32_MAX {
    return capabilities.currentExtent;
  } else {

    actual_extent : VkExtent2D = .{
      xx clamp(window.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
      xx clamp(window.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
    };

    return actual_extent;
  }
}

// Image Views
create_image_views :: () {
  swap_chain_image_views = NewArray(swap_chain_images.count, VkImageView);

  for it, index : swap_chain_images {
    create_info : VkImageViewCreateInfo;
    create_info.sType = .VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    create_info.image = it;
    create_info.viewType = .VK_IMAGE_VIEW_TYPE_2D; // What kind of image this is... Dimentionally
    create_info.format = swap_chain_image_format;

    // Map the color components to channels
    create_info.components.r = .VK_COMPONENT_SWIZZLE_IDENTITY;
    create_info.components.g = .VK_COMPONENT_SWIZZLE_IDENTITY;
    create_info.components.b = .VK_COMPONENT_SWIZZLE_IDENTITY;
    create_info.components.a = .VK_COMPONENT_SWIZZLE_IDENTITY;

    create_info.subresourceRange.aspectMask = .VK_IMAGE_ASPECT_COLOR_BIT;
    create_info.subresourceRange.baseMipLevel = 0; // Mipmapping?
    create_info.subresourceRange.levelCount = 1; // Number of MipMap images?
    create_info.subresourceRange.baseArrayLayer = 0;
    create_info.subresourceRange.layerCount = 1;

    if vkCreateImageView(device, *create_info, null, *swap_chain_image_views[index]) != .VK_SUCCESS {
      print("failed to create image views!\n");
    }
  }
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

  create_info.enabledExtensionCount = cast(u32) required_device_extensions.count;
  create_info.ppEnabledExtensionNames = required_device_extensions.data;

  if validation_layers_enabled {
    create_info.enabledLayerCount = cast(u32) validation_layers.count;
    create_info.ppEnabledLayerNames = validation_layers.data;
  } else {
    create_info.enabledLayerCount = 0;
  }

  if vkCreateDevice(physical_device, *create_info, null, *device) != .VK_SUCCESS {
    print("failed to create logical device!\n");
  }

  vkGetDeviceQueue(device, indices.graphics_family.value, 0, *graphics_queue);
  vkGetDeviceQueue(device, indices.present_family.value, 0, *present_queue);
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
      // print("validation layer:%\n", to_string(pCallbackData.pMessage));
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

create_surface :: (instance : VkInstance, window : ReactorWindow) -> bool {
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

// Create our Render Pass
create_render_pass :: () {
  color_attachment : VkAttachmentDescription;
  color_attachment.format = swap_chain_image_format;
  color_attachment.samples = .VK_SAMPLE_COUNT_1_BIT;
  color_attachment.loadOp = .VK_ATTACHMENT_LOAD_OP_CLEAR; // Clear color bit on load?
  color_attachment.storeOp = .VK_ATTACHMENT_STORE_OP_STORE;
  color_attachment.stencilLoadOp = .VK_ATTACHMENT_LOAD_OP_DONT_CARE;
  color_attachment.stencilStoreOp = .VK_ATTACHMENT_STORE_OP_DONT_CARE;
  color_attachment.initialLayout = .VK_IMAGE_LAYOUT_UNDEFINED;
  color_attachment.finalLayout = .VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

  color_attachment_ref : VkAttachmentReference;
  color_attachment_ref.attachment = 0;
  color_attachment_ref.layout = .VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

  subpass : VkSubpassDescription;
  subpass.pipelineBindPoint = .VK_PIPELINE_BIND_POINT_GRAPHICS;
  subpass.colorAttachmentCount = 1;
  subpass.pColorAttachments = *color_attachment_ref;

  dependency : VkSubpassDependency;
  dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
  dependency.dstSubpass = 0;
  dependency.srcStageMask = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
  dependency.srcAccessMask = 0;
  dependency.dstStageMask = .VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
  dependency.dstAccessMask = .VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
  
  render_pass_info : VkRenderPassCreateInfo;
  render_pass_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
  render_pass_info.attachmentCount = 1; // Color only
  render_pass_info.pAttachments = *color_attachment; // array.data later.
  render_pass_info.subpassCount = 1;
  render_pass_info.pSubpasses = *subpass;
  render_pass_info.dependencyCount = 1;
  render_pass_info.pDependencies = *dependency;

  if vkCreateRenderPass(device , *render_pass_info, null, *render_pass) != .VK_SUCCESS {
    print("failed to create render pass!\n");
  }
}

// Create our UBO layout stuff
create_descriptor_set_layout :: () {
  ubo_layout_binding : VkDescriptorSetLayoutBinding;
  ubo_layout_binding.binding = 0;
  ubo_layout_binding.descriptorType = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
  ubo_layout_binding.descriptorCount = 1;
  ubo_layout_binding.stageFlags = .VK_SHADER_STAGE_VERTEX_BIT; // VK_SHADER_STAGE_ALL_GRAPHICS
  ubo_layout_binding.pImmutableSamplers = null;

  layout_info : VkDescriptorSetLayoutCreateInfo;
  layout_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
  layout_info.bindingCount = 1;
  layout_info.pBindings = *ubo_layout_binding;

  if vkCreateDescriptorSetLayout(device, *layout_info, null, *descriptor_set_layout) != .VK_SUCCESS {
    print("failed to create descriptor set layout!\n");
  }
}

// Create our Graphics Pipeline
create_graphics_pipeline :: () {
  vert_success, vert_source := load_shader("./res/shaders/simple_shader.vert.spv");
  frag_success, frag_source := load_shader("./res/shaders/simple_shader.frag.spv");

  vert_module_success, vert_shader_module := create_shader_module(vert_source);
  frag_module_success, frag_shader_module := create_shader_module(frag_source);

  // Create our pipeline
  vertex_shader_stage_info : VkPipelineShaderStageCreateInfo;
  vertex_shader_stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  vertex_shader_stage_info.stage = .VK_SHADER_STAGE_VERTEX_BIT;
  vertex_shader_stage_info.module = vert_shader_module;
  vertex_shader_stage_info.pName = "main"; // Entrypoint
  // vertex_shader_stage_info.pSpecializationInfo // Not used for now.

  fragment_shader_stage_info : VkPipelineShaderStageCreateInfo;
  fragment_shader_stage_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  fragment_shader_stage_info.stage = .VK_SHADER_STAGE_FRAGMENT_BIT;
  fragment_shader_stage_info.module = frag_shader_module;
  fragment_shader_stage_info.pName = "main"; // Entrypoint  

  // Define our shader stages //TODO use dynamic array.
  shader_stages : [2] VkPipelineShaderStageCreateInfo;
  shader_stages[0] = vertex_shader_stage_info;
  shader_stages[1] = fragment_shader_stage_info;

  vertex_input_info : VkPipelineVertexInputStateCreateInfo;
  vertex_input_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
  // Get data about our vertices from the Mesh class.
  binding_description := get_binding_description();
  vertex_input_info.vertexBindingDescriptionCount = 1;
  vertex_input_info.pVertexBindingDescriptions = *binding_description;
  attribute_descriptions := get_attribute_descriptions();
  vertex_input_info.vertexAttributeDescriptionCount = attribute_descriptions.count;
  vertex_input_info.pVertexAttributeDescriptions = attribute_descriptions.data;

  // Input Assembly // How vertices should be assembled.
  input_assembly : VkPipelineInputAssemblyStateCreateInfo;
  input_assembly.sType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
  input_assembly.topology = .VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
  input_assembly.primitiveRestartEnable = VK_FALSE;

  // For non-dynamic
  /**
  // Define our viewport
  viewport : VkViewport;
  viewport.x = 0.0;
  viewport.y = 0.0;
  viewport.width = xx swap_chain_extent.width;
  viewport.height = xx swap_chain_extent.height;
  viewport.minDepth = 0.0;
  viewport.maxDepth = 1.0;

  // Sciscor rectangle
  scissor : VkRect2D;
  scissor.offset = .{0,0};
  scissor.extent = swap_chain_extent;

  VkPipelineViewportStateCreateInfo viewportState{};
  viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  viewportState.viewportCount = 1;
  viewportState.pViewports = &viewport;
  viewportState.scissorCount = 1;
  viewportState.pScissors = &scissor;
  */

  viewport_state : VkPipelineViewportStateCreateInfo;
  viewport_state.sType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  viewport_state.viewportCount = 1;
  viewport_state.scissorCount = 1;

  // Define our Rasterizer
  rasterizer : VkPipelineRasterizationStateCreateInfo;
  rasterizer.sType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
  rasterizer.depthClampEnable = VK_FALSE;
  /**
    If depthClampEnable is set to VK_TRUE, then fragments that are beyond the near and far planes are clamped to them as opposed to discarding them. This is useful in some special cases like shadow maps. Using this requires enabling a GPU feature.
  */
  rasterizer.rasterizerDiscardEnable = VK_FALSE;
  rasterizer.polygonMode = .VK_POLYGON_MODE_FILL;
  rasterizer.lineWidth = 1.0; // Bigger than this requires enabling WideLines
  rasterizer.cullMode = .VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VkFrontFace.VK_FRONT_FACE_CLOCKWISE;
  // rasterizer.frontFace = VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE;
  rasterizer.depthBiasEnable = VK_FALSE; // Could this be used to help fix shadow Acne?
  rasterizer.depthBiasConstantFactor = 0.0;
  rasterizer.depthBiasClamp = 0.0;
  rasterizer.depthBiasSlopeFactor = 0.0;

  // Multisampling
  multisampling : VkPipelineMultisampleStateCreateInfo;
  multisampling.sType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
  multisampling.sampleShadingEnable = VK_FALSE;
  multisampling.rasterizationSamples = .VK_SAMPLE_COUNT_1_BIT;
  multisampling.minSampleShading = 1.0;
  multisampling.pSampleMask = null;
  multisampling.alphaToCoverageEnable = VK_FALSE;
  multisampling.alphaToOneEnable = VK_FALSE;

  // TODO VkPipelineDepthStencilStateCreateInfo

  // Color Blending // Blend Mode?
  color_blend_attachment : VkPipelineColorBlendAttachmentState;
  // color_blend_attachment.colorWriteMask = xx .VK_COLOR_COMPONENT_R_BIT | xx .VK_COLOR_COMPONENT_G_BIT | xx .VK_COLOR_COMPONENT_B_BIT | .VK_COLOR_COMPONENT_A_BIT;
  color_blend_attachment.colorWriteMask = 0x1 | 0x2 | 0x4 | 0x8; // TODO fix OR of enums
  color_blend_attachment.blendEnable = VK_FALSE; // VK_TRUE 
  color_blend_attachment.srcColorBlendFactor = .VK_BLEND_FACTOR_ONE; //VK_BLEND_FACTOR_SRC_ALPHA
  color_blend_attachment.dstColorBlendFactor = .VK_BLEND_FACTOR_ZERO; //VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
  color_blend_attachment.colorBlendOp = .VK_BLEND_OP_ADD;
  color_blend_attachment.srcAlphaBlendFactor = .VK_BLEND_FACTOR_ONE;
  color_blend_attachment.dstAlphaBlendFactor = .VK_BLEND_FACTOR_ZERO;
  color_blend_attachment.alphaBlendOp = .VK_BLEND_OP_ADD;

  color_blending : VkPipelineColorBlendStateCreateInfo;
  color_blending.sType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
  color_blending.logicOpEnable = VK_FALSE;
  color_blending.logicOp = .VK_LOGIC_OP_COPY;
  color_blending.attachmentCount = 1;
  color_blending.pAttachments = *color_blend_attachment;
  color_blending.blendConstants[0] = 0.0;
  color_blending.blendConstants[1] = 0.0;
  color_blending.blendConstants[2] = 0.0;
  color_blending.blendConstants[3] = 0.0;

  // create the popeline
  pipeline_layout_info : VkPipelineLayoutCreateInfo;
  pipeline_layout_info.sType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
  pipeline_layout_info.setLayoutCount = 1;
  pipeline_layout_info.pSetLayouts = *descriptor_set_layout;
  pipeline_layout_info.pushConstantRangeCount = 0;
  pipeline_layout_info.pPushConstantRanges = null;

  if vkCreatePipelineLayout(device , *pipeline_layout_info, null, *pipeline_layout) != .VK_SUCCESS {
    print("failed to create pipeline layout!\n");
  }

  // Configure Dynamic State
  dynamic_states := VkDynamicState.[.VK_DYNAMIC_STATE_VIEWPORT, .VK_DYNAMIC_STATE_SCISSOR];

  dynamic_state : VkPipelineDynamicStateCreateInfo;
  dynamic_state.sType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
  dynamic_state.dynamicStateCount = dynamic_states.count;
  dynamic_state.pDynamicStates = dynamic_states.data;

  // Create our pipeline!
    // Reference Create info
  pipeline_info : VkGraphicsPipelineCreateInfo;
  pipeline_info.sType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
  // Reference Fixed Function Stages
  pipeline_info.stageCount = 2;
  pipeline_info.pStages = shader_stages.data;
  pipeline_info.pVertexInputState = *vertex_input_info;
  pipeline_info.pInputAssemblyState = *input_assembly;
  pipeline_info.pViewportState = *viewport_state;
  pipeline_info.pRasterizationState = *rasterizer;
  pipeline_info.pMultisampleState = *multisampling;
  pipeline_info.pDepthStencilState = null; 
  pipeline_info.pColorBlendState = *color_blending;
  pipeline_info.pDynamicState = *dynamic_state;
  // Reference pipeline layout
  pipeline_info.layout = pipeline_layout;
  // Render Pass
  pipeline_info.renderPass = render_pass;
  pipeline_info.subpass = 0;
  // Pipeline recreation stuff
  pipeline_info.basePipelineHandle = VK_NULL_HANDLE;
  pipeline_info.basePipelineIndex = -1;

  if vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, *pipeline_info, null, *graphics_pipeline) != .VK_SUCCESS {
    print("failed to create graphics pipeline!\n");
  }


  // Destroy our shaders
  vkDestroyShaderModule(device, vert_shader_module, null);
  vkDestroyShaderModule(device, frag_shader_module, null);

  // Free our files
  free(vert_source);
  free(frag_source);
}

// Framebuffer stuff
create_frame_buffers :: () {
  free(swap_chain_frame_buffers.data);
  swap_chain_frame_buffers = NewArray(swap_chain_image_views.count, VkFramebuffer);

  for it, index : swap_chain_image_views {
    attachments : [1]VkImageView;
    attachments[0] = swap_chain_image_views[index];

    frame_buffer_info : VkFramebufferCreateInfo;
    frame_buffer_info.sType = .VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    frame_buffer_info.renderPass = render_pass;
    frame_buffer_info.attachmentCount = 1;
    frame_buffer_info.pAttachments = attachments.data;
    frame_buffer_info.width = swap_chain_extent.width;
    frame_buffer_info.height = swap_chain_extent.height;
    frame_buffer_info.layers = 1;

    if vkCreateFramebuffer(device, *frame_buffer_info, null, *swap_chain_frame_buffers[index]) != .VK_SUCCESS{
      print("failed to create framebuffer!\n");
    }
  }
}

// Create command pool
create_command_pool :: () {
  queue_family_indices := find_queue_famlilies(physical_device); // TODO cache once.

  pool_info : VkCommandPoolCreateInfo;
  pool_info.sType = .COMMAND_POOL_CREATE_INFO;
  pool_info.flags = .VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT; //VK_COMMAND_POOL_CREATE_TRANSIENT_BIT command buffer changes frequently.
  pool_info.queueFamilyIndex = queue_family_indices.graphics_family.value;

  if vkCreateCommandPool(device , *pool_info, null, *command_pool) != .VK_SUCCESS {
    print("failed to create command pool!\n");
  }
}

// Create our vertex buffer
create_vertex_buffer :: () {
  buffer_size : VkDeviceSize = xx (size_of(Vector3) * first_mesh.vertex_count);

  staging_buffer : VkBuffer;
  staging_buffer_memory : VkDeviceMemory;
  create_buffer(buffer_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, *staging_buffer, *staging_buffer_memory);

  data : *void;
  vkMapMemory(device, staging_buffer_memory, 0, buffer_size, 0, *data);
  memcpy(data, first_mesh.vertices.data, xx buffer_size);
  vkUnmapMemory(device, staging_buffer_memory);

  create_buffer(buffer_size, VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, *vertex_buffer, *vertex_buffer_memory);
  copy_buffer(staging_buffer, vertex_buffer, buffer_size);

  vkDestroyBuffer(device, staging_buffer, null);
  vkFreeMemory(device, staging_buffer_memory, null);
}

copy_buffer :: (src_buffer : VkBuffer , dst_buffer : VkBuffer, size : VkDeviceSize) {
  alloc_info : VkCommandBufferAllocateInfo;
  alloc_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  alloc_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  alloc_info.commandPool = command_pool;
  alloc_info.commandBufferCount = 1;

  command_buffer : VkCommandBuffer;
  vkAllocateCommandBuffers(device, *alloc_info, *command_buffer);

  begin_info : VkCommandBufferBeginInfo;
  begin_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  begin_info.flags = .VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

  vkBeginCommandBuffer(command_buffer, *begin_info);

  copy_region : VkBufferCopy;
  copy_region.srcOffset = 0;
  copy_region.dstOffset = 0;
  copy_region.size = size;
  vkCmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, *copy_region);
  vkEndCommandBuffer(command_buffer);

  submit_info : VkSubmitInfo;
  submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO;
  submit_info.commandBufferCount = 1;
  submit_info.pCommandBuffers = *command_buffer;

  vkQueueSubmit(graphics_queue, 1, *submit_info, VK_NULL_HANDLE);
  vkQueueWaitIdle(graphics_queue);

  vkFreeCommandBuffers(device, command_pool, 1, *command_buffer);
}

create_buffer :: (size : VkDeviceSize, usage : VkBufferUsageFlags , properties : VkMemoryPropertyFlagBits, buffer : *VkBuffer, buffer_memory : *VkDeviceMemory) {
  buffer_info : VkBufferCreateInfo;
  buffer_info.sType = .VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  buffer_info.size = size;
  buffer_info.usage = usage;
  buffer_info.sharingMode = .VK_SHARING_MODE_EXCLUSIVE;

  if vkCreateBuffer(device, *buffer_info, null, buffer) != .VK_SUCCESS {
    print("failed to create buffer!\n");
  }

  mem_requirements : VkMemoryRequirements;
  vkGetBufferMemoryRequirements(device, << buffer, *mem_requirements);

  alloc_info : VkMemoryAllocateInfo;
  alloc_info.sType = .VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  alloc_info.allocationSize = mem_requirements.size;
  alloc_info.memoryTypeIndex = find_memory_type(mem_requirements.memoryTypeBits, properties);

  if vkAllocateMemory(device, *alloc_info, null, buffer_memory) != .VK_SUCCESS {
    print("failed to allocate buffer memory!\n");
    return;
  }

  vkBindBufferMemory(device, << buffer, << buffer_memory, 0);
}

create_index_buffer :: () {
  buffer_size : VkDeviceSize = xx (size_of(u32) * first_mesh.index_count);

  staging_buffer : VkBuffer;
  staging_buffer_memory : VkDeviceMemory;
  create_buffer(buffer_size, .VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, *staging_buffer, *staging_buffer_memory);

  data : *void;
  vkMapMemory(device, staging_buffer_memory, 0, buffer_size, 0, *data);
  memcpy(data, first_mesh.indices.data, xx buffer_size);
  vkUnmapMemory(device, staging_buffer_memory);

  create_buffer(buffer_size, VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_DST_BIT | .VK_BUFFER_USAGE_INDEX_BUFFER_BIT, .VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, *index_buffer, *index_buffer_memory);
  copy_buffer(staging_buffer, index_buffer, buffer_size);

  vkDestroyBuffer(device, staging_buffer, null);
  vkFreeMemory(device, staging_buffer_memory, null);
}

create_uniform_buffers :: () {
  buffer_size : VkDeviceSize = xx size_of(UBO_MVP);
  //THIS COULD BE THE PROBLEM WHEN THIS DOES NOT WORK.
  for 0 .. MAX_FRAMES_IN_FLIGHT - 1 {
    create_buffer(buffer_size, .VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | .VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, *uniform_buffers[it], *uniform_buffers_memory[it]);
    vkMapMemory(device, uniform_buffers_memory[it], 0, buffer_size, 0, *uniform_buffers_mapped[it]);
  } 
}

create_descriptor_pool :: () {
  pool_size : VkDescriptorPoolSize;
  pool_size.type = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
  pool_size.descriptorCount = MAX_FRAMES_IN_FLIGHT;

  pool_info : VkDescriptorPoolCreateInfo;
  pool_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
  pool_info.poolSizeCount = 1;
  pool_info.pPoolSizes = *pool_size;
  pool_info.maxSets = MAX_FRAMES_IN_FLIGHT;

  if vkCreateDescriptorPool(device, *pool_info, null, *descriptor_pool) != .VK_SUCCESS {
    print("failed to create descriptor pool!\n");
  }
}

create_descriptor_sets :: () {

  alloc_info : VkDescriptorSetAllocateInfo ;
  alloc_info.sType = .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
  alloc_info.descriptorPool = descriptor_pool;
  alloc_info.descriptorSetCount = 1;
  alloc_info.pSetLayouts = *descriptor_set_layout;

  for 0 .. MAX_FRAMES_IN_FLIGHT - 1 {

    if vkAllocateDescriptorSets(device, *alloc_info, *descriptor_sets[it]) != .VK_SUCCESS {
      print("failed to allocate descriptor sets!\n");
    }

    buffer_info : VkDescriptorBufferInfo;
    buffer_info.buffer = uniform_buffers[it];
    buffer_info.offset = 0;
    buffer_info.range = size_of(UBO_MVP);

    descriptor_write : VkWriteDescriptorSet;
    descriptor_write.sType = .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    descriptor_write.dstSet = descriptor_sets[it];
    descriptor_write.dstBinding = 0;
    descriptor_write.dstArrayElement = 0; // If we are using an array, the array index.
    descriptor_write.descriptorType = .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    descriptor_write.descriptorCount = 1;
    descriptor_write.pBufferInfo = *buffer_info;
    descriptor_write.pImageInfo = null;
    descriptor_write.pTexelBufferView = null;

    vkUpdateDescriptorSets(device, 1, *descriptor_write, 0, null);
  }

}

// Create Command Buffer
create_command_buffers :: () {
  alloc_info : VkCommandBufferAllocateInfo;
  alloc_info.sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  alloc_info.commandPool = command_pool;
  alloc_info.level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  alloc_info.commandBufferCount = MAX_FRAMES_IN_FLIGHT;
  /**
    VK_COMMAND_BUFFER_LEVEL_PRIMARY: Can be submitted to a queue for execution, but cannot be called from other command buffers.
    VK_COMMAND_BUFFER_LEVEL_SECONDARY: Cannot be submitted directly, but can be called from primary command buffers.
  */
  

  if vkAllocateCommandBuffers(device, *alloc_info, command_buffers.data) != .VK_SUCCESS {
    print("failed to allocate command buffers!\n");
  }
}

record_command_buffer :: (command_buffer : VkCommandBuffer, image_index : u32) {
  begin_info : VkCommandBufferBeginInfo;
  begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO; //VK_STRUCTURE_COMMAND_BUFFER_BEGIN_INFO?
  begin_info.flags = 0;
  begin_info.pInheritanceInfo = null;

  if vkBeginCommandBuffer(command_buffer, *begin_info) {
    print("failed to begin recording command buffer!\n");
  }

  // Start Render pass
  render_pass_info : VkRenderPassBeginInfo;
  render_pass_info.sType = .VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
  render_pass_info.renderPass = render_pass;
  render_pass_info.framebuffer = swap_chain_frame_buffers[image_index];
  // Define the Size of the render area.
  render_pass_info.renderArea.offset = .{0, 0};
  render_pass_info.renderArea.extent = swap_chain_extent;
  // Define the clear color.
  clear_color : VkClearValue = .{.{.[0.0, 0.0, 0.0, 1.0]}}; // .color._flaot32
  render_pass_info.clearValueCount = 1;
  render_pass_info.pClearValues = *clear_color;

  // Begin Render Pass
  vkCmdBeginRenderPass(command_buffer, *render_pass_info, .VK_SUBPASS_CONTENTS_INLINE); // Primary vs Secondary Command buffer.
  // Bind the Graphics Pipeline
  vkCmdBindPipeline(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, graphics_pipeline);

  viewport : VkViewport;
  viewport.x = 0.0;
  viewport.y = 0.0;
  viewport.width = xx swap_chain_extent.width;
  viewport.height = xx swap_chain_extent.height;
  viewport.minDepth = 0.0;
  viewport.maxDepth = 1.0;
  vkCmdSetViewport(command_buffer, 0, 1, *viewport);

  scissor : VkRect2D;
  scissor.offset = .{0, 0};
  scissor.extent = swap_chain_extent;
  vkCmdSetScissor(command_buffer, 0, 1, *scissor);

  vertex_buffers : [1]VkBuffer; // TODO Dynamic?
  vertex_buffers[0] = vertex_buffer;
  offsets := VkDeviceSize.[0];
  vkCmdBindVertexBuffers(command_buffer, 0, 1, vertex_buffers.data, offsets.data);
  vkCmdBindIndexBuffer(command_buffer, index_buffer, 0, .VK_INDEX_TYPE_UINT32);

  vkCmdBindDescriptorSets(command_buffer, .VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout, 0, 1, *descriptor_sets[frame_index], 0, null);
  vkCmdDrawIndexed(command_buffer, first_mesh.index_count, 1, 0, 0, 0); // Draw call??
  /**
  commandBuffer   is the command buffer into which the command is recorded.
  vertexCount     is the number of vertices to draw.
  instanceCount   is the number of instances to draw.
  firstVertex     is the index of the first vertex to draw.
  firstInstance   is the instance ID of the first instance to draw.
  */
  vkCmdEndRenderPass(command_buffer);
  if (vkEndCommandBuffer(command_buffer) != .VK_SUCCESS) {
    print("failed to record command buffer!");
  }
}

create_sync_objects :: () {
  semaphore_info : VkSemaphoreCreateInfo;
  semaphore_info.sType = .VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

  fence_info : VkFenceCreateInfo;
  fence_info.sType = .VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
  fence_info.flags = .VK_FENCE_CREATE_SIGNALED_BIT; // Create this fence in the signaled state to not block forever on first frame.

  for 0 .. (MAX_FRAMES_IN_FLIGHT - 1) {
    if vkCreateSemaphore(device, *semaphore_info, null, *image_available_semaphores[it]) != .VK_SUCCESS ||
      vkCreateSemaphore(device, *semaphore_info, null, *render_finished_semaphores[it]) != .VK_SUCCESS ||
      vkCreateFence(device, *fence_info, null, *in_flight_fences[it]) != .VK_SUCCESS {
      print("failed to create semaphores!\n");
    }
  }

}

draw_frame :: (delta_time : float64) {

  // Wait for previous frame to finish
  vkWaitForFences(device, 1, *in_flight_fences[frame_index], VK_TRUE, U64_MAX);

  // Acquire and image from the swap chain
  image_index : u32;
  result := vkAcquireNextImageKHR(device, swap_chain, U64_MAX, image_available_semaphores[frame_index], VK_NULL_HANDLE, *image_index);

  // Check if the driver did not detect the .VK_ERROR_OUT_OF_DATE_KHR but we did resize.
  if result == .VK_SUCCESS && window_changed_sizes {
    window_changed_sizes = false;
    result = .VK_ERROR_OUT_OF_DATE_KHR;
  }

  if result == {
    case .SUCCESS;
      // Succeded
    case .VK_ERROR_OUT_OF_DATE_KHR; #through; 
    case .VK_SUBOPTIMAL_KHR;
      // print("Recreated swap chain!\n");
      recreate_swap_chain();
      return;
    case; // Unhandled error.
      print("failed to acquire swap chain image!\n");
  }

  update_uniform_buffer(delta_time, frame_index);

  // Only reset the fence if we are submitting work. // Errors which cause the swapchain to be regenerated will return before this.
  vkResetFences(device, 1, *in_flight_fences[frame_index]);
  
  vkResetCommandBuffer(command_buffers[frame_index], 0); //VkCommandBufferResetFlagBits
  record_command_buffer(command_buffers[frame_index], image_index); // the index comes from vkAcquireNextImageKHR

  // Submit the recorded command buffer
  submit_info : VkSubmitInfo;
  submit_info.sType = .VK_STRUCTURE_TYPE_SUBMIT_INFO;

  wait_semaphores : [1] VkSemaphore;
  wait_semaphores[0] = image_available_semaphores[frame_index]; // TODO: replace with Vector or dynamic array.
  wait_stages := VkPipelineStageFlags.[.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT]; // Wait on the color attachment being output
  submit_info.waitSemaphoreCount = 1;
  submit_info.pWaitSemaphores = wait_semaphores.data;
  submit_info.pWaitDstStageMask = wait_stages.data;
  submit_info.commandBufferCount = 1;
  submit_info.pCommandBuffers = *command_buffers[frame_index];

  signal_semaphores : [1] VkSemaphore;
  signal_semaphores[0] = render_finished_semaphores[frame_index];
  submit_info.signalSemaphoreCount = 1;
  submit_info.pSignalSemaphores = signal_semaphores.data;

  // Submit queue
  if vkQueueSubmit(graphics_queue, 1, *submit_info, in_flight_fences[frame_index]) != .VK_SUCCESS {
    print("failed to submit draw command buffer!");
  }

  // Present the swap chain image.
  present_info : VkPresentInfoKHR;
  present_info.sType = .VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  present_info.waitSemaphoreCount = 1;
  present_info.pWaitSemaphores = signal_semaphores.data;

  swap_chains : [1]VkSwapchainKHR;
  swap_chains[0] = swap_chain;
  present_info.swapchainCount = 1; // TODO count of swap_chains?
  present_info.pSwapchains = swap_chains.data;
  present_info.pImageIndices = *image_index;
  present_info.pResults = null; // Check if presentation was successful or not.

  // Present the presentation_queue
  result = vkQueuePresentKHR(present_queue, *present_info);

  // Advance frame_index
  frame_index = (frame_index + 1) % MAX_FRAMES_IN_FLIGHT;
}

update_uniform_buffer :: ( delta : float64, current_image : u32 ) {

  speed : float = xx ( 1.0 * delta);

  if is_key_pressed(*keyboard, 87) { // W
    Camera.translate(*active_camera, 0.0, 0.0, speed);
  }

  if is_key_pressed(*keyboard, 83) { // S
    Camera.translate(*active_camera, 0.0, 0.0, -speed);
  }

  if is_key_pressed(*keyboard, 65) { // A
    Camera.translate(*active_camera, -speed, 0.0, 0.0);
  }

  if is_key_pressed(*keyboard, 68) { // D
    Camera.translate(*active_camera, speed, 0.0, 0.0);
  }

  if is_key_pressed(*keyboard, 81) { // Q
    Camera.translate(*active_camera, 0.0, speed, 0.0);
  }

  if is_key_pressed(*keyboard, 69) { // E
    Camera.translate(*active_camera, 0.0, -speed, 0.0);
  }

  // Update our UBO
  ubo.aspect_ratio = window.aspect_ratio;

  rotation = xx fmod_cycling(rotation + delta, 2.0 * PI);

  translation := transpose(.{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 5,
    0, 0, 0, 1
  });

  test := Quaternion.{0, 1, 0, ((sin(rotation) + 1.0) / 2.0) * 10.0};
  normalize_or_identity(*test);
  ubo.model = translation;

  ubo.view = Camera.getView(*active_camera);
  ubo.projection = active_camera.proj;

  memcpy(uniform_buffers_mapped[current_image], *ubo, size_of(UBO_MVP));
}

create_shader_module :: ( source : string) -> bool, VkShaderModule {

  create_info : VkShaderModuleCreateInfo;
  create_info.sType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  create_info.codeSize = cast(u64) source.count;
  create_info.pCode = cast(*u32)*source[0];

  shader_module : VkShaderModule;
  if vkCreateShaderModule(device, *create_info, null, *shader_module) != .VK_SUCCESS {
    print("failed to create shader module!\n");
    return false, null;
  }

  return true, shader_module;
}