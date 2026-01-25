//! macOS NSAccessibility implementation
//!
//! This module implements the platform bridge for macOS using the NSAccessibility API.
//! NSAccessibility is the native accessibility framework for macOS, used by VoiceOver
//! and other assistive technologies.
//!
//! Architecture:
//! - Creates NSAccessibilityElement objects for each AccessibilityNode
//! - Implements the NSAccessibility protocol methods
//! - Posts NSAccessibility notifications for focus, property, and structure changes
//! - Integrates with the application's NSWindow hierarchy
//!
//! Note: This is a stub implementation for Phase 2. Full NSAccessibility integration
//! will be implemented in Phase 2.5.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const types = @import("../types.zig");
const node_mod = @import("../node.zig");
const logger = @import("../../logger.zig");

const AccessibilityNode = node_mod.AccessibilityNode;
const PlatformBridge = platform.PlatformBridge;
const Allocator = std.mem.Allocator;

pub const MacOSNSA = struct {
    allocator: Allocator,
    action_callback: ?types.ActionCallback,

    // NSAccessibility state (will be expanded in Phase 2.5)
    nodes: std.StringHashMap(*AccessibilityNode),
    root_node_id: ?[]const u8,
    focused_node_id: ?[]const u8,

    // Initialization state
    initialized: bool,

    const Self = @This();

    pub fn create(allocator: Allocator) !PlatformBridge {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .action_callback = null,
            .nodes = std.StringHashMap(*AccessibilityNode).init(allocator),
            .root_node_id = null,
            .focused_node_id = null,
            .initialized = false,
        };

        // Initialize NSAccessibility
        self.initializeNSAccessibility() catch |err| {
            logger.warn("Failed to initialize macOS NSAccessibility: {}", .{err});
            // Continue with uninitialized state - methods will be no-ops
        };

        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// Initialize NSAccessibility infrastructure
    fn initializeNSAccessibility(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            return;
        }

        // TODO: Phase 2.5 - Full NSAccessibility implementation
        // 1. Get the application's main window
        // 2. Create a custom NSAccessibilityElement subclass
        // 3. Set up the accessibility hierarchy
        // 4. Implement required NSAccessibility protocol methods

        logger.info("macOS NSAccessibility bridge initialized (stub)", .{});
        self.initialized = true;
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // Clean up tracked nodes (we don't own them, just clear references)
        self.nodes.deinit();

        if (self.root_node_id) |id| {
            self.allocator.free(id);
        }
        if (self.focused_node_id) |id| {
            self.allocator.free(id);
        }

        // TODO: Clean up NSAccessibilityElement objects

        self.allocator.destroy(self);
    }

    fn addNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // Track node reference
        self.nodes.put(node.id, node) catch {
            return PlatformBridge.Error.OutOfMemory;
        };

        // Set as root if no parent
        if (node.parent_id == null) {
            if (self.root_node_id) |old_id| {
                self.allocator.free(old_id);
            }
            self.root_node_id = self.allocator.dupe(u8, node.id) catch {
                return PlatformBridge.Error.OutOfMemory;
            };
        }

        // TODO: Create NSAccessibilityElement and post NSAccessibilityCreatedNotification
        logger.debug("NSAccessibility: Added node '{s}' with role {s}", .{ node.id, node.role.name() });
    }

    fn updateNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        if (!self.nodes.contains(node.id)) {
            return PlatformBridge.Error.NodeNotFound;
        }

        // TODO: Post appropriate NSAccessibility notifications
        logger.debug("NSAccessibility: Updated node '{s}'", .{node.id});
    }

    fn removeNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        _ = self.nodes.remove(node.id);

        // Clear root if this was the root
        if (self.root_node_id) |root_id| {
            if (std.mem.eql(u8, root_id, node.id)) {
                self.allocator.free(root_id);
                self.root_node_id = null;
            }
        }

        // Clear focus if this was focused
        if (self.focused_node_id) |focused_id| {
            if (std.mem.eql(u8, focused_id, node.id)) {
                self.allocator.free(focused_id);
                self.focused_node_id = null;
            }
        }

        // TODO: Post NSAccessibilityUIElementDestroyedNotification
        logger.debug("NSAccessibility: Removed node '{s}'", .{node.id});
    }

    fn notifyFocusChanged(ctx: *anyopaque, node: ?*AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // Update tracked focus
        if (self.focused_node_id) |old_id| {
            self.allocator.free(old_id);
        }

        if (node) |n| {
            self.focused_node_id = self.allocator.dupe(u8, n.id) catch {
                return PlatformBridge.Error.OutOfMemory;
            };
            // TODO: Post NSAccessibilityFocusedUIElementChangedNotification
            logger.debug("NSAccessibility: Focus changed to '{s}'", .{n.id});
        } else {
            self.focused_node_id = null;
            logger.debug("NSAccessibility: Focus cleared", .{});
        }
    }

    fn notifyPropertyChanged(ctx: *anyopaque, node: *AccessibilityNode, property: types.Property) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        if (!self.nodes.contains(node.id)) {
            return PlatformBridge.Error.NodeNotFound;
        }

        // TODO: Post appropriate NSAccessibility notification based on property
        // NSAccessibilityTitleChangedNotification, NSAccessibilityValueChangedNotification, etc.
        logger.debug("NSAccessibility: Property '{s}' changed for node '{s}'", .{ @tagName(property), node.id });
    }

    fn announce(ctx: *anyopaque, message: []const u8, priority: types.LiveSetting) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO: Post NSAccessibilityAnnouncementRequestedNotification
        // With NSAccessibilityAnnouncementKey and NSAccessibilityPriorityKey

        const priority_str = switch (priority) {
            .off => "off",
            .polite => "polite",
            .assertive => "assertive",
        };
        logger.debug("NSAccessibility: Announce ({s}): {s}", .{ priority_str, message });
    }

    fn setActionCallback(ctx: *anyopaque, callback: ?types.ActionCallback) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.action_callback = callback;
    }

    /// Map accessibility role to NSAccessibility role
    /// NSAccessibility roles are string constants defined in AppKit
    pub fn roleToNSARole(role: types.Role) []const u8 {
        return switch (role) {
            .button => "AXButton",
            .checkbox => "AXCheckBox",
            .textbox => "AXTextField",
            .radio => "AXRadioButton",
            .combobox => "AXComboBox",
            .list => "AXList",
            .list_item => "AXStaticText", // macOS uses different approach
            .menu => "AXMenu",
            .menu_item => "AXMenuItem",
            .menu_bar => "AXMenuBar",
            .tab => "AXRadioButton", // Tab buttons are often radio buttons
            .tab_list => "AXTabGroup",
            .tab_panel => "AXGroup",
            .dialog => "AXSheet",
            .alert => "AXSheet",
            .progressbar => "AXProgressIndicator",
            .slider => "AXSlider",
            .scrollbar => "AXScrollBar",
            .separator => "AXSplitter",
            .group => "AXGroup",
            .region => "AXGroup",
            .image => "AXImage",
            .link => "AXLink",
            .heading => "AXStaticText",
            .paragraph => "AXStaticText",
            .window => "AXWindow",
            .tree => "AXOutline",
            .tree_item => "AXRow",
            .grid => "AXTable",
            .grid_cell => "AXCell",
            .row => "AXRow",
            .column_header => "AXColumn",
            .row_header => "AXRow",
            .tooltip => "AXHelpTag",
            .status => "AXStaticText",
            .toolbar => "AXToolbar",
            .search => "AXTextField",
            .form => "AXGroup",
            .article => "AXGroup",
            .document => "AXScrollArea",
            .application => "AXApplication",
            .none => "AXUnknown",
            .custom => "AXUnknown",
        };
    }

    const vtable = PlatformBridge.VTable{
        .deinit = deinit,
        .addNode = addNode,
        .updateNode = updateNode,
        .removeNode = removeNode,
        .notifyFocusChanged = notifyFocusChanged,
        .notifyPropertyChanged = notifyPropertyChanged,
        .announce = announce,
        .setActionCallback = setActionCallback,
    };
};

// Tests
test "MacOSNSA role mapping" {
    try std.testing.expectEqualStrings("AXButton", MacOSNSA.roleToNSARole(.button));
    try std.testing.expectEqualStrings("AXCheckBox", MacOSNSA.roleToNSARole(.checkbox));
    try std.testing.expectEqualStrings("AXTextField", MacOSNSA.roleToNSARole(.textbox));
}
