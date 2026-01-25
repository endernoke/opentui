//! Linux AT-SPI2 accessibility implementation
//!
//! This module implements the platform bridge for Linux using the AT-SPI2 API.
//! AT-SPI2 (Assistive Technology Service Provider Interface) is the standard
//! accessibility framework for Linux desktops (GNOME, KDE, etc.).
//!
//! Architecture:
//! - Connects to the AT-SPI2 bus via D-Bus
//! - Registers as an AT-SPI2 accessible application
//! - Each AccessibilityNode is exposed as an AT-SPI2 accessible object
//! - Implements the Accessible, Component, and relevant interfaces
//! - Emits AT-SPI2 events for focus, property, and structure changes
//!
//! Note: This is a stub implementation for Phase 2. Full AT-SPI2 integration
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

pub const LinuxATSPI = struct {
    allocator: Allocator,
    action_callback: ?types.ActionCallback,

    // AT-SPI2 state (will be expanded in Phase 2.5)
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

        // Initialize AT-SPI2
        self.initializeATSPI() catch |err| {
            logger.warn("Failed to initialize Linux AT-SPI2: {}", .{err});
            // Continue with uninitialized state - methods will be no-ops
        };

        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// Initialize AT-SPI2 infrastructure
    fn initializeATSPI(self: *Self) !void {
        if (builtin.os.tag != .linux) {
            return;
        }

        // TODO: Phase 2.5 - Full AT-SPI2 implementation
        // 1. Connect to the session D-Bus
        // 2. Get the AT-SPI2 registry object
        // 3. Register this application as an accessible
        // 4. Set up the root accessible object
        // 5. Implement the Accessible interface

        logger.info("Linux AT-SPI2 accessibility bridge initialized (stub)", .{});
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

        // TODO: Disconnect from D-Bus and clean up AT-SPI2 resources

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

        // TODO: Emit AT-SPI2 children-changed::add event
        logger.debug("AT-SPI2: Added node '{s}' with role {s}", .{ node.id, node.role.name() });
    }

    fn updateNode(ctx: *anyopaque, node: *AccessibilityNode) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        if (!self.nodes.contains(node.id)) {
            return PlatformBridge.Error.NodeNotFound;
        }

        // TODO: Emit AT-SPI2 property-change events
        logger.debug("AT-SPI2: Updated node '{s}'", .{node.id});
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

        // TODO: Emit AT-SPI2 children-changed::remove event
        logger.debug("AT-SPI2: Removed node '{s}'", .{node.id});
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
            // TODO: Emit AT-SPI2 focus event
            logger.debug("AT-SPI2: Focus changed to '{s}'", .{n.id});
        } else {
            self.focused_node_id = null;
            logger.debug("AT-SPI2: Focus cleared", .{});
        }
    }

    fn notifyPropertyChanged(ctx: *anyopaque, node: *AccessibilityNode, property: types.Property) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        if (!self.nodes.contains(node.id)) {
            return PlatformBridge.Error.NodeNotFound;
        }

        // TODO: Emit AT-SPI2 property-change event
        logger.debug("AT-SPI2: Property '{s}' changed for node '{s}'", .{ @tagName(property), node.id });
    }

    fn announce(ctx: *anyopaque, message: []const u8, priority: types.LiveSetting) PlatformBridge.Error!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (!self.initialized) return;

        // TODO: Emit AT-SPI2 announcement event
        // Use object:text-changed:insert or a dedicated live region approach

        const priority_str = switch (priority) {
            .off => "off",
            .polite => "polite",
            .assertive => "assertive",
        };
        logger.debug("AT-SPI2: Announce ({s}): {s}", .{ priority_str, message });
    }

    fn setActionCallback(ctx: *anyopaque, callback: ?types.ActionCallback) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.action_callback = callback;
    }

    /// Map accessibility role to AT-SPI2 role
    /// AT-SPI2 roles are defined in atspi-constants.h
    pub fn roleToATSPIRole(role: types.Role) u32 {
        // AT-SPI2 Role constants (from atspi-constants.h)
        const ATSPI_ROLE_INVALID: u32 = 0;
        const ATSPI_ROLE_PUSH_BUTTON: u32 = 42;
        const ATSPI_ROLE_CHECK_BOX: u32 = 15;
        const ATSPI_ROLE_TEXT: u32 = 60;
        const ATSPI_ROLE_RADIO_BUTTON: u32 = 43;
        const ATSPI_ROLE_COMBO_BOX: u32 = 17;
        const ATSPI_ROLE_LIST: u32 = 34;
        const ATSPI_ROLE_LIST_ITEM: u32 = 35;
        const ATSPI_ROLE_MENU: u32 = 37;
        const ATSPI_ROLE_MENU_ITEM: u32 = 38;
        const ATSPI_ROLE_MENU_BAR: u32 = 36;
        const ATSPI_ROLE_PAGE_TAB: u32 = 39;
        const ATSPI_ROLE_PAGE_TAB_LIST: u32 = 40;
        const ATSPI_ROLE_DIALOG: u32 = 23;
        const ATSPI_ROLE_ALERT: u32 = 2;
        const ATSPI_ROLE_PROGRESS_BAR: u32 = 41;
        const ATSPI_ROLE_SLIDER: u32 = 53;
        const ATSPI_ROLE_SCROLL_BAR: u32 = 47;
        const ATSPI_ROLE_SEPARATOR: u32 = 49;
        const ATSPI_ROLE_PANEL: u32 = 25;
        const ATSPI_ROLE_IMAGE: u32 = 26;
        const ATSPI_ROLE_LINK: u32 = 70;
        const ATSPI_ROLE_HEADING: u32 = 68;
        const ATSPI_ROLE_PARAGRAPH: u32 = 73;
        const ATSPI_ROLE_FRAME: u32 = 22;
        const ATSPI_ROLE_TREE: u32 = 64;
        const ATSPI_ROLE_TREE_ITEM: u32 = 65;
        const ATSPI_ROLE_UNKNOWN: u32 = 66;

        return switch (role) {
            .button => ATSPI_ROLE_PUSH_BUTTON,
            .checkbox => ATSPI_ROLE_CHECK_BOX,
            .textbox => ATSPI_ROLE_TEXT,
            .radio => ATSPI_ROLE_RADIO_BUTTON,
            .combobox => ATSPI_ROLE_COMBO_BOX,
            .list => ATSPI_ROLE_LIST,
            .list_item => ATSPI_ROLE_LIST_ITEM,
            .menu => ATSPI_ROLE_MENU,
            .menu_item => ATSPI_ROLE_MENU_ITEM,
            .menu_bar => ATSPI_ROLE_MENU_BAR,
            .tab => ATSPI_ROLE_PAGE_TAB,
            .tab_list => ATSPI_ROLE_PAGE_TAB_LIST,
            .dialog => ATSPI_ROLE_DIALOG,
            .alert => ATSPI_ROLE_ALERT,
            .progressbar => ATSPI_ROLE_PROGRESS_BAR,
            .slider => ATSPI_ROLE_SLIDER,
            .scrollbar => ATSPI_ROLE_SCROLL_BAR,
            .separator => ATSPI_ROLE_SEPARATOR,
            .group, .region => ATSPI_ROLE_PANEL,
            .image => ATSPI_ROLE_IMAGE,
            .link => ATSPI_ROLE_LINK,
            .heading => ATSPI_ROLE_HEADING,
            .paragraph => ATSPI_ROLE_PARAGRAPH,
            .window => ATSPI_ROLE_FRAME,
            .tree => ATSPI_ROLE_TREE,
            .tree_item => ATSPI_ROLE_TREE_ITEM,
            .none => ATSPI_ROLE_INVALID,
            else => ATSPI_ROLE_UNKNOWN,
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
test "LinuxATSPI role mapping" {
    try std.testing.expectEqual(@as(u32, 42), LinuxATSPI.roleToATSPIRole(.button));
    try std.testing.expectEqual(@as(u32, 15), LinuxATSPI.roleToATSPIRole(.checkbox));
    try std.testing.expectEqual(@as(u32, 60), LinuxATSPI.roleToATSPIRole(.textbox));
}
