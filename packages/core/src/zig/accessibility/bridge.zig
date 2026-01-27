//! Accessibility Bridge for OpenTUI
//!
//! This module provides the main accessibility bridge that coordinates between
//! the TypeScript layer and platform-specific accessibility implementations.
//! It maintains the accessibility tree and exposes FFI functions for TypeScript.
//!
//! Architecture:
//! - AccessibilityBridge manages the accessibility tree (nodes stored in HashMap)
//! - Platform-specific implementation is created based on compile-time detection
//! - FFI exports allow TypeScript to create/update/remove nodes and trigger events
//! - Thread-safe via mutex protection

const std = @import("std");
const types = @import("types.zig");
const node_mod = @import("node.zig");
const platform_mod = @import("platform/platform.zig");
const logger = @import("../logger.zig");

const AccessibilityNode = node_mod.AccessibilityNode;
const PlatformBridge = platform_mod.PlatformBridge;
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

/// The main accessibility bridge
/// Manages the accessibility tree and coordinates with platform implementations
pub const AccessibilityBridge = struct {
    allocator: Allocator,

    // Node storage
    nodes: std.StringHashMap(*AccessibilityNode),
    root_id: ?[]const u8,
    focused_id: ?[]const u8,

    // Platform-specific implementation
    platform: PlatformBridge,

    // Thread safety
    mutex: Mutex,

    // State
    enabled: bool,

    const Self = @This();

    /// Create a new accessibility bridge
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .nodes = std.StringHashMap(*AccessibilityNode).init(allocator),
            .root_id = null,
            .focused_id = null,
            .platform = try platform_mod.createPlatformBridge(allocator),
            .mutex = .{},
            .enabled = true,
        };

        logger.info("Accessibility bridge initialized for {s}", .{platform_mod.getPlatformName()});

        return self;
    }

    /// Clean up the bridge
    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Clean up all nodes
        var iter = self.nodes.valueIterator();
        while (iter.next()) |node| {
            node.*.deinit();
        }
        self.nodes.deinit();

        // Clean up stored IDs
        if (self.root_id) |id| self.allocator.free(id);
        if (self.focused_id) |id| self.allocator.free(id);

        // Clean up platform bridge
        self.platform.deinit();

        self.allocator.destroy(self);
    }

    /// Enable or disable accessibility
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.enabled = enabled;
        logger.info("Accessibility {s}", .{if (enabled) "enabled" else "disabled"});
    }

    /// Check if accessibility is enabled
    pub fn isEnabled(self: *Self) bool {
        return self.enabled;
    }

    /// Add or update a node from FFI data
    pub fn upsertNode(self: *Self, data: *const types.NodeData) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.enabled) return;

        const id = data.getId();

        if (self.nodes.get(id)) |existing| {
            // Update existing node
            const changed = try existing.updateFromData(data);
            if (changed) {
                try self.platform.updateNode(existing);
            }
        } else {
            // Create new node
            const node = try AccessibilityNode.init(self.allocator, data);
            errdefer node.deinit();

            try self.nodes.put(node.id, node);
            try self.platform.addNode(node);

            // Update parent's children list
            if (data.getParentId()) |parent_id| {
                if (self.nodes.get(parent_id)) |parent| {
                    try parent.addChild(node.id);
                }
            } else {
                // This is a root node
                if (self.root_id) |old_root| {
                    self.allocator.free(old_root);
                }
                self.root_id = try self.allocator.dupe(u8, node.id);
            }

            logger.debug("Added accessibility node: {s}", .{node.id});
        }
    }

    /// Remove a node by ID
    pub fn removeNode(self: *Self, id_ptr: [*]const u8, id_len: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.enabled) return;

        const id = id_ptr[0..id_len];

        if (self.nodes.fetchRemove(id)) |kv| {
            const node = kv.value;

            // Remove from parent's children list
            if (node.parent_id) |parent_id| {
                if (self.nodes.get(parent_id)) |parent| {
                    parent.removeChild(node.id);
                }
            }

            // Clear root if this was the root
            if (self.root_id) |root_id| {
                if (std.mem.eql(u8, root_id, id)) {
                    self.allocator.free(root_id);
                    self.root_id = null;
                }
            }

            // Clear focus if this was focused
            if (self.focused_id) |focused_id| {
                if (std.mem.eql(u8, focused_id, id)) {
                    self.allocator.free(focused_id);
                    self.focused_id = null;
                    try self.platform.notifyFocusChanged(null);
                }
            }

            // Notify platform
            try self.platform.removeNode(node);

            logger.debug("Removed accessibility node: {s}", .{id});

            // Clean up node
            node.deinit();
        }
    }

    /// Set focus to a node
    pub fn setFocus(self: *Self, id_ptr: ?[*]const u8, id_len: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.enabled) return;

        // Clear previous focus tracking
        if (self.focused_id) |old_id| {
            // Update old node's focused state
            if (self.nodes.get(old_id)) |old_node| {
                old_node.state.focused = false;
            }
            self.allocator.free(old_id);
            self.focused_id = null;
        }

        if (id_ptr) |ptr| {
            const id = ptr[0..id_len];
            if (self.nodes.get(id)) |node| {
                // Update node's focused state
                node.state.focused = true;
                self.focused_id = try self.allocator.dupe(u8, id);
                try self.platform.notifyFocusChanged(node);
                logger.debug("Focus set to: {s}", .{id});
            }
        } else {
            try self.platform.notifyFocusChanged(null);
            logger.debug("Focus cleared", .{});
        }
    }

    /// Announce a message to screen readers
    pub fn announce(self: *Self, message_ptr: [*]const u8, message_len: usize, priority: types.LiveSetting) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.enabled) return;

        const message = message_ptr[0..message_len];
        try self.platform.announce(message, priority);
    }

    /// Notify that a property changed on a node
    pub fn notifyPropertyChanged(self: *Self, id_ptr: [*]const u8, id_len: usize, property: types.Property) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.enabled) return;

        const id = id_ptr[0..id_len];
        if (self.nodes.get(id)) |node| {
            try self.platform.notifyPropertyChanged(node, property);
        }
    }

    /// Set the action callback
    pub fn setActionCallback(self: *Self, callback: ?types.ActionCallback) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.platform.setActionCallback(callback);
    }

    /// Get node count (for debugging)
    pub fn getNodeCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.nodes.count();
    }

    /// Clear all nodes
    pub fn clear(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.nodes.valueIterator();
        while (iter.next()) |node| {
            self.platform.removeNode(node.*) catch {};
            node.*.deinit();
        }
        self.nodes.clearRetainingCapacity();

        if (self.root_id) |id| {
            self.allocator.free(id);
            self.root_id = null;
        }
        if (self.focused_id) |id| {
            self.allocator.free(id);
            self.focused_id = null;
        }
    }

    /// Performs any periodic updates needed by platforms
    pub fn tick(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.enabled) return;

        self.platform.tick();
    }
};

