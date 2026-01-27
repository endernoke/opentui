//! Platform detection and abstraction for accessibility
//!
//! This module provides compile-time platform detection and the common interface
//! that all platform-specific accessibility implementations must follow.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("../types.zig");
const node_mod = @import("../node.zig");

const AccessibilityNode = node_mod.AccessibilityNode;
const Allocator = std.mem.Allocator;

/// Supported platforms
pub const Platform = enum {
    windows,
    linux,
    macos,
    unsupported,
};

/// Detect current platform at compile time
pub const current: Platform = switch (builtin.os.tag) {
    .windows => .windows,
    .linux => .linux,
    .macos => .macos,
    else => .unsupported,
};

/// Platform bridge interface
/// All platform-specific implementations must provide these methods
pub const PlatformBridge = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        addNode: *const fn (ptr: *anyopaque, node: *AccessibilityNode) Error!void,
        updateNode: *const fn (ptr: *anyopaque, node: *AccessibilityNode) Error!void,
        removeNode: *const fn (ptr: *anyopaque, node: *AccessibilityNode) Error!void,
        notifyFocusChanged: *const fn (ptr: *anyopaque, node: ?*AccessibilityNode) Error!void,
        notifyPropertyChanged: *const fn (ptr: *anyopaque, node: *AccessibilityNode, property: types.Property) Error!void,
        announce: *const fn (ptr: *anyopaque, message: []const u8, priority: types.LiveSetting) Error!void,
        setActionCallback: *const fn (ptr: *anyopaque, callback: ?types.ActionCallback) void,
        tick: *const fn (ptr: *anyopaque) void,
    };

    pub const Error = error{
        InitializationFailed,
        NodeNotFound,
        PlatformError,
        OutOfMemory,
    };

    pub fn deinit(self: PlatformBridge) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn addNode(self: PlatformBridge, node: *AccessibilityNode) Error!void {
        return self.vtable.addNode(self.ptr, node);
    }

    pub fn updateNode(self: PlatformBridge, node: *AccessibilityNode) Error!void {
        return self.vtable.updateNode(self.ptr, node);
    }

    pub fn removeNode(self: PlatformBridge, node: *AccessibilityNode) Error!void {
        return self.vtable.removeNode(self.ptr, node);
    }

    pub fn notifyFocusChanged(self: PlatformBridge, node: ?*AccessibilityNode) Error!void {
        return self.vtable.notifyFocusChanged(self.ptr, node);
    }

    pub fn notifyPropertyChanged(self: PlatformBridge, node: *AccessibilityNode, property: types.Property) Error!void {
        return self.vtable.notifyPropertyChanged(self.ptr, node, property);
    }

    pub fn announce(self: PlatformBridge, message: []const u8, priority: types.LiveSetting) Error!void {
        return self.vtable.announce(self.ptr, message, priority);
    }

    pub fn setActionCallback(self: PlatformBridge, callback: ?types.ActionCallback) void {
        self.vtable.setActionCallback(self.ptr, callback);
    }

    pub fn tick(self: PlatformBridge) void {
        self.vtable.tick(self.ptr);
    }
};

/// Create the appropriate platform bridge for the current platform
pub fn createPlatformBridge(allocator: Allocator) !PlatformBridge {
    switch (current) {
        .windows => {
            const windows_uia = @import("windows_uia.zig");
            return windows_uia.WindowsUIA.create(allocator);
        },
        .linux => {
            const linux_atspi = @import("linux_atspi.zig");
            return linux_atspi.LinuxATSPI.create(allocator);
        },
        .macos => {
            const macos_nsa = @import("macos_nsa.zig");
            return macos_nsa.MacOSNSA.create(allocator);
        },
        .unsupported => {
            const stub = @import("stub.zig");
            return stub.StubBridge.create(allocator);
        },
    }
}

/// Check if the current platform supports accessibility
pub fn isPlatformSupported() bool {
    return current != .unsupported;
}

/// Get the name of the current platform
pub fn getPlatformName() []const u8 {
    return switch (current) {
        .windows => "Windows UIA",
        .linux => "Linux AT-SPI2",
        .macos => "macOS NSAccessibility",
        .unsupported => "Unsupported",
    };
}
