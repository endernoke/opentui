//! Accessibility Node representation for OpenTUI
//!
//! This module provides the internal node representation used by the accessibility bridge.
//! Nodes are stored in the native layer and mirror the TypeScript AccessibilityNode structure.

const std = @import("std");
const types = @import("types.zig");

const Allocator = std.mem.Allocator;

/// Native representation of an accessibility node
/// This is the internal storage format, separate from the FFI NodeData
pub const AccessibilityNode = struct {
    allocator: Allocator,

    // Node identity
    id: []const u8,

    // Properties
    role: types.Role,
    name: ?[]const u8,
    value: ?[]const u8,
    description: ?[]const u8,
    hint: ?[]const u8,
    rect: types.Rect,
    state: types.StateFlags,
    live: types.LiveSetting,
    orientation: types.Orientation,
    level: u8,

    // Numeric properties (for sliders, progress bars)
    min_value: f64,
    max_value: f64,
    current_value: f64,

    // Hierarchy (stored as IDs, resolved via bridge)
    parent_id: ?[]const u8,
    children_ids: std.ArrayList([]const u8),

    // Platform-specific data (opaque pointer managed by platform implementation)
    platform_data: ?*anyopaque,

    // Dirty flags for incremental updates
    dirty: bool,

    /// Create a new node from FFI NodeData
    pub fn init(allocator: Allocator, data: *const types.NodeData) !*AccessibilityNode {
        const node = try allocator.create(AccessibilityNode);
        errdefer allocator.destroy(node);

        node.* = AccessibilityNode{
            .allocator = allocator,
            .id = try allocator.dupe(u8, data.getId()),
            .role = data.role,
            .name = if (data.getName()) |n| try allocator.dupe(u8, n) else null,
            .value = if (data.getValue()) |v| try allocator.dupe(u8, v) else null,
            .description = if (data.getDescription()) |d| try allocator.dupe(u8, d) else null,
            .hint = if (data.getHint()) |h| try allocator.dupe(u8, h) else null,
            .rect = data.rect,
            .state = data.state_flags,
            .live = data.live_setting,
            .orientation = data.orientation,
            .level = data.level,
            .min_value = data.min_value,
            .max_value = data.max_value,
            .current_value = data.current_value,
            .parent_id = if (data.getParentId()) |p| try allocator.dupe(u8, p) else null,
            .children_ids = .{},
            .platform_data = null,
            .dirty = true,
        };

        return node;
    }

    /// Clean up all allocated memory
    pub fn deinit(self: *AccessibilityNode) void {
        self.allocator.free(self.id);
        if (self.name) |n| self.allocator.free(n);
        if (self.value) |v| self.allocator.free(v);
        if (self.description) |d| self.allocator.free(d);
        if (self.hint) |h| self.allocator.free(h);
        if (self.parent_id) |p| self.allocator.free(p);

        for (self.children_ids.items) |child_id| {
            self.allocator.free(child_id);
        }
        self.children_ids.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Update node properties from new FFI data
    /// Returns true if any property changed
    pub fn updateFromData(self: *AccessibilityNode, data: *const types.NodeData) !bool {
        var changed = false;

        // Update role
        if (self.role != data.role) {
            self.role = data.role;
            changed = true;
        }

        // Update name
        const new_name = data.getName();
        if (!optionalSliceEqual(self.name, new_name)) {
            if (self.name) |n| self.allocator.free(n);
            self.name = if (new_name) |n| try self.allocator.dupe(u8, n) else null;
            changed = true;
        }

        // Update value
        const new_value = data.getValue();
        if (!optionalSliceEqual(self.value, new_value)) {
            if (self.value) |v| self.allocator.free(v);
            self.value = if (new_value) |v| try self.allocator.dupe(u8, v) else null;
            changed = true;
        }

        // Update description
        const new_desc = data.getDescription();
        if (!optionalSliceEqual(self.description, new_desc)) {
            if (self.description) |d| self.allocator.free(d);
            self.description = if (new_desc) |d| try self.allocator.dupe(u8, d) else null;
            changed = true;
        }

        // Update hint
        const new_hint = data.getHint();
        if (!optionalSliceEqual(self.hint, new_hint)) {
            if (self.hint) |h| self.allocator.free(h);
            self.hint = if (new_hint) |h| try self.allocator.dupe(u8, h) else null;
            changed = true;
        }

        // Update rect
        if (!std.meta.eql(self.rect, data.rect)) {
            self.rect = data.rect;
            changed = true;
        }

        // Update state
        if (self.state.toU32() != data.state_flags.toU32()) {
            self.state = data.state_flags;
            changed = true;
        }

        // Update live setting
        if (self.live != data.live_setting) {
            self.live = data.live_setting;
            changed = true;
        }

        // Update orientation
        if (self.orientation != data.orientation) {
            self.orientation = data.orientation;
            changed = true;
        }

        // Update level
        if (self.level != data.level) {
            self.level = data.level;
            changed = true;
        }

        // Update numeric values
        if (self.min_value != data.min_value) {
            self.min_value = data.min_value;
            changed = true;
        }
        if (self.max_value != data.max_value) {
            self.max_value = data.max_value;
            changed = true;
        }
        if (self.current_value != data.current_value) {
            self.current_value = data.current_value;
            changed = true;
        }

        // Update parent_id
        const new_parent = data.getParentId();
        if (!optionalSliceEqual(self.parent_id, new_parent)) {
            if (self.parent_id) |p| self.allocator.free(p);
            self.parent_id = if (new_parent) |p| try self.allocator.dupe(u8, p) else null;
            changed = true;
        }

        if (changed) {
            self.dirty = true;
        }

        return changed;
    }

    /// Add a child ID to this node
    pub fn addChild(self: *AccessibilityNode, child_id: []const u8) !void {
        const id_copy = try self.allocator.dupe(u8, child_id);
        try self.children_ids.append(self.allocator, id_copy);
        self.dirty = true;
    }

    /// Remove a child ID from this node
    pub fn removeChild(self: *AccessibilityNode, child_id: []const u8) void {
        var i: usize = 0;
        while (i < self.children_ids.items.len) {
            if (std.mem.eql(u8, self.children_ids.items[i], child_id)) {
                self.allocator.free(self.children_ids.items[i]);
                _ = self.children_ids.orderedRemove(i);
                self.dirty = true;
                return;
            }
            i += 1;
        }
    }

    /// Clear all children
    pub fn clearChildren(self: *AccessibilityNode) void {
        for (self.children_ids.items) |child_id| {
            self.allocator.free(child_id);
        }
        self.children_ids.clearRetainingCapacity();
        self.dirty = true;
    }

    /// Check if node is focusable
    pub fn isFocusable(self: *const AccessibilityNode) bool {
        return self.state.focusable;
    }

    /// Check if node is focused
    pub fn isFocused(self: *const AccessibilityNode) bool {
        return self.state.focused;
    }

    /// Check if node is hidden from accessibility tree
    pub fn isHidden(self: *const AccessibilityNode) bool {
        return self.state.hidden;
    }

    /// Get the accessible name (label)
    pub fn getAccessibleName(self: *const AccessibilityNode) ?[]const u8 {
        return self.name;
    }

    /// Mark node as clean (after platform sync)
    pub fn markClean(self: *AccessibilityNode) void {
        self.dirty = false;
    }
};

/// Helper to compare optional slices
fn optionalSliceEqual(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

// Tests
test "AccessibilityNode creation and update" {
    const allocator = std.testing.allocator;

    // Create test node data
    const id = "test-node-1";
    const name = "Test Button";
    const value = "clicked";

    var data = types.NodeData{
        .id_ptr = id.ptr,
        .id_len = id.len,
        .role = .button,
        .name_ptr = name.ptr,
        .name_len = name.len,
        .value_ptr = value.ptr,
        .value_len = value.len,
        .description_ptr = null,
        .description_len = 0,
        .hint_ptr = null,
        .hint_len = 0,
        .rect = .{ .x = 10, .y = 20, .width = 100, .height = 30 },
        .state_flags = .{ .focusable = true },
        .parent_id_ptr = null,
        .parent_id_len = 0,
        .child_count = 0,
        .live_setting = .off,
        .orientation = .horizontal,
        .level = 0,
        .min_value = 0,
        .max_value = 100,
        .current_value = 50,
    };

    const node = try AccessibilityNode.init(allocator, &data);
    defer node.deinit();

    try std.testing.expectEqualStrings("test-node-1", node.id);
    try std.testing.expectEqualStrings("Test Button", node.name.?);
    try std.testing.expect(node.role == .button);
    try std.testing.expect(node.isFocusable());
    try std.testing.expect(!node.isFocused());
}

test "AccessibilityNode child management" {
    const allocator = std.testing.allocator;

    const id = "parent";
    var data = types.NodeData{
        .id_ptr = id.ptr,
        .id_len = id.len,
        .role = .group,
        .name_ptr = null,
        .name_len = 0,
        .value_ptr = null,
        .value_len = 0,
        .description_ptr = null,
        .description_len = 0,
        .hint_ptr = null,
        .hint_len = 0,
        .rect = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .state_flags = .{},
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

    const node = try AccessibilityNode.init(allocator, &data);
    defer node.deinit();

    try node.addChild("child-1");
    try node.addChild("child-2");
    try std.testing.expectEqual(@as(usize, 2), node.children_ids.items.len);

    node.removeChild("child-1");
    try std.testing.expectEqual(@as(usize, 1), node.children_ids.items.len);
    try std.testing.expectEqualStrings("child-2", node.children_ids.items[0]);
}