// ============================================================================
// FFI Exports (called from lib.zig)
// ============================================================================

var globalAllocator: ?Allocator = null;

fn getAllocator() Allocator {
    if (globalAllocator) |alloc| {
        return alloc;
    }
    // Use page allocator as fallback if no global allocator set
    return std.heap.page_allocator;
}

/// Create a new accessibility bridge
pub fn accessibilityCreateBridge() ?*AccessibilityBridge {
    return AccessibilityBridge.init(getAllocator()) catch |err| {
        logger.err("Failed to create accessibility bridge: {}", .{err});
        return null;
    };
}

/// Destroy an accessibility bridge
pub fn accessibilityDestroyBridge(bridge: *AccessibilityBridge) void {
    bridge.deinit();
}

/// Enable or disable accessibility
pub fn accessibilitySetEnabled(bridge: *AccessibilityBridge, enabled: bool) void {
    bridge.setEnabled(enabled);
}

/// Check if accessibility is enabled
pub fn accessibilityIsEnabled(bridge: *AccessibilityBridge) bool {
    return bridge.isEnabled();
}

/// Add or update a node
pub fn accessibilityUpsertNode(bridge: *AccessibilityBridge, data: *const types.NodeData) bool {
    bridge.upsertNode(data) catch |err| {
        logger.err("Failed to upsert accessibility node: {}", .{err});
        return false;
    };
    return true;
}

/// Remove a node
pub fn accessibilityRemoveNode(bridge: *AccessibilityBridge, id_ptr: [*]const u8, id_len: usize) bool {
    bridge.removeNode(id_ptr, id_len) catch |err| {
        logger.err("Failed to remove accessibility node: {}", .{err});
        return false;
    };
    return true;
}

