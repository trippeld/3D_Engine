const std = @import("std");
const sdl = @import("../../platform/sdl.zig");
const vk = sdl.c;

pub const Renderer = struct {
    instance: vk.VkInstance = null,
    surface: vk.VkSurfaceKHR = null,

    physical_device: vk.VkPhysicalDevice = null,
    device: vk.VkDevice = null,

    graphics_queue: vk.VkQueue = null,
    present_queue: vk.VkQueue = null,

    graphics_queue_family_index: u32 = 0,
    present_queue_family_index: u32 = 0,

    swapchain: vk.VkSwapchainKHR = null,
    swapchain_images: []vk.VkImage = &.{},
    swapchain_image_views: []vk.VkImageView = &.{},
    swapchain_format: vk.VkFormat = vk.VK_FORMAT_UNDEFINED,
    swapchain_extent: vk.VkExtent2D = .{ .width = 0, .height = 0 },

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, window: *sdl.Window) !Renderer {
        var self = Renderer{
            .allocator = allocator,
        };

        try self.create_instance();
        errdefer self.deinit();

        try self.create_surface(window);
        try self.pick_physical_device();
        try self.create_logical_device();
        try self.create_swapchain(window);
        try self.create_image_views();

        std.log.info("Vulkan device + swapchain bootstrap completed", .{});
        return self;
    }

    pub fn deinit(self: *Renderer) void {
        self.destroy_swapchain();

        if (self.device != null) {
            vk.vkDestroyDevice(self.device, null);
            self.device = null;
        }

        if (self.surface != null and self.instance != null) {
            vk.vkDestroySurfaceKHR(self.instance, self.surface, null);
            self.surface = null;
        }

        if (self.instance != null) {
            vk.vkDestroyInstance(self.instance, null);
            self.instance = null;
        }
    }

    fn destroy_swapchain(self: *Renderer) void {
        for (self.swapchain_image_views) |view| {
            vk.vkDestroyImageView(self.device, view, null);
        }
        if (self.swapchain_image_views.len != 0) {
            self.allocator.free(self.swapchain_image_views);
            self.swapchain_image_views = &.{};
        }

        if (self.swapchain_images.len != 0) {
            self.allocator.free(self.swapchain_images);
            self.swapchain_images = &.{};
        }

        if (self.swapchain != null) {
            vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);
            self.swapchain = null;
        }
    }

    fn create_instance(self: *Renderer) !void {
        var sdl_ext_count: u32 = 0;
        const sdl_ext_names = vk.SDL_Vulkan_GetInstanceExtensions(&sdl_ext_count) orelse {
            std.log.err("SDL_Vulkan_GetInstanceExtensions failed: {s}", .{vk.SDL_GetError()});
            return error.SdlVulkanExtensionsFailed;
        };

        const portability_ext = "VK_KHR_portability_enumeration";

        var all_ext_names: [16][*:0]const u8 = undefined;
        var ext_count: u32 = 0;

        var i: usize = 0;
        while (i < sdl_ext_count) : (i += 1) {
            all_ext_names[ext_count] = sdl_ext_names[i];
            ext_count += 1;
        }

        all_ext_names[ext_count] = portability_ext;
        ext_count += 1;

        var app_info = std.mem.zeroes(vk.VkApplicationInfo);
        app_info.sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        app_info.pApplicationName = "3D Engine";
        app_info.applicationVersion = vk.VK_MAKE_API_VERSION(0, 0, 1, 0);
        app_info.pEngineName = "3D Engine";
        app_info.engineVersion = vk.VK_MAKE_API_VERSION(0, 0, 1, 0);
        app_info.apiVersion = vk.VK_API_VERSION_1_3;

        var create_info = std.mem.zeroes(vk.VkInstanceCreateInfo);
        create_info.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        create_info.pApplicationInfo = &app_info;
        create_info.enabledExtensionCount = ext_count;
        create_info.ppEnabledExtensionNames = @ptrCast(&all_ext_names[0]);
        create_info.flags = vk.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;

        const result = vk.vkCreateInstance(&create_info, null, &self.instance);
        if (result != vk.VK_SUCCESS) {
            std.log.err("vkCreateInstance failed with VkResult={d}", .{result});
            return error.VkCreateInstanceFailed;
        }

        std.log.info("Vulkan instance created with {d} extensions", .{ext_count});
    }

    fn create_surface(self: *Renderer, window: *sdl.Window) !void {
        if (!vk.SDL_Vulkan_CreateSurface(window, self.instance, null, &self.surface)) {
            std.log.err("SDL_Vulkan_CreateSurface failed: {s}", .{vk.SDL_GetError()});
            return error.SdlVulkanSurfaceFailed;
        }

        std.log.info("SDL Vulkan surface created", .{});
    }

    fn pick_physical_device(self: *Renderer) !void {
        var device_count: u32 = 0;
        if (vk.vkEnumeratePhysicalDevices(self.instance, &device_count, null) != vk.VK_SUCCESS or device_count == 0) {
            return error.NoPhysicalDevices;
        }

        const devices = try self.allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer self.allocator.free(devices);

        if (vk.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr) != vk.VK_SUCCESS) {
            return error.PhysicalDeviceEnumerationFailed;
        }

        for (devices) |device| {
            if (try self.is_physical_device_suitable(device)) {
                self.physical_device = device;
                break;
            }
        }

        if (self.physical_device == null) {
            return error.NoSuitablePhysicalDevice;
        }

        var props = std.mem.zeroes(vk.VkPhysicalDeviceProperties);
        vk.vkGetPhysicalDeviceProperties(self.physical_device, &props);

        std.log.info("Selected GPU: {s}", .{props.deviceName});
    }

    fn is_physical_device_suitable(self: *Renderer, device: vk.VkPhysicalDevice) !bool {
        const indices = try self.find_queue_families(device);
        if (!indices.complete()) return false;

        if (!try self.check_device_extension_support(device)) return false;

        const swapchain_support = try self.query_swapchain_support(device);
        defer swapchain_support.deinit(self.allocator);

        return swapchain_support.formats.len != 0 and swapchain_support.present_modes.len != 0;
    }

    fn create_logical_device(self: *Renderer) !void {
        const indices = try self.find_queue_families(self.physical_device);
        if (!indices.complete()) return error.MissingQueueFamilies;

        self.graphics_queue_family_index = indices.graphics_family.?;
        self.present_queue_family_index = indices.present_family.?;

        const queue_priority: f32 = 1.0;

        var queue_infos: [2]vk.VkDeviceQueueCreateInfo = undefined;
        var queue_info_count: u32 = 0;

        queue_infos[queue_info_count] = std.mem.zeroes(vk.VkDeviceQueueCreateInfo);
        queue_infos[queue_info_count].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queue_infos[queue_info_count].queueFamilyIndex = self.graphics_queue_family_index;
        queue_infos[queue_info_count].queueCount = 1;
        queue_infos[queue_info_count].pQueuePriorities = &queue_priority;
        queue_info_count += 1;

        if (self.present_queue_family_index != self.graphics_queue_family_index) {
            queue_infos[queue_info_count] = std.mem.zeroes(vk.VkDeviceQueueCreateInfo);
            queue_infos[queue_info_count].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            queue_infos[queue_info_count].queueFamilyIndex = self.present_queue_family_index;
            queue_infos[queue_info_count].queueCount = 1;
            queue_infos[queue_info_count].pQueuePriorities = &queue_priority;
            queue_info_count += 1;
        }

        const device_extensions = [_][*:0]const u8{
            "VK_KHR_swapchain",
            "VK_KHR_portability_subset",
        };

        var features = std.mem.zeroes(vk.VkPhysicalDeviceFeatures);

        var create_info = std.mem.zeroes(vk.VkDeviceCreateInfo);
        create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        create_info.queueCreateInfoCount = queue_info_count;
        create_info.pQueueCreateInfos = &queue_infos[0];
        create_info.enabledExtensionCount = device_extensions.len;
        create_info.ppEnabledExtensionNames = @ptrCast(&device_extensions[0]);
        create_info.pEnabledFeatures = &features;

        const result = vk.vkCreateDevice(self.physical_device, &create_info, null, &self.device);
        if (result != vk.VK_SUCCESS) {
            std.log.err("vkCreateDevice failed with VkResult={d}", .{result});
            return error.VkCreateDeviceFailed;
        }

        vk.vkGetDeviceQueue(self.device, self.graphics_queue_family_index, 0, &self.graphics_queue);
        vk.vkGetDeviceQueue(self.device, self.present_queue_family_index, 0, &self.present_queue);

        std.log.info(
            "Logical device created (graphics family {d}, present family {d})",
            .{ self.graphics_queue_family_index, self.present_queue_family_index },
        );
    }

    fn create_swapchain(self: *Renderer, window: *sdl.Window) !void {
        const support = try self.query_swapchain_support(self.physical_device);
        defer support.deinit(self.allocator);

        const surface_format = choose_swap_surface_format(support.formats);
        const present_mode = choose_present_mode(support.present_modes);
        const extent = try choose_swap_extent(window, support.capabilities);

        var image_count = support.capabilities.minImageCount + 1;
        if (support.capabilities.maxImageCount > 0 and image_count > support.capabilities.maxImageCount) {
            image_count = support.capabilities.maxImageCount;
        }

        var queue_family_indices = [_]u32{
            self.graphics_queue_family_index,
            self.present_queue_family_index,
        };

        var create_info = std.mem.zeroes(vk.VkSwapchainCreateInfoKHR);
        create_info.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        create_info.surface = self.surface;
        create_info.minImageCount = image_count;
        create_info.imageFormat = surface_format.format;
        create_info.imageColorSpace = surface_format.colorSpace;
        create_info.imageExtent = extent;
        create_info.imageArrayLayers = 1;
        create_info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        if (self.graphics_queue_family_index != self.present_queue_family_index) {
            create_info.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT;
            create_info.queueFamilyIndexCount = 2;
            create_info.pQueueFamilyIndices = &queue_family_indices[0];
        } else {
            create_info.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
            create_info.queueFamilyIndexCount = 0;
            create_info.pQueueFamilyIndices = null;
        }

        create_info.preTransform = support.capabilities.currentTransform;
        create_info.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        create_info.presentMode = present_mode;
        create_info.clipped = vk.VK_TRUE;
        create_info.oldSwapchain = null;

        const result = vk.vkCreateSwapchainKHR(self.device, &create_info, null, &self.swapchain);
        if (result != vk.VK_SUCCESS) {
            std.log.err("vkCreateSwapchainKHR failed with VkResult={d}", .{result});
            return error.VkCreateSwapchainFailed;
        }

        self.swapchain_format = surface_format.format;
        self.swapchain_extent = extent;

        var actual_image_count: u32 = 0;
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &actual_image_count, null);

        self.swapchain_images = try self.allocator.alloc(vk.VkImage, actual_image_count);
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &actual_image_count, self.swapchain_images.ptr);

        std.log.info(
            "Swapchain created: {d} images, extent {d}x{d}",
            .{ actual_image_count, extent.width, extent.height },
        );
    }

    fn create_image_views(self: *Renderer) !void {
        self.swapchain_image_views = try self.allocator.alloc(vk.VkImageView, self.swapchain_images.len);

        for (self.swapchain_images, 0..) |image, i| {
            var create_info = std.mem.zeroes(vk.VkImageViewCreateInfo);
            create_info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            create_info.image = image;
            create_info.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
            create_info.format = self.swapchain_format;
            create_info.components.r = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.components.g = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.components.b = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.components.a = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            create_info.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
            create_info.subresourceRange.baseMipLevel = 0;
            create_info.subresourceRange.levelCount = 1;
            create_info.subresourceRange.baseArrayLayer = 0;
            create_info.subresourceRange.layerCount = 1;

            const result = vk.vkCreateImageView(self.device, &create_info, null, &self.swapchain_image_views[i]);
            if (result != vk.VK_SUCCESS) {
                std.log.err("vkCreateImageView failed with VkResult={d}", .{result});
                return error.VkCreateImageViewFailed;
            }
        }

        std.log.info("Created {d} swapchain image views", .{self.swapchain_image_views.len});
    }

    fn check_device_extension_support(self: *Renderer, device: vk.VkPhysicalDevice) !bool {
    var extension_count: u32 = 0;
    _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, null);

    const available = try self.allocator.alloc(vk.VkExtensionProperties, extension_count);
    defer self.allocator.free(available);

    _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, available.ptr);

    for (available) |ext| {
        const name = std.mem.span(@as([*:0]const u8, @ptrCast(&ext.extensionName[0])));
        if (std.mem.eql(u8, name, "VK_KHR_swapchain")) {
            return true;
        }
    }

    return false;
}

    fn find_queue_families(self: *Renderer, device: vk.VkPhysicalDevice) !QueueFamilyIndices {
    var count: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &count, null);

    const families = try self.allocator.alloc(vk.VkQueueFamilyProperties, count);
    defer self.allocator.free(families);

    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &count, families.ptr);

    var indices = QueueFamilyIndices{};

    for (families, 0..) |family, i| {
        if ((family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT) != 0) {
            indices.graphics_family = @intCast(i);
        }

        var present_support: vk.VkBool32 = vk.VK_FALSE;
        _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), self.surface, &present_support);
        if (present_support == vk.VK_TRUE) {
            indices.present_family = @intCast(i);
        }

        if (indices.complete()) break;
    }

    return indices;
}

    fn query_swapchain_support(self: *Renderer, device: vk.VkPhysicalDevice) !SwapchainSupportDetails {
        var details = SwapchainSupportDetails{};

        _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, self.surface, &details.capabilities);

        var format_count: u32 = 0;
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, null);
        if (format_count != 0) {
            details.formats = try self.allocator.alloc(vk.VkSurfaceFormatKHR, format_count);
            _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, details.formats.ptr);
        }

        var present_mode_count: u32 = 0;
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_mode_count, null);
        if (present_mode_count != 0) {
            details.present_modes = try self.allocator.alloc(vk.VkPresentModeKHR, present_mode_count);
            _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_mode_count, details.present_modes.ptr);
        }

        return details;
    }
};

