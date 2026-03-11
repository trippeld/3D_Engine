const std = @import("std");
const sdl = @import("../../platform/sdl.zig");
const vk = sdl.c;
const math = @import("../../core/math.zig");

pub const FrameData = struct {
    view_proj: math.Mat4,
    models: []const math.Mat4,
};

const Vertex = struct {
    pos: [3]f32,
    color: [3]f32,
};

const cube_vertices = [_]Vertex{
    .{ .pos = .{ -0.5, -0.5, 0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .pos = .{ 0.5, -0.5, 0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .pos = .{ 0.5, 0.5, 0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
    .{ .pos = .{ -0.5, 0.5, 0.5 }, .color = .{ 1.0, 1.0, 0.0 } },

    .{ .pos = .{ -0.5, -0.5, -0.5 }, .color = .{ 1.0, 0.0, 1.0 } },
    .{ .pos = .{ 0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 1.0 } },
    .{ .pos = .{ 0.5, 0.5, -0.5 }, .color = .{ 1.0, 1.0, 1.0 } },
    .{ .pos = .{ -0.5, 0.5, -0.5 }, .color = .{ 0.2, 0.2, 0.2 } },
};

const cube_indices = [_]u32{
    0, 1, 2, 2, 3, 0, // front
    4, 6, 5, 6, 4, 7, // back
    4, 0, 3, 3, 7, 4, // left
    1, 5, 6, 6, 2, 1, // right
    3, 2, 6, 6, 7, 3, // top
    4, 5, 1, 1, 0, 4, // bottom
};

const PushConstants = struct {
    view_proj: [16]f32,
    model: [16]f32,
};

const triangle_vert_spv align(@alignOf(u32)) = @embedFile("shaders/triangle.vert.spv").*;
const triangle_frag_spv align(@alignOf(u32)) = @embedFile("shaders/triangle.frag.spv").*;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    window: *sdl.Window,

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
    swapchain_image_initialized: []bool = &.{},
    swapchain_format: vk.VkFormat = vk.VK_FORMAT_UNDEFINED,
    swapchain_extent: vk.VkExtent2D = .{ .width = 0, .height = 0 },

    command_pool: vk.VkCommandPool = null,
    command_buffers: []vk.VkCommandBuffer = &.{},

    image_available_semaphore: vk.VkSemaphore = null,
    render_finished_semaphore: vk.VkSemaphore = null,
    in_flight_fence: vk.VkFence = null,

    pipeline_layout: vk.VkPipelineLayout = null,
    graphics_pipeline: vk.VkPipeline = null,

    vertex_buffer: vk.VkBuffer = null,
    vertex_buffer_memory: vk.VkDeviceMemory = null,

    index_buffer: vk.VkBuffer = null,
    index_buffer_memory: vk.VkDeviceMemory = null,
    index_count: u32 = 0,

    depth_image: vk.VkImage = null,
    depth_image_memory: vk.VkDeviceMemory = null,
    depth_image_view: vk.VkImageView = null,

    pub fn init(allocator: std.mem.Allocator, window: *sdl.Window) !Renderer {
        var self = Renderer{
            .allocator = allocator,
            .window = window,
        };

        try self.create_instance();
        errdefer self.deinit();

        try self.create_surface(window);
        try self.pick_physical_device();
        try self.create_logical_device();
        try self.create_swapchain(window);
        try self.create_image_views();
        try self.create_depth_resources();
        try self.create_command_pool();
        try self.create_command_buffers();
        try self.create_sync_objects();
        try self.create_vertex_buffer();
        try self.create_index_buffer();
        try self.create_graphics_pipeline();

        std.log.info("Vulkan renderer clear-screen bootstrap completed", .{});
        return self;
    }

    pub fn deinit(self: *Renderer) void {
        if (self.device != null) {
            _ = vk.vkDeviceWaitIdle(self.device);
        }

        if (self.in_flight_fence != null) {
            vk.vkDestroyFence(self.device, self.in_flight_fence, null);
            self.in_flight_fence = null;
        }

        if (self.render_finished_semaphore != null) {
            vk.vkDestroySemaphore(self.device, self.render_finished_semaphore, null);
            self.render_finished_semaphore = null;
        }

        if (self.image_available_semaphore != null) {
            vk.vkDestroySemaphore(self.device, self.image_available_semaphore, null);
            self.image_available_semaphore = null;
        }

        if (self.depth_image_view != null) {
            vk.vkDestroyImageView(self.device, self.depth_image_view, null);
            self.depth_image_view = null;
        }

        if (self.depth_image != null) {
            vk.vkDestroyImage(self.device, self.depth_image, null);
            self.depth_image = null;
        }

        if (self.depth_image_memory != null) {
            vk.vkFreeMemory(self.device, self.depth_image_memory, null);
            self.depth_image_memory = null;
        }

        if (self.index_buffer != null) {
            vk.vkDestroyBuffer(self.device, self.index_buffer, null);
            self.index_buffer = null;
        }

        if (self.index_buffer_memory != null) {
            vk.vkFreeMemory(self.device, self.index_buffer_memory, null);
            self.index_buffer_memory = null;
        }

        if (self.vertex_buffer != null) {
            vk.vkDestroyBuffer(self.device, self.vertex_buffer, null);
            self.vertex_buffer = null;
        }

        if (self.vertex_buffer_memory != null) {
            vk.vkFreeMemory(self.device, self.vertex_buffer_memory, null);
            self.vertex_buffer_memory = null;
        }

        if (self.graphics_pipeline != null) {
            vk.vkDestroyPipeline(self.device, self.graphics_pipeline, null);
            self.graphics_pipeline = null;
        }

        if (self.pipeline_layout != null) {
            vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);
            self.pipeline_layout = null;
        }

        self.destroy_command_buffers();

        if (self.command_pool != null) {
            vk.vkDestroyCommandPool(self.device, self.command_pool, null);
            self.command_pool = null;
        }

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

    pub fn draw_frame(self: *Renderer, frame: FrameData) !void {
        _ = vk.vkWaitForFences(
            self.device,
            1,
            &self.in_flight_fence,
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );
        _ = vk.vkResetFences(self.device, 1, &self.in_flight_fence);

        var image_index: u32 = 0;
        const acquire_result = vk.vkAcquireNextImageKHR(
            self.device,
            self.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphore,
            null,
            &image_index,
        );

        if (acquire_result == vk.VK_ERROR_OUT_OF_DATE_KHR) {
            try self.recreate_swapchain();
            return;
        }

        if (acquire_result != vk.VK_SUCCESS and acquire_result != vk.VK_SUBOPTIMAL_KHR) {
            std.log.err("vkAcquireNextImageKHR failed with VkResult={d}", .{acquire_result});
            return error.VkAcquireNextImageFailed;
        }

        const command_buffer = self.command_buffers[image_index];
        _ = vk.vkResetCommandBuffer(command_buffer, 0);

        try self.record_command_buffer(command_buffer, image_index, frame);

        var wait_stage = [_]vk.VkPipelineStageFlags{
            vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        };

        var submit_info = std.mem.zeroes(vk.VkSubmitInfo);
        submit_info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submit_info.waitSemaphoreCount = 1;
        submit_info.pWaitSemaphores = &self.image_available_semaphore;
        submit_info.pWaitDstStageMask = &wait_stage[0];
        submit_info.commandBufferCount = 1;
        submit_info.pCommandBuffers = &command_buffer;
        submit_info.signalSemaphoreCount = 1;
        submit_info.pSignalSemaphores = &self.render_finished_semaphore;

        const submit_result = vk.vkQueueSubmit(
            self.graphics_queue,
            1,
            &submit_info,
            self.in_flight_fence,
        );
        if (submit_result != vk.VK_SUCCESS) {
            std.log.err("vkQueueSubmit failed with VkResult={d}", .{submit_result});
            return error.VkQueueSubmitFailed;
        }

        var present_info = std.mem.zeroes(vk.VkPresentInfoKHR);
        present_info.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        present_info.waitSemaphoreCount = 1;
        present_info.pWaitSemaphores = &self.render_finished_semaphore;
        present_info.swapchainCount = 1;
        present_info.pSwapchains = &self.swapchain;
        present_info.pImageIndices = &image_index;

        const present_result = vk.vkQueuePresentKHR(self.present_queue, &present_info);
        if (present_result == vk.VK_ERROR_OUT_OF_DATE_KHR or present_result == vk.VK_SUBOPTIMAL_KHR) {
            try self.recreate_swapchain();
            return;
        }
        if (present_result != vk.VK_SUCCESS) {
            std.log.err("vkQueuePresentKHR failed with VkResult={d}", .{present_result});
            return error.VkQueuePresentFailed;
        }
    }

    fn destroy_command_buffers(self: *Renderer) void {
        if (self.command_buffers.len != 0) {
            vk.vkFreeCommandBuffers(
                self.device,
                self.command_pool,
                @intCast(self.command_buffers.len),
                self.command_buffers.ptr,
            );
            self.allocator.free(self.command_buffers);
            self.command_buffers = &.{};
        }
    }

    fn recreate_swapchain(self: *Renderer) !void {
        try self.wait_for_nonzero_window_size();

        _ = vk.vkDeviceWaitIdle(self.device);

        self.destroy_command_buffers();
        self.destroy_swapchain();

        try self.create_swapchain(self.window);
        try self.create_image_views();
        try self.create_depth_resources();
        try self.create_command_buffers();

        std.log.info(
            "Swapchain recreated: extent {d}x{d}, images {d}",
            .{ self.swapchain_extent.width, self.swapchain_extent.height, self.swapchain_images.len },
        );
    }

    fn wait_for_nonzero_window_size(self: *Renderer) !void {
        while (true) {
            var width: c_int = 0;
            var height: c_int = 0;

            if (!vk.SDL_GetWindowSizeInPixels(self.window, &width, &height)) {
                return error.GetWindowSizeFailed;
            }

            if (width > 0 and height > 0) return;

            sdl.delay_ms(16);
        }
    }

    fn destroy_swapchain(self: *Renderer) void {
        if (self.depth_image_view != null) {
            vk.vkDestroyImageView(self.device, self.depth_image_view, null);
            self.depth_image_view = null;
        }

        if (self.depth_image != null) {
            vk.vkDestroyImage(self.device, self.depth_image, null);
            self.depth_image = null;
        }

        if (self.depth_image_memory != null) {
            vk.vkFreeMemory(self.device, self.depth_image_memory, null);
            self.depth_image_memory = null;
        }

        for (self.swapchain_image_views) |view| {
            vk.vkDestroyImageView(self.device, view, null);
        }
        if (self.swapchain_image_views.len != 0) {
            self.allocator.free(self.swapchain_image_views);
            self.swapchain_image_views = &.{};
        }

        if (self.swapchain_image_initialized.len != 0) {
            self.allocator.free(self.swapchain_image_initialized);
            self.swapchain_image_initialized = &.{};
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

        var all_ext_names: [16][*:0]const u8 = undefined;
        var ext_count: u32 = 0;

        var i: usize = 0;
        while (i < sdl_ext_count) : (i += 1) {
            all_ext_names[ext_count] = sdl_ext_names[i];
            ext_count += 1;
        }

        const portability_ext = "VK_KHR_portability_enumeration";
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

        const has_portability_subset = try self.has_device_extension(
            self.physical_device,
            "VK_KHR_portability_subset",
        );

        var device_extensions: [2][*:0]const u8 = undefined;
        var device_extension_count: u32 = 0;

        device_extensions[device_extension_count] = "VK_KHR_swapchain";
        device_extension_count += 1;

        if (has_portability_subset) {
            device_extensions[device_extension_count] = "VK_KHR_portability_subset";
            device_extension_count += 1;
        }

        var dynamic_rendering_features = std.mem.zeroes(vk.VkPhysicalDeviceDynamicRenderingFeatures);
        dynamic_rendering_features.sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES;
        dynamic_rendering_features.dynamicRendering = vk.VK_TRUE;

        var features2 = std.mem.zeroes(vk.VkPhysicalDeviceFeatures2);
        features2.sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
        features2.pNext = &dynamic_rendering_features;

        vk.vkGetPhysicalDeviceFeatures2(self.physical_device, &features2);

        if (dynamic_rendering_features.dynamicRendering != vk.VK_TRUE) {
            return error.DynamicRenderingNotSupported;
        }

        dynamic_rendering_features.dynamicRendering = vk.VK_TRUE;

        var create_info = std.mem.zeroes(vk.VkDeviceCreateInfo);
        create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        create_info.pNext = &dynamic_rendering_features;
        create_info.queueCreateInfoCount = queue_info_count;
        create_info.pQueueCreateInfos = &queue_infos[0];
        create_info.enabledExtensionCount = device_extension_count;
        create_info.ppEnabledExtensionNames = @ptrCast(&device_extensions[0]);
        create_info.pEnabledFeatures = null;

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

        self.swapchain_image_initialized = try self.allocator.alloc(bool, actual_image_count);
        @memset(self.swapchain_image_initialized, false);

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

    fn create_depth_resources(self: *Renderer) !void {
        const depth_format = vk.VK_FORMAT_D32_SFLOAT;

        var image_info = std.mem.zeroes(vk.VkImageCreateInfo);
        image_info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        image_info.imageType = vk.VK_IMAGE_TYPE_2D;
        image_info.extent.width = self.swapchain_extent.width;
        image_info.extent.height = self.swapchain_extent.height;
        image_info.extent.depth = 1;
        image_info.mipLevels = 1;
        image_info.arrayLayers = 1;
        image_info.format = depth_format;
        image_info.tiling = vk.VK_IMAGE_TILING_OPTIMAL;
        image_info.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        image_info.usage = vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
        image_info.samples = vk.VK_SAMPLE_COUNT_1_BIT;
        image_info.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;

        if (vk.vkCreateImage(self.device, &image_info, null, &self.depth_image) != vk.VK_SUCCESS) {
            return error.VkCreateImageFailed;
        }

        var mem_requirements = std.mem.zeroes(vk.VkMemoryRequirements);
        vk.vkGetImageMemoryRequirements(self.device, self.depth_image, &mem_requirements);

        const memory_type_index = try self.find_memory_type(
            mem_requirements.memoryTypeBits,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );

        var alloc_info = std.mem.zeroes(vk.VkMemoryAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc_info.allocationSize = mem_requirements.size;
        alloc_info.memoryTypeIndex = memory_type_index;

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, &self.depth_image_memory) != vk.VK_SUCCESS) {
            return error.VkAllocateMemoryFailed;
        }

        if (vk.vkBindImageMemory(self.device, self.depth_image, self.depth_image_memory, 0) != vk.VK_SUCCESS) {
            return error.VkBindImageMemoryFailed;
        }

        var view_info = std.mem.zeroes(vk.VkImageViewCreateInfo);
        view_info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        view_info.image = self.depth_image;
        view_info.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
        view_info.format = depth_format;
        view_info.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_DEPTH_BIT;
        view_info.subresourceRange.baseMipLevel = 0;
        view_info.subresourceRange.levelCount = 1;
        view_info.subresourceRange.baseArrayLayer = 0;
        view_info.subresourceRange.layerCount = 1;

        if (vk.vkCreateImageView(self.device, &view_info, null, &self.depth_image_view) != vk.VK_SUCCESS) {
            return error.VkCreateImageViewFailed;
        }

        std.log.info(
            "Depth resources created: {d}x{d}",
            .{ self.swapchain_extent.width, self.swapchain_extent.height },
        );
    }

    fn create_command_pool(self: *Renderer) !void {
        var create_info = std.mem.zeroes(vk.VkCommandPoolCreateInfo);
        create_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        create_info.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        create_info.queueFamilyIndex = self.graphics_queue_family_index;

        const result = vk.vkCreateCommandPool(self.device, &create_info, null, &self.command_pool);
        if (result != vk.VK_SUCCESS) {
            std.log.err("vkCreateCommandPool failed with VkResult={d}", .{result});
            return error.VkCreateCommandPoolFailed;
        }

        std.log.info("Command pool created", .{});
    }

    fn create_command_buffers(self: *Renderer) !void {
        self.command_buffers = try self.allocator.alloc(vk.VkCommandBuffer, self.swapchain_images.len);

        var alloc_info = std.mem.zeroes(vk.VkCommandBufferAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        alloc_info.commandPool = self.command_pool;
        alloc_info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        alloc_info.commandBufferCount = @intCast(self.command_buffers.len);

        const result = vk.vkAllocateCommandBuffers(self.device, &alloc_info, self.command_buffers.ptr);
        if (result != vk.VK_SUCCESS) {
            std.log.err("vkAllocateCommandBuffers failed with VkResult={d}", .{result});
            return error.VkAllocateCommandBuffersFailed;
        }

        std.log.info("Allocated {d} command buffers", .{self.command_buffers.len});
    }

    fn create_sync_objects(self: *Renderer) !void {
        var semaphore_info = std.mem.zeroes(vk.VkSemaphoreCreateInfo);
        semaphore_info.sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

        var fence_info = std.mem.zeroes(vk.VkFenceCreateInfo);
        fence_info.sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fence_info.flags = vk.VK_FENCE_CREATE_SIGNALED_BIT;

        if (vk.vkCreateSemaphore(self.device, &semaphore_info, null, &self.image_available_semaphore) != vk.VK_SUCCESS) {
            return error.VkCreateSemaphoreFailed;
        }
        if (vk.vkCreateSemaphore(self.device, &semaphore_info, null, &self.render_finished_semaphore) != vk.VK_SUCCESS) {
            return error.VkCreateSemaphoreFailed;
        }
        if (vk.vkCreateFence(self.device, &fence_info, null, &self.in_flight_fence) != vk.VK_SUCCESS) {
            return error.VkCreateFenceFailed;
        }

        std.log.info("Sync objects created", .{});
    }

    fn create_vertex_buffer(self: *Renderer) !void {
        const buffer_size = @sizeOf(Vertex) * cube_vertices.len;

        var staging_buffer: vk.VkBuffer = null;
        var staging_buffer_memory: vk.VkDeviceMemory = null;
        defer {
            if (staging_buffer != null) vk.vkDestroyBuffer(self.device, staging_buffer, null);
            if (staging_buffer_memory != null) vk.vkFreeMemory(self.device, staging_buffer_memory, null);
        }

        try self.create_buffer(
            buffer_size,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &staging_buffer,
            &staging_buffer_memory,
        );

        var mapped: ?*anyopaque = null;
        if (vk.vkMapMemory(self.device, staging_buffer_memory, 0, buffer_size, 0, &mapped) != vk.VK_SUCCESS) {
            return error.VkMapMemoryFailed;
        }
        defer vk.vkUnmapMemory(self.device, staging_buffer_memory);

        const dst: [*]Vertex = @ptrCast(@alignCast(mapped.?));
        @memcpy(dst[0..cube_vertices.len], cube_vertices[0..]);

        try self.create_buffer(
            buffer_size,
            vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT | vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &self.vertex_buffer,
            &self.vertex_buffer_memory,
        );

        try self.copy_buffer(staging_buffer, self.vertex_buffer, buffer_size);
    }

    fn create_index_buffer(self: *Renderer) !void {
        const buffer_size = @sizeOf(u32) * cube_indices.len;

        var buffer_info = std.mem.zeroes(vk.VkBufferCreateInfo);
        buffer_info.sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        buffer_info.size = buffer_size;
        buffer_info.usage = vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT;
        buffer_info.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;

        if (vk.vkCreateBuffer(self.device, &buffer_info, null, &self.index_buffer) != vk.VK_SUCCESS) {
            return error.VkCreateBufferFailed;
        }

        var mem_requirements = std.mem.zeroes(vk.VkMemoryRequirements);
        vk.vkGetBufferMemoryRequirements(self.device, self.index_buffer, &mem_requirements);

        const memory_type_index = try self.find_memory_type(
            mem_requirements.memoryTypeBits,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );

        var alloc_info = std.mem.zeroes(vk.VkMemoryAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc_info.allocationSize = mem_requirements.size;
        alloc_info.memoryTypeIndex = memory_type_index;

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, &self.index_buffer_memory) != vk.VK_SUCCESS) {
            return error.VkAllocateMemoryFailed;
        }

        if (vk.vkBindBufferMemory(self.device, self.index_buffer, self.index_buffer_memory, 0) != vk.VK_SUCCESS) {
            return error.VkBindBufferMemoryFailed;
        }

        var mapped: ?*anyopaque = null;
        if (vk.vkMapMemory(self.device, self.index_buffer_memory, 0, buffer_size, 0, &mapped) != vk.VK_SUCCESS) {
            return error.VkMapMemoryFailed;
        }
        defer vk.vkUnmapMemory(self.device, self.index_buffer_memory);

        const dst: [*]u32 = @ptrCast(@alignCast(mapped.?));
        @memcpy(dst[0..cube_indices.len], cube_indices[0..]);

        self.index_count = @intCast(cube_indices.len);
    }

    fn create_graphics_pipeline(self: *Renderer) !void {
        var vert_module: vk.VkShaderModule = null;
        var frag_module: vk.VkShaderModule = null;
        defer {
            if (vert_module != null) vk.vkDestroyShaderModule(self.device, vert_module, null);
            if (frag_module != null) vk.vkDestroyShaderModule(self.device, frag_module, null);
        }

        vert_module = try self.create_shader_module(&triangle_vert_spv);
        frag_module = try self.create_shader_module(&triangle_frag_spv);

        var push_constant_range = std.mem.zeroes(vk.VkPushConstantRange);
        push_constant_range.stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT;
        push_constant_range.offset = 0;
        push_constant_range.size = @sizeOf(PushConstants);

        var pipeline_layout_info = std.mem.zeroes(vk.VkPipelineLayoutCreateInfo);
        pipeline_layout_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipeline_layout_info.pushConstantRangeCount = 1;
        pipeline_layout_info.pPushConstantRanges = &push_constant_range;

        if (vk.vkCreatePipelineLayout(self.device, &pipeline_layout_info, null, &self.pipeline_layout) != vk.VK_SUCCESS) {
            return error.VkCreatePipelineLayoutFailed;
        }

        var vert_stage = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        vert_stage.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vert_stage.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
        vert_stage.module = vert_module;
        vert_stage.pName = "main";

        var frag_stage = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        frag_stage.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        frag_stage.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
        frag_stage.module = frag_module;
        frag_stage.pName = "main";

        var shader_stages = [_]vk.VkPipelineShaderStageCreateInfo{
            vert_stage,
            frag_stage,
        };

        const binding_description = vk.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        const attribute_descriptions = [_]vk.VkVertexInputAttributeDescription{
            .{
                .location = 0,
                .binding = 0,
                .format = vk.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(Vertex, "pos"),
            },
            .{
                .location = 1,
                .binding = 0,
                .format = vk.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(Vertex, "color"),
            },
        };

        var vertex_input_info = std.mem.zeroes(vk.VkPipelineVertexInputStateCreateInfo);
        vertex_input_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
        vertex_input_info.vertexBindingDescriptionCount = 1;
        vertex_input_info.pVertexBindingDescriptions = &binding_description;
        vertex_input_info.vertexAttributeDescriptionCount = attribute_descriptions.len;
        vertex_input_info.pVertexAttributeDescriptions = &attribute_descriptions;

        var input_assembly = std.mem.zeroes(vk.VkPipelineInputAssemblyStateCreateInfo);
        input_assembly.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        input_assembly.topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        input_assembly.primitiveRestartEnable = vk.VK_FALSE;

        var viewport_state = std.mem.zeroes(vk.VkPipelineViewportStateCreateInfo);
        viewport_state.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewport_state.viewportCount = 1;
        viewport_state.scissorCount = 1;

        const dynamic_states = [_]vk.VkDynamicState{
            vk.VK_DYNAMIC_STATE_VIEWPORT,
            vk.VK_DYNAMIC_STATE_SCISSOR,
        };

        var dynamic_state = std.mem.zeroes(vk.VkPipelineDynamicStateCreateInfo);
        dynamic_state.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        dynamic_state.dynamicStateCount = dynamic_states.len;
        dynamic_state.pDynamicStates = &dynamic_states;

        var rasterizer = std.mem.zeroes(vk.VkPipelineRasterizationStateCreateInfo);
        rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizer.depthClampEnable = vk.VK_FALSE;
        rasterizer.rasterizerDiscardEnable = vk.VK_FALSE;
        rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL;
        rasterizer.lineWidth = 1.0;
        rasterizer.cullMode = vk.VK_CULL_MODE_NONE;
        rasterizer.frontFace = vk.VK_FRONT_FACE_CLOCKWISE;
        rasterizer.depthBiasEnable = vk.VK_FALSE;

        var multisampling = std.mem.zeroes(vk.VkPipelineMultisampleStateCreateInfo);
        multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampling.rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT;
        multisampling.sampleShadingEnable = vk.VK_FALSE;

        var depth_stencil = std.mem.zeroes(vk.VkPipelineDepthStencilStateCreateInfo);
        depth_stencil.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
        depth_stencil.depthTestEnable = vk.VK_TRUE;
        depth_stencil.depthWriteEnable = vk.VK_TRUE;
        depth_stencil.depthCompareOp = vk.VK_COMPARE_OP_LESS;
        depth_stencil.depthBoundsTestEnable = vk.VK_FALSE;
        depth_stencil.stencilTestEnable = vk.VK_FALSE;

        var color_blend_attachment = std.mem.zeroes(vk.VkPipelineColorBlendAttachmentState);
        color_blend_attachment.colorWriteMask =
            vk.VK_COLOR_COMPONENT_R_BIT |
            vk.VK_COLOR_COMPONENT_G_BIT |
            vk.VK_COLOR_COMPONENT_B_BIT |
            vk.VK_COLOR_COMPONENT_A_BIT;
        color_blend_attachment.blendEnable = vk.VK_FALSE;

        var color_blending = std.mem.zeroes(vk.VkPipelineColorBlendStateCreateInfo);
        color_blending.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        color_blending.logicOpEnable = vk.VK_FALSE;
        color_blending.attachmentCount = 1;
        color_blending.pAttachments = &color_blend_attachment;

        var color_attachment_formats = [_]vk.VkFormat{
            self.swapchain_format,
        };

        var rendering_info = std.mem.zeroes(vk.VkPipelineRenderingCreateInfo);
        rendering_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
        rendering_info.colorAttachmentCount = 1;
        rendering_info.pColorAttachmentFormats = &color_attachment_formats;
        rendering_info.depthAttachmentFormat = vk.VK_FORMAT_D32_SFLOAT;

        var pipeline_info = std.mem.zeroes(vk.VkGraphicsPipelineCreateInfo);
        pipeline_info.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipeline_info.pNext = &rendering_info;
        pipeline_info.stageCount = shader_stages.len;
        pipeline_info.pStages = &shader_stages;
        pipeline_info.pVertexInputState = &vertex_input_info;
        pipeline_info.pInputAssemblyState = &input_assembly;
        pipeline_info.pViewportState = &viewport_state;
        pipeline_info.pRasterizationState = &rasterizer;
        pipeline_info.pMultisampleState = &multisampling;
        pipeline_info.pDepthStencilState = &depth_stencil;
        pipeline_info.pColorBlendState = &color_blending;
        pipeline_info.pDynamicState = &dynamic_state;
        pipeline_info.layout = self.pipeline_layout;
        pipeline_info.renderPass = null;
        pipeline_info.subpass = 0;

        if (vk.vkCreateGraphicsPipelines(
            self.device,
            null,
            1,
            &pipeline_info,
            null,
            &self.graphics_pipeline,
        ) != vk.VK_SUCCESS) {
            return error.VkCreateGraphicsPipelinesFailed;
        }

        std.log.info("Graphics pipeline created", .{});
    }

    fn create_shader_module(self: *Renderer, spirv_bytes: []const u8) !vk.VkShaderModule {
        var create_info = std.mem.zeroes(vk.VkShaderModuleCreateInfo);
        create_info.sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        create_info.codeSize = spirv_bytes.len;
        create_info.pCode = @ptrCast(@alignCast(spirv_bytes.ptr));

        var module: vk.VkShaderModule = null;
        if (vk.vkCreateShaderModule(self.device, &create_info, null, &module) != vk.VK_SUCCESS) {
            return error.VkCreateShaderModuleFailed;
        }

        return module;
    }

    fn record_command_buffer(
        self: *Renderer,
        command_buffer: vk.VkCommandBuffer,
        image_index: u32,
        frame: FrameData,
    ) !void {
        var begin_info = std.mem.zeroes(vk.VkCommandBufferBeginInfo);
        begin_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        if (vk.vkBeginCommandBuffer(command_buffer, &begin_info) != vk.VK_SUCCESS) {
            return error.VkBeginCommandBufferFailed;
        }

        const image = self.swapchain_images[image_index];
        const image_view = self.swapchain_image_views[image_index];

        const was_initialized = self.swapchain_image_initialized[image_index];

        var to_color_barrier = std.mem.zeroes(vk.VkImageMemoryBarrier);
        to_color_barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        to_color_barrier.oldLayout = if (was_initialized)
            vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        else
            vk.VK_IMAGE_LAYOUT_UNDEFINED;
        to_color_barrier.newLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        to_color_barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        to_color_barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        to_color_barrier.image = image;
        to_color_barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        to_color_barrier.subresourceRange.baseMipLevel = 0;
        to_color_barrier.subresourceRange.levelCount = 1;
        to_color_barrier.subresourceRange.baseArrayLayer = 0;
        to_color_barrier.subresourceRange.layerCount = 1;
        to_color_barrier.srcAccessMask = if (was_initialized)
            0
        else
            0;
        to_color_barrier.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

        vk.vkCmdPipelineBarrier(
            command_buffer,
            if (was_initialized) vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT else vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &to_color_barrier,
        );

        var depth_barrier = std.mem.zeroes(vk.VkImageMemoryBarrier);
        depth_barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        depth_barrier.oldLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
        depth_barrier.newLayout = vk.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;
        depth_barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        depth_barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        depth_barrier.image = self.depth_image;
        depth_barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_DEPTH_BIT;
        depth_barrier.subresourceRange.baseMipLevel = 0;
        depth_barrier.subresourceRange.levelCount = 1;
        depth_barrier.subresourceRange.baseArrayLayer = 0;
        depth_barrier.subresourceRange.layerCount = 1;
        depth_barrier.srcAccessMask = 0;
        depth_barrier.dstAccessMask = vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

        vk.vkCmdPipelineBarrier(
            command_buffer,
            vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &depth_barrier,
        );

        var clear = std.mem.zeroes(vk.VkClearValue);
        clear.color.float32[0] = 0.08;
        clear.color.float32[1] = 0.10;
        clear.color.float32[2] = 0.18;
        clear.color.float32[3] = 1.0;

        var color_attachment = std.mem.zeroes(vk.VkRenderingAttachmentInfo);
        color_attachment.sType = vk.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        color_attachment.imageView = image_view;
        color_attachment.imageLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        color_attachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        color_attachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
        color_attachment.clearValue = clear;

        var depth_clear = std.mem.zeroes(vk.VkClearValue);
        depth_clear.depthStencil.depth = 1.0;
        depth_clear.depthStencil.stencil = 0;

        var depth_attachment = std.mem.zeroes(vk.VkRenderingAttachmentInfo);
        depth_attachment.sType = vk.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        depth_attachment.imageView = self.depth_image_view;
        depth_attachment.imageLayout = vk.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;
        depth_attachment.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
        depth_attachment.storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
        depth_attachment.clearValue = depth_clear;

        var render_info = std.mem.zeroes(vk.VkRenderingInfo);
        render_info.sType = vk.VK_STRUCTURE_TYPE_RENDERING_INFO;
        render_info.renderArea.offset.x = 0;
        render_info.renderArea.offset.y = 0;
        render_info.renderArea.extent = self.swapchain_extent;
        render_info.layerCount = 1;
        render_info.colorAttachmentCount = 1;
        render_info.pColorAttachments = &color_attachment;
        render_info.pDepthAttachment = &depth_attachment;

        vk.vkCmdBeginRendering(command_buffer, &render_info);

        vk.vkCmdBindPipeline(
            command_buffer,
            vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
            self.graphics_pipeline,
        );

        var viewport = std.mem.zeroes(vk.VkViewport);
        viewport.x = 0;
        viewport.y = 0;
        viewport.width = @floatFromInt(self.swapchain_extent.width);
        viewport.height = @floatFromInt(self.swapchain_extent.height);
        viewport.minDepth = 0.0;
        viewport.maxDepth = 1.0;
        vk.vkCmdSetViewport(command_buffer, 0, 1, &viewport);

        var scissor = std.mem.zeroes(vk.VkRect2D);
        scissor.offset.x = 0;
        scissor.offset.y = 0;
        scissor.extent = self.swapchain_extent;
        vk.vkCmdSetScissor(command_buffer, 0, 1, &scissor);

        const vertex_buffers = [_]vk.VkBuffer{self.vertex_buffer};
        const offsets = [_]vk.VkDeviceSize{0};
        vk.vkCmdBindVertexBuffers(
            command_buffer,
            0,
            1,
            &vertex_buffers[0],
            &offsets[0],
        );

        vk.vkCmdBindIndexBuffer(
            command_buffer,
            self.index_buffer,
            0,
            vk.VK_INDEX_TYPE_UINT32,
        );

        for (frame.models) |model| {
            const push_constants = PushConstants{
                .view_proj = frame.view_proj.data,
                .model = model.data,
            };

            vk.vkCmdPushConstants(
                command_buffer,
                self.pipeline_layout,
                vk.VK_SHADER_STAGE_VERTEX_BIT,
                0,
                @sizeOf(PushConstants),
                &push_constants,
            );

            vk.vkCmdDrawIndexed(command_buffer, self.index_count, 1, 0, 0, 0);
        }

        vk.vkCmdEndRendering(command_buffer);

        var to_present_barrier = std.mem.zeroes(vk.VkImageMemoryBarrier);
        to_present_barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        to_present_barrier.oldLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        to_present_barrier.newLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        to_present_barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        to_present_barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED;
        to_present_barrier.image = image;
        to_present_barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        to_present_barrier.subresourceRange.baseMipLevel = 0;
        to_present_barrier.subresourceRange.levelCount = 1;
        to_present_barrier.subresourceRange.baseArrayLayer = 0;
        to_present_barrier.subresourceRange.layerCount = 1;
        to_present_barrier.srcAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        to_present_barrier.dstAccessMask = 0;

        vk.vkCmdPipelineBarrier(
            command_buffer,
            vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            0,
            0,
            null,
            0,
            null,
            1,
            &to_present_barrier,
        );

        self.swapchain_image_initialized[image_index] = true;

        if (vk.vkEndCommandBuffer(command_buffer) != vk.VK_SUCCESS) {
            return error.VkEndCommandBufferFailed;
        }
    }

    fn find_memory_type(self: *Renderer, type_filter: u32, properties: vk.VkMemoryPropertyFlags) !u32 {
        var mem_properties = std.mem.zeroes(vk.VkPhysicalDeviceMemoryProperties);
        vk.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &mem_properties);

        var i: u32 = 0;
        while (i < mem_properties.memoryTypeCount) : (i += 1) {
            const matches_type = (type_filter & (@as(u32, 1) << @intCast(i))) != 0;
            const has_properties =
                (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;

            if (matches_type and has_properties) {
                return i;
            }
        }

        return error.NoSuitableMemoryType;
    }

    fn create_buffer(
        self: *Renderer,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
        out_buffer: *vk.VkBuffer,
        out_memory: *vk.VkDeviceMemory,
    ) !void {
        var buffer_info = std.mem.zeroes(vk.VkBufferCreateInfo);
        buffer_info.sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        buffer_info.size = size;
        buffer_info.usage = usage;
        buffer_info.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;

        if (vk.vkCreateBuffer(self.device, &buffer_info, null, out_buffer) != vk.VK_SUCCESS) {
            return error.VkCreateBufferFailed;
        }

        var mem_requirements = std.mem.zeroes(vk.VkMemoryRequirements);
        vk.vkGetBufferMemoryRequirements(self.device, out_buffer.*, &mem_requirements);

        const memory_type_index = try self.find_memory_type(
            mem_requirements.memoryTypeBits,
            memory_properties,
        );

        var alloc_info = std.mem.zeroes(vk.VkMemoryAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        alloc_info.allocationSize = mem_requirements.size;
        alloc_info.memoryTypeIndex = memory_type_index;

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, out_memory) != vk.VK_SUCCESS) {
            return error.VkAllocateMemoryFailed;
        }

        if (vk.vkBindBufferMemory(self.device, out_buffer.*, out_memory.*, 0) != vk.VK_SUCCESS) {
            return error.VkBindBufferMemoryFailed;
        }
    }

    fn copy_buffer(
        self: *Renderer,
        src_buffer: vk.VkBuffer,
        dst_buffer: vk.VkBuffer,
        size: vk.VkDeviceSize,
    ) !void {
        var alloc_info = std.mem.zeroes(vk.VkCommandBufferAllocateInfo);
        alloc_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        alloc_info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        alloc_info.commandPool = self.command_pool;
        alloc_info.commandBufferCount = 1;

        var command_buffer: vk.VkCommandBuffer = null;
        if (vk.vkAllocateCommandBuffers(self.device, &alloc_info, &command_buffer) != vk.VK_SUCCESS) {
            return error.VkAllocateCommandBuffersFailed;
        }
        defer vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);

        var begin_info = std.mem.zeroes(vk.VkCommandBufferBeginInfo);
        begin_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        begin_info.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

        if (vk.vkBeginCommandBuffer(command_buffer, &begin_info) != vk.VK_SUCCESS) {
            return error.VkBeginCommandBufferFailed;
        }

        var copy_region = std.mem.zeroes(vk.VkBufferCopy);
        copy_region.srcOffset = 0;
        copy_region.dstOffset = 0;
        copy_region.size = size;

        vk.vkCmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region);

        if (vk.vkEndCommandBuffer(command_buffer) != vk.VK_SUCCESS) {
            return error.VkEndCommandBufferFailed;
        }

        var submit_info = std.mem.zeroes(vk.VkSubmitInfo);
        submit_info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submit_info.commandBufferCount = 1;
        submit_info.pCommandBuffers = &command_buffer;

        if (vk.vkQueueSubmit(self.graphics_queue, 1, &submit_info, null) != vk.VK_SUCCESS) {
            return error.VkQueueSubmitFailed;
        }

        if (vk.vkQueueWaitIdle(self.graphics_queue) != vk.VK_SUCCESS) {
            return error.VkQueueWaitIdleFailed;
        }
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

    fn has_device_extension(self: *Renderer, device: vk.VkPhysicalDevice, wanted: []const u8) !bool {
        var extension_count: u32 = 0;
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, null);

        const available = try self.allocator.alloc(vk.VkExtensionProperties, extension_count);
        defer self.allocator.free(available);

        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, available.ptr);

        for (available) |ext| {
            const name = std.mem.span(@as([*:0]const u8, @ptrCast(&ext.extensionName[0])));
            if (std.mem.eql(u8, name, wanted)) return true;
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

    extent.width = std.math.clamp(
        extent.width,
        capabilities.minImageExtent.width,
        capabilities.maxImageExtent.width,
    );
    extent.height = std.math.clamp(
        extent.height,
        capabilities.minImageExtent.height,
        capabilities.maxImageExtent.height,
    );

    return extent;
}