/// Set focus to a node (pass null id_ptr to clear focus)
pub fn accessibilitySetFocus(bridge: *AccessibilityBridge, id_ptr: ?[*]const u8, id_len: usize) bool {
    bridge.setFocus(id_ptr, id_len) catch |err| {
        logger.err("Failed to set accessibility focus: {}", .{err});
        return false;
    };
    return true;
}

/// Announce a message
pub fn accessibilityAnnounce(bridge: *AccessibilityBridge, message_ptr: [*]const u8, message_len: usize, priority: u8) bool {
    const live_setting: types.LiveSetting = switch (priority) {
        0 => .off,
        1 => .polite,
        2 => .assertive,
        else => .polite,
    };
    bridge.announce(message_ptr, message_len, live_setting) catch |err| {
        logger.err("Failed to announce: {}", .{err});
        return false;
    };
    return true;
}

/// Notify property changed
pub fn accessibilityNotifyPropertyChanged(bridge: *AccessibilityBridge, id_ptr: [*]const u8, id_len: usize, property: u32) bool {
    const prop: types.Property = @enumFromInt(property);
    bridge.notifyPropertyChanged(id_ptr, id_len, prop) catch |err| {
        logger.err("Failed to notify property change: {}", .{err});
        return false;
    };
    return true;
}

/// Set action callback
pub fn accessibilitySetActionCallback(bridge: *AccessibilityBridge, callback: ?types.ActionCallback) void {
    bridge.setActionCallback(callback);
}

/// Get node count
pub fn accessibilityGetNodeCount(bridge: *AccessibilityBridge) usize {
    return bridge.getNodeCount();
}

/// Clear all nodes
pub fn accessibilityClear(bridge: *AccessibilityBridge) void {
    bridge.clear();
}

// Performs any periodic updates needed by platforms
pub fn accessibilityTick(bridge: *AccessibilityBridge) void {
    bridge.tick();
}

/// Check if platform is supported
pub fn accessibilityIsPlatformSupported() bool {
    return platform_mod.isPlatformSupported();
}

/// Get platform name
pub fn accessibilityGetPlatformName(out_ptr: [*]u8, max_len: usize) usize {
    const name = platform_mod.getPlatformName();
    const copy_len = @min(name.len, max_len);
    @memcpy(out_ptr[0..copy_len], name[0..copy_len]);
    return copy_len;
}

// ============================================================================
// Tests
// ============================================================================

test "AccessibilityBridge basic operations" {
    const allocator = std.testing.allocator;

    const bridge = try AccessibilityBridge.init(allocator);
    defer bridge.deinit();

    // Create test node data
    const id = "test-button";
    const name = "Click Me";
    const data = types.NodeData{
        .id_ptr = id.ptr,
        .id_len = id.len,
        .role = .button,
        .name_ptr = name.ptr,
        .name_len = name.len,
        .value_ptr = null,
        .value_len = 0,
        .description_ptr = null,
        .description_len = 0,
        .hint_ptr = null,
        .hint_len = 0,
        .rect = .{ .x = 0, .y = 0, .width = 10, .height = 1 },
        .state_flags = .{ .focusable = true },
        .parent_id_ptr = null,
        .parent_id_len = 0,
        .child_count = 0,
        .live_setting = .off,
        .orientation = .horizontal,
        .level = 0,
        .min_value = 0,
        .max_value = 0,
        .current_value = 0,
    };

    // Add node
    try bridge.upsertNode(&data);
    try std.testing.expectEqual(@as(usize, 1), bridge.getNodeCount());

    // Set focus
    try bridge.setFocus(id.ptr, id.len);

    // Remove node
    try bridge.removeNode(id.ptr, id.len);
    try std.testing.expectEqual(@as(usize, 0), bridge.getNodeCount());
}

test "AccessibilityBridge enable/disable" {
    const allocator = std.testing.allocator;

    const bridge = try AccessibilityBridge.init(allocator);
    defer bridge.deinit();

    try std.testing.expect(bridge.isEnabled());

    bridge.setEnabled(false);
    try std.testing.expect(!bridge.isEnabled());

    bridge.setEnabled(true);
    try std.testing.expect(bridge.isEnabled());
}