const QueueFamilyIndices = struct {
    graphics_family: ?u32 = null,
    present_family: ?u32 = null,

    fn complete(self: QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

const SwapchainSupportDetails = struct {
    capabilities: vk.VkSurfaceCapabilitiesKHR = std.mem.zeroes(vk.VkSurfaceCapabilitiesKHR),
    formats: []vk.VkSurfaceFormatKHR = &.{},
    present_modes: []vk.VkPresentModeKHR = &.{},

    fn deinit(self: SwapchainSupportDetails, allocator: std.mem.Allocator) void {
        if (self.formats.len != 0) allocator.free(self.formats);
        if (self.present_modes.len != 0) allocator.free(self.present_modes);
    }
};

fn choose_swap_surface_format(formats: []const vk.VkSurfaceFormatKHR) vk.VkSurfaceFormatKHR {
    for (formats) |format| {
        if (format.format == vk.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format;
        }
    }
    return formats[0];
}

fn choose_present_mode(present_modes: []const vk.VkPresentModeKHR) vk.VkPresentModeKHR {
    for (present_modes) |mode| {
        if (mode == vk.VK_PRESENT_MODE_MAILBOX_KHR) return mode;
    }
    return vk.VK_PRESENT_MODE_FIFO_KHR;
}

fn choose_swap_extent(window: *sdl.Window, capabilities: vk.VkSurfaceCapabilitiesKHR) !vk.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    }

    var width: c_int = 0;
    var height: c_int = 0;
    if (!vk.SDL_GetWindowSizeInPixels(window, &width, &height)) {
        return error.GetWindowSizeFailed;
    }

    var extent = vk.VkExtent2D{
        .width = @intCast(width),
        .height = @intCast(height),
    };

    extent.width = std.math.clamp(extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
    extent.height = std.math.clamp(extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);

    return extent;
}
